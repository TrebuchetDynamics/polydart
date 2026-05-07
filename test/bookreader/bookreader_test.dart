import 'package:polydart/src/bookreader/bookreader.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

OrderBook _book({
  List<OrderBookLevel> bids = const [],
  List<OrderBookLevel> asks = const [],
}) => OrderBook(
  market: 'm',
  assetId: 'a',
  timestamp: '0',
  hash: '0x',
  bids: bids,
  asks: asks,
);

void main() {
  group('BookReader', () {
    test('sorts bids descending and asks ascending', () {
      final reader = BookReader(
        _book(
          bids: const [
            OrderBookLevel(price: '0.45', size: '10'),
            OrderBookLevel(price: '0.49', size: '5'),
            OrderBookLevel(price: '0.47', size: '20'),
          ],
          asks: const [
            OrderBookLevel(price: '0.55', size: '8'),
            OrderBookLevel(price: '0.51', size: '15'),
            OrderBookLevel(price: '0.53', size: '12'),
          ],
        ),
      );
      expect(reader.bids.map((l) => l.price), ['0.49', '0.47', '0.45']);
      expect(reader.asks.map((l) => l.price), ['0.51', '0.53', '0.55']);
      expect(reader.bestBid?.price, '0.49');
      expect(reader.bestAsk?.price, '0.51');
    });

    test('midpoint and spread', () {
      final reader = BookReader(
        _book(
          bids: const [OrderBookLevel(price: '0.49', size: '5')],
          asks: const [OrderBookLevel(price: '0.51', size: '5')],
        ),
      );
      expect(reader.midpoint, closeTo(0.50, 1e-9));
      expect(reader.spread, closeTo(0.02, 1e-9));
    });

    test('depth aggregates top N levels', () {
      final reader = BookReader(
        _book(
          bids: const [
            OrderBookLevel(price: '0.49', size: '10'),
            OrderBookLevel(price: '0.48', size: '20'),
            OrderBookLevel(price: '0.47', size: '30'),
          ],
        ),
      );
      expect(reader.depth(Side.buy, levels: 2), closeTo(30, 1e-9));
      expect(reader.depth(Side.buy, levels: 5), closeTo(60, 1e-9));
    });

    test('one-sided / empty', () {
      final empty = BookReader(_book());
      expect(empty.isEmpty, isTrue);
      expect(empty.midpoint, isNull);
      expect(empty.spread, isNull);

      final oneSided = BookReader(
        _book(
          bids: const [OrderBookLevel(price: '0.5', size: '1')],
        ),
      );
      expect(oneSided.isOneSided, isTrue);
      expect(oneSided.midpoint, isNull);
    });
  });
}
