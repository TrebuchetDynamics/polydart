import 'package:polydart/src/execution/executor.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/orders/order_intent.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:polydart/src/types/decimal.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

void main() {
  OrderIntent buildIntent({
    String tokenId = 'tok-1',
    Side side = Side.buy,
    String price = '0.55',
    String size = '10',
  }) {
    return (OrderBuilder(tokenId: tokenId, side: side)
          ..price(price)
          ..size(size)
          ..tickSize('0.01')
          ..feeRateBps(0))
        .build();
  }

  group('PaperExecutor', () {
    test('Place buy order succeeds', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      final resp = executor.place(intent);

      expect(resp.success, isTrue);
      expect(resp.orderId, isNotEmpty);
      expect(executor.orders, hasLength(1));
      expect(executor.fills, hasLength(1));
    });

    test('Cancel existing order', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      final resp = executor.place(intent);
      executor.cancel(resp.orderId);

      final order = executor.getOrder(resp.orderId);
      expect(order, isNotNull);
      expect(order!.status, LifecycleState.canceled);
    });

    test('Cancel nonexistent order throws', () {
      final executor = PaperExecutor(initialCash: '1000');
      expect(
        () => executor.cancel('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    test('GetOrder returns order by ID', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      final resp = executor.place(intent);

      final order = executor.getOrder(resp.orderId);
      expect(order, isNotNull);
      expect(order!.orderId, resp.orderId);
    });

    test('GetOrder returns null for missing ID', () {
      final executor = PaperExecutor(initialCash: '1000');
      expect(executor.getOrder('missing'), isNull);
    });

    test('ListOrders returns all placed orders', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      executor.place(intent);
      executor.place(intent);

      final allOrders = executor.listOrders();
      expect(allOrders, hasLength(2));
    });

    test('Rejects invalid intent', () {
      final executor = PaperExecutor(initialCash: '1000');
      final emptyIntent = const OrderIntent(
        tokenId: '',
        side: Side.buy,
        price: Decimal.zero,
        size: Decimal.zero,
        tickSize: TickSize(
          minimumTickSize: '0.01',
          minimumOrderSize: '1',
          tickSize: '0.01',
        ),
      );
      expect(
        () => executor.place(emptyIntent),
        throwsA(isA<Exception>()),
      );
    });

    test('Cash balance is tracked', () {
      final executor = PaperExecutor(initialCash: '500');
      expect(executor.cash, 500);
    });

    test('Order IDs are sequential', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      final r1 = executor.place(intent);
      final r2 = executor.place(intent);
      final r3 = executor.place(intent);

      expect(r1.orderId, 'paper-1');
      expect(r2.orderId, 'paper-2');
      expect(r3.orderId, 'paper-3');
    });

    test('Snapshot returns current state', () {
      final executor = PaperExecutor(initialCash: '1000');
      final intent = buildIntent();
      executor.place(intent);

      final snap = executor.snapshot('USD');
      expect(snap.cash, 1000);
      expect(snap.fills, hasLength(1));
    });
  });
}
