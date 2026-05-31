/// Pure market-discovery eligibility rules.
///
/// Gamma search responses and market-list responses can disagree on how much
/// lifecycle state they include. Keep the enrichment gate in one place so CLOB
/// reads are only attempted for markets that are visibly open for order-book
/// discovery.
library;

import 'package:meta/meta.dart';

import '../types/market.dart';

/// Reason a market is not a safe CLOB-enrichment candidate.
enum MarketEnrichmentRejection { inactive, closed, archived, orderBookDisabled }

@immutable
final class MarketEnrichmentEligibility {
  const MarketEnrichmentEligibility({required this.rejections});

  final Set<MarketEnrichmentRejection> rejections;

  bool get isEligible => rejections.isEmpty;
}

/// Returns the explicit CLOB-enrichment gate state for [market].
MarketEnrichmentEligibility inspectMarketEnrichment(Market market) {
  final rejections = <MarketEnrichmentRejection>{};
  if (!market.active) rejections.add(MarketEnrichmentRejection.inactive);
  if (market.closed) rejections.add(MarketEnrichmentRejection.closed);
  if (market.archived) rejections.add(MarketEnrichmentRejection.archived);
  if (!market.enableOrderBook) {
    rejections.add(MarketEnrichmentRejection.orderBookDisabled);
  }
  return MarketEnrichmentEligibility(rejections: Set.unmodifiable(rejections));
}

/// Returns true when [market] is a candidate for CLOB enrichment.
bool shouldEnrichMarket(Market market) =>
    inspectMarketEnrichment(market).isEligible;
