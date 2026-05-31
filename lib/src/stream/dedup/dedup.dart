/// Cross-stream message deduplication.
///
/// Mirrors `internal/stream/dedup.go`. The CLOB market feed is often
/// consumed across multiple WebSocket connections for redundancy; this
/// deduplicator keeps a small TTL-bounded set of recently-seen message keys
/// so the consumer only sees each event once.
///
/// The canonical key rules (`extractKey`) match polygolem verbatim:
///
/// * `book` / `tick_size_change` → `eventType:hash`
/// * `price_change` → `pc:hash`, falling back to `pc:market:timestamp`
/// * `last_trade_price` → `ltp:assetId:price:size`
///
/// When no key can be extracted (parse failure, unknown event, missing
/// hash/asset) the message is treated as new.
library;

import 'dart:convert';

import '../shared/json_array_frame.dart';

/// TTL-bounded set of recently seen message keys.
final class Deduplicator {
  Deduplicator({
    required int size,
    required Duration ttl,
    DateTime Function()? clock,
  }) : _size = size,
       _ttlMs = ttl.inMilliseconds,
       _clock = clock ?? DateTime.now;

  final int _size;
  final int _ttlMs;
  final DateTime Function() _clock;
  final Map<String, int> _seen = <String, int>{};

  int _in = 0;
  int _dup = 0;
  int _out = 0;

  /// Total messages observed (whether new or duplicate).
  int get inCount => _in;

  /// Messages dropped as duplicates within TTL.
  int get dupCount => _dup;

  /// Messages forwarded to consumers.
  int get outCount => _out;

  /// Returns `true` if [data] is a brand-new message, `false` if it
  /// duplicates a still-live key. An empty key (parse failure or unknown
  /// event shape) counts as new.
  bool process(List<int> data) {
    final extraction = extractDedupKey(data);
    if (!extraction.hasKey) {
      _in += 1;
      _out += 1;
      return true;
    }
    final key = extraction.key;

    final nowMs = _clock().millisecondsSinceEpoch;
    _in += 1;

    final seenAt = _seen[key];
    if (seenAt != null && (nowMs - seenAt) < _ttlMs) {
      _dup += 1;
      return false;
    }

    _rememberKey(key, nowMs);
    _out += 1;
    return true;
  }

  /// Drops every key and zeroes the counters.
  void reset() {
    _seen.clear();
    _in = 0;
    _dup = 0;
    _out = 0;
  }

  void _rememberKey(String key, int nowMs) {
    // Reinsert so a key that was seen after TTL expiry becomes newest in the
    // insertion-ordered map before size-based eviction runs.
    _seen.remove(key);
    _seen[key] = nowMs;
    _evictExpired(nowMs);
    _evictOverflow();
  }

  void _evictExpired(int nowMs) {
    _seen.removeWhere((_, ts) => (nowMs - ts) >= _ttlMs);
  }

  void _evictOverflow() {
    if (_size <= 0) {
      _seen.clear();
      return;
    }
    while (_seen.length > _size) {
      _seen.remove(_seen.keys.first);
    }
  }
}

/// Why a payload did or did not produce a replayable deduplication key.
enum DedupKeyStatus {
  keyed,
  emptyPayload,
  invalidJson,
  nonObjectJson,
  unknownEventType,
  missingRequiredFields,
}

/// Replayable result of extracting a deduplication key from one stream frame.
final class DedupKeyExtraction {
  const DedupKeyExtraction._(this.status, this.key);

  const DedupKeyExtraction.keyed(String key)
    : this._(DedupKeyStatus.keyed, key);

  const DedupKeyExtraction.unkeyed(DedupKeyStatus status) : this._(status, '');

  final DedupKeyStatus status;
  final String key;

  bool get hasKey => status == DedupKeyStatus.keyed;
}

/// Extracts the canonical deduplication key for a single stream frame.
DedupKeyExtraction extractDedupKey(List<int> data) {
  if (data.isEmpty) {
    return const DedupKeyExtraction.unkeyed(DedupKeyStatus.emptyPayload);
  }
  Object? decoded;
  try {
    decoded = json.decode(utf8.decode(data));
  } on FormatException {
    return const DedupKeyExtraction.unkeyed(DedupKeyStatus.invalidJson);
  }
  if (decoded is! Map) {
    return const DedupKeyExtraction.unkeyed(DedupKeyStatus.nonObjectJson);
  }
  final m = decoded.map((k, v) => MapEntry(k.toString(), v));
  String pick(String key) => (m[key] ?? '').toString();

  final eventType = pick('event_type');
  final hash = pick('hash');
  switch (eventType) {
    case 'book':
    case 'tick_size_change':
      if (hash.isNotEmpty) return DedupKeyExtraction.keyed('$eventType:$hash');
      return const DedupKeyExtraction.unkeyed(
        DedupKeyStatus.missingRequiredFields,
      );
    case 'price_change':
      return _keyedOrMissing(
        _priceChangeKey(
          hash: hash,
          market: pick('market'),
          timestamp: pick('timestamp'),
        ),
      );
    case 'last_trade_price':
      return _keyedOrMissing(
        _lastTradePriceKey(
          assetId: pick('asset_id'),
          price: pick('price'),
          size: pick('size'),
        ),
      );
  }
  return const DedupKeyExtraction.unkeyed(DedupKeyStatus.unknownEventType);
}

DedupKeyExtraction _keyedOrMissing(String key) => key.isEmpty
    ? const DedupKeyExtraction.unkeyed(DedupKeyStatus.missingRequiredFields)
    : DedupKeyExtraction.keyed(key);

String _priceChangeKey({
  required String hash,
  required String market,
  required String timestamp,
}) {
  if (hash.isNotEmpty) return 'pc:$hash';
  if (market.isEmpty || timestamp.isEmpty) return '';
  return 'pc:$market:$timestamp';
}

String _lastTradePriceKey({
  required String assetId,
  required String price,
  required String size,
}) {
  if (assetId.isEmpty || price.isEmpty || size.isEmpty) return '';
  return 'ltp:$assetId:$price:$size';
}

/// Splits a JSON array of CLOB market events into individual byte payloads.
/// Mirrors `internal/stream::SplitArray`. Returns an empty list if [data] is
/// empty, isn't a JSON array, or fails to parse.
List<List<int>> splitArray(List<int> data) => splitJsonArrayFrame(data).frames;
