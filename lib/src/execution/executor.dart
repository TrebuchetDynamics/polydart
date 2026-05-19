/// Execution layer: Executor interface and paper-mode implementation.
///
/// Mirrors `internal/execution` from polygolem. The [Executor] interface
/// defines the order execution contract; [PaperExecutor] provides a
/// simulated implementation that never touches the network.
///
/// A live executor (not shipped in the public SDK surface) satisfies the
/// same contract behind the live-mode gate from [../modes/modes.dart].
library;

import '../modes/modes.dart';
import '../orders/order_intent.dart';
import '../paper/paper.dart';

/// Contract for order execution.
///
/// Paper and live implementations share this interface.
/// Mirrors `execution.Executor` from polygolem.
abstract interface class Executor {
  /// Place submits one order intent and returns the result.
  OrderResponse place(OrderIntent intent);

  /// Cancel cancels an order by ID.
  void cancel(String orderId);

  /// GetOrder fetches a single order by ID.
  PaperOrderEntry? getOrder(String orderId);

  /// ListOrders lists all orders.
  List<PaperOrderEntry> listOrders();
}

/// A tracked order entry in the executor's internal state.
final class PaperOrderEntry {
  const PaperOrderEntry({
    required this.orderId,
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    required this.status,
    this.filledSize = '0',
  });

  final String orderId;
  final String tokenId;
  final String side;
  final String price;
  final String size;
  final LifecycleState status;
  final String filledSize;

  PaperOrderEntry copyWith({LifecycleState? status, String? filledSize}) =>
      PaperOrderEntry(
        orderId: orderId,
        tokenId: tokenId,
        side: side,
        price: price,
        size: size,
        status: status ?? this.status,
        filledSize: filledSize ?? this.filledSize,
      );
}

/// Paper-mode executor: simulates order execution locally.
///
/// Never touches the network or authenticated endpoints.
/// Mirrors `execution.PaperExecutor` from polygolem.
final class PaperExecutor implements Executor {
  /// Creates a paper executor with initial cash balance.
  PaperExecutor({String initialCash = '1000'})
    : _orders = <PaperOrderEntry>[],
      _fills = <PaperFillEntry>[],
      _cash = double.parse(initialCash);

  final List<PaperOrderEntry> _orders;
  final List<PaperFillEntry> _fills;
  final double _cash;

  /// Current cash balance.
  double get cash => _cash;

  /// All orders placed through this executor.
  List<PaperOrderEntry> get orders => List.unmodifiable(_orders);

  /// All fills executed through this executor.
  List<PaperFillEntry> get fills => List.unmodifiable(_fills);

  /// Snapshot of current paper state.
  PaperState snapshot(String currency) => PaperState(
    currency: currency,
    cash: _cash,
    fills: _fills
        .map(
          (f) => PaperFill(
            marketId: '',
            tokenId: f.tokenId,
            price: double.parse(f.price),
            size: double.parse(f.size),
            live: false,
          ),
        )
        .toList(),
  );

  @override
  OrderResponse place(OrderIntent intent) {
    // Validate the intent before processing.
    intent.validate();

    // Gate: must be paper or live mode.
    requirePaperOrLive(PolydartMode.paper);

    final orderId = 'paper-${_orders.length + 1}';
    final sideLabel = intent.side.label;

    final order = PaperOrderEntry(
      orderId: orderId,
      tokenId: intent.tokenId,
      side: sideLabel,
      price: intent.price.toString(),
      size: intent.size.toString(),
      status: LifecycleState.accepted,
    );
    _orders.add(order);

    // Simulate immediate fill (paper trading assumes instant execution).
    final filledOrder = order.copyWith(
      status: LifecycleState.matched,
      filledSize: intent.size.toString(),
    );
    _orders[_orders.length - 1] = filledOrder;

    _fills.add(
      PaperFillEntry(
        orderId: orderId,
        tokenId: intent.tokenId,
        side: sideLabel,
        price: intent.price.toString(),
        size: intent.size.toString(),
      ),
    );

    return OrderResponse(
      success: true,
      orderId: orderId,
      status: LifecycleState.matched.name,
    );
  }

  @override
  void cancel(String orderId) {
    for (var i = 0; i < _orders.length; i++) {
      if (_orders[i].orderId == orderId) {
        _orders[i] = _orders[i].copyWith(status: LifecycleState.canceled);
        return;
      }
    }
    throw StateError('order $orderId not found');
  }

  @override
  PaperOrderEntry? getOrder(String orderId) {
    for (final o in _orders) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  @override
  List<PaperOrderEntry> listOrders() => List.unmodifiable(_orders);
}

/// A simulated fill entry.
final class PaperFillEntry {
  const PaperFillEntry({
    required this.orderId,
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
  });

  final String orderId;
  final String tokenId;
  final String side;
  final String price;
  final String size;
}
