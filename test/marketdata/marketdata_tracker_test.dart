import 'package:polydart/src/marketdata/marketdata_tracker.dart';
import 'package:polydart/src/stream/stream_messages.dart';
import 'package:test/test.dart';

// Parity reference: polygolem/pkg/marketdata/tracker_test.go at 2b7cde7.
void main() {
  group('MarketDataTracker', () {
    test('book computes best bid/ask and midpoint', () {
      final tracker = MarketDataTracker();

      final snapshot = tracker.applyBook(
        const BookMessage(
          eventType: 'book',
          assetId: 'token-1',
          market: 'market-1',
          timestamp: '1000',
          hash: '',
          bids: <PriceLevel>[
            PriceLevel(price: '0.49', size: '10'),
            PriceLevel(price: '0.51', size: '4'),
          ],
          asks: <PriceLevel>[
            PriceLevel(price: '0.55', size: '2'),
            PriceLevel(price: '0.53', size: '7'),
          ],
        ),
      );

      expect(snapshot.assetId, 'token-1');
      expect(snapshot.market, 'market-1');
      expect(snapshot.bestBid, '0.51');
      expect(snapshot.bestAsk, '0.53');
      expect(snapshot.midpoint, '0.52');
      expect(snapshot.bids.map((level) => level.price), <String>[
        '0.51',
        '0.49',
      ]);
      expect(snapshot.asks.map((level) => level.price), <String>[
        '0.53',
        '0.55',
      ]);
    });

    test('price change updates book and best prices', () {
      final tracker = MarketDataTracker()
        ..applyBook(
          const BookMessage(
            eventType: 'book',
            assetId: 'token-1',
            market: 'market-1',
            timestamp: '',
            hash: '',
            bids: <PriceLevel>[PriceLevel(price: '0.49', size: '10')],
            asks: <PriceLevel>[PriceLevel(price: '0.53', size: '7')],
          ),
        );

      final snapshots = tracker.applyPriceChange(
        const PriceChangeMessage(
          eventType: 'price_change',
          market: 'market-1',
          timestamp: '1001',
          changes: <PriceChangeEntry>[
            PriceChangeEntry(
              assetId: 'token-1',
              side: 'BUY',
              price: '0.52',
              size: '12',
              bestBid: '0.52',
              bestAsk: '0.53',
              hash: 'hash-1',
            ),
          ],
        ),
      );

      expect(snapshots, hasLength(1));
      final snapshot = snapshots.single;
      expect(snapshot.eventType, 'price_change');
      expect(snapshot.updateHash, 'hash-1');
      expect(snapshot.bestBid, '0.52');
      expect(snapshot.bestAsk, '0.53');
      expect(snapshot.midpoint, '0.525');
      expect(snapshot.bids.first.price, '0.52');
      expect(snapshot.bids.first.size, '12');
    });

    test('price change removes zero-size levels', () {
      final tracker = MarketDataTracker()
        ..applyBook(
          const BookMessage(
            eventType: '',
            assetId: 'token-1',
            market: 'market-1',
            timestamp: '',
            hash: '',
            bids: <PriceLevel>[
              PriceLevel(price: '0.49', size: '10'),
              PriceLevel(price: '0.48', size: '8'),
            ],
            asks: <PriceLevel>[PriceLevel(price: '0.53', size: '7')],
          ),
        );

      final snapshots = tracker.applyPriceChange(
        const PriceChangeMessage(
          eventType: '',
          market: 'market-1',
          timestamp: '1001',
          changes: <PriceChangeEntry>[
            PriceChangeEntry(
              assetId: 'token-1',
              side: 'BUY',
              price: '0.49',
              size: '0',
              hash: 'hash-1',
            ),
          ],
        ),
      );

      expect(snapshots.single.eventType, 'price_change');
      expect(snapshots.single.bids.map((level) => level.price), <String>[
        '0.48',
      ]);
      expect(snapshots.single.bestBid, '0.48');
    });

    test('last trade preserves book prices', () {
      final tracker = MarketDataTracker()
        ..applyBook(
          const BookMessage(
            eventType: 'book',
            assetId: 'token-1',
            market: 'market-1',
            timestamp: '',
            hash: '',
            bids: <PriceLevel>[PriceLevel(price: '0.49', size: '10')],
            asks: <PriceLevel>[PriceLevel(price: '0.53', size: '7')],
          ),
        );

      final snapshot = tracker.applyLastTrade(
        const LastTradeMessage(
          eventType: 'last_trade_price',
          assetId: 'token-1',
          market: 'market-1',
          price: '0.5',
          size: '25',
          side: 'BUY',
          feeRateBps: '',
          timestamp: '1002',
          transactionHash: '0xabc',
        ),
      );

      expect(snapshot.lastTradePrice, '0.5');
      expect(snapshot.lastTradeSize, '25');
      expect(snapshot.lastTradeSide, 'BUY');
      expect(snapshot.bestBid, '0.49');
      expect(snapshot.bestAsk, '0.53');
      expect(snapshot.midpoint, '0.51');
      expect(snapshot.transactionHash, '0xabc');
    });

    test('price change best bid/ask override stale book levels', () {
      final tracker = MarketDataTracker()
        ..applyBook(
          const BookMessage(
            eventType: 'book',
            assetId: 'token-1',
            market: 'market-1',
            timestamp: '',
            hash: '',
            bids: <PriceLevel>[PriceLevel(price: '0.49', size: '10')],
            asks: <PriceLevel>[PriceLevel(price: '0.53', size: '7')],
          ),
        );

      final snapshots = tracker.applyPriceChange(
        const PriceChangeMessage(
          eventType: 'price_change',
          market: 'market-1',
          timestamp: '1003',
          changes: <PriceChangeEntry>[
            PriceChangeEntry(
              assetId: 'token-1',
              side: '',
              price: '',
              size: '',
              hash: '',
              bestBid: '0.50',
              bestAsk: '0.54',
            ),
          ],
        ),
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.single.bestBid, '0.50');
      expect(snapshots.single.bestAsk, '0.54');
      expect(snapshots.single.midpoint, '0.52');
    });

    test('best bid/ask updates snapshot without book delta', () {
      final tracker = MarketDataTracker();

      final snapshot = tracker.applyBestBidAsk(
        const BestBidAskMessage(
          eventType: 'best_bid_ask',
          assetId: 'token-1',
          market: 'market-1',
          bestBid: '0.73',
          bestAsk: '0.77',
          spread: '0.04',
          timestamp: '1004',
        ),
      );

      expect(snapshot.eventType, 'best_bid_ask');
      expect(snapshot.assetId, 'token-1');
      expect(snapshot.bestBid, '0.73');
      expect(snapshot.bestAsk, '0.77');
      expect(snapshot.spread, '0.04');
      expect(snapshot.midpoint, '0.75');
    });

    test('tick size change tracks current tick size', () {
      final tracker = MarketDataTracker();

      final snapshot = tracker.applyTickSizeChange(
        const TickSizeChangeMessage(
          eventType: 'tick_size_change',
          assetId: 'token-1',
          market: 'market-1',
          oldTickSize: '0.01',
          newTickSize: '0.001',
          timestamp: '1005',
        ),
      );

      expect(snapshot.eventType, 'tick_size_change');
      expect(snapshot.tickSize, '0.001');
      expect(snapshot.previousTickSize, '0.01');
    });

    test('snapshot returns the latest view for an asset', () {
      final tracker = MarketDataTracker()
        ..applyBook(
          const BookMessage(
            eventType: '',
            assetId: 'token-1',
            market: 'market-1',
            timestamp: '',
            hash: '',
            bids: <PriceLevel>[PriceLevel(price: '0.49', size: '10')],
            asks: <PriceLevel>[PriceLevel(price: '0.53', size: '7')],
          ),
        );

      expect(tracker.snapshot('token-1')?.bestBid, '0.49');
      expect(tracker.snapshot('missing'), isNull);
    });

    test('stream message decoders use Polygolem field names', () {
      final change = PriceChangeEntry.fromJson(const <String, dynamic>{
        'asset_id': 'token-1',
        'side': 'BUY',
        'price': '0.50',
        'size': '10',
        'hash': 'hash-1',
        'best_bid': '0.50',
        'best_ask': '0.54',
      });
      expect(change.bestBid, '0.50');
      expect(change.bestAsk, '0.54');

      final trade = LastTradeMessage.fromJson(const <String, dynamic>{
        'event_type': 'last_trade_price',
        'asset_id': 'token-1',
        'market': 'market-1',
        'price': '0.5',
        'side': 'BUY',
        'size': '25',
        'fee_rate_bps': '0',
        'timestamp': '1002',
        'transaction_hash': '0xabc',
      });
      expect(trade.transactionHash, '0xabc');

      final best = BestBidAskMessage.fromJson(const <String, dynamic>{
        'event_type': 'best_bid_ask',
        'asset_id': 'token-1',
        'market': 'market-1',
        'best_bid': '0.73',
        'best_ask': '0.77',
        'spread': '0.04',
        'timestamp': '1004',
      });
      expect(best.bestBid, '0.73');

      final tick = TickSizeChangeMessage.fromJson(const <String, dynamic>{
        'event_type': 'tick_size_change',
        'asset_id': 'token-1',
        'market': 'market-1',
        'old_tick_size': '0.01',
        'new_tick_size': '0.001',
        'timestamp': '1005',
      });
      expect(tick.newTickSize, '0.001');
    });
  });
}
