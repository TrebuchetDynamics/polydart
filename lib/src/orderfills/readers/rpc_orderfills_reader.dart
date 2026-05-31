/// Polygon JSON-RPC reader for on-chain OrderFilled logs.
///
/// Mirrors Polygolem `pkg/orderfills/reader.go`. This module is read-only:
/// it calls `eth_getLogs`, `eth_getBlockByNumber`, and `eth_blockNumber` only.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/eth_hex.dart';
import '../../contracts/contracts.dart' as contracts;
import '../../errors/errors.dart';
import '../orderfills_core.dart';

final class RpcOrderFillsReader
    implements OrderFillsReader, OrderFillsBlockNumberReader {
  RpcOrderFillsReader({
    String rpcUrl = contracts.PolygonRPC,
    List<String> exchangeAddresses = const <String>[],
    http.Client? client,
  }) : _rpcUrl = rpcUrl.trim().isEmpty ? contracts.PolygonRPC : rpcUrl.trim(),
       _exchangeAddresses = List<String>.unmodifiable(exchangeAddresses),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String _rpcUrl;
  final List<String> _exchangeAddresses;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<OrderFill>> orderFilled(OrderFillsQuery query) async {
    validateOrderFillsQuery(query);
    final markets = _MarketIndex(query.markets);
    final logs = await _rpc('eth_getLogs', <Object>[
      <String, Object>{
        'fromBlock': _quantity(query.fromBlock),
        'toBlock': _quantity(query.toBlock),
        'address': _filterAddresses(query.exchangeAddresses),
        'topics': <Object>[
          <String>[_orderFilledEventId],
        ],
      },
    ]);
    if (logs is! List<dynamic>) {
      throw const FormatException('eth_getLogs result must be a list');
    }

    final marketFilter = query.marketId.trim();
    final tokenFilter = _normalizedSet(query.tokenIds, _normalizeTokenId);
    final conditionFilter = _normalizedSet(
      query.conditionIds,
      _normalizeConditionId,
    );
    final blockTimes = <int, DateTime>{};
    final fills = <OrderFill>[];

    for (var index = 0; index < logs.length; index += 1) {
      final log = _logObjectAt(logs, index);
      final decoded = _decodeOrderFilledLog(log);
      if (decoded == null) continue;
      if (tokenFilter.isNotEmpty &&
          !tokenFilter.contains(_normalizeTokenId(decoded.tokenId))) {
        continue;
      }
      final market = markets.byToken[_normalizeTokenId(decoded.tokenId)];
      final mapped = market != null;
      if (query.markets.isNotEmpty && !mapped) continue;
      if (marketFilter.isNotEmpty &&
          (!mapped || market.marketId.trim() != marketFilter)) {
        continue;
      }
      if (conditionFilter.isNotEmpty) {
        if (!mapped) continue;
        if (!conditionFilter.contains(
          _normalizeConditionId(market.conditionId),
        )) {
          continue;
        }
      }

      final blockNumber = _parseQuantity(
        _requiredString(log['blockNumber'], 'log.blockNumber'),
        'log.blockNumber',
      );
      final filledAt = await _blockTimestamp(blockNumber, blockTimes);
      fills.add(
        normalizeOrderFill(
          OrderFill(
            txHash: _requiredString(log['transactionHash'], 'log.txHash'),
            logIndex: _parseQuantity(
              _requiredString(log['logIndex'], 'log.logIndex'),
              'log.logIndex',
            ),
            exchange: _normalizeExchangeAddress(
              _requiredString(log['address'], 'log.address'),
            ),
            marketId: mapped ? market.marketId.trim() : '',
            conditionId: mapped ? market.conditionId.trim() : '',
            tokenId: decoded.tokenId,
            side: decoded.side,
            price: decoded.price,
            size: decoded.size,
            blockNumber: blockNumber,
            filledAt: filledAt,
            source: orderFillSourceOnchainOrderFilled,
          ),
        ),
      );
    }

    fills.sort((a, b) {
      final blockCompare = a.blockNumber.compareTo(b.blockNumber);
      if (blockCompare != 0) return blockCompare;
      return a.logIndex.compareTo(b.logIndex);
    });
    return fills;
  }

  @override
  Future<int> latestBlockNumber() async {
    final result = await _rpc('eth_blockNumber', const <Object>[]);
    if (result is! String) {
      throw const FormatException(
        'eth_blockNumber result must be a hex string',
      );
    }
    return _parseQuantity(result, 'eth_blockNumber');
  }

  /// Closes the owned HTTP client. Injected clients remain owned by callers.
  void close() {
    if (_ownsClient) _client.close();
  }

  List<String> _filterAddresses(List<String> queryAddresses) {
    var addresses = queryAddresses;
    if (addresses.isEmpty) addresses = _exchangeAddresses;
    if (addresses.isEmpty) {
      addresses = const <String>[
        contracts.CTFExchangeV2,
        contracts.NegRiskExchangeV2,
      ];
    }
    final out = <String>[
      for (final raw in addresses)
        if (raw.trim().isNotEmpty) _normalizeExchangeAddress(raw),
    ];
    if (out.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'orderfills exchange address is required',
        field: 'exchangeAddresses',
      );
    }
    return out;
  }

  Future<DateTime> _blockTimestamp(
    int blockNumber,
    Map<int, DateTime> cache,
  ) async {
    final cached = cache[blockNumber];
    if (cached != null) return cached;
    final result = await _rpc('eth_getBlockByNumber', <Object>[
      _quantity(blockNumber),
      false,
    ]);
    if (result is! Map<dynamic, dynamic>) {
      throw const FormatException(
        'eth_getBlockByNumber result must be an object',
      );
    }
    final timestamp = _parseQuantity(
      _requiredString(result['timestamp'], 'block.timestamp'),
      'block.timestamp',
    );
    final at = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    cache[blockNumber] = at;
    return at;
  }

  Future<Object?> _rpc(String method, List<Object> params) async {
    final response = await _client.post(
      Uri.parse(_rpcUrl),
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
        Uri.parse(_rpcUrl),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$method response must be a JSON object');
    }
    final error = decoded['error'];
    if (error != null) throw StateError('$method error: $error');
    return decoded['result'];
  }
}

const String _orderFilledEventSignature =
    'OrderFilled(bytes32,address,address,uint256,uint256,uint256,uint256,uint256)';
final String _orderFilledEventId = bytesToHex0x(
  keccak256Utf8(_orderFilledEventSignature),
);

final class _DecodedOrderFilled {
  const _DecodedOrderFilled({
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
  });

  final String tokenId;
  final String side;
  final String price;
  final String size;
}

Map<String, dynamic> _logObjectAt(List<dynamic> logs, int index) {
  final raw = logs[index];
  if (raw is! Map<dynamic, dynamic>) {
    throw FormatException('eth_getLogs[$index] must be an object');
  }
  return raw.cast<String, dynamic>();
}

_DecodedOrderFilled? _decodeOrderFilledLog(Map<String, dynamic> log) {
  final topics = log['topics'];
  if (topics is! List<dynamic> || topics.isEmpty) return null;
  final topic0 = topics.first;
  if (topic0 is! String || topic0.toLowerCase() != _orderFilledEventId) {
    return null;
  }

  final words = _decodeUint256Words(_requiredString(log['data'], 'log.data'));
  final makerAssetId = words[0];
  final takerAssetId = words[1];
  final makerAmountFilled = words[2];
  final takerAmountFilled = words[3];

  BigInt? tokenId;
  BigInt? collateral;
  BigInt? shares;
  var side = '';
  if (makerAssetId.sign != 0 && takerAssetId.sign == 0) {
    tokenId = makerAssetId;
    collateral = takerAmountFilled;
    shares = makerAmountFilled;
    side = orderFillSideBuy;
  } else if (makerAssetId.sign == 0 && takerAssetId.sign != 0) {
    tokenId = takerAssetId;
    collateral = makerAmountFilled;
    shares = takerAmountFilled;
    side = orderFillSideSell;
  } else {
    return null;
  }

  if (tokenId.sign == 0 || collateral.sign <= 0 || shares.sign <= 0) {
    return null;
  }
  return _DecodedOrderFilled(
    tokenId: tokenId.toString(),
    side: side,
    price: _formatRatio(collateral, shares, 8),
    size: _formatScaled(shares, 6),
  );
}

List<BigInt> _decodeUint256Words(String data) {
  final clean = _strip0x(data).toLowerCase();
  if (clean.length != 64 * 5) {
    throw const FormatException(
      'OrderFilled data must contain five uint256 words',
    );
  }
  hexToBytes(clean);
  return <BigInt>[
    for (var i = 0; i < clean.length; i += 64)
      BigInt.parse(clean.substring(i, i + 64), radix: 16),
  ];
}

final class _MarketIndex {
  _MarketIndex(List<OrderFillsMarket> markets)
    : byToken = <String, OrderFillsMarket>{} {
    for (final market in markets) {
      final normalized = OrderFillsMarket(
        marketId: market.marketId.trim(),
        conditionId: market.conditionId.trim(),
        yesTokenId: market.yesTokenId,
        noTokenId: market.noTokenId,
      );
      for (final tokenId in <String>[market.yesTokenId, market.noTokenId]) {
        final normalizedToken = _normalizeTokenId(tokenId);
        if (normalizedToken.isEmpty) continue;
        final previous = byToken[normalizedToken];
        if (previous != null) {
          throw ValidationException(
            code: ErrorCode.invalidValue,
            message:
                'orderfills markets duplicate token id $normalizedToken maps to both ${previous.marketId} and ${normalized.marketId}',
            field: 'markets',
          );
        }
        byToken[normalizedToken] = normalized;
      }
    }
  }

  final Map<String, OrderFillsMarket> byToken;
}

Set<String> _normalizedSet(
  List<String> values,
  String Function(String value) normalize,
) {
  return <String>{
    for (final value in values)
      if (normalize(value).isNotEmpty) normalize(value),
  };
}

String _normalizeTokenId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('0x')) {
    final parsed = BigInt.tryParse(lower.substring(2), radix: 16);
    return parsed?.toString() ?? trimmed;
  }
  return BigInt.tryParse(trimmed)?.toString() ?? trimmed;
}

String _normalizeConditionId(String raw) => raw.trim().toLowerCase();

String _normalizeExchangeAddress(String raw) {
  final clean = _strip0x(raw.trim());
  if (clean.length != 40) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'orderfills exchange address "$raw" is not a hex address',
      field: 'exchangeAddresses',
    );
  }
  hexToBytes(clean);
  return '0x${clean.toLowerCase()}';
}

String _formatRatio(BigInt numerator, BigInt denominator, int precision) {
  if (denominator.sign == 0) return '';
  final scale = BigInt.from(10).pow(precision);
  var scaled = numerator * scale;
  final remainder = scaled % denominator;
  scaled ~/= denominator;
  if (remainder * BigInt.two >= denominator) {
    scaled += BigInt.one;
  }
  return _trimDecimal(_fixedDecimal(scaled, precision));
}

String _formatScaled(BigInt value, int decimals) {
  final scale = BigInt.from(10).pow(decimals);
  final whole = value ~/ scale;
  final fraction = (value % scale).toString().padLeft(decimals, '0');
  return _trimDecimal('$whole.$fraction');
}

String _fixedDecimal(BigInt scaled, int decimals) {
  if (decimals == 0) return scaled.toString();
  final raw = scaled.toString().padLeft(decimals + 1, '0');
  final whole = raw.substring(0, raw.length - decimals);
  final fraction = raw.substring(raw.length - decimals);
  return '$whole.$fraction';
}

String _trimDecimal(String value) {
  var out = value;
  while (out.contains('.') && out.endsWith('0')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out.isEmpty ? '0' : out;
}

String _quantity(int value) {
  if (value < 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'quantity cannot be negative',
    );
  }
  return '0x${value.toRadixString(16)}';
}

int _parseQuantity(String raw, String label) {
  final digits = _quantityDigits(raw, label);
  return BigInt.parse(digits, radix: 16).toInt();
}

String _quantityDigits(String raw, String label) {
  final clean = raw.trim().toLowerCase();
  if (!clean.startsWith('0x')) {
    throw FormatException('$label must be a JSON-RPC quantity');
  }
  final digits = clean.substring(2);
  if (digits.isEmpty || (digits.length > 1 && digits.startsWith('0'))) {
    throw FormatException('$label must be a JSON-RPC quantity');
  }
  try {
    BigInt.parse(digits, radix: 16);
  } on FormatException {
    throw FormatException('$label must be a JSON-RPC quantity');
  }
  return digits;
}

String _requiredString(Object? value, String label) {
  if (value is! String) throw FormatException('$label must be a string');
  return value;
}

String _strip0x(String value) {
  if (value.startsWith('0x') || value.startsWith('0X')) {
    return value.substring(2);
  }
  return value;
}
