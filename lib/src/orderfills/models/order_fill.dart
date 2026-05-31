/// Read-only on-chain OrderFilled truth model.
///
/// Mirrors Polygolem `pkg/orderfills` public fill model.
library;

import 'package:meta/meta.dart';

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
