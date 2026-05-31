// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:polydart/src/gamma/gamma_params.dart';
import 'package:test/test.dart';

import '../support/gamma_test_client.dart';

void main() {
  group('markets', () {
    test('decodes a list response', () async {
      Uri? captured;
      final client = gammaTestClient((req) async {
        captured = req.url;
        return gammaJsonList([
          <String, dynamic>{
            'id': '1',
            'question': 'BTC > 100k?',
            'slug': 'btc-100k',
            'active': true,
            'closed': false,
            'archived': false,
          },
        ]);
      });
      final markets = await client.markets(
        const GetMarketsParams(limit: 5, active: true, closed: false),
      );
      expect(markets, hasLength(1));
      expect(markets.first.slug, 'btc-100k');
      expect(captured!.path, '/markets');
      expect(captured!.queryParameters['limit'], '5');
      expect(captured!.queryParameters['active'], 'true');
      expect(captured!.queryParameters['closed'], 'false');
    });

    test('multi-valued slug param emits repeated keys', () async {
      Uri? captured;
      final client = gammaTestClient((req) async {
        captured = req.url;
        return gammaJsonList(<Map<String, dynamic>>[]);
      });
      await client.markets(const GetMarketsParams(slug: ['a', 'b']));
      expect(captured!.queryParametersAll['slug'], ['a', 'b']);
    });
  });

  group('marketById / marketBySlug', () {
    test('GETs /markets/{id}', () async {
      Uri? captured;
      final client = gammaTestClient((req) async {
        captured = req.url;
        return gammaJsonObj(<String, dynamic>{'id': '42', 'slug': 'btc-100k'});
      });
      final m = await client.marketById('42');
      expect(m!.id, '42');
      expect(captured!.path, '/markets/42');
    });

    test('marketBySlug GETs /markets?slug=...&limit=1', () async {
      Uri? captured;
      final client = gammaTestClient((req) async {
        captured = req.url;
        return gammaJsonList([
          <String, dynamic>{'id': '42', 'slug': 'btc-100k'},
        ]);
      });
      final m = await client.marketBySlug('btc-100k');
      expect(m!.slug, 'btc-100k');
      expect(captured!.path, '/markets');
      expect(captured!.queryParameters['slug'], 'btc-100k');
      expect(captured!.queryParameters['limit'], '1');
    });

    test('marketBySlug returns null on empty list', () async {
      final client = gammaTestClient((req) async {
        return gammaJsonList(<Map<String, dynamic>>[]);
      });
      final m = await client.marketBySlug('does-not-exist');
      expect(m, isNull);
    });
  });

  group('search', () {
    test('q encoded; events + tags decoded', () async {
      Uri? captured;
      final client = gammaTestClient((req) async {
        captured = req.url;
        return gammaJsonObj(<String, dynamic>{
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'e1',
              'ticker': 'BTC',
              'slug': 'btc',
              'title': 'Bitcoin',
              'description': '',
              'image': '',
              'icon': '',
              'active': true,
              'closed': false,
              'archived': false,
              'featured': true,
              'liquidity': 1000,
              'volume': 500,
              'markets': <Map<String, dynamic>>[],
              'tags': <Map<String, dynamic>>[],
            },
          ],
          'tags': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 't1',
              'label': 'Crypto',
              'slug': 'crypto',
              'event_count': 99,
            },
          ],
          'profiles': <Object>[],
          'pagination': <String, dynamic>{'hasMore': false, 'totalResults': 1},
        });
      });
      final r = await client.search(
        const SearchParams(query: 'btc 5m', limitPerType: 5),
      );
      expect(captured!.path, '/public-search');
      expect(captured!.queryParameters['q'], 'btc 5m');
      expect(captured!.queryParameters['limit_per_type'], '5');
      expect(r.events.first.ticker, 'BTC');
      expect(r.tags.first.eventCount, 99);
      expect(r.pagination.totalResults, 1);
    });
  });
}
