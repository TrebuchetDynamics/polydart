/// Polymarket web-app read endpoints.
library;

import '../errors/errors.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/market.dart';
import '../types/string_or_array.dart';

final class PolymarketGeoblock {
  const PolymarketGeoblock({
    required this.blocked,
    required this.country,
    required this.region,
  });

  factory PolymarketGeoblock.fromJson(Map<String, dynamic> json) {
    final blocked = json['blocked'];
    if (blocked is! bool) {
      throw const FormatException('geoblock: blocked must be a boolean');
    }
    return PolymarketGeoblock(
      blocked: blocked,
      country: json['country']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
    );
  }

  final bool blocked;
  final String country;
  final String region;
}

final class PolymarketMoverHistoryPoint {
  const PolymarketMoverHistoryPoint({
    required this.timestamp,
    required this.price,
  });

  factory PolymarketMoverHistoryPoint.fromJson(Map<String, dynamic> json) =>
      PolymarketMoverHistoryPoint(
        timestamp: _parseInt(json['t']),
        price: json['p']?.toString() ?? '',
      );

  final int timestamp;
  final String price;
}

final class PolymarketBiggestMover {
  const PolymarketBiggestMover({
    required this.market,
    required this.marketSlug,
    required this.eventSlug,
    required this.currentPrice,
    required this.oneDayPriceChange,
    required this.livePriceChange,
    required this.clobTokenIds,
    required this.history,
  });

  factory PolymarketBiggestMover.fromJson(Map<String, dynamic> json) {
    final market = Market.fromJson(json);
    final history = json['history'];
    return PolymarketBiggestMover(
      market: market,
      marketSlug: market.slug,
      eventSlug: market.events.isEmpty ? '' : market.events.first.slug,
      currentPrice: _parseDouble(json['currentPrice']),
      oneDayPriceChange: _parseDouble(json['oneDayPriceChange']),
      livePriceChange: _parseInt(json['livePriceChange']),
      clobTokenIds: parseStringOrArray(json['clobTokenIds']),
      history: history is List
          ? history
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (point) => PolymarketMoverHistoryPoint.fromJson(
                    point.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false)
          : const <PolymarketMoverHistoryPoint>[],
    );
  }

  final Market market;
  final String marketSlug;
  final String eventSlug;
  final double currentPrice;
  final double oneDayPriceChange;
  final int livePriceChange;
  final List<String> clobTokenIds;
  final List<PolymarketMoverHistoryPoint> history;
}

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

  Future<PolymarketGeoblock> geoblock() async {
    final raw = await _transport.getJson('/api/geoblock');
    return PolymarketGeoblock.fromJson(raw);
  }

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

  /// Unstable polymarket.com web extension. Its exact wire shape may change.
  Future<List<PolymarketBiggestMover>> biggestMovers([
    String category = 'all',
  ]) async {
    final normalized = category.trim();
    final raw = await _transport.getJson(
      '/api/biggest-movers',
      query: <String, dynamic>{
        'category': normalized.isEmpty ? 'all' : normalized,
      },
    );
    final markets = raw['markets'];
    return markets is List
        ? markets
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (market) => PolymarketBiggestMover.fromJson(
                  market.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <PolymarketBiggestMover>[];
  }

  /// Unstable polymarket.com newsletter mutation for native consumers.
  Future<void> subscribeDailyUpdates(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'email must be a valid address',
        field: 'email',
      );
    }
    await _transport.postJson('/api/daily-updates', <String, dynamic>{
      'email': normalized,
    });
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

double _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String _canonicalCryptoCountKey(String key) {
  return switch (key.trim().toLowerCase()) {
    '5m' || 'five-minute' || 'five-minute markets' => 'fiveM',
    '15m' || 'fifteen-minute' => 'fifteenM',
    'pre market' || 'premarket' => 'pre-market',
    '4h' || '4hr' || 'four-hour' => 'fourhour',
    final normalized => normalized,
  };
}
