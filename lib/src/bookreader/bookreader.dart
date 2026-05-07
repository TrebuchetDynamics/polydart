/// Order book aggregation helper.
///
/// Mirrors `pkg/bookreader`. Pure compute — no I/O — so Flutter consumers
/// can drop a [BookReader] into widgets, providers, or controllers without
/// worrying about lifecycle.
library;

import '../types/clob.dart';
import '../types/enums.dart';

final class BookReader {
  BookReader(this.book) {
    _sortedBids = _sortedDesc(book.bids);
    _sortedAsks = _sortedAsc(book.asks);
  }

  final OrderBook book;
  late final List<OrderBookLevel> _sortedBids;
  late final List<OrderBookLevel> _sortedAsks;

  /// Bids sorted by price descending (best first).
  List<OrderBookLevel> get bids => _sortedBids;

  /// Asks sorted by price ascending (best first).
  List<OrderBookLevel> get asks => _sortedAsks;

  /// Best bid — highest price the book is willing to buy at.
  OrderBookLevel? get bestBid => _sortedBids.isEmpty ? null : _sortedBids.first;

  /// Best ask — lowest price the book is willing to sell at.
  OrderBookLevel? get bestAsk => _sortedAsks.isEmpty ? null : _sortedAsks.first;

  /// Midpoint between best bid and best ask. Returns null if either side
  /// is empty.
  double? get midpoint {
    final b = _priceOf(bestBid);
    final a = _priceOf(bestAsk);
    if (b == null || a == null) return null;
    return (b + a) / 2;
  }

  /// Bid-ask spread, or null if the book is one-sided / empty.
  double? get spread {
    final b = _priceOf(bestBid);
    final a = _priceOf(bestAsk);
    if (b == null || a == null) return null;
    return a - b;
  }

  /// Total size on [side] across the top [levels] price levels.
  double depth(Side side, {int levels = 5}) {
    final source = side == Side.buy ? _sortedBids : _sortedAsks;
    final slice = source.take(levels);
    var total = 0.0;
    for (final l in slice) {
      total += double.tryParse(l.size) ?? 0;
    }
    return total;
  }

  /// True if either side of the book is empty.
  bool get isOneSided => _sortedBids.isEmpty || _sortedAsks.isEmpty;

  /// True if both sides are empty.
  bool get isEmpty => _sortedBids.isEmpty && _sortedAsks.isEmpty;

  static double? _priceOf(OrderBookLevel? l) =>
      l == null ? null : double.tryParse(l.price);

  static List<OrderBookLevel> _sortedDesc(List<OrderBookLevel> levels) {
    final out = List<OrderBookLevel>.from(levels);
    out.sort((a, b) {
      final ap = double.tryParse(a.price) ?? 0;
      final bp = double.tryParse(b.price) ?? 0;
      return bp.compareTo(ap);
    });
    return out;
  }

  static List<OrderBookLevel> _sortedAsc(List<OrderBookLevel> levels) {
    final out = List<OrderBookLevel>.from(levels);
    out.sort((a, b) {
      final ap = double.tryParse(a.price) ?? 0;
      final bp = double.tryParse(b.price) ?? 0;
      return ap.compareTo(bp);
    });
    return out;
  }
}
