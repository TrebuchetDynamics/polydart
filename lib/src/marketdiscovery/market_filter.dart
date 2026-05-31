/// Pure market-discovery eligibility rules.
///
/// Gamma search responses and market-list responses can disagree on how much
/// lifecycle state they include. Keep the enrichment gate in one place so CLOB
/// reads are only attempted for markets that are visibly open for order-book
/// discovery.
library;

import '../types/market.dart';

/// Returns true when [market] is a candidate for CLOB enrichment.
bool shouldEnrichMarket(Market market) =>
    market.active &&
    !market.closed &&
    !market.archived &&
    market.enableOrderBook;
