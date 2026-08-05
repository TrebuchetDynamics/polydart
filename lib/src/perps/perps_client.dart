/// Public Polymarket Perps reads.
library;

import 'package:meta/meta.dart';

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';

@immutable
final class PerpsInstrument {
  const PerpsInstrument({
    required this.instrumentId,
    required this.category,
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.fundingInterval,
    required this.minNotional,
    required this.maxLeverage,
    required this.isolatedOnly,
  });

  factory PerpsInstrument.fromJson(Map<String, dynamic> json) =>
      PerpsInstrument(
        instrumentId: _int(json['instrument_id']),
        category: json['category']?.toString() ?? '',
        symbol: json['symbol']?.toString() ?? '',
        baseAsset: json['base_asset']?.toString() ?? '',
        quoteAsset: json['quote_asset']?.toString() ?? '',
        fundingInterval: json['funding_interval']?.toString() ?? '',
        minNotional: json['min_notional']?.toString() ?? '',
        maxLeverage: _int(json['max_leverage']),
        isolatedOnly: _bool(json['isolated_only']),
      );

  final int instrumentId;
  final String category;
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final String fundingInterval;
  final String minNotional;
  final int maxLeverage;
  final bool isolatedOnly;
}

final class PerpsClient {
  PerpsClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  static const String defaultBaseUrl = 'https://api.perpetuals.polymarket.com';

  final HttpTransport _transport;

  Future<List<PerpsInstrument>> instruments() async {
    final rows = await _transport.getJsonList('/v1/info/instruments');
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => PerpsInstrument.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  void close() => _transport.close();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}
