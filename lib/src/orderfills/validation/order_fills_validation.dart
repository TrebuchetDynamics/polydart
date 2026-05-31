/// Validation and normalization policy for orderfills values.
library;

import '../../errors/errors.dart';
import '../models/models.dart';

const String orderFillSideBuy = 'BUY';
const String orderFillSideSell = 'SELL';

const String orderFillSourceOnchainOrderFilled = 'onchain_order_filled';

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
