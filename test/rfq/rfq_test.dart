// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/rfq/rfq.dart';
import 'package:test/test.dart';

void main() {
  // Fixed clock so expiration checks are deterministic.
  final now = DateTime.utc(2026, 1, 1, 12);

  group('validateRfqRequest', () {
    test('accepts a request with either a market or a token id', () {
      for (final req in <RfqRequest>[
        const RfqRequest(
          marketId: 'market-1',
          side: rfqSideBuy,
          amount: '10.5',
        ),
        const RfqRequest(tokenId: 'token-1', side: rfqSideSell, amount: '2'),
      ]) {
        expect(() => validateRfqRequest(req, now: now), returnsNormally);
      }
    });

    test('accepts case-insensitive, padded sides', () {
      const req = RfqRequest(marketId: 'm', side: '  buy ', amount: '1');
      expect(() => validateRfqRequest(req, now: now), returnsNormally);
    });

    test('accepts a future expiration', () {
      final req = RfqRequest(
        marketId: 'm',
        side: rfqSideBuy,
        amount: '1',
        expiration: now.add(const Duration(minutes: 1)),
      );
      expect(() => validateRfqRequest(req, now: now), returnsNormally);
    });

    test('rejects missing required fields and bad values', () {
      final cases = <RfqRequest>[
        const RfqRequest(side: rfqSideBuy, amount: '1'), // no market/token
        const RfqRequest(marketId: 'market-1', amount: '1'), // no side
        const RfqRequest(marketId: 'market-1', side: rfqSideBuy), // no amount
        const RfqRequest(marketId: 'market-1', side: rfqSideBuy, amount: '0'),
        const RfqRequest(marketId: 'market-1', side: rfqSideBuy, amount: '0.0'),
        const RfqRequest(marketId: 'market-1', side: rfqSideBuy, amount: '-1'),
        const RfqRequest(marketId: 'market-1', side: rfqSideBuy, amount: '1e3'),
        const RfqRequest(
          marketId: 'market-1',
          side: rfqSideBuy,
          amount: '1.2.3',
        ),
        const RfqRequest(marketId: 'market-1', side: 'HOLD', amount: '1'),
        RfqRequest(
          marketId: 'market-1',
          side: rfqSideSell,
          amount: '1',
          expiration: now.subtract(const Duration(minutes: 1)),
        ),
      ];
      for (final req in cases) {
        expect(
          () => validateRfqRequest(req, now: now),
          throwsA(isA<ValidationException>()),
          reason: 'expected validation error for $req',
        );
      }
    });

    test('rejects an expiration equal to now (must be strictly future)', () {
      final req = RfqRequest(
        marketId: 'm',
        side: rfqSideBuy,
        amount: '1',
        expiration: now,
      );
      expect(
        () => validateRfqRequest(req, now: now),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('RfqClient.submit', () {
    test('refuses a valid request with a SafetyException', () {
      const client = RfqClient();
      const req = RfqRequest(
        marketId: 'market-1',
        side: rfqSideBuy,
        amount: '1',
      );
      expect(
        () => client.submit(req, now: now),
        throwsA(
          isA<SafetyException>().having(
            (e) => e.code,
            'code',
            ErrorCode.liveDisabled,
          ),
        ),
      );
    });

    test('surfaces validation errors before refusing', () {
      const client = RfqClient();
      const req = RfqRequest(marketId: 'market-1', side: 'HOLD', amount: '1');
      expect(
        () => client.submit(req, now: now),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('RfqClient.comboMarkets', () {
    test('GETs the public combo catalog and preserves its cursor', () async {
      Uri? captured;
      String? method;
      final client = RfqClient(
        transport: HttpTransport(
          config: const TransportConfig(baseUrl: RfqClient.defaultBaseUrl),
          inner: MockClient((request) async {
            captured = request.url;
            method = request.method;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'markets': [
                  <String, dynamic>{
                    'id': '1897034',
                    'condition_id': '0xcondition',
                    'position_ids': ['yes-id', 'no-id'],
                    'slug': 'mexico-win',
                    'title': 'Will Mexico win?',
                    'outcomes': ['Yes', 'No'],
                    'outcome_prices': ['0.685', '0.315'],
                    'image': 'https://example.com/image.png',
                    'volume': '330327.7128580074',
                    'tags': ['sports', 'soccer'],
                  },
                ],
                'next_cursor': ' opaque cursor ',
              }),
              200,
            );
          }),
        ),
      );

      final page = await client.comboMarkets(
        limit: 25,
        cursor: 'CUR',
        exclude: const ['0xa', '0xb'],
      );

      expect(method, 'GET');
      expect(captured!.path, '/v1/rfq/combo-markets');
      expect(captured!.queryParameters['limit'], '25');
      expect(captured!.queryParameters['cursor'], 'CUR');
      expect(captured!.queryParameters['exclude'], '0xa,0xb');
      expect(page.markets.single.conditionId, '0xcondition');
      expect(page.markets.single.positionIds, ['yes-id', 'no-id']);
      expect(page.markets.single.outcomePrices, ['0.685', '0.315']);
      expect(page.markets.single.volume, '330327.7128580074');
      expect(page.nextCursor, ' opaque cursor ');
    });

    test('surfaces non-success responses as transport errors', () async {
      final client = RfqClient(
        transport: HttpTransport(
          config: const TransportConfig(baseUrl: RfqClient.defaultBaseUrl),
          inner: MockClient((_) async => http.Response('unavailable', 400)),
        ),
      );

      await expectLater(
        client.comboMarkets(),
        throwsA(isA<TransportException>()),
      );
    });

    test('validates limits and preserves a null terminal cursor', () async {
      final client = RfqClient(
        transport: HttpTransport(
          config: const TransportConfig(baseUrl: RfqClient.defaultBaseUrl),
          inner: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, dynamic>{
                'markets': <Object>[],
                'next_cursor': null,
              }),
              200,
            ),
          ),
        ),
      );

      expect(() => client.comboMarkets(limit: 0), throwsArgumentError);
      expect(() => client.comboMarkets(limit: 101), throwsArgumentError);
      expect((await client.comboMarkets()).nextCursor, isNull);
    });
  });

  group('DTO round-trips', () {
    test('RfqRequest survives toJson/fromJson', () {
      final req = RfqRequest(
        marketId: 'market-1',
        tokenId: 'token-1',
        side: rfqSideBuy,
        amount: '10.5',
        expiration: now,
        maker: '0xabc',
        metadata: const RfqMetadata(
          clientOrderId: 'coid',
          builderCode: 'bld',
          notes: 'hi',
        ),
      );
      final back = RfqRequest.fromJson(req.toJson());
      expect(back.marketId, 'market-1');
      expect(back.tokenId, 'token-1');
      expect(back.side, rfqSideBuy);
      expect(back.amount, '10.5');
      expect(back.expiration, now);
      expect(back.maker, '0xabc');
      expect(back.metadata.clientOrderId, 'coid');
      expect(back.metadata.builderCode, 'bld');
      expect(back.metadata.notes, 'hi');
    });

    test('omits empty optional fields', () {
      const req = RfqRequest(marketId: 'm', side: rfqSideBuy, amount: '1');
      final json = req.toJson();
      expect(json.containsKey('expiration'), isFalse);
      expect(json.containsKey('maker'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('RfqResponse decodes nested quotes', () {
      final resp = RfqResponse.fromJson(<String, dynamic>{
        'request_id': 'req-1',
        'status': 'quoted',
        'quotes': [
          <String, dynamic>{
            'id': 'q1',
            'request_id': 'req-1',
            'price': '0.42',
            'size': '5',
          },
        ],
      });
      expect(resp.requestId, 'req-1');
      expect(resp.status, 'quoted');
      expect(resp.quotes.single.id, 'q1');
      expect(resp.quotes.single.price, '0.42');
    });
  });
}
