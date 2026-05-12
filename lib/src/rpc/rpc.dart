import 'dart:convert';

import 'package:http/http.dart' as http;

const String polygonRpc = 'https://polygon-bor-rpc.publicnode.com';

const String _isApprovedForAllSelector = 'e985e9c5';
const String _erc20AllowanceSelector = 'dd62ed3e';

/// Checks Polygon `eth_getCode` for non-empty bytecode.
Future<bool> hasCode(
  String address, {
  String rpcUrl = polygonRpc,
  http.Client? client,
}) async {
  final normalizedAddress = _requireHexAddress(address, 'address');
  final result = await _rpc(
    'eth_getCode',
    <Object>[normalizedAddress, 'latest'],
    rpcUrl: rpcUrl,
    client: client,
  );
  if (result is! String) {
    throw const FormatException('eth_getCode result must be a hex string');
  }
  return result.trim().length > 2;
}

/// Calls ERC-1155 `isApprovedForAll(owner, operator)` via `eth_call`.
Future<bool> isApprovedForAll(
  String tokenAddress,
  String owner,
  String operator, {
  String rpcUrl = polygonRpc,
  http.Client? client,
}) async {
  final normalizedToken = _requireHexAddress(tokenAddress, 'tokenAddress');
  final callData = _callData(_isApprovedForAllSelector, <String>[
    _requireHexAddress(owner, 'owner'),
    _requireHexAddress(operator, 'operator'),
  ]);
  final result = await _ethCall(
    normalizedToken,
    callData,
    rpcUrl: rpcUrl,
    client: client,
  );

  final word = _decodeHexWord(result, 'isApprovedForAll');
  for (var i = 0; i < 31; i++) {
    if (word[i] != 0) {
      throw FormatException(
        'isApprovedForAll bool has non-zero high bytes: $result',
      );
    }
  }
  final value = word[31];
  if (value == 0) {
    return false;
  }
  if (value == 1) {
    return true;
  }
  throw FormatException('isApprovedForAll bool must be 0 or 1: $result');
}

/// Calls ERC-20 `allowance(owner, spender)` via `eth_call`.
Future<BigInt> erc20Allowance(
  String tokenAddress,
  String owner,
  String spender, {
  String rpcUrl = polygonRpc,
  http.Client? client,
}) async {
  final normalizedToken = _requireHexAddress(tokenAddress, 'tokenAddress');
  final callData = _callData(_erc20AllowanceSelector, <String>[
    _requireHexAddress(owner, 'owner'),
    _requireHexAddress(spender, 'spender'),
  ]);
  final result = await _ethCall(
    normalizedToken,
    callData,
    rpcUrl: rpcUrl,
    client: client,
  );

  final word = _decodeHexWord(result, 'allowance');
  return BigInt.parse(_bytesToHex(word), radix: 16);
}

Future<Object?> _ethCall(
  String to,
  String data, {
  required String rpcUrl,
  required http.Client? client,
}) {
  return _rpc(
    'eth_call',
    <Object>[
      <String, String>{'to': to, 'input': data},
      'latest',
    ],
    rpcUrl: rpcUrl,
    client: client,
  );
}

Future<Object?> _rpc(
  String method,
  List<Object> params, {
  required String rpcUrl,
  required http.Client? client,
}) async {
  final effectiveRpcUrl = rpcUrl.trim().isEmpty ? polygonRpc : rpcUrl.trim();
  final uri = Uri.parse(effectiveRpcUrl);
  final ownsClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.post(
      uri,
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw http.ClientException(
        '$method HTTP ${response.statusCode}: ${response.body}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$method response must be a JSON object');
    }
    final error = decoded['error'];
    if (error != null) {
      throw StateError('$method error: $error');
    }
    return decoded['result'];
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

String _callData(String selector, List<String> addresses) {
  final args = addresses.map(
    (address) => address.substring(2).padLeft(64, '0'),
  );
  return '0x$selector${args.join()}';
}

List<int> _decodeHexWord(Object? result, String label) {
  if (result is! String) {
    throw FormatException('$label result must be a hex string');
  }
  final hex = result.trim();
  if (!hex.startsWith('0x')) {
    throw FormatException('$label result must be 0x-prefixed');
  }
  final raw = hex.substring(2);
  if (raw.length != 64) {
    throw FormatException('$label response must be 32 bytes');
  }
  if (!_hexPattern.hasMatch(raw)) {
    throw FormatException('$label result contains non-hex characters');
  }

  return <int>[
    for (var i = 0; i < raw.length; i += 2)
      int.parse(raw.substring(i, i + 2), radix: 16),
  ];
}

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _requireHexAddress(String address, String name) {
  final trimmed = address.trim();
  if (!_hexAddressPattern.hasMatch(trimmed)) {
    throw ArgumentError.value(address, name, 'invalid Ethereum address');
  }
  return trimmed.toLowerCase();
}

final RegExp _hexAddressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]+$');
