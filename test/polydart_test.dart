import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  group('Polydart.readOnly', () {
    test('uses default config when none supplied', () {
      final p = Polydart.readOnly();
      expect(p.mode, PolydartMode.readOnly);
      expect(p.config.gammaBaseUrl, PolydartConfig.defaultGammaBaseUrl);
      expect(p.config.clobBaseUrl, PolydartConfig.defaultClobBaseUrl);
      expect(p.config.dataBaseUrl, PolydartConfig.defaultDataBaseUrl);
      expect(p.eoaAddress, isEmpty);
      p.close();
    });

    test('honours overrides from PolydartConfig', () {
      const cfg = PolydartConfig(
        gammaBaseUrl: 'https://gamma.test',
        clobBaseUrl: 'https://clob.test',
        dataBaseUrl: 'https://data.test',
        requestTimeout: Duration(seconds: 5),
      );
      final p = Polydart.readOnly(config: cfg);
      expect(p.config.gammaBaseUrl, 'https://gamma.test');
      expect(p.config.clobBaseUrl, 'https://clob.test');
      expect(p.config.dataBaseUrl, 'https://data.test');
      expect(p.mode, PolydartMode.readOnly);
      p.close();
    });

    test('exposes resolver, discovery, and data surfaces', () {
      final p = Polydart.readOnly();
      expect(p.resolver, isNotNull);
      expect(p.discovery, isNotNull);
      expect(p.data, isNotNull);
      p.close();
    });

    test('routes data reads through the injected Data API transport', () async {
      Uri? captured;
      final p = Polydart.readOnly(
        dataTransport: HttpTransport(
          config: const TransportConfig(baseUrl: DataApiClient.defaultBaseUrl),
          inner: MockClient((req) async {
            captured = req.url;
            return http.Response(
              jsonEncode([
                <String, dynamic>{
                  'conditionId': '0xfed',
                  'asset': 'yes-token',
                  'side': 'BUY',
                },
              ]),
              200,
            );
          }),
        ),
      );

      addTearDown(p.close);

      final trades = await p.data.marketTrades('0xfed', limit: 3);

      expect(captured!.path, '/trades');
      expect(captured!.queryParameters['market'], '0xfed');
      expect(captured!.queryParameters['limit'], '3');
      expect(trades.single.market, '0xfed');
    });
  });

  group('Polydart.paper', () {
    test('requires a non-empty eoa address', () {
      expect(
        () => Polydart.paper(eoaAddress: ''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => Polydart.paper(eoaAddress: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('captures eoa and switches mode', () {
      final p = Polydart.paper(eoaAddress: '0xabc');
      expect(p.mode, PolydartMode.paper);
      expect(p.eoaAddress, '0xabc');
      p.close();
    });
  });
}
