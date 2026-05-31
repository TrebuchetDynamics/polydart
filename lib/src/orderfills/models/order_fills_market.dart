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
}
