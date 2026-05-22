/// Read-only on-chain OrderFilled truth models.
///
/// Mirrors Polygolem `pkg/orderfills` public model and validation surface.
/// This module defines typed fill/query DTOs only; live Polygon RPC log reads
/// stay outside this slice so no SDK caller gets a hidden transaction or
/// credential path.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';

const String orderFillSideBuy = 'BUY';
const String orderFillSideSell = 'SELL';

const String orderFillSourceOnchainOrderFilled = 'onchain_order_filled';

@immutable
final class OrderFill {
  const OrderFill({
    required this.txHash,
    required this.logIndex,
    required this.exchange,
    required this.marketId,
    required this.conditionId,
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    required this.blockNumber,
    required this.filledAt,
    required this.source,
  });

  final String txHash;
  final int logIndex;
  final String exchange;
  final String marketId;
  final String conditionId;
  final String tokenId;
  final String side;
  final String price;
  final String size;
  final int blockNumber;
  final DateTime filledAt;
  final String source;

  OrderFill copyWith({
    String? txHash,
    int? logIndex,
    String? exchange,
    String? marketId,
    String? conditionId,
    String? tokenId,
    String? side,
    String? price,
    String? size,
    int? blockNumber,
    DateTime? filledAt,
    String? source,
  }) => OrderFill(
    txHash: txHash ?? this.txHash,
    logIndex: logIndex ?? this.logIndex,
    exchange: exchange ?? this.exchange,
    marketId: marketId ?? this.marketId,
    conditionId: conditionId ?? this.conditionId,
    tokenId: tokenId ?? this.tokenId,
    side: side ?? this.side,
    price: price ?? this.price,
    size: size ?? this.size,
    blockNumber: blockNumber ?? this.blockNumber,
    filledAt: filledAt ?? this.filledAt,
    source: source ?? this.source,
  );
}

@immutable
final class OrderFillsMarket {
  const OrderFillsMarket({
    this.marketId = '',
    this.conditionId = '',
    this.yesTokenId = '',
    this.noTokenId = '',
  });

  final String marketId;
  final String conditionId;
  final String yesTokenId;
  final String noTokenId;
}

@immutable
final class OrderFillsQuery {
  const OrderFillsQuery({
    this.exchangeAddresses = const <String>[],
    this.fromBlock = 0,
    this.toBlock = 0,
    this.marketId = '',
    this.conditionIds = const <String>[],
    this.tokenIds = const <String>[],
    this.markets = const <OrderFillsMarket>[],
  });

  final List<String> exchangeAddresses;
  final int fromBlock;
  final int toBlock;
  final String marketId;
  final List<String> conditionIds;
  final List<String> tokenIds;
  final List<OrderFillsMarket> markets;
}

abstract interface class OrderFillsReader {
  Future<List<OrderFill>> orderFilled(OrderFillsQuery query);
}

abstract interface class OrderFillsBlockNumberReader {
  Future<int> latestBlockNumber();
}

void validateOrderFillsQuery(OrderFillsQuery query) {
  if (query.fromBlock == 0 && query.toBlock == 0) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'orderfills query block range is required',
      field: 'blockRange',
    );
  }
  if (query.fromBlock == 0) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'orderfills query from block is required',
      field: 'fromBlock',
    );
  }
  if (query.toBlock == 0) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'orderfills query to block is required',
      field: 'toBlock',
    );
  }
  if (query.fromBlock > query.toBlock) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'orderfills query from block must be <= to block',
      field: 'fromBlock',
    );
  }
}

OrderFill normalizeOrderFill(OrderFill fill) {
  final side = fill.side.trim().toUpperCase();
  if (side != orderFillSideBuy && side != orderFillSideSell) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'orderfills fill side must be BUY or SELL',
      field: 'side',
    );
  }

  var source = fill.source.trim();
  if (source.isEmpty) source = orderFillSourceOnchainOrderFilled;
  if (source != orderFillSourceOnchainOrderFilled) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'orderfills fill source must be $orderFillSourceOnchainOrderFilled',
      field: 'source',
    );
  }

  return fill.copyWith(side: side, source: source);
}

void validateOrderFill(OrderFill fill) {
  normalizeOrderFill(fill);
}
