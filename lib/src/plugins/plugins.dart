/// Extension points for caller-owned Polydart integrations.
///
/// Mirrors the lightweight `polygolem/pkg/plugins` contracts. Implementations
/// are provided by consumers; Polydart only defines the boundary types.
library;

import '../types/market.dart';

abstract interface class MarketDataPlugin {
  /// Resolves an asset/timeframe pair to the best matching market.
  Future<Market> resolve({required String asset, required String timeframe});

  /// Returns whether [market] passes caller-defined criteria.
  Future<bool> filter(Market market);
}

abstract interface class RiskPlugin {
  /// Evaluates an order before it is signed or submitted.
  ///
  /// Throwing blocks the caller from proceeding. This interface performs no
  /// signing or live write by itself.
  Future<void> checkOrder(PluginOrder order);
}

final class PluginOrder {
  const PluginOrder({
    this.tokenId = '',
    this.side = '',
    this.price = '',
    this.size = '',
    this.orderType = '',
  });

  final String tokenId;
  final String side;
  final String price;
  final String size;
  final String orderType;
}
