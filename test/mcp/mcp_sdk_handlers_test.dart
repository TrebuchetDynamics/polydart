// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/dataapi/dataapi_client.dart';
import 'package:polydart/src/dataapi/dataapi_types.dart' show Position;
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/marketdata/marketdata_tracker.dart';
import 'package:polydart/src/mcp/mcp.dart';
import 'package:polydart/src/mcp/mcp_sdk_handlers.dart';
import 'package:polydart/src/stream/models/stream_messages.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

HttpTransport _transport(
  String baseUrl,
  Future<http.Response> Function(http.BaseRequest) handler,
) => HttpTransport(
  config: TransportConfig(baseUrl: baseUrl, retryMax: 0),
  inner: MockClient(handler),
);

GammaClient _gamma(
  Future<http.Response> Function(http.BaseRequest) handler, {
  void Function(Uri)? onRequest,
}) => GammaClient(
  transport: _transport(GammaClient.defaultBaseUrl, (req) {
    onRequest?.call(req.url);
    return handler(req);
  }),
);

DataApiClient _data(Future<http.Response> Function(http.BaseRequest) handler) =>
    DataApiClient(transport: _transport(DataApiClient.defaultBaseUrl, handler));

ClobClient _clob(Future<http.Response> Function(http.BaseRequest) handler) =>
    ClobClient(transport: _transport(ClobClient.defaultBaseUrl, handler));

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  group('newSdkReadOnlyMcpHandlers', () {
    test('returns no handlers when every client is null', () {
      expect(newSdkReadOnlyMcpHandlers(), isEmpty);
    });

    test('preserves an explicit adapter even with nil clients', () {
      final handlers = newSdkReadOnlyMcpHandlers(
        config: McpHandlerConfig(
          adapters: McpReadOnlyAdapters(
            marketDataSnapshot: (_) => <String, String>{'custom': 'ok'},
          ),
        ),
      );
      expect(handlers.keys, contains('polydart.marketdata_snapshot'));
    });

    test('skips tools for absent clients (gamma only)', () {
      final handlers = newSdkReadOnlyMcpHandlers(
        gamma: _gamma((_) async => _ok(<String, dynamic>{})),
      );
      expect(handlers.keys, containsAll(<String>['polydart.discover_search']));
      expect(handlers.containsKey('polydart.health'), isTrue);
      expect(handlers.containsKey('polydart.data_positions'), isFalse);
      expect(handlers.containsKey('polydart.orderbook_book'), isFalse);
    });

    test(
      'wires discover_search to Gamma and forwards a string limit',
      () async {
        Uri? captured;
        final handlers = newSdkReadOnlyMcpHandlers(
          gamma: _gamma(
            (_) async => _ok(<String, dynamic>{'events': <dynamic>[]}),
            onRequest: (u) => captured = u,
          ),
        );
        final result = await handlers['polydart.discover_search']!(
          <String, Object?>{'query': 'btc', 'limit': '7'},
        );
        expect(result, isNotNull);
        expect(captured!.queryParameters['q'], 'btc');
        // _intArg parses the string "7" → limit_per_type=7.
        expect(captured!.queryParameters['limit_per_type'], '7');
      },
    );

    test('wires data_positions to the Data API', () async {
      final handlers = newSdkReadOnlyMcpHandlers(
        data: _data(
          (_) async => _ok(<Map<String, dynamic>>[
            <String, dynamic>{
              'token_id': 'tok',
              'condition_id': 'cond',
              'market_id': 'mkt',
              'side': 'YES',
              'size': 100.0,
            },
          ]),
        ),
      );
      final result = await handlers['polydart.data_positions']!(
        <String, Object?>{'user': '0xabc'},
      );
      expect(result, isA<List<Position>>());
      expect((result! as List<Position>).single.marketId, 'mkt');
    });

    test('health reports ok and surfaces per-client errors', () async {
      final handlers = newSdkReadOnlyMcpHandlers(
        gamma: _gamma((_) async => http.Response('boom', 500)),
        clob: _clob((_) async => _ok(<String, dynamic>{})),
      );
      final result =
          await handlers['polydart.health']!(<String, Object?>{})
              as Map<String, String>;
      expect(result['gamma'], startsWith('error:'));
      expect(result['clob'], 'ok');
    });

    test(
      'an explicit health adapter wins over the SDK one (base-wins)',
      () async {
        final handlers = newSdkReadOnlyMcpHandlers(
          config: McpHandlerConfig(
            adapters: McpReadOnlyAdapters(
              health: () => <String, String>{'source': 'explicit'},
            ),
          ),
          gamma: _gamma((_) async => _ok(<String, dynamic>{})),
          clob: _clob((_) async => _ok(<String, dynamic>{})),
        );
        final result =
            await handlers['polydart.health']!(<String, Object?>{})
                as Map<String, String>;
        expect(result['source'], 'explicit');
      },
    );

    test('runs end-to-end through McpServer for orderbook_book', () async {
      final handlers = newSdkReadOnlyMcpHandlers(
        clob: _clob(
          (_) async => _ok(<String, dynamic>{
            'market': '0xabc',
            'asset_id': 'tok-1',
            'bids': <Map<String, dynamic>>[
              <String, dynamic>{'price': '0.49', 'size': '100'},
            ],
            'asks': <Map<String, dynamic>>[
              <String, dynamic>{'price': '0.51', 'size': '50'},
            ],
          }),
        ),
      );
      final server = McpServer(handlers: handlers);
      final response = await server.handle(
        const McpRequest(
          jsonrpc: '2.0',
          id: 1,
          method: 'tools/call',
          params: <String, Object?>{
            'name': 'polydart.orderbook_book',
            'arguments': <String, Object?>{'token_id': 'tok-1'},
          },
        ),
      );
      expect(response.error, isNull);
      final result = response.result! as Map<String, Object?>;
      final content =
          (result['content']! as List).first as Map<String, Object?>;
      expect(content['type'], 'text');
      expect(content['text'], contains('0.49'));
    });

    test('marshals data_positions end-to-end through McpServer', () async {
      final handlers = newSdkReadOnlyMcpHandlers(
        data: _data(
          (_) async => _ok(<Map<String, dynamic>>[
            <String, dynamic>{
              'asset': 'tok',
              'conditionId': 'cond',
              'market': 'mkt',
              'side': 'YES',
              'size': 100.0,
            },
          ]),
        ),
      );
      final server = McpServer(handlers: handlers);
      final response = await server.handle(
        const McpRequest(
          jsonrpc: '2.0',
          id: 1,
          method: 'tools/call',
          params: <String, Object?>{
            'name': 'polydart.data_positions',
            'arguments': <String, Object?>{'user': '0xabc'},
          },
        ),
      );
      // Position.toJson makes this marshal cleanly (previously a -32000 error).
      expect(response.error, isNull);
      final result = response.result! as Map<String, Object?>;
      final content =
          (result['content']! as List).first as Map<String, Object?>;
      expect(content['text'], contains('mkt'));
    });

    test('marshals discover_search end-to-end through McpServer', () async {
      final handlers = newSdkReadOnlyMcpHandlers(
        gamma: _gamma(
          (_) async => _ok(<String, dynamic>{
            'events': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'ev-1', 'title': 'BTC up?'},
            ],
            'tags': <Map<String, dynamic>>[],
            'profiles': <Map<String, dynamic>>[],
            'pagination': <String, dynamic>{
              'hasMore': false,
              'totalResults': 1,
            },
          }),
        ),
      );
      final server = McpServer(handlers: handlers);
      final response = await server.handle(
        const McpRequest(
          jsonrpc: '2.0',
          id: 1,
          method: 'tools/call',
          params: <String, Object?>{
            'name': 'polydart.discover_search',
            'arguments': <String, Object?>{'query': 'btc'},
          },
        ),
      );
      // SearchResponse.toJson (Event re-emits its raw payload) marshals cleanly.
      expect(response.error, isNull);
      final result = response.result! as Map<String, Object?>;
      final content =
          (result['content']! as List).first as Map<String, Object?>;
      expect(content['text'], contains('ev-1'));
      expect(content['text'], contains('BTC up?'));
    });
  });

  group('newMarketDataSnapshotMcpHandler', () {
    test('returns null for a null tracker', () {
      expect(newMarketDataSnapshotMcpHandler(null), isNull);
    });

    test('reads the latest snapshot and errors on unknown assets', () async {
      final tracker = MarketDataTracker();
      tracker.applyBestBidAsk(
        const BestBidAskMessage(
          eventType: 'best_bid_ask',
          assetId: 'token-1',
          market: '0xabc',
          bestBid: '0.40',
          bestAsk: '0.42',
          spread: '0.02',
          timestamp: '1714000000',
        ),
      );
      final handler = newMarketDataSnapshotMcpHandler(tracker)!;

      final got = await handler(<String, Object?>{'token_id': 'token-1'});
      expect((got! as Snapshot).bestBid, '0.40');
      expect((got as Snapshot).bestAsk, '0.42');

      // Falls back to asset_id, and errors when missing/unknown.
      final viaAssetId = await handler(<String, Object?>{
        'asset_id': 'token-1',
      });
      expect((viaAssetId! as Snapshot).assetId, 'token-1');
      expect(() => handler(<String, Object?>{}), throwsA(isA<ArgumentError>()));
      expect(
        () => handler(<String, Object?>{'token_id': 'missing'}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
