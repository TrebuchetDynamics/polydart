import 'dart:convert';

import 'package:polydart/src/openapi/openapi.dart';
import 'package:test/test.dart';

Map<String, dynamic> _firstParameterForPath(
  Map<String, dynamic> paths,
  String path,
) {
  final pathItem = paths[path] as Map<String, dynamic>;
  final get = pathItem['get'] as Map<String, dynamic>;
  final params = get['parameters'] as List<dynamic>;
  expect(params, isNotEmpty);
  return params.first as Map<String, dynamic>;
}

void main() {
  group('openApiSpec', () {
    test('keeps path and query parameters distinct', () {
      final spec = openApiSpec();
      final paths = spec['paths'] as Map<String, dynamic>;

      final orderBookParam = _firstParameterForPath(
        paths,
        '/orderbook/{token_id}',
      );
      expect(orderBookParam['name'], 'token_id');
      expect(orderBookParam['in'], 'path');
      expect(orderBookParam['required'], isTrue);

      final marketDataParam = _firstParameterForPath(
        paths,
        '/marketdata/snapshot',
      );
      expect(marketDataParam['name'], 'token_id');
      expect(marketDataParam['in'], 'query');
      expect(marketDataParam['required'], isTrue);
    });

    test('exposes only read-only paths', () {
      final spec = openApiSpec();
      expect(spec['openapi'], '3.1.0');

      final paths = spec['paths'] as Map<String, dynamic>;
      expect(paths, isNotEmpty);
      for (final required in const [
        '/health',
        '/diag',
        '/discover/search',
        '/data/positions',
        '/orderbook/{token_id}',
        '/marketdata/snapshot',
      ]) {
        expect(
          paths.containsKey(required),
          isTrue,
          reason: 'missing $required',
        );
      }
    });

    test('contains no mutating wording', () {
      final lower = jsonEncode(openApiSpec()).toLowerCase();
      for (final blocked in const [
        'create-order',
        'withdraw',
        'approve',
        'signing',
        'trade',
      ]) {
        expect(
          lower.contains(blocked),
          isFalse,
          reason: 'spec must not contain mutating wording "$blocked"',
        );
      }
    });

    test('sorts query parameters by key', () {
      final spec = openApiSpec();
      final paths = spec['paths'] as Map<String, dynamic>;
      final search =
          (paths['/discover/search'] as Map<String, dynamic>)['get']
              as Map<String, dynamic>;
      final params = (search['parameters'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      // `limit` sorts before `q`.
      expect(params.map((p) => p['name']).toList(), <String>['limit', 'q']);
    });

    test('describes an OpenAPI 3.1 read-only info block', () {
      final info = openApiSpec()['info'] as Map<String, dynamic>;
      expect(info['title'], 'polydart read-only API');
      expect(info['version'], '0.1.0');
    });
  });
}
