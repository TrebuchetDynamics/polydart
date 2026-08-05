import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  PolymarketWebClient client(
    Future<http.Response> Function(http.BaseRequest) handler, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return PolymarketWebClient(
      transport: HttpTransport(
        config: TransportConfig(
          baseUrl: PolymarketWebClient.defaultBaseUrl,
          retryMax: 0,
          timeout: timeout,
        ),
        inner: MockClient(handler),
      ),
    );
  }

  group('geoblock', () {
    test(
      'GETs /api/geoblock and decodes eligibility without retaining IP',
      () async {
        Uri? captured;
        String? method;
        final web = client((request) async {
          captured = request.url;
          method = request.method;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'blocked': true,
              'ip': '203.0.113.9',
              'country': 'US',
              'region': 'CA',
            }),
            200,
          );
        });

        final result = await web.geoblock();

        expect(method, 'GET');
        expect(captured!.path, '/api/geoblock');
        expect(result.blocked, isTrue);
        expect(result.country, 'US');
        expect(result.region, 'CA');
        expect(result.toString(), isNot(contains('203.0.113.9')));
      },
    );

    test('rejects payloads without a boolean blocked field', () async {
      final web = client(
        (_) async =>
            http.Response(jsonEncode(<String, dynamic>{'blocked': 'yes'}), 200),
      );

      expect(web.geoblock(), throwsFormatException);
    });

    test(
      'uses the normal transport error model for non-2xx and timeouts',
      () async {
        final failing = client((_) async => http.Response('no', 403));
        await expectLater(
          failing.geoblock(),
          throwsA(
            isA<TransportException>().having(
              (error) => error.httpStatus,
              'httpStatus',
              403,
            ),
          ),
        );

        final timingOut = client(
          (_) => Completer<http.Response>().future,
          timeout: Duration.zero,
        );
        await expectLater(
          timingOut.geoblock(),
          throwsA(
            isA<TransportException>().having(
              (error) => error.code,
              'code',
              ErrorCode.timeout,
            ),
          ),
        );
      },
    );
  });

  test('cryptoCounts GETs /api/crypto/counts', () async {
    Uri? captured;
    final web = client((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{'all': 12, 'fiveM': '3'}),
        200,
      );
    });

    final counts = await web.cryptoCounts();

    expect(captured!.path, '/api/crypto/counts');
    expect(counts.all, 12);
    expect(counts.fiveMinute, 3);
  });

  test('cryptoMarkets GETs category feed with Polymarket query keys', () async {
    Uri? captured;
    final web = client((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'events': [
            <String, dynamic>{
              'id': '1',
              'slug': 'btc-updown-5m',
              'title': 'BTC Up or Down',
              'description': '',
              'image': '',
              'icon': '',
              'active': true,
              'closed': false,
              'archived': false,
              'featured': false,
            },
          ],
        }),
        200,
      );
    });

    final response = await web.cryptoMarkets(category: '5M');

    expect(captured!.path, '/api/crypto/markets');
    expect(captured!.queryParameters['_c'], '5M');
    expect(captured!.queryParameters['_s'], 'volume24hr');
    expect(captured!.queryParameters['_sts'], 'active');
    expect(captured!.queryParameters['_l'], '20');
    expect(captured!.queryParameters['_offset'], '0');
    expect(response.events.single.slug, 'btc-updown-5m');
  });

  test('biggestMovers preserves typed and raw unstable wire fields', () async {
    Uri? captured;
    String? method;
    final web = client((request) async {
      captured = request.url;
      method = request.method;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'markets': [
            <String, dynamic>{
              'id': 'm1',
              'question': 'Will BTC rise?',
              'slug': 'will-btc-rise',
              'outcomePrices': ['0.64', '0.36'],
              'clobTokenIds': ['yes', 'no'],
              'currentPrice': '0.64',
              'oneDayPriceChange': 0.12,
              'livePriceChange': 19,
              'events': [
                <String, dynamic>{'id': 'e1', 'slug': 'btc-event'},
              ],
              'history': [
                <String, dynamic>{'t': 1720000000, 'p': '0.52'},
              ],
            },
          ],
        }),
        200,
      );
    });

    final movers = await web.biggestMovers('crypto');
    final mover = movers.single;

    expect(method, 'GET');
    expect(captured!.path, '/api/biggest-movers');
    expect(captured!.queryParameters['category'], 'crypto');
    expect(mover.market.slug, 'will-btc-rise');
    expect(mover.market.raw['clobTokenIds'], ['yes', 'no']);
    expect(mover.clobTokenIds, ['yes', 'no']);
    expect(mover.marketSlug, 'will-btc-rise');
    expect(mover.eventSlug, 'btc-event');
    expect(mover.currentPrice, 0.64);
    expect(mover.oneDayPriceChange, 0.12);
    expect(mover.livePriceChange, 19);
    expect(mover.history.single.timestamp, 1720000000);
    expect(mover.history.single.price, '0.52');
  });

  test('biggestMovers surfaces transport errors', () async {
    final web = client((_) async => http.Response('unavailable', 400));

    await expectLater(web.biggestMovers(), throwsA(isA<TransportException>()));
  });

  group('subscribeDailyUpdates', () {
    test('POSTs a normalized email to the unstable web endpoint', () async {
      String? method;
      Uri? captured;
      String? body;
      final web = client((request) async {
        method = request.method;
        captured = request.url;
        body = (request as http.Request).body;
        return http.Response('', 204);
      });

      await web.subscribeDailyUpdates('  USER@Example.COM  ');

      expect(method, 'POST');
      expect(captured!.path, '/api/daily-updates');
      expect(jsonDecode(body!), <String, dynamic>{'email': 'user@example.com'});
    });

    test('rejects invalid email before transport', () async {
      var calls = 0;
      final web = client((_) async {
        calls += 1;
        return http.Response('', 204);
      });

      await expectLater(
        web.subscribeDailyUpdates('not-an-email'),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.field,
            'field',
            'email',
          ),
        ),
      );
      expect(calls, 0);
    });

    test(
      'surfaces upstream failures through the transport error model',
      () async {
        final web = client((_) async => http.Response('{"error":"no"}', 400));

        await expectLater(
          web.subscribeDailyUpdates('user@example.com'),
          throwsA(
            isA<TransportException>().having(
              (error) => error.httpStatus,
              'httpStatus',
              400,
            ),
          ),
        );

        final timingOut = client(
          (_) => Completer<http.Response>().future,
          timeout: Duration.zero,
        );
        await expectLater(
          timingOut.subscribeDailyUpdates('user@example.com'),
          throwsA(
            isA<TransportException>().having(
              (error) => error.code,
              'code',
              ErrorCode.timeout,
            ),
          ),
        );
      },
    );
  });

  test('filteredTags GETs web tag endpoint', () async {
    Uri? captured;
    final web = client((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode([
          <String, dynamic>{'id': '1', 'label': 'Crypto', 'slug': 'crypto'},
        ]),
        200,
      );
    });

    final tags = await web.filteredTags('crypto', locale: 'en');

    expect(captured!.path, '/api/tags/filtered');
    expect(captured!.queryParameters['tag'], 'crypto');
    expect(captured!.queryParameters['status'], 'active');
    expect(captured!.queryParameters['locale'], 'en');
    expect(tags.single.slug, 'crypto');
  });

  test('filteredTagsBySlug GETs web tag slug endpoint', () async {
    Uri? captured;
    final web = client((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode([
          <String, dynamic>{'id': '2', 'label': 'Bitcoin', 'slug': 'bitcoin'},
        ]),
        200,
      );
    });

    final tags = await web.filteredTagsBySlug('bitcoin');

    expect(captured!.path, '/api/tags/filteredBySlug');
    expect(captured!.queryParameters['tag'], 'bitcoin');
    expect(tags.single.label, 'Bitcoin');
  });
}
