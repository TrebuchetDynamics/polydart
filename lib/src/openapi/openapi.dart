/// Minimal OpenAPI description for safe read-only Polydart surfaces.
///
/// Mirrors `pkg/openapi`. The spec is built as a plain map (no schema
/// framework dependency) so agents/proxies get a stable discovery artifact.
/// Live trading, signing, approvals, withdrawals, and other mutating
/// operations are deliberately excluded.
library;

/// Returns a small OpenAPI 3.1 document for read-only local proxy/tooling
/// experiments. Callers may serialize it directly as JSON.
///
/// Mirrors `openapi.Spec`.
Map<String, dynamic> openApiSpec() => <String, dynamic>{
  'openapi': '3.1.0',
  'info': <String, dynamic>{
    'title': 'polydart read-only API',
    'version': '0.1.0',
    'description':
        'Read-only Polymarket discovery, data, orderbook, health, and '
        'diagnostics surfaces. Mutating trading and credentialed operations '
        'are deliberately excluded.',
  },
  'paths': <String, dynamic>{
    '/health': _get(
      'Health check',
      'Check read-only Gamma and CLOB reachability.',
    ),
    '/diag': _get(
      'Diagnostics',
      'Return redacted local diagnostics and endpoint configuration.',
    ),
    '/discover/search': _getWithParams(
      'Search markets',
      'Search Polymarket Gamma markets.',
      <String, dynamic>{
        'q': _stringParam('q', true, 'Search query.'),
        'limit': _integerParam('limit', false, 'Maximum number of rows.'),
      },
    ),
    '/data/positions': _getWithParams(
      'Positions',
      'Read public Data API positions for a user address.',
      <String, dynamic>{
        'user': _stringParam('user', true, 'User or wallet address.'),
        'limit': _integerParam('limit', false, 'Maximum number of rows.'),
      },
    ),
    '/orderbook/{token_id}': _getWithParams(
      'Order book',
      'Read a public CLOB order book by token id.',
      <String, dynamic>{
        'token_id': _pathStringParam('token_id', 'CLOB token id.'),
      },
    ),
    '/marketdata/snapshot': _getWithParams(
      'Market data snapshot',
      'Return a normalized market-data snapshot for a token.',
      <String, dynamic>{
        'token_id': _stringParam('token_id', true, 'CLOB token id.'),
      },
    ),
  },
};

Map<String, dynamic> _get(String summary, String description) =>
    <String, dynamic>{'get': _operation(summary, description, null)};

Map<String, dynamic> _getWithParams(
  String summary,
  String description,
  Map<String, dynamic> params,
) => <String, dynamic>{'get': _operation(summary, description, params)};

Map<String, dynamic> _operation(
  String summary,
  String description,
  Map<String, dynamic>? params,
) {
  final op = <String, dynamic>{
    'summary': summary,
    'description': description,
    'responses': <String, dynamic>{
      '200': <String, dynamic>{
        'description': 'Successful read-only response.',
      },
    },
  };
  if (params != null && params.isNotEmpty) {
    final keys = params.keys.toList()..sort();
    op['parameters'] = <dynamic>[for (final key in keys) params[key]];
  }
  return op;
}

Map<String, dynamic> _stringParam(
  String name,
  bool required,
  String description,
) => _parameter(name, 'query', required, description, 'string');

Map<String, dynamic> _pathStringParam(String name, String description) =>
    _parameter(name, 'path', true, description, 'string');

Map<String, dynamic> _integerParam(
  String name,
  bool required,
  String description,
) => _parameter(name, 'query', required, description, 'integer');

Map<String, dynamic> _parameter(
  String name,
  String location,
  bool required,
  String description,
  String type,
) => <String, dynamic>{
  'name': name,
  'in': location,
  'required': required,
  'description': description,
  'schema': <String, dynamic>{'type': type},
};
