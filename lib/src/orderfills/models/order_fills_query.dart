/// Query contract for read-only on-chain OrderFilled scans.
library;

import 'order_fills_market.dart';

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
