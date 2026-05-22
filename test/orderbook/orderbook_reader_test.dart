import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/bookreader/bookreader.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orderbook/orderbook_reader.dart';
import 'package:test/test.dart';

void main() {
  group('ClobOrderBookReader', () {
    test('orderBook fetches and returns sorted book', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/book');
        expect(request.url.queryParameters['token_id'], 'token-1');
        return http.Response(
          jsonEncode({
            'market': 'condition-1',
            'asset_id': 'token-1',
            'bids': [
              {'price': '0.01', 'size': '100'},
              {'price': '0.25', 'size': '5'},
            ],
            'asks': [
              {'price': '0.99', 'size': '100'},
              {'price': '0.26', 'size': '5'},
            ],
          }),
          200,
        );
      });

      final reader = ClobOrderBookReader(httpClient: client);
      final book = await reader.orderBook('token-1');

      expect(book.market, 'condition-1');
      expect(book.assetId, 'token-1');
      expect(book.bids, hasLength(2));
      expect(book.asks, hasLength(2));
      // BookReader sorts; verify via BookReader wrapper.
      final br = BookReader(book);
      expect(br.bids.first.price, '0.25'); // best bid first
      expect(br.asks.first.price, '0.26'); // best ask first
      reader.close();
    });

    test('orderBooks fetches batch in one request', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        expect(request.method, 'POST');
        expect(request.url.path, '/books');
        final body = jsonDecode(request.body) as List;
        expect(body, hasLength(2));
        expect((body[0] as Map)['token_id'], 'up-token');
        expect((body[1] as Map)['token_id'], 'down-token');
        return http.Response(
          jsonEncode([
            {
              'market': 'condition-1',
              'asset_id': 'up-token',
              'bids': [
                {'price': '0.44', 'size': '10'},
              ],
              'asks': [
                {'price': '0.46', 'size': '11'},
              ],
            },
            {
              'market': 'condition-1',
              'asset_id': 'down-token',
              'bids': [
                {'price': '0.54', 'size': '10'},
              ],
              'asks': [
                {'price': '0.56', 'size': '11'},
              ],
            },
          ]),
          200,
        );
      });

      final reader = ClobOrderBookReader(httpClient: client);
      final books = await reader.orderBooks(['up-token', 'down-token']);

      expect(requestCount, 1);
      expect(books, hasLength(2));
      expect(books[0].assetId, 'up-token');
      expect(books[1].assetId, 'down-token');
      reader.close();
    });

    test('orderBooks skips empty token IDs', () async {
      final client = MockClient((request) async {
        fail('should not make HTTP request');
      });

      final reader = ClobOrderBookReader(httpClient: client);
      final books = await reader.orderBooks(['', '', '']);
      expect(books, isEmpty);
      reader.close();
    });

    test('orderBook rejects empty token ID', () async {
      final client = MockClient((request) async {
        fail('should not make HTTP request');
      });

      final reader = ClobOrderBookReader(httpClient: client);
      expect(() => reader.orderBook(''), throwsA(isA<ValidationException>()));
      reader.close();
    });

    test('BatchOrderBookReader interface is implemented', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'market': 'm',
            'asset_id': 't',
            'bids': <dynamic>[],
            'asks': <dynamic>[],
          }),
          200,
        );
      });

      final reader = ClobOrderBookReader(httpClient: client);
      expect(reader, isA<BatchOrderBookReader>());
      reader.close();
    });
  });
}
