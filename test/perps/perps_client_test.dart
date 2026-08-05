import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'instruments GETs /v1/info/instruments and preserves public fields',
    () async {
      Uri? captured;
      String? method;
      final client = PerpsClient(
        transport: HttpTransport(
          config: const TransportConfig(baseUrl: PerpsClient.defaultBaseUrl),
          inner: MockClient((request) async {
            captured = request.url;
            method = request.method;
            return http.Response(
              jsonEncode([
                <String, dynamic>{
                  'instrument_id': '123',
                  'category': 'equity',
                  'symbol': 'NVDA-USDC',
                  'base_asset': 'NVDA',
                  'quote_asset': 'USDC',
                  'funding_interval': '1h',
                  'min_notional': '1.00',
                  'max_leverage': '20',
                  'isolated_only': true,
                },
              ]),
              200,
            );
          }),
        ),
      );

      final instruments = await client.instruments();
      final instrument = instruments.single;

      expect(method, 'GET');
      expect(captured!.path, '/v1/info/instruments');
      expect(instrument.instrumentId, 123);
      expect(instrument.category, 'equity');
      expect(instrument.symbol, 'NVDA-USDC');
      expect(instrument.baseAsset, 'NVDA');
      expect(instrument.quoteAsset, 'USDC');
      expect(instrument.fundingInterval, '1h');
      expect(instrument.minNotional, '1.00');
      expect(instrument.maxLeverage, 20);
      expect(instrument.isolatedOnly, isTrue);
    },
  );

  test('surfaces non-success responses as transport errors', () async {
    final client = PerpsClient(
      transport: HttpTransport(
        config: const TransportConfig(baseUrl: PerpsClient.defaultBaseUrl),
        inner: MockClient((_) async => http.Response('unavailable', 400)),
      ),
    );

    await expectLater(client.instruments(), throwsA(isA<TransportException>()));
  });
}
