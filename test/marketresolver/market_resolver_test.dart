// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/marketresolver/market_resolver.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

void main() {
  group('parseClobTokenIds', () {
    test('empty / null forms', () {
      expect(parseClobTokenIds(''), isEmpty);
      expect(parseClobTokenIds('[]'), isEmpty);
      expect(parseClobTokenIds('null'), isEmpty);
    });

    test('JSON-encoded array', () {
      expect(parseClobTokenIds('["t1","t2"]'), ['t1', 't2']);
    });

    test('JSON with surrounding whitespace', () {
      expect(parseClobTokenIds('  ["t1","t2"]  '), ['t1', 't2']);
    });

    test('legacy unquoted-style fallback', () {
      // Manual parser kicks in only for non-JSON shapes.
      expect(parseClobTokenIds('"t1","t2"'), ['t1', 't2']);
    });
  });

  group('ResolvedMarket', () {
    test('isAvailable requires aligned outcomes/tokenIds', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '0xq',
        slug: 's',
        question: 'q',
        outcomes: ['Yes', 'No'],
        tokenIds: ['t1', 't2'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.isAvailable, isTrue);
      expect(r.yesTokenId, 't1');
      expect(r.noTokenId, 't2');
    });

    test('mismatched lengths fail isAvailable', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '0xq',
        slug: 's',
        question: 'q',
        outcomes: ['Yes', 'No'],
        tokenIds: ['t1'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.isAvailable, isFalse);
      expect(r.yesTokenId, isNull);
    });

    test('tokenIdFor handles up/down aliases', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '',
        slug: 's',
        question: 'q',
        outcomes: ['Up', 'Down'],
        tokenIds: ['t1', 't2'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.yesTokenId, 't1');
      expect(r.noTokenId, 't2');
    });
  });

  group('MarketResolver', () {
    test('resolveBySlug populates the result', () async {
      final mock = MockClient((req) async {
        // marketBySlug calls /markets?slug=… and expects a JSON list.
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'id': '1',
              'question': 'BTC > 100k?',
              'conditionId': '0xc',
              'slug': 'btc-100k',
              'outcomes': '["Yes","No"]',
              'clobTokenIds': '["t1","t2"]',
              'active': true,
              'closed': false,
              'archived': false,
              'acceptingOrders': true,
              'enableOrderBook': true,
            },
          ]),
          200,
        );
      });
      final resolver = MarketResolver(
        gamma: GammaClient(
          transport: HttpTransport(
            config: const TransportConfig(
              baseUrl: GammaClient.defaultBaseUrl,
              retryMax: 0,
            ),
            inner: mock,
          ),
        ),
      );

      final r = await resolver.resolveBySlug('btc-100k');
      expect(r, isNotNull);
      expect(r!.conditionId, '0xc');
      expect(r.tokenIds, ['t1', 't2']);
      expect(r.outcomes, ['Yes', 'No']);
      expect(r.yesTokenId, 't1');
      expect(r.isAvailable, isTrue);
    });
  });
}
