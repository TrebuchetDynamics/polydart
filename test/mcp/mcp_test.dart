import 'dart:async';
import 'dart:convert';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test('safeMcpTools lists only read-only polydart tools', () {
    final tools = safeMcpTools();
    expect(tools.map((t) => t.name), <String>[
      'polydart.health',
      'polydart.discover_search',
      'polydart.data_positions',
      'polydart.orderbook_book',
      'polydart.marketdata_snapshot',
    ]);
    final encoded = jsonEncode(tools.map((t) => t.toJson()).toList());
    expect(encoded, isNot(contains('trade')));
    expect(encoded, isNot(contains('sign')));
    expect(encoded, isNot(contains('approve')));
    expect(encoded, isNot(contains('withdraw')));
  });

  test('McpServer initialize and tools/list follow JSON-RPC shape', () async {
    final server = McpServer();

    final init = await server.handle(
      const McpRequest(jsonrpc: '2.0', id: 1, method: 'initialize'),
    );
    expect(init.error, isNull);
    expect(
      (init.result! as Map<String, Object?>)['protocolVersion'],
      mcpProtocolVersion,
    );

    final listed = await server.handle(
      const McpRequest(jsonrpc: '2.0', id: 2, method: 'tools/list'),
    );
    final result = listed.result! as Map<String, Object?>;
    expect(result['tools'], isA<List<Object?>>());
    expect((result['tools']! as List<Object?>), hasLength(5));
  });

  test('McpServer rejects unsafe or unconfigured tool calls', () async {
    final server = McpServer();

    final unsafe = await server.handle(
      const McpRequest(
        jsonrpc: '2.0',
        id: 1,
        method: 'tools/call',
        params: <String, Object?>{'name': 'polydart.trade'},
      ),
    );
    expect(unsafe.error?.code, -32602);

    final unconfigured = await server.handle(
      const McpRequest(
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/call',
        params: <String, Object?>{'name': 'polydart.health'},
      ),
    );
    expect(unconfigured.error?.code, -32000);
  });

  test(
    'McpServer executes configured read-only handlers as text content',
    () async {
      final server = McpServer(
        handlers: <String, McpToolHandler>{
          'polydart.health': (_) => <String, Object?>{'ok': true},
        },
      );

      final response = await server.handle(
        const McpRequest(
          jsonrpc: '2.0',
          id: 'call-1',
          method: 'tools/call',
          params: <String, Object?>{
            'name': 'polydart.health',
            'arguments': <String, Object?>{},
          },
        ),
      );

      expect(response.error, isNull);
      final result = response.result! as Map<String, Object?>;
      final content = result['content']! as List<Object?>;
      expect((content.single! as Map<String, Object?>)['type'], 'text');
      expect((content.single! as Map<String, Object?>)['text'], '{"ok":true}');
    },
  );

  test('newReadOnlyMcpHandlers validates required string args', () async {
    final handlers = newReadOnlyMcpHandlers(
      McpHandlerConfig(
        adapters: McpReadOnlyAdapters(
          discoverSearch: (args) => 'query=${args['query']}',
        ),
      ),
    );

    expect(
      await handlers['polydart.discover_search']!(<String, Object?>{
        'query': 'btc',
      }),
      'query=btc',
    );
    expect(
      () => handlers['polydart.discover_search']!(const <String, Object?>{}),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('newReadOnlyMcpHandlers applies timeout', () async {
    final handlers = newReadOnlyMcpHandlers(
      McpHandlerConfig(
        timeout: const Duration(milliseconds: 1),
        adapters: McpReadOnlyAdapters(
          orderBook: (_) => Future<void>.delayed(const Duration(seconds: 1)),
        ),
      ),
    );

    expect(
      handlers['polydart.orderbook_book']!(const <String, Object?>{
        'token_id': 'token-1',
      }),
      throwsA(isA<TimeoutException>()),
    );
  });
}
