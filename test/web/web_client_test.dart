import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  PolymarketWebClient client(
    Future<http.Response> Function(http.BaseRequest) handler,
  ) {
    return PolymarketWebClient(
      transport: HttpTransport(
        config: const TransportConfig(
          baseUrl: PolymarketWebClient.defaultBaseUrl,
          retryMax: 0,
        ),
        inner: MockClient(handler),
      ),
    );
  }

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
