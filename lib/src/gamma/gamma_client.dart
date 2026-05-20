/// Read-only Gamma API client.
///
/// Mirrors the read-side of `internal/gamma/client.go`. Covers markets,
/// events, series, tags, teams, comments, profiles, sports metadata,
/// market-by-token, and keyset pagination.
library;

import '../pagination/pagination.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/market.dart';
import 'gamma_params.dart';

/// One page of a keyset-paginated response.
///
/// `nextCursor` is empty when no further pages exist. Mirrors the
/// `(data, next_cursor, error)` triple polygolem returns from
/// [GammaClient.eventsKeyset] / [GammaClient.marketsKeyset].
typedef KeysetPage<T> = ({List<T> data, String nextCursor});

const int _defaultMarketPageSize = 100;
const int _defaultMaxMarketPages = 50;
const int _defaultEventPageSize = 100;
const int _defaultMaxEventPages = 50;
const int _defaultSeriesPageSize = 100;
const int _defaultMaxSeriesPages = 50;
const int _defaultTagPageSize = 100;
const int _defaultMaxTagPages = 50;

final class GammaClient {
  GammaClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  /// Public Polymarket Gamma base URL.
  static const String defaultBaseUrl = 'https://gamma-api.polymarket.com';

  final HttpTransport _transport;

  /// Closes the underlying HTTP transport. Safe to call multiple times.
  void close() => _transport.close();

  /// Fetches the root endpoint to verify reachability.
  Future<HealthResponse> health() async {
    final body = await _transport.getJson('/');
    if (body.isEmpty) return const HealthResponse(data: 'ok');
    return HealthResponse.fromJson(body);
  }

  /// Lists markets with optional filters.
  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) async {
    final list = await _transport.getJsonList(
      '/markets',
      query: params.toQuery(),
    );
    return _markets(list);
  }

  /// Returns a single market by Gamma id.
  Future<Market?> marketById(String id) async {
    final body = await _transport.getJson('/markets/$id');
    if (body.isEmpty) return null;
    return Market.fromJson(body);
  }

  /// Returns a single market by slug.
  ///
  /// Gamma's `/markets/{id}` route only accepts numeric ids; slug lookups
  /// must go through `/markets?slug=...&limit=1`. Returns null if no
  /// market matches.
  Future<Market?> marketBySlug(String slug) async {
    final list = await _transport.getJsonList(
      '/markets',
      query: <String, dynamic>{'slug': slug, 'limit': '1'},
    );
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is Map) return Market.fromJson(first.cast<String, dynamic>());
    return null;
  }

  /// Cross-entity search.
  Future<SearchResponse> search(SearchParams params) async {
    final body = await _transport.getJson(
      '/public-search',
      query: params.toQuery(),
    );
    return SearchResponse.fromJson(body);
  }

  /// Returns active, non-closed markets. Sugar for
  /// `markets(GetMarketsParams(active: true, closed: false))`.
  Future<List<Market>> activeMarkets() =>
      markets(const GetMarketsParams(active: true, closed: false));

  /// Collects active, non-closed markets across offset pages and deduplicates
  /// by condition ID. Intended for discovery/indexing surfaces that need more
  /// than the first Gamma page.
  Future<List<Market>> activeMarketsAll({
    int pageSize = _defaultMarketPageSize,
    int maxPages = _defaultMaxMarketPages,
  }) async {
    final raw = await collectOffset<Market>((offset, limit) async {
      if (offset >= pageSize * maxPages) {
        return const OffsetPageResult<Market>(items: [], count: 0);
      }
      final page = await markets(
        GetMarketsParams(
          active: true,
          closed: false,
          limit: limit,
          offset: offset,
        ),
      );
      return OffsetPageResult<Market>(items: page, count: page.length);
    }, pageSize);
    return deduplicateMarketsByConditionId(raw);
  }

  /// Collects non-closed events across offset pages and deduplicates by slug,
  /// falling back to ID when slug is empty.
  Future<List<Event>> activeEventsAll({
    int pageSize = _defaultEventPageSize,
    int maxPages = _defaultMaxEventPages,
  }) async {
    final raw = await collectOffset<Event>((offset, limit) async {
      if (offset >= pageSize * maxPages) {
        return const OffsetPageResult<Event>(items: [], count: 0);
      }
      final page = await events(
        GetEventsParams(closed: false, limit: limit, offset: offset),
      );
      return OffsetPageResult<Event>(items: page, count: page.length);
    }, pageSize);
    return deduplicateEventsBySlugOrId(raw);
  }

  /// Lists events with optional filters.
  Future<List<Event>> events([
    GetEventsParams params = const GetEventsParams(),
  ]) async {
    final list = await _transport.getJsonList(
      '/events',
      query: params.toQuery(),
    );
    return _events(list);
  }

  /// Returns a single event by Gamma id.
  Future<Event?> eventById(String id) async {
    final body = await _transport.getJson('/events/$id');
    if (body.isEmpty) return null;
    return Event.fromJson(body);
  }

  /// Returns a single event by slug.
  ///
  /// Gamma's `/events/{id}` route only accepts numeric ids; slug lookups
  /// must go through `/events?slug=...&limit=1`. Returns null if no event
  /// matches.
  Future<Event?> eventBySlug(String slug) async {
    final list = await events(GetEventsParams(limit: 1, slug: <String>[slug]));
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Collects non-closed series across offset pages and deduplicates by slug,
  /// falling back to ID when slug is empty.
  Future<List<Series>> activeSeriesAll({
    int pageSize = _defaultSeriesPageSize,
    int maxPages = _defaultMaxSeriesPages,
  }) async {
    final raw = await collectOffset<Series>((offset, limit) async {
      if (offset >= pageSize * maxPages) {
        return const OffsetPageResult<Series>(items: [], count: 0);
      }
      final page = await series(
        GetSeriesParams(closed: false, limit: limit, offset: offset),
      );
      return OffsetPageResult<Series>(items: page, count: page.length);
    }, pageSize);
    return deduplicateSeriesBySlugOrId(raw);
  }

  /// Lists series with optional filters.
  Future<List<Series>> series([
    GetSeriesParams params = const GetSeriesParams(),
  ]) async {
    final list = await _transport.getJsonList(
      '/series',
      query: params.toQuery(),
    );
    return _seriesList(list);
  }

  /// Returns a single series by id.
  Future<Series?> seriesById(String id) async {
    final body = await _transport.getJson('/series/$id');
    if (body.isEmpty) return null;
    return Series.fromJson(body);
  }

  /// Collects tags across offset pages and deduplicates by slug, falling back
  /// to ID when slug is empty.
  Future<List<Tag>> tagsAll({
    int pageSize = _defaultTagPageSize,
    int maxPages = _defaultMaxTagPages,
  }) async {
    final raw = await collectOffset<Tag>((offset, limit) async {
      if (offset >= pageSize * maxPages) {
        return const OffsetPageResult<Tag>(items: [], count: 0);
      }
      final page = await tags(GetTagsParams(limit: limit, offset: offset));
      return OffsetPageResult<Tag>(items: page, count: page.length);
    }, pageSize);
    return deduplicateTagsBySlugOrId(raw);
  }

  /// Lists tags with optional filters.
  Future<List<Tag>> tags([GetTagsParams params = const GetTagsParams()]) async {
    final list = await _transport.getJsonList('/tags', query: params.toQuery());
    return _tagList(list);
  }

  /// Returns a single tag by id.
  Future<Tag?> tagById(String id) async {
    final body = await _transport.getJson('/tags/$id');
    if (body.isEmpty) return null;
    return Tag.fromJson(body);
  }

  /// Returns a single tag by slug. Polymarket reuses the `/tags/{id}` route
  /// for slug lookups.
  Future<Tag?> tagBySlug(String slug) async {
    final body = await _transport.getJson('/tags/$slug');
    if (body.isEmpty) return null;
    return Tag.fromJson(body);
  }

  /// Returns related tags for a tag id.
  Future<List<TagRelationship>> relatedTagsById(String tagId) async {
    final list = await _transport.getJsonList('/tags/$tagId/related');
    return _tagRelationships(list);
  }

  /// Returns related tags for a tag slug.
  Future<List<TagRelationship>> relatedTagsBySlug(String slug) async {
    final list = await _transport.getJsonList('/tags/$slug/related');
    return _tagRelationships(list);
  }

  /// Lists sports teams with optional filters.
  Future<List<Team>> teams([
    GetTeamsParams params = const GetTeamsParams(),
  ]) async {
    final list = await _transport.getJsonList(
      '/teams',
      query: params.toQuery(),
    );
    return _teams(list);
  }

  /// Lists comments with optional filters.
  Future<List<Comment>> comments(CommentQuery query) async {
    final list = await _transport.getJsonList(
      '/comments',
      query: query.toQuery(),
    );
    return _commentsList(list);
  }

  /// Returns a single comment by id.
  Future<Comment?> commentById(String id) async {
    final body = await _transport.getJson('/comments/$id');
    if (body.isEmpty) return null;
    return Comment.fromJson(body);
  }

  /// Lists comments authored by a user. Mirrors polygolem's
  /// `CommentsByUser(addr, limit)` shape: both query parameters are always
  /// emitted, even when [limit] is zero.
  Future<List<Comment>> commentsByUser(
    String userAddress, {
    int limit = 0,
  }) async {
    final list = await _transport.getJsonList(
      '/comments',
      query: <String, dynamic>{
        'user_address': userAddress,
        'limit': limit.toString(),
      },
    );
    return _commentsList(list);
  }

  /// Returns sports metadata.
  Future<List<SportMetadata>> sportsMetadata() async {
    final list = await _transport.getJsonList('/sports-metadata');
    return _sportsMetadata(list);
  }

  /// Returns the catalogue of valid sports market types.
  Future<List<SportsMarketType>> sportsMarketTypes() async {
    final list = await _transport.getJsonList('/sports-market-types');
    return _sportsMarketTypes(list);
  }

  /// Resolves a market by CLOB token id.
  Future<MarketByTokenResponse?> marketByToken(String tokenId) async {
    final body = await _transport.getJson('/markets/token/$tokenId');
    if (body.isEmpty) return null;
    return MarketByTokenResponse.fromJson(body);
  }

  /// Returns the public profile for a wallet address.
  Future<Profile?> publicProfile(String walletAddress) async {
    final body = await _transport.getJson('/profiles/$walletAddress');
    if (body.isEmpty) return null;
    return Profile.fromJson(body);
  }

  /// Keyset-paginated events. Returns the data slice and the cursor for the
  /// next page (empty when there is no next page).
  Future<KeysetPage<Event>> eventsKeyset(KeysetParams params) async {
    final body = await _transport.getJson(
      '/events-keyset',
      query: params.toQuery(),
    );
    final raw = body['data'];
    final data = raw is List ? _events(raw) : const <Event>[];
    return (data: data, nextCursor: body['next_cursor']?.toString() ?? '');
  }

  /// Keyset-paginated markets. Returns the data slice and the cursor for
  /// the next page (empty when there is no next page).
  Future<KeysetPage<Market>> marketsKeyset(KeysetParams params) async {
    final body = await _transport.getJson(
      '/markets-keyset',
      query: params.toQuery(),
    );
    final raw = body['data'];
    final data = raw is List ? _markets(raw) : const <Market>[];
    return (data: data, nextCursor: body['next_cursor']?.toString() ?? '');
  }

  static List<Market> _markets(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Market.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<Event> _events(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Event.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<Series> _seriesList(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Series.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<Tag> _tagList(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Tag.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<TagRelationship> _tagRelationships(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => TagRelationship.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<Team> _teams(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Team.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<Comment> _commentsList(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Comment.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<SportMetadata> _sportsMetadata(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => SportMetadata.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  static List<SportsMarketType> _sportsMarketTypes(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => SportsMarketType.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

/// Returns series in input order, dropping repeated slugs or repeated IDs when
/// slug is empty.
List<Series> deduplicateSeriesBySlugOrId(Iterable<Series> series) {
  final seen = <String>{};
  final out = <Series>[];
  for (final item in series) {
    var key = item.slug.trim();
    if (key.isEmpty) key = item.id.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(item);
  }
  return out;
}

/// Returns tags in input order, dropping repeated slugs or repeated IDs when
/// slug is empty.
List<Tag> deduplicateTagsBySlugOrId(Iterable<Tag> tags) {
  final seen = <String>{};
  final out = <Tag>[];
  for (final tag in tags) {
    var key = tag.slug.trim();
    if (key.isEmpty) key = tag.id.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(tag);
  }
  return out;
}

/// Returns events in input order, dropping repeated slugs or repeated IDs when
/// slug is empty.
List<Event> deduplicateEventsBySlugOrId(Iterable<Event> events) {
  final seen = <String>{};
  final out = <Event>[];
  for (final event in events) {
    var key = event.slug.trim();
    if (key.isEmpty) key = event.id.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(event);
  }
  return out;
}

/// Applies Polymarket-style category aliases over an event list. Empty and
/// `All` selections return all events.
List<Event> filterEventsByCategory(Iterable<Event> events, String category) {
  final selected = category.trim().toLowerCase();
  if (selected.isEmpty || selected == 'all') {
    return events.toList(growable: false);
  }
  return events
      .where((event) => marketMatchesCategory(event.category, selected))
      .toList(growable: false);
}

/// Returns markets in input order, dropping empty or duplicate condition IDs.
List<Market> deduplicateMarketsByConditionId(Iterable<Market> markets) {
  final seen = <String>{};
  final out = <Market>[];
  for (final market in markets) {
    final conditionId = market.conditionId.trim();
    if (conditionId.isEmpty || !seen.add(conditionId)) continue;
    out.add(market);
  }
  return out;
}

/// Applies Polymarket-style category aliases over a market list. Empty and
/// `All` selections return all markets.
List<Market> filterMarketsByCategory(
  Iterable<Market> markets,
  String category,
) {
  final selected = category.trim().toLowerCase();
  if (selected.isEmpty || selected == 'all') {
    return markets.toList(growable: false);
  }
  return markets
      .where(
        (market) =>
            marketMatchesCategory(market.category, selected) ||
            _marketTagsMatchCategory(market.tags, selected),
      )
      .toList(growable: false);
}

/// Returns whether a provider category matches a user-facing category label.
bool marketMatchesCategory(String marketCategory, String selectedCategory) {
  final market = marketCategory.trim().toLowerCase();
  final selected = selectedCategory.trim().toLowerCase();
  if (selected.isEmpty || selected == 'all') return true;
  if (market.isNotEmpty &&
      (market.contains(selected) || selected.contains(market))) {
    return true;
  }
  return _categoryAliases(selected).any(market.contains);
}

bool _marketTagsMatchCategory(Iterable<Tag> tags, String selected) {
  for (final tag in tags) {
    if (marketMatchesCategory(tag.label, selected) ||
        marketMatchesCategory(tag.slug, selected)) {
      return true;
    }
  }
  return false;
}

Set<String> _categoryAliases(String category) {
  switch (category) {
    case 'finance':
    case 'economy':
      return const {'finance', 'business', 'economy', 'markets'};
    case 'technology':
    case 'tech':
      return const {'technology', 'tech', 'science', 'ai'};
    case 'entertainment':
    case 'culture':
    case 'pop culture':
      return const {'entertainment', 'culture', 'pop culture', 'movies'};
    case 'elections':
      return const {'elections', 'election', 'politics'};
    case 'world':
      return const {'world', 'global', 'geopolitics', 'politics'};
    case 'weather':
      return const {'weather', 'climate', 'science'};
    default:
      return {category};
  }
}
