// ignore_for_file: prefer_const_literals_to_create_immutables
/// Routing tests for the methods added to bring polydart's GammaClient to
/// parity with polygolem's `internal/gamma/client.go`. Each test asserts
/// the path, query keys polygolem emits, and a minimal field decode so we
/// catch wire-shape regressions without re-asserting every JSON field.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/gamma/gamma_params.dart';
import 'package:polydart/src/types/market.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

GammaClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
  return GammaClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: GammaClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
  );
}

http.Response _jsonList(List<Map<String, dynamic>> rows) =>
    http.Response(jsonEncode(rows), 200);

http.Response _jsonObj(Map<String, dynamic> obj) =>
    http.Response(jsonEncode(obj), 200);

Market _market({required String conditionId, required String category}) {
  return Market.fromJson(<String, dynamic>{
    'id': conditionId,
    'conditionId': conditionId,
    'question': 'Question $conditionId',
    'category': category,
    'active': true,
    'closed': false,
  });
}

void main() {
  group('activeMarkets', () {
    test(
      'activeMarketsAll collects pages and dedupes by condition id',
      () async {
        final client = _client((req) async {
          expect(req.url.path, '/markets');
          expect(req.url.queryParameters['active'], 'true');
          expect(req.url.queryParameters['closed'], 'false');
          expect(req.url.queryParameters['limit'], '100');
          final offset =
              int.tryParse(req.url.queryParameters['offset'] ?? '') ?? 0;
          final rows = switch (offset) {
            0 => [
              for (var index = 0; index < 100; index++)
                <String, dynamic>{
                  'id': '$index',
                  'conditionId': 'c$index',
                  'question': 'Market $index',
                  'active': true,
                  'closed': false,
                },
            ],
            100 => [
              <String, dynamic>{
                'id': 'dup',
                'conditionId': 'c99',
                'question': 'Duplicate',
                'active': true,
                'closed': false,
              },
              <String, dynamic>{
                'id': '100',
                'conditionId': 'c100',
                'question': 'Page two',
                'active': true,
                'closed': false,
              },
            ],
            _ => <Map<String, dynamic>>[],
          };
          return _jsonList(rows);
        });

        final markets = await client.activeMarketsAll();

        expect(markets, hasLength(101));
        expect(markets.last.conditionId, 'c100');
      },
    );

    test('category filters use Polymarket-style aliases', () {
      final markets = [
        _market(conditionId: 'business', category: 'Business'),
        _market(conditionId: 'science', category: 'Science'),
        _market(conditionId: 'politics', category: 'Politics'),
      ];

      expect(
        filterMarketsByCategory(markets, 'Finance').single.conditionId,
        'business',
      );
      expect(
        filterMarketsByCategory(markets, 'Tech').single.conditionId,
        'science',
      );
      expect(
        filterMarketsByCategory(markets, 'Elections').single.conditionId,
        'politics',
      );
    });

    test('GETs /markets with active=true&closed=false', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': '1', 'slug': 'a', 'active': true},
        ]);
      });
      final ms = await client.activeMarkets();
      expect(captured!.path, '/markets');
      expect(captured!.queryParameters['active'], 'true');
      expect(captured!.queryParameters['closed'], 'false');
      expect(ms, hasLength(1));
    });
  });

  group('events / eventById / eventBySlug', () {
    test('events GETs /events with limit + slug repeated', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': 'e1', 'slug': 'btc'},
        ]);
      });
      final out = await client.events(
        const GetEventsParams(limit: 5, slug: ['a', 'b']),
      );
      expect(captured!.path, '/events');
      expect(captured!.queryParameters['limit'], '5');
      expect(captured!.queryParametersAll['slug'], ['a', 'b']);
      expect(out, hasLength(1));
      expect(out.first.id, 'e1');
    });

    test('eventById GETs /events/{id}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{'id': '7', 'slug': 'x'});
      });
      final e = await client.eventById('7');
      expect(captured!.path, '/events/7');
      expect(e!.id, '7');
    });

    test('eventBySlug GETs /events?slug=...&limit=1', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': '9', 'slug': 'btc-100k'},
        ]);
      });
      final e = await client.eventBySlug('btc-100k');
      expect(captured!.path, '/events');
      expect(captured!.queryParameters['slug'], 'btc-100k');
      expect(captured!.queryParameters['limit'], '1');
      expect(e!.slug, 'btc-100k');
    });

    test('eventBySlug returns null on empty list', () async {
      final client = _client(
        (req) async => _jsonList(<Map<String, dynamic>>[]),
      );
      expect(await client.eventBySlug('does-not-exist'), isNull);
    });
  });

  group('series / seriesById', () {
    test('series GETs /series with order/ascending', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': 's1', 'slug': 'masters'},
        ]);
      });
      final out = await client.series(
        const GetSeriesParams(limit: 10, order: 'volume', ascending: true),
      );
      expect(captured!.path, '/series');
      expect(captured!.queryParameters['order'], 'volume');
      expect(captured!.queryParameters['ascending'], 'true');
      expect(out.first.id, 's1');
    });

    test('seriesById GETs /series/{id}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{'id': '42', 'slug': 'masters'});
      });
      final s = await client.seriesById('42');
      expect(captured!.path, '/series/42');
      expect(s!.id, '42');
    });
  });

  group('tags / tagById / tagBySlug', () {
    test('tags GETs /tags', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': 't1', 'label': 'Crypto', 'slug': 'crypto'},
        ]);
      });
      final out = await client.tags(const GetTagsParams(limit: 25));
      expect(captured!.path, '/tags');
      expect(captured!.queryParameters['limit'], '25');
      expect(out.first.slug, 'crypto');
    });

    test('tagById GETs /tags/{id}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'id': '1',
          'label': 'Crypto',
          'slug': 'crypto',
        });
      });
      final t = await client.tagById('1');
      expect(captured!.path, '/tags/1');
      expect(t!.label, 'Crypto');
    });

    test('tagBySlug GETs /tags/{slug}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'id': '2',
          'label': 'Sports',
          'slug': 'sports',
        });
      });
      final t = await client.tagBySlug('sports');
      expect(captured!.path, '/tags/sports');
      expect(t!.id, '2');
    });
  });

  group('relatedTagsById / relatedTagsBySlug', () {
    test('relatedTagsById GETs /tags/{id}/related', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{
            'id': 'rel-1',
            'tagID': 1,
            'relatedTagID': 7,
            'rank': 0,
          },
        ]);
      });
      final out = await client.relatedTagsById('1');
      expect(captured!.path, '/tags/1/related');
      expect(out.first.tagId, 1);
      expect(out.first.relatedTagId, 7);
    });

    test('relatedTagsBySlug GETs /tags/{slug}/related', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList(<Map<String, dynamic>>[]);
      });
      final out = await client.relatedTagsBySlug('crypto');
      expect(captured!.path, '/tags/crypto/related');
      expect(out, isEmpty);
    });
  });

  group('teams', () {
    test('teams GETs /teams with repeated league/name', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{
            'id': 1,
            'name': 'Lakers',
            'league': 'NBA',
            'abbreviation': 'LAL',
          },
        ]);
      });
      final out = await client.teams(
        const GetTeamsParams(league: ['NBA', 'NFL'], name: ['Lakers']),
      );
      expect(captured!.path, '/teams');
      expect(captured!.queryParametersAll['league'], ['NBA', 'NFL']);
      expect(captured!.queryParametersAll['name'], ['Lakers']);
      expect(out.first.name, 'Lakers');
    });
  });

  group('comments / commentById / commentsByUser', () {
    test(
      'comments GETs /comments with parent_entity_id + parent_entity_type',
      () async {
        Uri? captured;
        final client = _client((req) async {
          captured = req.url;
          return _jsonList([
            <String, dynamic>{
              'id': 'c1',
              'body': 'gm',
              'user': <String, dynamic>{
                'address': '0xabc',
                'pseudonym': 'pix',
                'profileImage': '',
              },
            },
          ]);
        });
        final out = await client.comments(
          const CommentQuery(entityId: 99, entityType: 'Event', limit: 50),
        );
        expect(captured!.path, '/comments');
        expect(captured!.queryParameters['parent_entity_id'], '99');
        expect(captured!.queryParameters['parent_entity_type'], 'Event');
        expect(captured!.queryParameters.containsKey('entity_id'), isFalse);
        expect(captured!.queryParameters.containsKey('entity_type'), isFalse);
        expect(captured!.queryParameters['limit'], '50');
        expect(out.first.id, 'c1');
        expect(out.first.user.address, '0xabc');
      },
    );

    test('comments decodes current Gamma profile shape', () async {
      final client = _client((req) async {
        return _jsonList([
          <String, dynamic>{
            'id': '2933135',
            'body': 'Why so many people moving from this market?',
            'parentEntityType': 'Series',
            'parentEntityID': 35,
            'userAddress': '0xf5aa8ba8f7f0ef81f7ff0365212e6550116b0376',
            'createdAt': '2026-05-18T06:47:21.255417Z',
            'updatedAt': '2026-05-18T06:47:29.475121Z',
            'profile': <String, dynamic>{
              'name': 'Higuain76',
              'pseudonym': 'Growing-Bidding',
              'baseAddress': '0xf5aa8ba8f7f0ef81f7ff0365212e6550116b0376',
              'profileImage': 'https://example.com/profile.png',
            },
          },
        ]);
      });
      final out = await client.comments(
        const CommentQuery(entityId: 35, entityType: 'Series', limit: 3),
      );

      expect(out.first.id, '2933135');
      expect(out.first.parentId, 35);
      expect(
        out.first.user.address,
        '0xf5aa8ba8f7f0ef81f7ff0365212e6550116b0376',
      );
      expect(out.first.user.pseudonym, 'Growing-Bidding');
      expect(out.first.user.profileImage, 'https://example.com/profile.png');
    });

    test('commentById GETs /comments/{id}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'id': '42',
          'body': 'hi',
          'user': <String, dynamic>{
            'address': '0xdef',
            'pseudonym': '',
            'profileImage': '',
          },
        });
      });
      final c = await client.commentById('42');
      expect(captured!.path, '/comments/42');
      expect(c!.id, '42');
    });

    test('commentsByUser GETs /comments?user_address=...&limit=...', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList(<Map<String, dynamic>>[]);
      });
      await client.commentsByUser('0xfeed', limit: 10);
      expect(captured!.path, '/comments');
      expect(captured!.queryParameters['user_address'], '0xfeed');
      expect(captured!.queryParameters['limit'], '10');
    });
  });

  group('sports', () {
    test('sportsMetadata GETs /sports-metadata', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{
            'sport': 'NBA',
            'image': 'https://x/nba.png',
            'resolution': 'final-score',
            'ordering': '1',
            'tags': 'sports,nba',
            'series': '',
          },
        ]);
      });
      final out = await client.sportsMetadata();
      expect(captured!.path, '/sports-metadata');
      expect(out.first.sport, 'NBA');
    });

    test('sportsMarketTypes GETs /sports-market-types', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonList([
          <String, dynamic>{'id': 'ml', 'name': 'Moneyline', 'slug': 'ml'},
        ]);
      });
      final out = await client.sportsMarketTypes();
      expect(captured!.path, '/sports-market-types');
      expect(out.first.slug, 'ml');
    });
  });

  group('marketByToken', () {
    test('GETs /markets/token/{tokenId} and decodes wrapper', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'market': <String, dynamic>{'id': 'm1', 'slug': 's1'},
          'token_id': '0xToken',
          'outcome': 'YES',
        });
      });
      final r = await client.marketByToken('0xToken');
      expect(captured!.path, '/markets/token/0xToken');
      expect(r!.tokenId, '0xToken');
      expect(r.outcome, 'YES');
      expect(r.market.id, 'm1');
    });
  });

  group('publicProfile', () {
    test('GETs /profiles/{addr}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'id': 'p1',
          'name': 'pix',
          'proxyWallet': '0xproxy',
          'profileImage': '',
        });
      });
      final p = await client.publicProfile('0xWallet');
      expect(captured!.path, '/profiles/0xWallet');
      expect(p!.proxyWallet, '0xproxy');
    });
  });

  group('eventsKeyset / marketsKeyset', () {
    test('eventsKeyset returns (data, nextCursor) record', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'e1', 'slug': 'a'},
            <String, dynamic>{'id': 'e2', 'slug': 'b'},
          ],
          'next_cursor': 'cur-abc',
          'has_more': true,
        });
      });
      final page = await client.eventsKeyset(
        const KeysetParams(
          limit: 50,
          keysetId: 'cur-prev',
          ascending: true,
          active: true,
        ),
      );
      expect(captured!.path, '/events-keyset');
      expect(captured!.queryParameters['limit'], '50');
      expect(captured!.queryParameters['keyset_id'], 'cur-prev');
      expect(captured!.queryParameters['ascending'], 'true');
      expect(captured!.queryParameters['active'], 'true');
      expect(page.data, hasLength(2));
      expect(page.nextCursor, 'cur-abc');
    });

    test('marketsKeyset returns (data, nextCursor) record', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return _jsonObj(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'm1', 'slug': 'a'},
          ],
          'next_cursor': '',
          'has_more': false,
        });
      });
      final page = await client.marketsKeyset(
        const KeysetParams(limit: 25, closed: false, order: 'volume'),
      );
      expect(captured!.path, '/markets-keyset');
      expect(captured!.queryParameters['limit'], '25');
      expect(captured!.queryParameters['closed'], 'false');
      expect(captured!.queryParameters['order'], 'volume');
      expect(page.data, hasLength(1));
      expect(page.nextCursor, '');
    });
  });
}
