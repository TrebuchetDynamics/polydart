import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orderfills/orderfills.dart';
import 'package:test/test.dart';

// Parity reference: polygolem/pkg/orderfills/orderfills_test.go at 91876cf.
void main() {
  group('orderfills', () {
    test('validates required block range', () {
      expect(
        () => validateOrderFillsQuery(const OrderFillsQuery()),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('block range'),
          ),
        ),
      );

      expect(
        () => validateOrderFillsQuery(
          const OrderFillsQuery(fromBlock: 10, toBlock: 9),
        ),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('from block must be <= to block'),
          ),
        ),
      );
    });

    test('normalizes side and source', () {
      final normalized = normalizeOrderFill(
        _validFill(side: ' buy ', source: ''),
      );

      expect(normalized.side, orderFillSideBuy);
      expect(normalized.source, orderFillSourceOnchainOrderFilled);

      expect(
        () => normalizeOrderFill(_validFill(side: 'HOLD')),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('side must be BUY or SELL'),
          ),
        ),
      );

      expect(
        () => normalizeOrderFill(_validFill(source: 'clob_trades')),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains(orderFillSourceOnchainOrderFilled),
          ),
        ),
      );
    });

    test(
      'reader interface uses typed query and fills without auth fields',
      () async {
        final reader = _StubOrderFillsReader(<OrderFill>[_validFill()]);

        final fills = await reader.orderFilled(
          const OrderFillsQuery(fromBlock: 1, toBlock: 2),
        );

        expect(fills, hasLength(1));
        expect(fills.single.source, orderFillSourceOnchainOrderFilled);
        expect(fills.single.txHash, '0xtx');
      },
    );
  });
}

OrderFill _validFill({
  String side = orderFillSideSell,
  String source = orderFillSourceOnchainOrderFilled,
}) {
  return OrderFill(
    txHash: '0xtx',
    logIndex: 7,
    exchange: '0xexchange',
    marketId: 'market-1',
    conditionId: 'condition-1',
    tokenId: 'token-1',
    side: side,
    price: '0.42',
    size: '10',
    blockNumber: 12,
    filledAt: DateTime.utc(2026, 5, 16, 12),
    source: source,
  );
}

final class _StubOrderFillsReader implements OrderFillsReader {
  const _StubOrderFillsReader(this.fills);

  final List<OrderFill> fills;

  @override
  Future<List<OrderFill>> orderFilled(OrderFillsQuery query) async {
    validateOrderFillsQuery(query);
    return fills.map(normalizeOrderFill).toList(growable: false);
  }
}
