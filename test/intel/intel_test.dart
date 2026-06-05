import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  group('wallet intelligence scoring', () {
    test('shrinkageWinRate mirrors Polygolem normalization', () {
      expect(shrinkageWinRate(0, 0, 10, 20), closeTo(0.5, 1e-12));
      expect(shrinkageWinRate(2, 2, 10, 20), closeTo(12 / 22, 1e-12));
      expect(shrinkageWinRate(95, 150, 10, 20), closeTo(105 / 170, 1e-12));
      expect(shrinkageWinRate(10, 40, 10, 20), closeTo(20 / 60, 1e-12));
      expect(shrinkageWinRate(5, 2, 10, 20), closeTo(12 / 22, 1e-12));
      expect(shrinkageWinRate(0, 0, 0, 0), 0);
    });

    test('walletRoi avoids infinity for zero/negative volume', () {
      expect(walletRoi(25, 100), closeTo(0.25, 1e-12));
      expect(walletRoi(-5, 100), closeTo(-0.05, 1e-12));
      expect(walletRoi(25, 0), 0);
      expect(walletRoi(25, -10), 0);
    });

    test('scoreWallet produces deterministic explainable score', () {
      final asOf = DateTime.utc(2026, 6, 3);
      final score = scoreWallet(
        ScoreInput(
          wallet: '0xwallet',
          wins: 95,
          bets: 150,
          volume: 10000,
          realizedPnL: 1200,
          categoryEdge: 0.09,
          concentrationSignal: true,
          lateEntrySignal: true,
          coPositioningSignal: true,
          asOf: asOf,
          sourceRows: 300,
        ),
      );

      expect(score.wallet, '0xwallet');
      expect(score.value, 93);
      expect(score.confidence, confidenceHigh);
      expect(score.formulaVersion, formulaWalletScoreV1);
      expect(score.asOf, asOf);
      expect(score.sourceRows, 300);
      expect(score.rawMetrics.roi, closeTo(0.12, 1e-12));
      expect(score.rawMetrics.shrinkageWinRate, closeTo(105 / 170, 1e-12));
      final reasons = score.reasons.join(' | ');
      for (final needle in <String>[
        'large enough sample',
        'shrinkage-adjusted win rate is above prior',
        'positive realized PnL',
        'ROI is strongly positive',
        'category edge is elevated',
        'potential coordination signal',
      ]) {
        expect(reasons, contains(needle));
      }
      expect(score.language, contains('not a finding'));
    });

    test('scoreWallet discounts tiny samples and losing records', () {
      final small = scoreWallet(
        const ScoreInput(
          wallet: '0xsmall',
          wins: 2,
          bets: 2,
          volume: 100,
          realizedPnL: 10,
        ),
      );
      final durable = scoreWallet(
        const ScoreInput(
          wallet: '0xdurable',
          wins: 95,
          bets: 150,
          volume: 10000,
          realizedPnL: 1200,
        ),
      );
      expect(small.confidence, confidenceLow);
      expect(small.value, 45);
      expect(small.value, lessThan(durable.value));

      final empty = scoreWallet(const ScoreInput(wallet: '0xempty'));
      expect(empty.value, 0);
      expect(empty.confidence, confidenceNone);
      expect(empty.reasons, isEmpty);

      final losing = scoreWallet(
        const ScoreInput(
          wallet: '0xlosing',
          wins: 10,
          bets: 40,
          volume: 1000,
          realizedPnL: -100,
        ),
      );
      expect(losing.value, 12);
      expect(losing.confidence, confidenceMedium);
    });
  });

  group('WalletIntelService', () {
    test(
      'walletDossier uses closed positions as realized PnL authority',
      () async {
        final asOf = DateTime.utc(2026, 6, 3);
        final reader = _FakeWalletIntelDataReader(
          closed: <ClosedPosition>[
            const ClosedPosition(
              tokenId: 'won',
              conditionId: '',
              marketId: '',
              side: '',
              avgPriceBuy: 0,
              avgPriceSell: 0,
              avgPrice: 0.4,
              size: 10,
              totalBought: 4,
              realizedPnl: 6,
              timestamp: '2026-06-02T10:00:00Z',
            ),
            const ClosedPosition(
              tokenId: 'lost',
              conditionId: '',
              marketId: '',
              side: '',
              avgPriceBuy: 0,
              avgPriceSell: 0,
              avgPrice: 0.5,
              size: 5,
              totalBought: 2.5,
              realizedPnl: -2.5,
              timestamp: '2026-06-02T11:00:00Z',
            ),
          ],
          positions: <Position>[
            const Position(
              tokenId: 'open',
              conditionId: '',
              marketId: '',
              side: '',
              avgPrice: 0,
              size: 0,
              currentPrice: 0,
              unrealizedPnl: 0,
              proxyWallet: '0xwallet',
              currentValue: 12,
            ),
          ],
          trades: <Trade>[
            const Trade(
              id: 'trade',
              market: '',
              assetId: '',
              side: '',
              price: 0.9,
              size: 100,
              feeRateBps: 0,
              createdAt: '',
              proxyWallet: '0xwallet',
            ),
          ],
        );
        final service = WalletIntelService(reader);

        final dossier = await service.walletDossier(
          '0xwallet',
          options: DossierOptions(asOf: asOf, limit: 50),
        );

        expect(reader.closedLimit, 50);
        expect(reader.positionsLimit, 50);
        expect(reader.tradesLimit, 50);
        expect(dossier.status, dossierStatusPartial);
        expect(dossier.summary.bets, 2);
        expect(dossier.summary.wins, 1);
        expect(dossier.summary.realizedPnL, 3.5);
        expect(dossier.summary.volume, 6.5);
        expect(dossier.summary.sourceDescription, 'data_api.closed_positions');
        expect(dossier.summary.sourceRows, 2);
        expect(dossier.summary.lastActive, DateTime.utc(2026, 6, 2, 11));
        expect(dossier.score.rawMetrics.bets, 2);
        expect(dossier.score.rawMetrics.wins, 1);
        expect(dossier.sources, hasLength(3));
        expect(
          dossier.warnings.join('\n'),
          contains('current positions are present'),
        );
      },
    );

    test(
      'walletDossier marks partial when closed positions are unavailable',
      () async {
        final reader = _FakeWalletIntelDataReader(
          closedError: Exception('upstream closed down'),
          trades: <Trade>[
            const Trade(
              id: 'trade',
              market: '',
              assetId: '',
              side: '',
              price: 0,
              size: 0,
              feeRateBps: 0,
              createdAt: '',
              proxyWallet: '0xwallet',
            ),
          ],
        );
        final service = WalletIntelService(
          reader,
          now: () => DateTime.utc(2026, 6, 3),
        );

        final dossier = await service.walletDossier('0xwallet');

        expect(dossier.status, dossierStatusPartial);
        expect(dossier.score.confidence, confidenceNone);
        expect(dossier.score.value, 0);
        expect(
          dossier.warnings.join('\n'),
          contains('closed positions unavailable'),
        );
      },
    );

    test('walletDossier marks conflicted source rows', () async {
      final reader = _FakeWalletIntelDataReader(
        closed: <ClosedPosition>[
          const ClosedPosition(
            tokenId: 'won',
            conditionId: '',
            marketId: '',
            side: '',
            avgPriceBuy: 0,
            avgPriceSell: 0,
            size: 1,
            avgPrice: 0.4,
            realizedPnl: 0.6,
          ),
        ],
        positions: <Position>[
          const Position(
            tokenId: 'open',
            conditionId: '',
            marketId: '',
            side: '',
            avgPrice: 0,
            size: 0,
            currentPrice: 0,
            unrealizedPnl: 0,
            proxyWallet: '0xother',
          ),
        ],
        trades: <Trade>[
          const Trade(
            id: 'trade',
            market: '',
            assetId: '',
            side: '',
            price: 0,
            size: 0,
            feeRateBps: 0,
            createdAt: '',
            proxyWallet: '0xwallet',
          ),
        ],
      );
      final service = WalletIntelService(reader);

      final dossier = await service.walletDossier('0xwallet');

      expect(dossier.status, dossierStatusConflicted);
      expect(dossier.conflicts, hasLength(1));
      expect(dossier.conflicts.single.other, '0xother');
    });

    test('leaderboard uses Data API rows without inventing wins', () async {
      final asOf = DateTime.utc(2026, 6, 3);
      final reader = _FakeWalletIntelDataReader(
        leaderboard: <TraderLeaderboardEntry>[
          const TraderLeaderboardEntry(
            rank: 3,
            user: '0xwallet',
            volume: 1000,
            pnl: 125,
            roi: 0.125,
          ),
        ],
      );
      final service = WalletIntelService(reader);

      final rows = await service.leaderboard(
        options: LeaderboardOptions(limit: 7, asOf: asOf),
      );

      expect(reader.leaderboardLimit, 7);
      expect(rows, hasLength(1));
      expect(rows.single.rank, 3);
      expect(rows.single.wallet, '0xwallet');
      expect(rows.single.summary.volume, 1000);
      expect(rows.single.summary.realizedPnL, 125);
      expect(rows.single.summary.roi, 0.125);
      expect(rows.single.score.rawMetrics.bets, 0);
      expect(rows.single.score.rawMetrics.wins, 0);
    });

    test(
      'alerts returns a candidate signal only when threshold passes',
      () async {
        final reader = _FakeWalletIntelDataReader(
          closed: <ClosedPosition>[
            const ClosedPosition(
              tokenId: 'a',
              conditionId: '',
              marketId: '',
              side: '',
              avgPriceBuy: 0,
              avgPriceSell: 0,
              size: 10,
              totalBought: 5,
              realizedPnl: 10,
            ),
            const ClosedPosition(
              tokenId: 'b',
              conditionId: '',
              marketId: '',
              side: '',
              avgPriceBuy: 0,
              avgPriceSell: 0,
              size: 10,
              totalBought: 5,
              realizedPnl: 10,
            ),
          ],
        );
        final service = WalletIntelService(reader);

        final signals = await service.alerts(
          const AlertOptions(user: '0xwallet', minScore: 40),
        );
        expect(signals, hasLength(1));
        expect(signals.single.wallet, '0xwallet');
        expect(signals.single.score, greaterThanOrEqualTo(40));
        expect(signals.single.language, contains('not a finding'));

        final filtered = await service.alerts(
          const AlertOptions(user: '0xwallet', minScore: 99),
        );
        expect(filtered, isEmpty);
      },
    );

    test('marketFlow summarizes bounded Data API reads', () async {
      final asOf = DateTime.utc(2026, 6, 3);
      final reader = _FakeWalletIntelDataReader(
        holders: <MetaHolder>[
          const MetaHolder(address: '0xa', shares: 10, pnl: 0, volume: 100),
          const MetaHolder(address: '0xb', shares: 3, pnl: 0, volume: 25),
        ],
        marketTrades: <Trade>[
          const Trade(
            id: 't1',
            market: '',
            assetId: '',
            side: '',
            price: 0.5,
            size: 10,
            feeRateBps: 0,
            createdAt: '',
          ),
          const Trade(
            id: 't2',
            market: '',
            assetId: '',
            side: '',
            price: 0.25,
            size: 4,
            feeRateBps: 0,
            createdAt: '',
          ),
        ],
        openInterest: const OpenInterest(
          market: '0xmarket',
          assetId: '',
          openValue: 200,
        ),
      );
      final service = WalletIntelService(reader);

      final flow = await service.marketFlow(
        '0xmarket',
        options: MarketFlowOptions(limit: 12, asOf: asOf),
      );

      expect(reader.holdersLimit, 12);
      expect(reader.marketTradesLimit, 12);
      expect(flow.holderCount, 2);
      expect(flow.holderShares, 13);
      expect(flow.holderVolume, 125);
      expect(flow.tradeCount, 2);
      expect(flow.tradeNotional, 6);
      expect(flow.openInterest, 200);
      expect(flow.candidateSignal, isTrue);
      expect(flow.sources, hasLength(3));
    });

    test('requires wallet, market, and reader', () async {
      await expectLater(
        WalletIntelService(_FakeWalletIntelDataReader()).walletDossier(' '),
        throwsA(isA<WalletIntelException>()),
      );
      await expectLater(
        const WalletIntelService(null).walletDossier('0xwallet'),
        throwsA(isA<WalletIntelException>()),
      );
      await expectLater(
        WalletIntelService(_FakeWalletIntelDataReader()).marketFlow(' '),
        throwsA(isA<WalletIntelException>()),
      );
    });
  });
}

final class _FakeWalletIntelDataReader implements WalletIntelDataReader {
  _FakeWalletIntelDataReader({
    this.positions = const <Position>[],
    this.closed = const <ClosedPosition>[],
    this.trades = const <Trade>[],
    this.marketTrades = const <Trade>[],
    this.holders = const <MetaHolder>[],
    this.openInterest,
    this.leaderboard = const <TraderLeaderboardEntry>[],
    this.closedError,
  });

  final List<Position> positions;
  final List<ClosedPosition> closed;
  final List<Trade> trades;
  final List<Trade> marketTrades;
  final List<MetaHolder> holders;
  final OpenInterest? openInterest;
  final List<TraderLeaderboardEntry> leaderboard;
  final Object? closedError;

  int positionsLimit = 0;
  int closedLimit = 0;
  int tradesLimit = 0;
  int marketTradesLimit = 0;
  int holdersLimit = 0;
  int leaderboardLimit = 0;

  @override
  Future<List<Position>> currentPositions(String user, {int limit = 0}) async {
    positionsLimit = limit;
    return positions;
  }

  @override
  Future<List<ClosedPosition>> closedPositions(
    String user, {
    int limit = 0,
  }) async {
    closedLimit = limit;
    if (closedError != null) throw closedError!;
    return closed;
  }

  @override
  Future<List<Trade>> tradesForUser(String user, {int limit = 0}) async {
    tradesLimit = limit;
    return trades;
  }

  @override
  Future<List<Trade>> marketTradesForMarket(
    String market, {
    int limit = 0,
  }) async {
    marketTradesLimit = limit;
    return marketTrades;
  }

  @override
  Future<List<MetaHolder>> topHolders(String market, {int limit = 0}) async {
    holdersLimit = limit;
    return holders;
  }

  @override
  Future<OpenInterest?> openInterestForMarket(String market) async {
    return openInterest;
  }

  @override
  Future<List<TraderLeaderboardEntry>> traderLeaderboard({
    int limit = 0,
  }) async {
    leaderboardLimit = limit;
    return leaderboard;
  }
}
