/// Polymarket Data API client.
///
/// Mirrors `internal/dataapi/client.go` — read-only access to user-scoped
/// positions, trades, activity, and market-wide aggregates served from
/// `https://data-api.polymarket.com`. No authentication is required for
/// any of these endpoints.
library;

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import 'dataapi_types.dart';

final class DataApiClient {
  DataApiClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  /// Public Polymarket Data API base URL.
  static const String defaultBaseUrl = 'https://data-api.polymarket.com';

  final HttpTransport _transport;

  /// Closes the underlying transport.
  void close() => _transport.close();

  /// Pings the root endpoint. Throws [TransportException] on failure.
  Future<void> health() async {
    await _transport.getJson('/');
  }

  /// Returns [user]'s currently open positions. When [limit] is positive
  /// it is forwarded as the `limit` query parameter; otherwise the server
  /// default is used.
  Future<List<Position>> currentPositions(String user, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/positions',
      query: _userQuery(user, limit),
    );
    return _positions(list);
  }

  /// Returns [user]'s closed positions.
  Future<List<ClosedPosition>> closedPositions(
    String user, {
    int limit = 0,
  }) async {
    final list = await _transport.getJsonList(
      '/closed-positions',
      query: _userQuery(user, limit),
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => ClosedPosition.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns [user]'s most recent trades. The Go reference always sends
  /// `limit`, so we forward whatever the caller passed (default 0 still
  /// emits `limit=0`, matching polygolem).
  Future<List<Trade>> trades(String user, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/trades',
      query: <String, dynamic>{'user': user, 'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Trade.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns recent public trades for [market], a market condition ID.
  Future<List<Trade>> marketTrades(String market, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/trades',
      query: <String, dynamic>{'market': market, 'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Trade.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns [user]'s recent on/off-chain activity.
  Future<List<Activity>> activity(String user, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/activity',
      query: <String, dynamic>{'user': user, 'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Activity.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns the top holders for [market].
  Future<List<MetaHolder>> topHolders(String market, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/holders',
      query: <String, dynamic>{'market': market, 'limit': limit.toString()},
    );
    return _metaHolders(list);
  }

  /// Returns the total dollar value of [user]'s open positions.
  Future<TotalValue> totalValue(String user) async {
    final body = await _transport.getJsonValue(
      '/value',
      query: <String, dynamic>{'user': user},
    );
    return TotalValue.fromJson(body, defaultUser: user);
  }

  /// Returns the count of distinct markets [user] has traded.
  Future<TotalMarketsTraded> marketsTraded(String user) async {
    final body = await _transport.getJson(
      '/traded',
      query: <String, dynamic>{'user': user},
    );
    return TotalMarketsTraded.fromJson(body);
  }

  /// Returns the open interest in dollars for [market].
  Future<OpenInterest> openInterest(String market) async {
    final list = await _transport.getJsonList(
      '/oi',
      query: <String, dynamic>{'market': market},
    );
    final first = _firstMap(list);
    if (first == null) {
      return OpenInterest(market: market, assetId: '', openValue: 0);
    }
    return OpenInterest.fromJson(first);
  }

  /// Returns the global trader leaderboard.
  Future<List<TraderLeaderboardEntry>> traderLeaderboard({
    int limit = 0,
  }) async {
    final list = await _transport.getJsonList(
      '/v1/leaderboard',
      query: <String, dynamic>{'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => TraderLeaderboardEntry.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns live volume for [eventId].
  Future<LiveVolumeResponse> liveVolume(int eventId) async {
    final body = await _transport.getJsonValue(
      '/live-volume',
      query: <String, dynamic>{'id': eventId.toString()},
    );
    return LiveVolumeResponse.fromJson(body);
  }

  /// Builds the `{user, limit}` query map shared by `/positions` and
  /// `/closed-positions`. `limit` is omitted when `<= 0`, mirroring
  /// `CurrentPositionsWithLimit` in polygolem.
  Map<String, dynamic> _userQuery(String user, int limit) {
    final q = <String, dynamic>{'user': user};
    if (limit > 0) q['limit'] = limit.toString();
    return q;
  }

  List<Position> _positions(List<dynamic> list) => list
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Position.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  List<MetaHolder> _metaHolders(List<dynamic> list) {
    final holders = <MetaHolder>[];
    for (var i = 0; i < list.length; i++) {
      final item = _mapCandidateAt(list, i, '/holders');
      final nested = item['holders'];
      if (nested is List) {
        for (var j = 0; j < nested.length; j++) {
          final holder = _mapCandidateAt(nested, j, '/holders[$i].holders');
          holders.add(MetaHolder.fromJson(holder));
        }
      } else {
        holders.add(MetaHolder.fromJson(item));
      }
    }
    return holders.toList(growable: false);
  }

  Map<String, dynamic> _mapCandidateAt(
    List<dynamic> candidates,
    int index,
    String path,
  ) {
    final candidate = candidates[index];
    if (candidate is! Map<dynamic, dynamic>) {
      throw FormatException(
        'Data API $path[$index]: expected JSON object',
        candidate,
      );
    }
    return candidate.cast<String, dynamic>();
  }

  Map<String, dynamic>? _firstMap(List<dynamic> list) {
    for (final item in list) {
      if (item is Map<dynamic, dynamic>) return item.cast<String, dynamic>();
    }
    return null;
  }
}
