/// Minimal read-only Model Context Protocol surface for agent integrations.
///
/// Mirrors polygolem `pkg/mcp`: only no-credential read tools are exposed.
/// Live trading, signing, approvals, withdrawals, and authenticated mutations
/// are deliberately excluded.
library;

import 'dart:async';
import 'dart:convert';

const String mcpProtocolVersion = '2024-11-05';
const Duration defaultMcpHandlerTimeout = Duration(seconds: 10);

/// Executes one read-only MCP tool with decoded JSON object arguments.
typedef McpToolHandler =
    FutureOr<Object?> Function(Map<String, Object?> arguments);

final class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}

final class McpRequest {
  const McpRequest({
    required this.jsonrpc,
    this.id,
    required this.method,
    this.params,
  });

  factory McpRequest.fromJson(Map<String, Object?> json) => McpRequest(
    jsonrpc: json['jsonrpc']?.toString() ?? '',
    id: json['id'],
    method: json['method']?.toString() ?? '',
    params: json['params'] is Map
        ? (json['params']! as Map).cast<String, Object?>()
        : null,
  );

  final String jsonrpc;
  final Object? id;
  final String method;
  final Map<String, Object?>? params;
}

final class McpResponse {
  const McpResponse({this.id, this.result, this.error}) : jsonrpc = '2.0';

  final String jsonrpc;
  final Object? id;
  final Object? result;
  final McpResponseError? error;

  Map<String, Object?> toJson() => <String, Object?>{
    'jsonrpc': jsonrpc,
    if (id != null) 'id': id,
    if (result != null) 'result': result,
    if (error != null) 'error': error!.toJson(),
  };
}

final class McpResponseError {
  const McpResponseError({required this.code, required this.message});

  final int code;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
  };
}

final class McpContent {
  const McpContent({required this.type, required this.text});

  final String type;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'text': text,
  };
}

final class McpToolResult {
  const McpToolResult({required this.content});

  final List<McpContent> content;

  Map<String, Object?> toJson() => <String, Object?>{
    'content': content.map((c) => c.toJson()).toList(growable: false),
  };
}

final class McpServer {
  McpServer({
    Map<String, McpToolHandler> handlers = const <String, McpToolHandler>{},
  }) : _tools = safeMcpTools(),
       _handlers = <String, McpToolHandler>{} {
    final safeNames = _tools.map((tool) => tool.name).toSet();
    for (final entry in handlers.entries) {
      if (safeNames.contains(entry.key)) _handlers[entry.key] = entry.value;
    }
  }

  final List<McpTool> _tools;
  final Map<String, McpToolHandler> _handlers;

  Future<McpResponse> handle(McpRequest request) async {
    if (request.jsonrpc != '2.0') {
      return _error(request.id, -32600, 'invalid JSON-RPC version');
    }
    switch (request.method) {
      case 'initialize':
        return McpResponse(
          id: request.id,
          result: <String, Object?>{
            'protocolVersion': mcpProtocolVersion,
            'serverInfo': <String, String>{
              'name': 'polydart',
              'version': 'dev',
            },
            'capabilities': <String, Object?>{'tools': <String, Object?>{}},
          },
        );
      case 'tools/list':
        return McpResponse(
          id: request.id,
          result: <String, Object?>{
            'tools': _tools
                .map((tool) => tool.toJson())
                .toList(growable: false),
          },
        );
      case 'tools/call':
        return _callTool(request);
      default:
        return _error(request.id, -32601, 'method not found');
    }
  }

  Future<McpResponse> _callTool(McpRequest request) async {
    final params = request.params ?? const <String, Object?>{};
    final name = params['name']?.toString() ?? '';
    final rawArguments = params['arguments'];
    final arguments = rawArguments is Map
        ? rawArguments.cast<String, Object?>()
        : const <String, Object?>{};
    if (!_tools.any((tool) => tool.name == name)) {
      return _error(
        request.id,
        -32602,
        'tool "$name" is not exposed by polydart MCP',
      );
    }
    final handler = _handlers[name];
    if (handler == null) {
      return _error(
        request.id,
        -32000,
        'tool execution is not configured for this read-only MCP server',
      );
    }
    try {
      final result = await Future<Object?>.value(handler(arguments));
      final text = _marshalToolText(result);
      return McpResponse(
        id: request.id,
        result: McpToolResult(
          content: <McpContent>[McpContent(type: 'text', text: text)],
        ).toJson(),
      );
    } on Object catch (error) {
      return _error(request.id, -32000, error.toString());
    }
  }
}

final class McpReadOnlyAdapters {
  const McpReadOnlyAdapters({
    this.health,
    this.discoverSearch,
    this.dataPositions,
    this.orderBook,
    this.marketDataSnapshot,
  });

  final FutureOr<Object?> Function()? health;
  final McpToolHandler? discoverSearch;
  final McpToolHandler? dataPositions;
  final McpToolHandler? orderBook;
  final McpToolHandler? marketDataSnapshot;
}

final class McpHandlerConfig {
  const McpHandlerConfig({
    this.timeout = defaultMcpHandlerTimeout,
    this.adapters = const McpReadOnlyAdapters(),
  });

  final Duration timeout;
  final McpReadOnlyAdapters adapters;
}

Map<String, McpToolHandler> newReadOnlyMcpHandlers(McpHandlerConfig config) {
  final timeout = config.timeout > Duration.zero
      ? config.timeout
      : defaultMcpHandlerTimeout;
  final handlers = <String, McpToolHandler>{};
  void add(String name, McpToolHandler? fn) {
    if (fn == null) return;
    handlers[name] = (args) => Future<Object?>.value(fn(args)).timeout(timeout);
  }

  final health = config.adapters.health;
  if (health != null) {
    add('polydart.health', (_) => health());
  }
  add(
    'polydart.discover_search',
    _requireStringArg('query', config.adapters.discoverSearch),
  );
  add(
    'polydart.data_positions',
    _requireStringArg('user', config.adapters.dataPositions),
  );
  add(
    'polydart.orderbook_book',
    _requireStringArg('token_id', config.adapters.orderBook),
  );
  add(
    'polydart.marketdata_snapshot',
    _requireStringArg('token_id', config.adapters.marketDataSnapshot),
  );
  return handlers;
}

List<McpTool> safeMcpTools() => <McpTool>[
  McpTool(
    name: 'polydart.health',
    description: 'Check read-only Gamma and CLOB API reachability.',
    inputSchema: _objectSchema(null, null),
  ),
  McpTool(
    name: 'polydart.discover_search',
    description: 'Search Polymarket Gamma markets without credentials.',
    inputSchema: _objectSchema(
      <String>['query'],
      <String, Object?>{'query': _stringSchema(), 'limit': _integerSchema()},
    ),
  ),
  McpTool(
    name: 'polydart.data_positions',
    description: 'Read public Data API positions for a user address.',
    inputSchema: _objectSchema(
      <String>['user'],
      <String, Object?>{'user': _stringSchema(), 'limit': _integerSchema()},
    ),
  ),
  McpTool(
    name: 'polydart.orderbook_book',
    description: 'Read a public CLOB order book by token id.',
    inputSchema: _objectSchema(
      <String>['token_id'],
      <String, Object?>{'token_id': _stringSchema()},
    ),
  ),
  McpTool(
    name: 'polydart.marketdata_snapshot',
    description:
        'Return a normalized market-data snapshot for supplied stream events.',
    inputSchema: _objectSchema(
      <String>['token_id'],
      <String, Object?>{'token_id': _stringSchema()},
    ),
  ),
];

McpToolHandler? _requireStringArg(String name, McpToolHandler? fn) {
  if (fn == null) return null;
  return (args) {
    final value = args[name];
    if (value is! String || value.isEmpty) {
      throw ArgumentError('$name is required');
    }
    return fn(args);
  };
}

McpResponse _error(Object? id, int code, String message) => McpResponse(
  id: id,
  error: McpResponseError(code: code, message: message),
);

String _marshalToolText(Object? value) {
  if (value is String) return value;
  return jsonEncode(value);
}

Map<String, Object?> _objectSchema(
  List<String>? required,
  Map<String, Object?>? properties,
) => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': required,
  'properties': properties ?? const <String, Object?>{},
};

Map<String, Object?> _stringSchema() => const <String, Object?>{
  'type': 'string',
};

Map<String, Object?> _integerSchema() => const <String, Object?>{
  'type': 'integer',
  'minimum': 1,
};
