import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/clob/clob_auth_types.dart' as clob;
import 'package:polydart/src/dataapi/dataapi_types.dart' as data;
import 'package:polydart/src/orderresults/orderresults.dart';
import 'package:test/test.dart';

const _polygolemCommit = '2b7cde7';

void main() {
  group('buildReport', () {
    test('joins positions, closed positions, and Data API trades', () async {
      final source = _FakeDataReader(
        positions: const [
          data.Position(
            tokenId: 'token-sol-up',
            conditionId: '0xsol',
            marketId: '',
            side: '',
            avgPrice: 0.5099,
            size: 2.8627,
            currentPrice: 1,
            unrealizedPnl: 0,
            initialValue: 1.46,
            currentValue: 2.8627,
            cashPnl: 1.4027,
            redeemable: true,
            outcome: 'Up',
            title: 'Solana Up or Down - May 9, 8:20AM-8:25AM ET',
            slug: 'sol-updown-5m-1778329200',
          ),
          data.Position(
            tokenId: 'token-eth-up',
            conditionId: '0xeth',
            marketId: '',
            side: '',
            avgPrice: 0.5099,
            size: 4.0784,
            currentPrice: 0,
            unrealizedPnl: 0,
            initialValue: 2.08,
            currentValue: 0,
            cashPnl: -2.08,
            redeemable: true,
            outcome: 'Up',
            title: 'Ethereum Up or Down - May 9, 4:40AM-4:45AM ET',
            slug: 'eth-updown-5m-1778316000',
          ),
        ],
        closedPositions: const [
          data.ClosedPosition(
            tokenId: '',
            conditionId: '',
            marketId: '',
            side: '',
            avgPriceBuy: 0,
            avgPriceSell: 0,
            size: 0,
            realizedPnl: 0,
          ),
          data.ClosedPosition(
            tokenId: 'token-closed',
            conditionId: '0xclosed',
            marketId: '',
            side: '',
            avgPrice: 0.42,
            avgPriceBuy: 0.42,
            avgPriceSell: 0,
            size: 5,
            realizedPnl: 1.25,
            currentPrice: 1,
            title: 'Closed market',
            slug: 'closed-market',
            outcome: 'Yes',
          ),
        ],
        trades: const [
          data.Trade(
            id: 'trade-sol',
            market: '0xsol',
            assetId: 'token-sol-up',
            side: 'BUY',
            price: 0.51,
            size: 2.8627,
            feeRateBps: 0,
            createdAt: '1778329200',
            outcome: 'Up',
            transactionHash: '0xsoltx',
          ),
          data.Trade(
            id: 'trade-eth',
            market: '0xeth',
            assetId: 'token-eth-up',
            side: 'BUY',
            price: 0.51,
            size: 4.0784,
            feeRateBps: 0,
            createdAt: '1778316000',
            outcome: 'Up',
          ),
        ],
      );

      final report = await buildReport(
        source,
        user: ' 0xwallet ',
        options: const OrderResultsOptions(limit: 50),
      );

      expect(_polygolemCommit, '2b7cde7');
      expect(report.user, '0xwallet');
      expect(report.summary.won, 1);
      expect(report.summary.lost, 1);
      expect(report.summary.closed, 1);
      expect(report.summary.redeemable, 2);
      expect(report.summary.dataTrades, 2);
      expect(report.rows, hasLength(3));

      final sol = report.rowByToken('token-sol-up');
      expect(sol, isNotNull);
      expect(sol!.status, orderResultStatusWon);
      expect(sol.redeemable, isTrue);
      expect(sol.tradeCount, 1);
      expect(sol.trades.single.transactionHash, '0xsoltx');

      final eth = report.rowByToken('token-eth-up');
      expect(eth, isNotNull);
      expect(eth!.status, orderResultStatusLost);

      final closed = report.rowByToken('token-closed');
      expect(closed, isNotNull);
      expect(closed!.status, orderResultStatusClosed);
      expect(closed.realizedPnl, 1.25);
    });

    test(
      'can include authenticated CLOB history through ApiKey reader',
      () async {
        const apiKey = ApiKey(key: 'key', secret: 'secret', passphrase: 'pass');
        final clobReader = _FakeClobReader(
          orders: const [
            clob.OrderRecord(
              id: 'order-live',
              status: 'ORDER_STATUS_LIVE',
              owner: '',
              market: '0xopen',
              assetId: 'token-open',
              side: 'BUY',
              originalSize: '5',
              sizeMatched: '0',
              price: '0.48',
              outcome: 'Up',
              type: '',
              signatureType: 0,
              createdAt: '1778329500',
              expiration: '',
              makerAddress: '',
            ),
          ],
          trades: const [
            clob.TradeRecord(
              id: 'clob-trade',
              status: 'TRADE_STATUS_CONFIRMED',
              market: '0xopen',
              assetId: 'token-open',
              side: 'BUY',
              price: '0.48',
              size: '5',
              feeRateBps: '',
              outcome: 'Up',
              owner: '',
              builder: '',
              matchedAmount: '',
              transactionHash: '0xclobtx',
              createdAt: '1778329501',
              lastUpdated: '',
            ),
          ],
        );

        final report = await buildReport(
          _FakeDataReader(),
          user: '0xwallet',
          options: OrderResultsOptions(
            includeClob: true,
            clobReader: clobReader,
            clobApiKey: apiKey,
          ),
        );

        expect(clobReader.seenApiKey, same(apiKey));
        final row = report.rowByToken('token-open');
        expect(row, isNotNull);
        expect(row!.status, orderResultStatusOpen);
        expect(row.openOrderCount, 1);
        expect(row.tradeCount, 1);
        expect(row.openOrders.single.id, 'order-live');
        expect(row.trades.single.source, orderResultSourceClob);
      },
    );

    test('deduplicates Data API and CLOB trades by transaction hash', () async {
      final clobReader = _FakeClobReader(
        trades: const [
          clob.TradeRecord(
            id: 'clob-trade',
            status: 'CONFIRMED',
            market: '0xsol',
            assetId: 'token-sol-up',
            side: 'BUY',
            price: '0.51',
            size: '2',
            feeRateBps: '',
            outcome: 'Up',
            owner: '',
            builder: '',
            matchedAmount: '',
            transactionHash: '0xdupe',
            createdAt: '',
            lastUpdated: '',
          ),
        ],
      );

      final report = await buildReport(
        _FakeDataReader(
          trades: const [
            data.Trade(
              id: '',
              market: '0xsol',
              assetId: 'token-sol-up',
              side: 'BUY',
              price: 0.51,
              size: 2,
              feeRateBps: 0,
              createdAt: '',
              outcome: 'Up',
              transactionHash: '0xdupe',
            ),
          ],
        ),
        user: '0xwallet',
        options: OrderResultsOptions(
          includeClob: true,
          clobReader: clobReader,
          clobApiKey: const ApiKey(
            key: 'key',
            secret: 'secret',
            passphrase: 'pass',
          ),
        ),
      );

      final row = report.rowByToken('token-sol-up');
      expect(row, isNotNull);
      expect(row!.tradeCount, 1);
      expect(row.trades.single.source, orderResultSourceClob);
      expect(row.trades.single.id, 'clob-trade');
      expect(report.summary.matchedNotional, 1.02);
    });

    test(
      'requires an ApiKey and CLOB reader when CLOB inclusion is enabled',
      () {
        expect(
          () => buildReport(
            _FakeDataReader(),
            user: '0xwallet',
            options: const OrderResultsOptions(includeClob: true),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}

final class _FakeDataReader implements OrderResultsDataReader {
  _FakeDataReader({
    this.positions = const [],
    this.closedPositions = const [],
    this.trades = const [],
  });

  final List<data.Position> positions;
  final List<data.ClosedPosition> closedPositions;
  final List<data.Trade> trades;

  @override
  Future<List<data.Position>> currentPositions(
    String user, {
    required int limit,
  }) async => positions;

  @override
  Future<List<data.ClosedPosition>> closedPositionsForUser(
    String user, {
    required int limit,
  }) async => closedPositions;

  @override
  Future<List<data.Trade>> tradesForUser(
    String user, {
    required int limit,
  }) async => trades;
}

final class _FakeClobReader implements OrderResultsClobReader {
  _FakeClobReader({this.orders = const [], this.trades = const []});

  final List<clob.OrderRecord> orders;
  final List<clob.TradeRecord> trades;
  ApiKey? seenApiKey;

  @override
  Future<List<clob.OrderRecord>> listOrders({required ApiKey apiKey}) async {
    seenApiKey = apiKey;
    return orders;
  }

  @override
  Future<List<clob.TradeRecord>> listTrades({required ApiKey apiKey}) async {
    seenApiKey = apiKey;
    return trades;
  }
}
