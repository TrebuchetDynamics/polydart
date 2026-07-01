/// Polymarket web-app read endpoints.
library;

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/market.dart';

final class PolymarketCryptoCounts {
  const PolymarketCryptoCounts(this.counts);

  static const empty = PolymarketCryptoCounts(<String, int>{});

  factory PolymarketCryptoCounts.fromJson(Map<String, dynamic> json) {
    final parsed = <String, int>{};
    for (final entry in json.entries) {
      final key = entry.key.trim();
      final value = _parseCount(entry.value);
      if (key.isNotEmpty && value != null) parsed[key] = value;
    }
    return PolymarketCryptoCounts(Map.unmodifiable(parsed));
  }

  final Map<String, int> counts;

  int countFor(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) return 0;
    return counts[normalized] ??
        counts[_canonicalCryptoCountKey(normalized)] ??
        counts[normalized.toLowerCase()] ??
        0;
  }

  int get all => countFor('all');
  int get fiveMinute => countFor('fiveM');
  int get fifteenMinute => countFor('fifteenM');
  int get preMarket => countFor('pre-market');
  int get etf => countFor('etf');
  int get hourly => countFor('hourly');
  int get fourHour => countFor('fourhour');
  int get daily => countFor('daily');
  int get weekly => countFor('weekly');
}

final class PolymarketCryptoMarketsResponse {
  const PolymarketCryptoMarketsResponse({required this.events});

  factory PolymarketCryptoMarketsResponse.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    return PolymarketCryptoMarketsResponse(
      events: rawEvents is List
          ? rawEvents
                .whereType<Map<dynamic, dynamic>>()
                .map((event) => Event.fromJson(event.cast<String, dynamic>()))
                .toList(growable: false)
          : const <Event>[],
    );
  }

  final List<Event> events;
}

final class PolymarketWebClient {
  PolymarketWebClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  static const String defaultBaseUrl = 'https://polymarket.com';

  final HttpTransport _transport;

  Future<PolymarketCryptoCounts> cryptoCounts() async {
    final raw = await _transport.getJson('/api/crypto/counts');
    return PolymarketCryptoCounts.fromJson(raw);
  }

  Future<PolymarketCryptoMarketsResponse> cryptoMarkets({
    String category = '',
    String sort = 'volume24hr',
    String status = 'active',
    int limit = 20,
    int offset = 0,
  }) async {
    final normalized = category.trim();
    final raw = await _transport.getJson(
      '/api/crypto/markets',
      query: normalized.isEmpty
          ? null
          : <String, dynamic>{
              '_c': normalized,
              '_s': sort,
              '_sts': status,
              '_l': limit.toString(),
              '_offset': offset.toString(),
            },
    );
    return PolymarketCryptoMarketsResponse.fromJson(raw);
  }

  Future<List<Tag>> filteredTags(
    String tag, {
    String status = 'active',
    String locale = 'en',
  }) {
    return _filteredTags('/api/tags/filtered', tag, status, locale);
  }

  Future<List<Tag>> filteredTagsBySlug(
    String tagSlug, {
    String status = 'active',
    String locale = 'en',
  }) {
    return _filteredTags('/api/tags/filteredBySlug', tagSlug, status, locale);
  }

  void close() => _transport.close();

  Future<List<Tag>> _filteredTags(
    String path,
    String tag,
    String status,
    String locale,
  ) async {
    final raw = await _transport.getJsonList(
      path,
      query: <String, dynamic>{
        'tag': tag.trim(),
        'status': status.trim(),
        'locale': locale.trim(),
      },
    );
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((tag) => Tag.fromJson(tag.cast<String, dynamic>()))
        .where(
          (tag) => tag.label.trim().isNotEmpty && tag.slug.trim().isNotEmpty,
        )
        .toList(growable: false);
  }
}

int? _parseCount(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _canonicalCryptoCountKey(String key) {
  return switch (key.trim().toLowerCase()) {
    '5m' || 'five-minute' || 'five-minute markets' => 'fiveM',
    '15m' || 'fifteen-minute' => 'fifteenM',
    'pre market' || 'premarket' => 'pre-market',
    '4h' || '4hr' || 'four-hour' => 'fourhour',
    final normalized => normalized,
  };
}
