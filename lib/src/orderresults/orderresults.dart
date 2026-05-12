/// Read-only account result report builder.
///
/// Joins Data API positions/results with optional authenticated CLOB account
/// history. This module never signs, submits, approves, funds, cancels, or asks
/// for raw private key material; optional CLOB reads use an [ApiKey] or an
/// injected reader abstraction.
library;

import '../auth/l2.dart';
import '../clob/clob_auth_types.dart' as clob;
import '../clob/clob_client.dart';
import '../dataapi/dataapi_client.dart';
import '../dataapi/dataapi_types.dart' as data;

const String orderResultStatusOpen = 'open';
const String orderResultStatusWon = 'won';
const String orderResultStatusLost = 'lost';
const String orderResultStatusClosed = 'closed';
const String orderResultStatusUnknown = 'unknown';

const String orderResultSourceData = 'data';
const String orderResultSourceClob = 'clob';

abstract interface class OrderResultsDataReader {
  Future<List<data.Position>> currentPositions(
    String user, {
    required int limit,
  });

  Future<List<data.ClosedPosition>> closedPositionsForUser(
    String user, {
    required int limit,
  });

  Future<List<data.Trade>> tradesForUser(String user, {required int limit});
}

abstract interface class OrderResultsClobReader {
  Future<List<clob.OrderRecord>> listOrders({required ApiKey apiKey});

  Future<List<clob.TradeRecord>> listTrades({required ApiKey apiKey});
}

final class DataApiOrderResultsReader implements OrderResultsDataReader {
  const DataApiOrderResultsReader(this.client);

  final DataApiClient client;

  @override
  Future<List<data.Position>> currentPositions(
    String user, {
    required int limit,
  }) => client.currentPositions(user, limit: limit);

  @override
  Future<List<data.ClosedPosition>> closedPositionsForUser(
    String user, {
    required int limit,
  }) => client.closedPositions(user, limit: limit);

  @override
  Future<List<data.Trade>> tradesForUser(String user, {required int limit}) =>
      client.trades(user, limit: limit);
}

final class ClobOrderResultsReader implements OrderResultsClobReader {
  const ClobOrderResultsReader(this.client);

  final ClobClient client;

  @override
  Future<List<clob.OrderRecord>> listOrders({required ApiKey apiKey}) =>
      client.listOrders(apiKey: apiKey);

  @override
  Future<List<clob.TradeRecord>> listTrades({required ApiKey apiKey}) =>
      client.listTrades(apiKey: apiKey);
}

final class OrderResultsOptions {
  const OrderResultsOptions({
    this.limit = 0,
    this.includeClob = false,
    this.clobReader,
    this.clobApiKey,
  });

  final int limit;
  final bool includeClob;
  final OrderResultsClobReader? clobReader;
  final ApiKey? clobApiKey;
}

final class OrderResultsReport {
  const OrderResultsReport({
    required this.user,
    required this.limit,
    required this.summary,
    required this.rows,
    this.warnings = const [],
  });

  final String user;
  final int limit;
  final OrderResultsSummary summary;
  final List<OrderResultsRow> rows;
  final List<String> warnings;

  OrderResultsRow? rowByToken(String tokenId) {
    for (final row in rows) {
      if (row.tokenId == tokenId) return row;
    }
    return null;
  }
}

final class OrderResultsSummary {
  const OrderResultsSummary({
    this.positions = 0,
    this.closedPositions = 0,
    this.closed = 0,
    this.dataTrades = 0,
    this.clobTrades = 0,
    this.openOrders = 0,
    this.redeemable = 0,
    this.won = 0,
    this.lost = 0,
    this.open = 0,
    this.unknown = 0,
    this.initialValue = 0,
    this.currentValue = 0,
    this.cashPnl = 0,
    this.realizedPnl = 0,
    this.matchedNotional = 0,
  });

  final int positions;
  final int closedPositions;
  final int closed;
  final int dataTrades;
  final int clobTrades;
  final int openOrders;
  final int redeemable;
  final int won;
  final int lost;
  final int open;
  final int unknown;
  final double initialValue;
  final double currentValue;
  final double cashPnl;
  final double realizedPnl;
  final double matchedNotional;

  OrderResultsSummary copyWith({
    int? positions,
    int? closedPositions,
    int? closed,
    int? dataTrades,
    int? clobTrades,
    int? openOrders,
    int? redeemable,
    int? won,
    int? lost,
    int? open,
    int? unknown,
    double? initialValue,
    double? currentValue,
    double? cashPnl,
    double? realizedPnl,
    double? matchedNotional,
  }) {
    return OrderResultsSummary(
      positions: positions ?? this.positions,
      closedPositions: closedPositions ?? this.closedPositions,
      closed: closed ?? this.closed,
      dataTrades: dataTrades ?? this.dataTrades,
      clobTrades: clobTrades ?? this.clobTrades,
      openOrders: openOrders ?? this.openOrders,
      redeemable: redeemable ?? this.redeemable,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      open: open ?? this.open,
      unknown: unknown ?? this.unknown,
      initialValue: initialValue ?? this.initialValue,
      currentValue: currentValue ?? this.currentValue,
      cashPnl: cashPnl ?? this.cashPnl,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      matchedNotional: matchedNotional ?? this.matchedNotional,
    );
  }
}

final class OrderResultsRow {
  const OrderResultsRow({
    this.market = '',
    this.tokenId = '',
    this.title = '',
    this.slug = '',
    this.outcome = '',
    this.status = orderResultStatusUnknown,
    this.redeemable = false,
    this.mergeable = false,
    this.negativeRisk = false,
    this.size = 0,
    this.avgPrice = 0,
    this.initialValue = 0,
    this.currentPrice = 0,
    this.currentValue = 0,
    this.cashPnl = 0,
    this.percentPnl = 0,
    this.realizedPnl = 0,
    this.endDate = '',
    this.tradeCount = 0,
    this.openOrderCount = 0,
    this.trades = const [],
    this.openOrders = const [],
  });

  final String market;
  final String tokenId;
  final String title;
  final String slug;
  final String outcome;
  final String status;
  final bool redeemable;
  final bool mergeable;
  final bool negativeRisk;
  final double size;
  final double avgPrice;
  final double initialValue;
  final double currentPrice;
  final double currentValue;
  final double cashPnl;
  final double percentPnl;
  final double realizedPnl;
  final String endDate;
  final int tradeCount;
  final int openOrderCount;
  final List<OrderResultsTradeSummary> trades;
  final List<OrderResultsOrderSummary> openOrders;
}

final class OrderResultsTradeSummary {
  const OrderResultsTradeSummary({
    required this.source,
    this.id = '',
    this.status = '',
    this.side = '',
    this.price = 0,
    this.size = 0,
    this.outcome = '',
    this.timestamp = '',
    this.transactionHash = '',
  });

  final String source;
  final String id;
  final String status;
  final String side;
  final double price;
  final double size;
  final String outcome;
  final String timestamp;
  final String transactionHash;
}

final class OrderResultsOrderSummary {
  const OrderResultsOrderSummary({
    this.id = '',
    this.status = '',
    this.side = '',
    this.price = 0,
    this.originalSize = 0,
    this.sizeMatched = 0,
    this.outcome = '',
    this.createdAt = '',
  });

  final String id;
  final String status;
  final String side;
  final double price;
  final double originalSize;
  final double sizeMatched;
  final String outcome;
  final String createdAt;
}

Future<OrderResultsReport> buildReport(
  OrderResultsDataReader dataReader, {
  required String user,
  OrderResultsOptions options = const OrderResultsOptions(),
}) async {
  final trimmedUser = user.trim();
  if (trimmedUser.isEmpty) {
    throw ArgumentError.value(user, 'user', 'orderresults: user is required');
  }
  final limit = options.limit <= 0 ? 20 : options.limit;
  final builder = _ReportBuilder(trimmedUser, limit);

  final positions = await dataReader.currentPositions(
    trimmedUser,
    limit: limit,
  );
  for (final position in positions) {
    if (!_emptyPosition(position)) builder.addPosition(position);
  }

  final closed = await dataReader.closedPositionsForUser(
    trimmedUser,
    limit: limit,
  );
  for (final position in closed) {
    if (!_emptyClosedPosition(position)) builder.addClosedPosition(position);
  }

  final trades = await dataReader.tradesForUser(trimmedUser, limit: limit);
  for (final trade in trades) {
    if (!_emptyDataTrade(trade)) builder.addDataTrade(trade);
  }

  if (options.includeClob) {
    final clobReader = options.clobReader;
    final apiKey = options.clobApiKey;
    if (clobReader == null || apiKey == null) {
      throw ArgumentError(
        'orderresults: clob reader and API key are required when '
        'includeClob is true',
      );
    }

    final orders = await clobReader.listOrders(apiKey: apiKey);
    for (final order in orders) {
      if (!_emptyClobOrder(order)) builder.addClobOrder(order);
    }

    final clobTrades = await clobReader.listTrades(apiKey: apiKey);
    for (final trade in clobTrades) {
      if (!_emptyClobTrade(trade)) builder.addClobTrade(trade);
    }
  }

  return builder.build();
}

final class _ReportBuilder {
  _ReportBuilder(this.user, this.limit);

  final String user;
  final int limit;
  OrderResultsSummary summary = const OrderResultsSummary();
  final Map<String, _MutableRow> _rows = {};
  final List<String> _order = [];

  void addPosition(data.Position position) {
    final row = _row(position.conditionId, position.tokenId);
    row
      ..market = _firstNonEmpty(row.market, position.conditionId)
      ..tokenId = _firstNonEmpty(row.tokenId, position.tokenId)
      ..title = _firstNonEmpty(row.title, position.title)
      ..slug = _firstNonEmpty(row.slug, position.slug)
      ..outcome = _firstNonEmpty(row.outcome, position.outcome)
      ..status = _classifyPosition(position)
      ..redeemable = position.redeemable
      ..mergeable = position.mergeable
      ..negativeRisk = position.negativeRisk
      ..size = position.size
      ..avgPrice = position.avgPrice
      ..initialValue = position.initialValue
      ..currentPrice = position.currentPrice
      ..currentValue = position.currentValue
      ..cashPnl = position.cashPnl
      ..percentPnl = position.percentPnl
      ..realizedPnl = position.realizedPnl
      ..endDate = _firstNonEmpty(row.endDate, position.endDate);

    summary = summary.copyWith(
      positions: summary.positions + 1,
      initialValue: summary.initialValue + position.initialValue,
      currentValue: summary.currentValue + position.currentValue,
      cashPnl: summary.cashPnl + position.cashPnl,
      redeemable: summary.redeemable + (position.redeemable ? 1 : 0),
    );
    _countStatus(row.status);
  }

  void addClosedPosition(data.ClosedPosition position) {
    final row = _row(position.conditionId, position.tokenId);
    row
      ..market = _firstNonEmpty(
        row.market,
        position.conditionId,
        position.marketId,
      )
      ..tokenId = _firstNonEmpty(row.tokenId, position.tokenId)
      ..title = _firstNonEmpty(row.title, position.title)
      ..slug = _firstNonEmpty(row.slug, position.slug)
      ..outcome = _firstNonEmpty(row.outcome, position.outcome, position.side);
    if (row.status.isEmpty || row.status == orderResultStatusUnknown) {
      row.status = orderResultStatusClosed;
    }
    row
      ..size = _firstNonZero(row.size, position.size, position.totalBought)
      ..avgPrice = _firstNonZero(
        row.avgPrice,
        position.avgPrice,
        position.avgPriceBuy,
      )
      ..currentPrice = _firstNonZero(row.currentPrice, position.currentPrice)
      ..realizedPnl += position.realizedPnl
      ..endDate = _firstNonEmpty(row.endDate, position.endDate);

    summary = summary.copyWith(
      closedPositions: summary.closedPositions + 1,
      realizedPnl: summary.realizedPnl + position.realizedPnl,
    );
    if (row.status == orderResultStatusClosed) {
      _countStatus(orderResultStatusClosed);
    }
  }

  void addDataTrade(data.Trade trade) {
    final row = _row(trade.market, trade.assetId);
    row
      ..market = _firstNonEmpty(row.market, trade.market)
      ..tokenId = _firstNonEmpty(row.tokenId, trade.assetId)
      ..title = _firstNonEmpty(row.title, trade.title)
      ..slug = _firstNonEmpty(row.slug, trade.slug)
      ..outcome = _firstNonEmpty(row.outcome, trade.outcome);
    if (row.status.isEmpty) row.status = orderResultStatusUnknown;
    final added = _appendTrade(
      row,
      OrderResultsTradeSummary(
        source: orderResultSourceData,
        id: trade.id,
        status: trade.status,
        side: trade.side,
        price: trade.price,
        size: trade.size,
        outcome: trade.outcome,
        timestamp: trade.createdAt,
        transactionHash: trade.transactionHash,
      ),
    );
    summary = summary.copyWith(
      dataTrades: summary.dataTrades + 1,
      matchedNotional:
          summary.matchedNotional + (added ? trade.price * trade.size : 0),
    );
  }

  void addClobOrder(clob.OrderRecord order) {
    final row = _row(order.market, order.assetId);
    row
      ..market = _firstNonEmpty(row.market, order.market)
      ..tokenId = _firstNonEmpty(row.tokenId, order.assetId)
      ..outcome = _firstNonEmpty(row.outcome, order.outcome);
    if (row.status.isEmpty || row.status == orderResultStatusUnknown) {
      row.status = orderResultStatusOpen;
    }
    row.openOrders.add(
      OrderResultsOrderSummary(
        id: order.id,
        status: order.status,
        side: order.side,
        price: _parseDouble(order.price),
        originalSize: _parseDouble(order.originalSize),
        sizeMatched: _parseDouble(order.sizeMatched),
        outcome: order.outcome,
        createdAt: order.createdAt,
      ),
    );
    summary = summary.copyWith(openOrders: summary.openOrders + 1);
  }

  void addClobTrade(clob.TradeRecord trade) {
    final row = _row(trade.market, trade.assetId);
    row
      ..market = _firstNonEmpty(row.market, trade.market)
      ..tokenId = _firstNonEmpty(row.tokenId, trade.assetId)
      ..outcome = _firstNonEmpty(row.outcome, trade.outcome);
    if (row.status.isEmpty) row.status = orderResultStatusUnknown;
    final price = _parseDouble(trade.price);
    final size = _parseDouble(trade.size);
    final added = _appendTrade(
      row,
      OrderResultsTradeSummary(
        source: orderResultSourceClob,
        id: trade.id,
        status: trade.status,
        side: trade.side,
        price: price,
        size: size,
        outcome: trade.outcome,
        timestamp: _firstNonEmpty(trade.createdAt, trade.lastUpdated),
        transactionHash: trade.transactionHash,
      ),
    );
    summary = summary.copyWith(
      clobTrades: summary.clobTrades + 1,
      matchedNotional: summary.matchedNotional + (added ? price * size : 0),
    );
  }

  OrderResultsReport build() {
    final indexedRows = <({int index, OrderResultsRow row})>[
      for (var i = 0; i < _order.length; i++)
        (index: i, row: _rows[_order[i]]!.freeze()),
    ];
    indexedRows.sort((a, b) {
      final rank = _statusRank(
        a.row.status,
      ).compareTo(_statusRank(b.row.status));
      if (rank != 0) return rank;
      final title = a.row.title.compareTo(b.row.title);
      if (title != 0) return title;
      return a.index.compareTo(b.index);
    });
    return OrderResultsReport(
      user: user,
      limit: limit,
      summary: summary,
      rows: List.unmodifiable(indexedRows.map((entry) => entry.row)),
    );
  }

  _MutableRow _row(String market, String tokenId) {
    final key = _rowKey(market, tokenId);
    final existing = _rows[key];
    if (existing != null) return existing;
    final row = _MutableRow(
      market: market.trim(),
      tokenId: tokenId.trim(),
      status: orderResultStatusUnknown,
    );
    _rows[key] = row;
    _order.add(key);
    return row;
  }

  void _countStatus(String status) {
    switch (status) {
      case orderResultStatusWon:
        summary = summary.copyWith(won: summary.won + 1);
      case orderResultStatusLost:
        summary = summary.copyWith(lost: summary.lost + 1);
      case orderResultStatusOpen:
        summary = summary.copyWith(open: summary.open + 1);
      case orderResultStatusClosed:
        summary = summary.copyWith(closed: summary.closed + 1);
      default:
        summary = summary.copyWith(unknown: summary.unknown + 1);
    }
  }
}

final class _MutableRow {
  _MutableRow({
    this.market = '',
    this.tokenId = '',
    this.status = orderResultStatusUnknown,
  });

  String market;
  String tokenId;
  String title = '';
  String slug = '';
  String outcome = '';
  String status;
  bool redeemable = false;
  bool mergeable = false;
  bool negativeRisk = false;
  double size = 0;
  double avgPrice = 0;
  double initialValue = 0;
  double currentPrice = 0;
  double currentValue = 0;
  double cashPnl = 0;
  double percentPnl = 0;
  double realizedPnl = 0;
  String endDate = '';
  final List<OrderResultsTradeSummary> trades = [];
  final List<OrderResultsOrderSummary> openOrders = [];

  OrderResultsRow freeze() => OrderResultsRow(
    market: market,
    tokenId: tokenId,
    title: title,
    slug: slug,
    outcome: outcome,
    status: status,
    redeemable: redeemable,
    mergeable: mergeable,
    negativeRisk: negativeRisk,
    size: size,
    avgPrice: avgPrice,
    initialValue: initialValue,
    currentPrice: currentPrice,
    currentValue: currentValue,
    cashPnl: cashPnl,
    percentPnl: percentPnl,
    realizedPnl: realizedPnl,
    endDate: endDate,
    tradeCount: trades.length,
    openOrderCount: openOrders.length,
    trades: List.unmodifiable(trades),
    openOrders: List.unmodifiable(openOrders),
  );
}

bool _appendTrade(_MutableRow row, OrderResultsTradeSummary trade) {
  final tx = trade.transactionHash.trim();
  if (tx.isNotEmpty) {
    for (var i = 0; i < row.trades.length; i++) {
      final existing = row.trades[i];
      if (existing.transactionHash.toLowerCase() != tx.toLowerCase()) continue;
      if (existing.source == orderResultSourceData &&
          trade.source == orderResultSourceClob) {
        row.trades[i] = trade;
      }
      return false;
    }
  }
  row.trades.add(trade);
  return true;
}

String _classifyPosition(data.Position position) {
  if (position.redeemable) {
    if (position.currentPrice >= 0.999 ||
        position.currentValue > position.initialValue ||
        position.cashPnl > 0) {
      return orderResultStatusWon;
    }
    if (position.currentPrice <= 0.001 ||
        position.currentValue == 0 ||
        position.cashPnl < 0) {
      return orderResultStatusLost;
    }
  }
  if (position.size > 0) return orderResultStatusOpen;
  return orderResultStatusUnknown;
}

String _rowKey(String market, String tokenId) {
  final trimmedToken = tokenId.trim();
  if (trimmedToken.isNotEmpty) return 'token:$trimmedToken';
  final trimmedMarket = market.trim();
  if (trimmedMarket.isNotEmpty) return 'market:$trimmedMarket';
  return 'unknown';
}

bool _emptyPosition(data.Position position) =>
    position.tokenId.isEmpty &&
    position.conditionId.isEmpty &&
    position.size == 0 &&
    position.title.isEmpty;

bool _emptyClosedPosition(data.ClosedPosition position) =>
    position.tokenId.isEmpty &&
    position.conditionId.isEmpty &&
    position.size == 0 &&
    position.realizedPnl == 0 &&
    position.title.isEmpty;

bool _emptyDataTrade(data.Trade trade) =>
    trade.id.isEmpty &&
    trade.market.isEmpty &&
    trade.assetId.isEmpty &&
    trade.size == 0;

bool _emptyClobOrder(clob.OrderRecord order) =>
    order.id.isEmpty && order.market.isEmpty && order.assetId.isEmpty;

bool _emptyClobTrade(clob.TradeRecord trade) =>
    trade.id.isEmpty && trade.market.isEmpty && trade.assetId.isEmpty;

String _firstNonEmpty(String a, [String b = '', String c = '']) {
  for (final value in <String>[a, b, c]) {
    if (value.trim().isNotEmpty) return value;
  }
  return '';
}

double _firstNonZero(double a, [double b = 0, double c = 0]) {
  for (final value in <double>[a, b, c]) {
    if (value != 0) return value;
  }
  return 0;
}

double _parseDouble(String value) => double.tryParse(value.trim()) ?? 0;

int _statusRank(String status) {
  switch (status) {
    case orderResultStatusWon:
      return 0;
    case orderResultStatusLost:
      return 1;
    case orderResultStatusOpen:
      return 2;
    case orderResultStatusClosed:
      return 3;
    default:
      return 4;
  }
}
