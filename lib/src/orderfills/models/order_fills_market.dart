/// Market metadata used to map OrderFilled token IDs to market fields.
library;

import 'package:meta/meta.dart';

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

  /// Non-empty outcome token IDs in market order.
  List<String> get tokenIds => <String>[
    if (yesTokenId.trim().isNotEmpty) yesTokenId.trim(),
    if (noTokenId.trim().isNotEmpty) noTokenId.trim(),
  ];

  /// Returns a copy with stable, trimmed identifiers for indexing/errors.
  OrderFillsMarket normalizedIdentity() => OrderFillsMarket(
    marketId: marketId.trim(),
    conditionId: conditionId.trim(),
    yesTokenId: yesTokenId.trim(),
    noTokenId: noTokenId.trim(),
  );
}
