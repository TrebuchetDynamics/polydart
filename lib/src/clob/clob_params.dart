/// Request parameter shapes for the CLOB client.
library;

import 'package:meta/meta.dart';

import '../types/enums.dart';

/// Used for batch endpoints (`/books`, `/prices-post`, `/midpoints`,
/// `/last-trades-prices`).
@immutable
final class BookParams {
  const BookParams({required this.tokenId, this.side});

  final String tokenId;
  final Side? side;

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{'token_id': tokenId};
    if (side != null) out['side'] = side!.label;
    return out;
  }
}

/// Query parameters for `/prices-history`.
@immutable
final class PriceHistoryParams {
  const PriceHistoryParams({
    this.market,
    this.interval,
    this.fidelity,
    this.startTimestamp,
    this.endTimestamp,
  });

  final String? market;
  final String? interval;
  final int? fidelity;
  final int? startTimestamp;
  final int? endTimestamp;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (market != null && market!.isNotEmpty) q['market'] = market;
    if (interval != null && interval!.isNotEmpty) q['interval'] = interval;
    if (fidelity != null && fidelity! > 0) q['fidelity'] = fidelity!.toString();
    if (startTimestamp != null && startTimestamp! > 0) {
      q['startTs'] = startTimestamp!.toString();
    }
    if (endTimestamp != null && endTimestamp! > 0) {
      q['endTs'] = endTimestamp!.toString();
    }
    return q;
  }
}
