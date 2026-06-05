/// Read-only wallet intelligence DTOs, pure scoring, and Data API-backed
/// dossier assembly.
///
/// Mirrors Polygolem `pkg/intel` and `internal/intel` without adding auth,
/// signing, custody, or mutation. Scores are statistical candidate signals,
/// not findings of misconduct or trading advice.
library;

import 'package:meta/meta.dart';

import '../dataapi/dataapi_client.dart';
import '../dataapi/dataapi_types.dart';

const String formulaWalletScoreV1 = 'wallet_score_v1';
const String formulaShrinkageWinRateV1 = 'shrinkage_win_rate_v1';

const String confidenceNone = 'none';
const String confidenceLow = 'low';
const String confidenceMedium = 'medium';
const String confidenceHigh = 'high';

const String dossierStatusComplete = 'complete';
const String dossierStatusPartial = 'partial';
const String dossierStatusConflicted = 'conflicted';

const double _defaultPriorWins = 10.0;
const double _defaultPriorBets = 20.0;
const int _defaultLimit = 100;
const String _candidateLanguage =
    'statistical candidate signal; not a finding of misconduct';

/// Error raised by wallet-intelligence validation and configuration checks.
final class WalletIntelException implements Exception {
  const WalletIntelException(this.message);

  final String message;

  @override
  String toString() => 'WalletIntelException: $message';
}

/// Source-backed summary of a Polymarket wallet's public activity.
@immutable
final class WalletSummary {
  const WalletSummary({
    required this.wallet,
    this.volume = 0,
    this.realizedPnL = 0,
    this.roi = 0,
    this.bets = 0,
    this.wins = 0,
    this.rawWinRate = 0,
    this.shrinkageWinRate = 0,
    this.lastActive,
    this.asOf,
    this.formulaVersion = '',
    this.sourceRows = 0,
    this.sourceDescription = '',
  });

  final String wallet;
  final double volume;
  final double realizedPnL;
  final double roi;
  final int bets;
  final int wins;
  final double rawWinRate;
  final double shrinkageWinRate;
  final DateTime? lastActive;
  final DateTime? asOf;
  final String formulaVersion;
  final int sourceRows;
  final String sourceDescription;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wallet': wallet,
    'volume': volume,
    'realized_pnl': realizedPnL,
    'roi': roi,
    'bets': bets,
    'wins': wins,
    'raw_win_rate': rawWinRate,
    'shrinkage_win_rate': shrinkageWinRate,
    if (lastActive != null) 'last_active': _formatRfc3339(lastActive!),
    if (asOf != null) 'as_of': _formatRfc3339(asOf!),
    'formula_version': formulaVersion,
    'source_rows': sourceRows,
    if (sourceDescription.isNotEmpty) 'source_description': sourceDescription,
  };
}

/// Raw inputs and deterministic derived values used by [scoreWallet].
@immutable
final class WalletScoreMetrics {
  const WalletScoreMetrics({
    this.wins = 0,
    this.bets = 0,
    this.volume = 0,
    this.realizedPnL = 0,
    this.roi = 0,
    this.rawWinRate = 0,
    this.shrinkageWinRate = 0,
    this.categoryEdge = 0,
    this.concentrationSignal = false,
    this.lateEntrySignal = false,
    this.coPositioningSignal = false,
    this.shrinkagePriorWins = 0,
    this.shrinkagePriorBets = 0,
  });

  final int wins;
  final int bets;
  final double volume;
  final double realizedPnL;
  final double roi;
  final double rawWinRate;
  final double shrinkageWinRate;
  final double categoryEdge;
  final bool concentrationSignal;
  final bool lateEntrySignal;
  final bool coPositioningSignal;
  final double shrinkagePriorWins;
  final double shrinkagePriorBets;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wins': wins,
    'bets': bets,
    'volume': volume,
    'realized_pnl': realizedPnL,
    'roi': roi,
    'raw_win_rate': rawWinRate,
    'shrinkage_win_rate': shrinkageWinRate,
    if (categoryEdge != 0) 'category_edge': categoryEdge,
    if (concentrationSignal) 'concentration_signal': concentrationSignal,
    if (lateEntrySignal) 'late_entry_signal': lateEntrySignal,
    if (coPositioningSignal) 'co_positioning_signal': coPositioningSignal,
    'shrinkage_prior_wins': shrinkagePriorWins,
    'shrinkage_prior_bets': shrinkagePriorBets,
  };
}

/// Explainable score for a wallet intelligence candidate.
@immutable
final class WalletScore {
  const WalletScore({
    required this.wallet,
    this.value = 0,
    this.confidence = confidenceNone,
    this.formulaVersion = formulaWalletScoreV1,
    this.asOf,
    this.sourceRows = 0,
    this.reasons = const <String>[],
    this.rawMetrics = const WalletScoreMetrics(),
    this.language = _candidateLanguage,
  });

  final String wallet;
  final int value;
  final String confidence;
  final String formulaVersion;
  final DateTime? asOf;
  final int sourceRows;
  final List<String> reasons;
  final WalletScoreMetrics rawMetrics;
  final String language;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wallet': wallet,
    'value': value,
    'confidence': confidence,
    'formula_version': formulaVersion,
    if (asOf != null) 'as_of': _formatRfc3339(asOf!),
    'source_rows': sourceRows,
    'reasons': reasons,
    'raw_metrics': rawMetrics.toJson(),
    'language': language,
  };
}

/// Future SDK shape for a wallet research dossier.
@immutable
final class WalletDossier {
  const WalletDossier({
    required this.wallet,
    this.asOf,
    this.status = dossierStatusComplete,
    this.summary = const WalletSummary(wallet: ''),
    this.score = const WalletScore(wallet: ''),
    this.sources = const <SourceRef>[],
    this.conflicts = const <SourceConflict>[],
    this.warnings = const <String>[],
  });

  final String wallet;
  final DateTime? asOf;
  final String status;
  final WalletSummary summary;
  final WalletScore score;
  final List<SourceRef> sources;
  final List<SourceConflict> conflicts;
  final List<String> warnings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wallet': wallet,
    if (asOf != null) 'as_of': _formatRfc3339(asOf!),
    'status': status,
    'summary': summary.toJson(),
    'score': score.toJson(),
    if (sources.isNotEmpty)
      'sources': sources.map((source) => source.toJson()).toList(),
    if (conflicts.isNotEmpty)
      'conflicts': conflicts.map((conflict) => conflict.toJson()).toList(),
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

/// Ranked wallet row suitable for table or JSON output.
@immutable
final class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.wallet,
    required this.summary,
    required this.score,
  });

  final int rank;
  final String wallet;
  final WalletSummary summary;
  final WalletScore score;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rank': rank,
    'wallet': wallet,
    'summary': summary.toJson(),
    'score': score.toJson(),
  };
}

/// Payload shape for user-scoped dossier alerts.
@immutable
final class DossierAlerts {
  const DossierAlerts({this.dossierAlerts = const <Signal>[]});

  final List<Signal> dossierAlerts;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dossier_alerts': dossierAlerts.map((signal) => signal.toJson()).toList(),
  };
}

/// Explainable alert candidate.
@immutable
final class Signal {
  const Signal({
    required this.score,
    required this.wallet,
    this.market = '',
    this.side = '',
    this.size = 0,
    this.price = 0,
    this.confidence = confidenceNone,
    this.formulaVersion = formulaWalletScoreV1,
    this.asOf,
    this.language = _candidateLanguage,
    this.reasons = const <String>[],
    this.sources = const <SourceRef>[],
  });

  final int score;
  final String wallet;
  final String market;
  final String side;
  final double size;
  final double price;
  final String confidence;
  final String formulaVersion;
  final DateTime? asOf;
  final String language;
  final List<String> reasons;
  final List<SourceRef> sources;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'score': score,
    'wallet': wallet,
    if (market.isNotEmpty) 'market': market,
    if (side.isNotEmpty) 'side': side,
    if (size != 0) 'size': size,
    if (price != 0) 'price': price,
    'confidence': confidence,
    'formula_version': formulaVersion,
    if (asOf != null) 'as_of': _formatRfc3339(asOf!),
    'language': language,
    'reasons': reasons,
    if (sources.isNotEmpty)
      'sources': sources.map((source) => source.toJson()).toList(),
  };
}

/// Read-only market activity summary for research views.
@immutable
final class MarketFlow {
  const MarketFlow({
    required this.market,
    this.asOf,
    this.formulaVersion = '',
    this.openInterest = 0,
    this.holderCount = 0,
    this.holderShares = 0,
    this.holderVolume = 0,
    this.tradeCount = 0,
    this.tradeNotional = 0,
    this.candidateSignal = false,
    this.sources = const <SourceRef>[],
    this.warnings = const <String>[],
  });

  final String market;
  final DateTime? asOf;
  final String formulaVersion;
  final double openInterest;
  final int holderCount;
  final double holderShares;
  final double holderVolume;
  final int tradeCount;
  final double tradeNotional;
  final bool candidateSignal;
  final List<SourceRef> sources;
  final List<String> warnings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'market': market,
    if (asOf != null) 'as_of': _formatRfc3339(asOf!),
    if (formulaVersion.isNotEmpty) 'formula_version': formulaVersion,
    if (openInterest != 0) 'open_interest': openInterest,
    'holder_count': holderCount,
    if (holderShares != 0) 'holder_shares': holderShares,
    if (holderVolume != 0) 'holder_volume': holderVolume,
    'trade_count': tradeCount,
    if (tradeNotional != 0) 'trade_notional': tradeNotional,
    if (candidateSignal) 'candidate_signal': candidateSignal,
    if (sources.isNotEmpty)
      'sources': sources.map((source) => source.toJson()).toList(),
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

/// Source provenance for reproducible intelligence output.
@immutable
final class SourceRef {
  const SourceRef({required this.kind, this.rows = 0, this.asOf = ''});

  final String kind;
  final int rows;
  final String asOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    if (rows != 0) 'rows': rows,
    if (asOf.isNotEmpty) 'as_of': asOf,
  };
}

/// Reproducibility issue between source adapters.
@immutable
final class SourceConflict {
  const SourceConflict({
    required this.field,
    required this.primary,
    required this.other,
    required this.reason,
  });

  final String field;
  final String primary;
  final String other;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'field': field,
    'primary': primary,
    'other': other,
    'reason': reason,
  };
}

/// Pure input contract for [scoreWallet].
@immutable
final class ScoreInput {
  const ScoreInput({
    required this.wallet,
    this.wins = 0,
    this.bets = 0,
    this.volume = 0,
    this.realizedPnL = 0,
    this.categoryEdge = 0,
    this.concentrationSignal = false,
    this.lateEntrySignal = false,
    this.coPositioningSignal = false,
    this.priorWins = 0,
    this.priorBets = 0,
    this.asOf,
    this.sourceRows = 0,
  });

  final String wallet;
  final int wins;
  final int bets;
  final double volume;
  final double realizedPnL;
  final double categoryEdge;
  final bool concentrationSignal;
  final bool lateEntrySignal;
  final bool coPositioningSignal;
  final double priorWins;
  final double priorBets;
  final DateTime? asOf;
  final int sourceRows;
}

/// Source row limits and scoring priors for [WalletIntelService.walletDossier].
@immutable
final class DossierOptions {
  const DossierOptions({
    this.limit = 0,
    this.priorWins = 0,
    this.priorBets = 0,
    this.asOf,
  });

  final int limit;
  final double priorWins;
  final double priorBets;
  final DateTime? asOf;
}

/// Options for [WalletIntelService.leaderboard].
@immutable
final class LeaderboardOptions {
  const LeaderboardOptions({this.limit = 0, this.asOf});

  final int limit;
  final DateTime? asOf;
}

/// Options for [WalletIntelService.alerts].
@immutable
final class AlertOptions {
  const AlertOptions({
    required this.user,
    this.limit = 0,
    this.minScore = 0,
    this.asOf,
  });

  final String user;
  final int limit;
  final int minScore;
  final DateTime? asOf;
}

/// Options for [WalletIntelService.marketFlow].
@immutable
final class MarketFlowOptions {
  const MarketFlowOptions({this.limit = 0, this.asOf});

  final int limit;
  final DateTime? asOf;
}

/// Minimal Data API contract needed for wallet-intelligence dossiers.
abstract interface class WalletIntelDataReader {
  Future<List<Position>> currentPositions(String user, {int limit = 0});

  Future<List<ClosedPosition>> closedPositions(String user, {int limit = 0});

  Future<List<Trade>> tradesForUser(String user, {int limit = 0});

  Future<List<Trade>> marketTradesForMarket(String market, {int limit = 0});

  Future<List<MetaHolder>> topHolders(String market, {int limit = 0});

  Future<OpenInterest?> openInterestForMarket(String market);

  Future<List<TraderLeaderboardEntry>> traderLeaderboard({int limit = 0});
}

/// Adapter that wires [WalletIntelService] to [DataApiClient].
final class DataApiWalletIntelReader implements WalletIntelDataReader {
  const DataApiWalletIntelReader(this.data);

  final DataApiClient data;

  @override
  Future<List<Position>> currentPositions(String user, {int limit = 0}) {
    return data.currentPositions(user, limit: limit);
  }

  @override
  Future<List<ClosedPosition>> closedPositions(String user, {int limit = 0}) {
    return data.closedPositions(user, limit: limit);
  }

  @override
  Future<List<Trade>> tradesForUser(String user, {int limit = 0}) {
    return data.trades(user, limit: limit);
  }

  @override
  Future<List<Trade>> marketTradesForMarket(String market, {int limit = 0}) {
    return data.marketTrades(market, limit: limit);
  }

  @override
  Future<List<MetaHolder>> topHolders(String market, {int limit = 0}) {
    return data.topHolders(market, limit: limit);
  }

  @override
  Future<OpenInterest> openInterestForMarket(String market) {
    return data.openInterest(market);
  }

  @override
  Future<List<TraderLeaderboardEntry>> traderLeaderboard({int limit = 0}) {
    return data.traderLeaderboard(limit: limit);
  }
}

/// Builds read-only wallet-intelligence dossiers from source adapters.
final class WalletIntelService {
  const WalletIntelService(this._data, {DateTime Function()? now}) : _now = now;

  /// Creates a service backed by [DataApiClient].
  factory WalletIntelService.fromDataApi(
    DataApiClient data, {
    DateTime Function()? now,
  }) {
    return WalletIntelService(DataApiWalletIntelReader(data), now: now);
  }

  final WalletIntelDataReader? _data;
  final DateTime Function()? _now;

  /// Builds a source-backed wallet dossier.
  ///
  /// Closed-position rows are authoritative for realized PnL and win/loss
  /// counts in V1. Trade/current-position failures produce partial dossiers
  /// instead of synthetic zeroes.
  Future<WalletDossier> walletDossier(
    String wallet, {
    DossierOptions options = const DossierOptions(),
  }) async {
    wallet = wallet.trim();
    if (wallet.isEmpty) {
      throw const WalletIntelException('intel: wallet is required');
    }
    final data = _requireData();
    final limit = options.limit <= 0 ? _defaultLimit : options.limit;
    final asOf = options.asOf ?? _currentTime();
    final asOfString = _formatRfc3339(asOf);

    final warnings = <String>[];
    final conflicts = <SourceConflict>[];
    final sources = <SourceRef>[];

    List<ClosedPosition> closed = const <ClosedPosition>[];
    Object? closedErr;
    try {
      closed = await data.closedPositions(wallet, limit: limit);
      sources.add(
        SourceRef(
          kind: 'data_api.closed_positions',
          rows: closed.length,
          asOf: asOfString,
        ),
      );
    } on Object catch (e) {
      closedErr = e;
      warnings.add('closed positions unavailable: $e');
    }

    List<Position> positions = const <Position>[];
    try {
      positions = await data.currentPositions(wallet, limit: limit);
      sources.add(
        SourceRef(
          kind: 'data_api.current_positions',
          rows: positions.length,
          asOf: asOfString,
        ),
      );
      conflicts.addAll(_walletConflicts(wallet, positions));
    } on Object catch (e) {
      warnings.add('current positions unavailable: $e');
    }

    List<Trade> trades = const <Trade>[];
    try {
      trades = await data.tradesForUser(wallet, limit: limit);
      sources.add(
        SourceRef(
          kind: 'data_api.trades',
          rows: trades.length,
          asOf: asOfString,
        ),
      );
      conflicts.addAll(_tradeWalletConflicts(wallet, trades));
    } on Object catch (e) {
      warnings.add('trades unavailable: $e');
    }

    if (closedErr != null) {
      return WalletDossier(
        wallet: wallet,
        asOf: asOf,
        status: _statusFor(warnings, conflicts),
        summary: WalletSummary(wallet: wallet, asOf: asOf),
        score: WalletScore(
          wallet: wallet,
          formulaVersion: formulaWalletScoreV1,
          asOf: asOf,
          confidence: confidenceNone,
          language: _candidateLanguage,
        ),
        sources: sources,
        conflicts: conflicts,
        warnings: warnings,
      );
    }

    var summary = _summarizeClosed(wallet, closed, asOf);
    summary = WalletSummary(
      wallet: summary.wallet,
      volume: summary.volume,
      realizedPnL: summary.realizedPnL,
      roi: summary.roi,
      bets: summary.bets,
      wins: summary.wins,
      rawWinRate: summary.rawWinRate,
      shrinkageWinRate: summary.shrinkageWinRate,
      lastActive: summary.lastActive,
      asOf: summary.asOf,
      formulaVersion: summary.formulaVersion,
      sourceRows: closed.length,
      sourceDescription: 'data_api.closed_positions',
    );
    if (trades.isNotEmpty && closed.isEmpty) {
      warnings.add('trades exist but closed-position authority has no rows');
    }
    if (positions.isNotEmpty) {
      warnings.add(
        'current positions are present but not included in realized PnL',
      );
    }

    final score = scoreWallet(
      ScoreInput(
        wallet: wallet,
        wins: summary.wins,
        bets: summary.bets,
        volume: summary.volume,
        realizedPnL: summary.realizedPnL,
        priorWins: options.priorWins,
        priorBets: options.priorBets,
        asOf: asOf,
        sourceRows: summary.sourceRows,
      ),
    );

    return WalletDossier(
      wallet: wallet,
      asOf: asOf,
      status: _statusFor(warnings, conflicts),
      summary: summary,
      score: score,
      sources: sources,
      conflicts: conflicts,
      warnings: warnings,
    );
  }

  /// Returns Data-API-ranked wallet intelligence rows.
  ///
  /// V1 does not invent shrinkage win rates because the Data API leaderboard
  /// row does not expose wins/bets.
  Future<List<LeaderboardRow>> leaderboard({
    LeaderboardOptions options = const LeaderboardOptions(),
  }) async {
    final data = _requireData();
    final limit = options.limit <= 0 ? 20 : options.limit;
    final asOf = options.asOf ?? _currentTime();
    final rows = await data.traderLeaderboard(limit: limit);
    final out = <LeaderboardRow>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rank = row.rank == 0 ? i + 1 : row.rank;
      final summary = WalletSummary(
        wallet: row.user,
        volume: row.volume,
        realizedPnL: row.pnl,
        roi: row.roi,
        asOf: asOf,
        formulaVersion: formulaWalletScoreV1,
        sourceRows: 1,
        sourceDescription: 'data_api.trader_leaderboard',
      );
      final score = scoreWallet(
        ScoreInput(
          wallet: row.user,
          volume: row.volume,
          realizedPnL: row.pnl,
          asOf: asOf,
          sourceRows: 1,
        ),
      );
      out.add(
        LeaderboardRow(
          rank: rank,
          wallet: row.user,
          summary: summary,
          score: score,
        ),
      );
    }
    return out;
  }

  /// Builds batch intelligence alerts from a wallet dossier.
  Future<List<Signal>> alerts(AlertOptions options) async {
    final limit = options.limit <= 0 ? _defaultLimit : options.limit;
    final asOf = options.asOf ?? _currentTime();
    final dossier = await walletDossier(
      options.user,
      options: DossierOptions(limit: limit, asOf: asOf),
    );
    final minScore = options.minScore <= 0 ? 70 : options.minScore;
    if (dossier.score.value < minScore) return const <Signal>[];
    return <Signal>[
      Signal(
        score: dossier.score.value,
        wallet: dossier.wallet,
        confidence: dossier.score.confidence,
        formulaVersion: formulaWalletScoreV1,
        asOf: asOf,
        language: dossier.score.language,
        reasons: List<String>.of(dossier.score.reasons),
        sources: List<SourceRef>.of(dossier.sources),
      ),
    ];
  }

  /// Summarizes bounded Data API holder, trade, and open-interest reads for one
  /// market/token.
  Future<MarketFlow> marketFlow(
    String market, {
    MarketFlowOptions options = const MarketFlowOptions(),
  }) async {
    market = market.trim();
    if (market.isEmpty) {
      throw const WalletIntelException('intel: market is required');
    }
    final data = _requireData();
    final limit = options.limit <= 0 ? _defaultLimit : options.limit;
    final asOf = options.asOf ?? _currentTime();
    final asOfString = _formatRfc3339(asOf);
    final sources = <SourceRef>[];
    final warnings = <String>[];
    var holderCount = 0;
    var holderShares = 0.0;
    var holderVolume = 0.0;
    var tradeCount = 0;
    var tradeNotional = 0.0;
    var openInterest = 0.0;

    try {
      final holders = await data.topHolders(market, limit: limit);
      sources.add(
        SourceRef(
          kind: 'data_api.holders',
          rows: holders.length,
          asOf: asOfString,
        ),
      );
      holderCount = holders.length;
      for (final holder in holders) {
        holderShares += holder.shares;
        holderVolume += holder.volume;
      }
    } on Object catch (e) {
      warnings.add('holders unavailable: $e');
    }

    try {
      final trades = await data.marketTradesForMarket(market, limit: limit);
      sources.add(
        SourceRef(
          kind: 'data_api.market_trades',
          rows: trades.length,
          asOf: asOfString,
        ),
      );
      tradeCount = trades.length;
      for (final trade in trades) {
        tradeNotional += trade.price * trade.size;
      }
    } on Object catch (e) {
      warnings.add('market trades unavailable: $e');
    }

    try {
      final oi = await data.openInterestForMarket(market);
      if (oi != null) {
        sources.add(
          SourceRef(kind: 'data_api.open_interest', rows: 1, asOf: asOfString),
        );
        openInterest = oi.openValue;
      }
    } on Object catch (e) {
      warnings.add('open interest unavailable: $e');
    }

    return MarketFlow(
      market: market,
      asOf: asOf,
      formulaVersion: 'market_flow_v1',
      openInterest: openInterest,
      holderCount: holderCount,
      holderShares: holderShares,
      holderVolume: holderVolume,
      tradeCount: tradeCount,
      tradeNotional: tradeNotional,
      candidateSignal:
          tradeNotional > 0 || holderVolume > 0 || openInterest > 0,
      sources: sources,
      warnings: warnings,
    );
  }

  WalletIntelDataReader _requireData() {
    final data = _data;
    if (data == null) {
      throw const WalletIntelException('intel: data reader is required');
    }
    return data;
  }

  DateTime _currentTime() {
    final now = _now;
    return (now == null ? DateTime.now() : now()).toUtc();
  }
}

/// Win rate pulled toward a prior so tiny samples do not outrank durable records.
double shrinkageWinRate(
  int wins,
  int bets,
  double priorWins,
  double priorBets,
) {
  if (bets < 0) bets = 0;
  if (wins < 0) wins = 0;
  if (wins > bets) wins = bets;
  if (priorWins < 0) priorWins = 0;
  if (priorBets < 0) priorBets = 0;
  if (priorWins > priorBets && priorBets > 0) priorWins = priorBets;
  final denominator = bets + priorBets;
  if (denominator == 0) return 0;
  return (wins + priorWins) / denominator;
}

/// Realized PnL divided by traded volume; returns zero for non-positive volume.
double walletRoi(double realizedPnL, double volume) {
  if (volume <= 0) return 0;
  return realizedPnL / volume;
}

/// Converts public wallet metrics into a deterministic explainable score.
WalletScore scoreWallet(ScoreInput input) {
  final (priorWins, priorBets) = _normalizePrior(
    input.priorWins,
    input.priorBets,
  );
  final (wins, bets) = _normalizeRecord(input.wins, input.bets);
  final rawWinRate = bets > 0 ? wins / bets : 0.0;
  final roi = walletRoi(input.realizedPnL, input.volume);
  final shrinkage = shrinkageWinRate(wins, bets, priorWins, priorBets);

  var score = 0;
  final reasons = <String>[];

  final (sampleValue, sampleReason) = _sampleScore(bets);
  score += sampleValue;
  if (sampleReason.isNotEmpty) reasons.add(sampleReason);

  final (shrinkageValue, shrinkageReason) = _shrinkageScore(shrinkage);
  score += shrinkageValue;
  if (shrinkageReason.isNotEmpty) reasons.add(shrinkageReason);

  if (input.realizedPnL > 0) {
    score += 15;
    reasons.add('positive realized PnL');
  }

  final (roiValue, roiReason) = _roiScore(roi);
  score += roiValue;
  if (roiReason.isNotEmpty) reasons.add(roiReason);

  final (categoryValue, categoryReason) = _categoryEdgeScore(
    input.categoryEdge,
  );
  score += categoryValue;
  if (categoryReason.isNotEmpty) reasons.add(categoryReason);

  if (input.concentrationSignal) {
    score += 5;
    reasons.add('concentrated exposure requires review');
  }
  if (input.lateEntrySignal) {
    score += 5;
    reasons.add('late market entry requires review');
  }
  if (input.coPositioningSignal) {
    score += 5;
    reasons.add('repeat co-positioning suggests potential coordination signal');
  }

  if (score > 100) score = 100;
  if (score < 0) score = 0;

  return WalletScore(
    wallet: input.wallet,
    value: score,
    confidence: _confidenceForBets(bets),
    formulaVersion: formulaWalletScoreV1,
    asOf: input.asOf,
    sourceRows: input.sourceRows,
    reasons: reasons,
    language: _candidateLanguage,
    rawMetrics: WalletScoreMetrics(
      wins: wins,
      bets: bets,
      volume: input.volume,
      realizedPnL: input.realizedPnL,
      roi: roi,
      rawWinRate: rawWinRate,
      shrinkageWinRate: shrinkage,
      categoryEdge: input.categoryEdge,
      concentrationSignal: input.concentrationSignal,
      lateEntrySignal: input.lateEntrySignal,
      coPositioningSignal: input.coPositioningSignal,
      shrinkagePriorWins: priorWins,
      shrinkagePriorBets: priorBets,
    ),
  );
}

(double, double) _normalizePrior(double priorWins, double priorBets) {
  if (priorWins <= 0 && priorBets <= 0) {
    return (_defaultPriorWins, _defaultPriorBets);
  }
  if (priorWins < 0) priorWins = 0;
  if (priorBets <= 0) priorBets = _defaultPriorBets;
  if (priorWins > priorBets) priorWins = priorBets;
  return (priorWins, priorBets);
}

(int, int) _normalizeRecord(int wins, int bets) {
  if (bets < 0) bets = 0;
  if (wins < 0) wins = 0;
  if (wins > bets) wins = bets;
  return (wins, bets);
}

(int, String) _sampleScore(int bets) {
  if (bets >= 100) {
    return (20, 'large enough sample for high-confidence interpretation');
  }
  if (bets >= 30) return (12, 'moderate sample for interpretation');
  if (bets > 0) return (5, 'small sample; score is heavily discounted');
  return (0, '');
}

(int, String) _shrinkageScore(double rate) {
  if (rate >= 0.65) {
    return (25, 'shrinkage-adjusted win rate is materially above prior');
  }
  if (rate >= 0.58) return (18, 'shrinkage-adjusted win rate is above prior');
  if (rate >= 0.52) {
    return (10, 'shrinkage-adjusted win rate is slightly above prior');
  }
  return (0, '');
}

(int, String) _roiScore(double roi) {
  if (roi >= 0.10) return (15, 'ROI is strongly positive');
  if (roi >= 0.02) return (10, 'ROI is positive');
  if (roi > 0) return (5, 'ROI is slightly positive');
  return (0, '');
}

(int, String) _categoryEdgeScore(double edge) {
  if (edge >= 0.08) return (10, 'category edge is elevated');
  if (edge >= 0.03) return (5, 'category edge is positive');
  return (0, '');
}

String _confidenceForBets(int bets) {
  if (bets >= 100) return confidenceHigh;
  if (bets >= 30) return confidenceMedium;
  if (bets > 0) return confidenceLow;
  return confidenceNone;
}

WalletSummary _summarizeClosed(
  String wallet,
  List<ClosedPosition> rows,
  DateTime asOf,
) {
  var bets = 0;
  var wins = 0;
  var realizedPnL = 0.0;
  var volume = 0.0;
  DateTime? lastActive;
  for (final row in rows) {
    if (_emptyClosed(row)) continue;
    bets++;
    if (row.realizedPnl > 0) wins++;
    realizedPnL += row.realizedPnl;
    var rowVolume = row.totalBought;
    if (rowVolume == 0) rowVolume = row.size * row.avgPrice;
    volume += rowVolume;
    final ts = _parseRowTime(row.timestamp);
    if (ts != null && (lastActive == null || ts.isAfter(lastActive))) {
      lastActive = ts;
    }
  }
  final rawWinRate = bets > 0 ? wins / bets : 0.0;
  return WalletSummary(
    wallet: wallet,
    asOf: asOf,
    formulaVersion: formulaShrinkageWinRateV1,
    bets: bets,
    wins: wins,
    realizedPnL: realizedPnL,
    volume: volume,
    rawWinRate: rawWinRate,
    roi: walletRoi(realizedPnL, volume),
    shrinkageWinRate: shrinkageWinRate(wins, bets, 0, 0),
    lastActive: lastActive,
  );
}

String _statusFor(List<String> warnings, List<SourceConflict> conflicts) {
  if (conflicts.isNotEmpty) return dossierStatusConflicted;
  if (warnings.isNotEmpty) return dossierStatusPartial;
  return dossierStatusComplete;
}

List<SourceConflict> _walletConflicts(String wallet, List<Position> rows) {
  final out = <SourceConflict>[];
  for (final row in rows) {
    if (row.proxyWallet.isEmpty || _addressEqual(row.proxyWallet, wallet)) {
      continue;
    }
    out.add(
      SourceConflict(
        field: 'proxyWallet',
        primary: wallet,
        other: row.proxyWallet,
        reason: 'current position belongs to a different proxy wallet',
      ),
    );
  }
  return out;
}

List<SourceConflict> _tradeWalletConflicts(String wallet, List<Trade> rows) {
  final out = <SourceConflict>[];
  for (final row in rows) {
    if (row.proxyWallet.isEmpty || _addressEqual(row.proxyWallet, wallet)) {
      continue;
    }
    out.add(
      SourceConflict(
        field: 'proxyWallet',
        primary: wallet,
        other: row.proxyWallet,
        reason: 'trade belongs to a different proxy wallet',
      ),
    );
  }
  return out;
}

bool _emptyClosed(ClosedPosition row) {
  return row.tokenId.isEmpty &&
      row.conditionId.isEmpty &&
      row.marketId.isEmpty &&
      row.title.isEmpty &&
      row.realizedPnl == 0 &&
      row.size == 0;
}

DateTime? _parseRowTime(String raw) {
  raw = raw.trim();
  if (raw.isEmpty || !raw.contains('T')) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toUtc();
}

bool _addressEqual(String a, String b) => a.toLowerCase() == b.toLowerCase();

String _formatRfc3339(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  String four(int n) => n.toString().padLeft(4, '0');
  return '${four(utc.year)}-${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}
