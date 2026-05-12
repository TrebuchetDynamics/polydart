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

  /// Returns the top holders for [tokenId].
  Future<List<MetaHolder>> topHolders(String tokenId, {int limit = 0}) async {
    final list = await _transport.getJsonList(
      '/top-holders',
      query: <String, dynamic>{'token_id': tokenId, 'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => MetaHolder.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns the total dollar value of [user]'s open positions.
  Future<TotalValue> totalValue(String user) async {
    final body = await _transport.getJsonValue(
      '/total-value',
      query: <String, dynamic>{'user': user},
    );
    return TotalValue.fromJson(body, defaultUser: user);
  }

  /// Returns the count of distinct markets [user] has traded.
  Future<TotalMarketsTraded> marketsTraded(String user) async {
    final body = await _transport.getJson(
      '/total-markets-traded',
      query: <String, dynamic>{'user': user},
    );
    return TotalMarketsTraded.fromJson(body);
  }

  /// Returns the open interest in dollars for [tokenId].
  Future<OpenInterest> openInterest(String tokenId) async {
    final body = await _transport.getJson(
      '/open-interest',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return OpenInterest.fromJson(body);
  }

  /// Returns the global trader leaderboard.
  Future<List<TraderLeaderboardEntry>> traderLeaderboard({
    int limit = 0,
  }) async {
    final list = await _transport.getJsonList(
      '/trader-leaderboard',
      query: <String, dynamic>{'limit': limit.toString()},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => TraderLeaderboardEntry.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns the live-volume leaderboard for events.
  Future<LiveVolumeResponse> liveVolume({int limit = 0}) async {
    final body = await _transport.getJsonValue(
      '/live-volume',
      query: <String, dynamic>{'limit': limit.toString()},
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
}
