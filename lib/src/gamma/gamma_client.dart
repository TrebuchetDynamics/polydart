/// Read-only Gamma API client.
///
/// Mirrors the read-side of `internal/gamma/client.go`. Covers markets,
/// events, series, tags, teams, comments, profiles, sports metadata,
/// market-by-token, and keyset pagination.
library;

import 'package:meta/meta.dart';

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

/// A curated polymarket.com navigation category.
///
/// Polymarket does not expose one public endpoint for the website menu;
/// feed-capable rows map to Gamma `/events/keyset` tag_slug queries.
@immutable
final class PolymarketCategory {
  const PolymarketCategory({
    required this.label,
    required this.slug,
    required this.route,
    this.tagSlugs = const <String>[],
    required this.feedMode,
    this.note = '',
  });

  final String label;
  final String slug;
  final String route;
  final List<String> tagSlugs;
  final String feedMode;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'slug': slug,
    'route': route,
    if (tagSlugs.isNotEmpty) 'tag_slugs': tagSlugs,
    'feed_mode': feedMode,
    if (note.isNotEmpty) 'note': note,
  };
}

typedef CategoryEventsPage = ({
  PolymarketCategory category,
  List<Event> events,
  String nextCursor,
  bool hasMore,
});

const String categoryFeedEventsKeyset = 'events_keyset';
const String categoryFeedAllEventsKeyset = 'events_keyset_all';
const String categoryFeedRouteOnly = 'route_only';

const List<PolymarketCategory> polymarketCategories = <PolymarketCategory>[
  PolymarketCategory(
    label: 'Trending',
    slug: 'trending',
    route: '/',
    feedMode: categoryFeedAllEventsKeyset,
    note: 'Homepage feed; no public category-list endpoint observed.',
  ),
  PolymarketCategory(
    label: 'World Cup',
    slug: 'world-cup',
    route: '/sports/world-cup',
    tagSlugs: <String>[
      'fifa-world-cup',
      '2026-fifa-world-cup',
      'world-cup',
      'wc-tournament-futures',
    ],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Breaking',
    slug: 'breaking',
    route: '/breaking',
    feedMode: categoryFeedRouteOnly,
    note: 'Special polymarket.com route; no stable Gamma tag_slug found.',
  ),
  PolymarketCategory(
    label: 'Politics',
    slug: 'politics',
    route: '/politics',
    tagSlugs: <String>['politics'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Sports',
    slug: 'sports',
    route: '/sports/live',
    tagSlugs: <String>['sports'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Crypto',
    slug: 'crypto',
    route: '/crypto',
    tagSlugs: <String>['crypto'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Esports',
    slug: 'esports',
    route: '/esports',
    tagSlugs: <String>['esports'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Iran',
    slug: 'iran',
    route: '/iran',
    tagSlugs: <String>['iran'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Finance',
    slug: 'finance',
    route: '/finance',
    tagSlugs: <String>['finance'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Geopolitics',
    slug: 'geopolitics',
    route: '/geopolitics',
    tagSlugs: <String>['geopolitics'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Tech',
    slug: 'tech',
    route: '/tech',
    tagSlugs: <String>['tech'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Culture',
    slug: 'culture',
    route: '/pop-culture',
    tagSlugs: <String>['pop-culture'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Economy',
    slug: 'economy',
    route: '/economy',
    tagSlugs: <String>['economy'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Weather',
    slug: 'weather',
    route: '/weather',
    tagSlugs: <String>['weather'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Mentions',
    slug: 'mentions',
    route: '/mentions',
    tagSlugs: <String>['tweets-markets'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Elections',
    slug: 'elections',
    route: '/elections',
    tagSlugs: <String>['elections'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'Art',
    slug: 'art',
    route: '/pop-culture/art',
    tagSlugs: <String>['art'],
    feedMode: categoryFeedEventsKeyset,
  ),
  PolymarketCategory(
    label: 'All',
    slug: 'all',
    route: '/predictions',
    feedMode: categoryFeedAllEventsKeyset,
    note:
        'All active events feed; exact polymarket.com count is UI state, not a dedicated API field.',
  ),
];

PolymarketCategory? polymarketCategoryBySlug(String slug) {
  final needle = _normalizeCategorySlug(slug);
  for (final category in polymarketCategories) {
    if (category.slug == needle ||
        _normalizeCategorySlug(category.label) == needle ||
        _normalizeCategorySlug(category.route) == needle) {
      return category;
    }
    for (final tagSlug in category.tagSlugs) {
      if (_normalizeCategorySlug(tagSlug) == needle) return category;
    }
  }
  return null;
}

String _normalizeCategorySlug(String value) {
  var out = value.trim().toLowerCase();
  while (out.startsWith('/')) {
    out = out.substring(1);
  }
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.startsWith('predictions/')) out = out.substring(12);
  if (out.startsWith('sports/')) out = out.substring(7);
  out = out.replaceAll('_', '-').replaceAll(' ', '-');
  if (out == 'pop-culture') return 'culture';
  return out;
}

const int _defaultMarketPageSize = 100;
const int _defaultMaxMarketPages = 50;
const int _defaultEventPageSize = 100;
const int _defaultMaxEventPages = 50;
const int _defaultSeriesPageSize = 100;
const int _defaultMaxSeriesPages = 50;
const int _defaultTagPageSize = 100;
const int _defaultMaxTagPages = 50;

final class _OffsetCollectionPlan {
  _OffsetCollectionPlan({required this.pageSize, required this.maxPages}) {
    _checkPositive(pageSize, 'pageSize');
    _checkPositive(maxPages, 'maxPages');
  }

  final int pageSize;
  final int maxPages;

  int get maxOffsetExclusive => pageSize * maxPages;

  bool shouldStopBeforeFetch(int offset) => offset >= maxOffsetExclusive;
}

void _checkPositive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
}

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
    final plan = _OffsetCollectionPlan(pageSize: pageSize, maxPages: maxPages);
    final raw = await collectOffset<Market>((offset, limit) async {
      if (plan.shouldStopBeforeFetch(offset)) {
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
    }, plan.pageSize);
    return deduplicateMarketsByConditionId(raw);
  }

  /// Collects non-closed events across offset pages and deduplicates by slug,
  /// falling back to ID when slug is empty.
  Future<List<Event>> activeEventsAll({
    int pageSize = _defaultEventPageSize,
    int maxPages = _defaultMaxEventPages,
  }) async {
    final plan = _OffsetCollectionPlan(pageSize: pageSize, maxPages: maxPages);
    final raw = await collectOffset<Event>((offset, limit) async {
      if (plan.shouldStopBeforeFetch(offset)) {
        return const OffsetPageResult<Event>(items: [], count: 0);
      }
      final page = await events(
        GetEventsParams(closed: false, limit: limit, offset: offset),
      );
      return OffsetPageResult<Event>(items: page, count: page.length);
    }, plan.pageSize);
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
    final plan = _OffsetCollectionPlan(pageSize: pageSize, maxPages: maxPages);
    final raw = await collectOffset<Series>((offset, limit) async {
      if (plan.shouldStopBeforeFetch(offset)) {
        return const OffsetPageResult<Series>(items: [], count: 0);
      }
      final page = await series(
        GetSeriesParams(closed: false, limit: limit, offset: offset),
      );
      return OffsetPageResult<Series>(items: page, count: page.length);
    }, plan.pageSize);
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
    final plan = _OffsetCollectionPlan(pageSize: pageSize, maxPages: maxPages);
    final raw = await collectOffset<Tag>((offset, limit) async {
      if (plan.shouldStopBeforeFetch(offset)) {
        return const OffsetPageResult<Tag>(items: [], count: 0);
      }
      final page = await tags(GetTagsParams(limit: limit, offset: offset));
      return OffsetPageResult<Tag>(items: page, count: page.length);
    }, plan.pageSize);
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
    final list = await _transport.getJsonList('/sports');
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
    final body = await _transport.getJson(
      '/public-profile',
      query: <String, dynamic>{'address': walletAddress},
    );
    if (body.isEmpty) return null;
    return Profile.fromJson(body);
  }

  /// Returns a keyset-paginated event feed for a curated polymarket.com category.
  Future<CategoryEventsPage> categoryEvents(
    String slug, [
    CategoryEventsParams params = const CategoryEventsParams(),
  ]) async {
    final category = polymarketCategoryBySlug(slug);
    if (category == null) {
      throw ArgumentError.value(slug, 'slug', 'unknown polymarket category');
    }
    if (category.feedMode == categoryFeedRouteOnly) {
      throw UnsupportedError(
        'category ${category.slug} is route-only and has no Gamma events/keyset feed',
      );
    }
    final query = params.toQuery();
    if (category.feedMode != categoryFeedAllEventsKeyset) {
      query['tag_slug'] = category.tagSlugs.first;
    }
    final body = await _transport.getJson('/events/keyset', query: query);
    final raw = body['events'] ?? body['data'];
    final events = raw is List ? _events(raw) : const <Event>[];
    final nextCursor = body['next_cursor']?.toString() ?? '';
    return (
      category: category,
      events: events,
      nextCursor: nextCursor,
      hasMore: nextCursor.isNotEmpty,
    );
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

  static List<Market> _markets(List<dynamic> raw) =>
      _decodeObjectList(raw, 'markets', Market.fromJson);

  static List<Event> _events(List<dynamic> raw) =>
      _decodeObjectList(raw, 'events', Event.fromJson);

  static List<Series> _seriesList(List<dynamic> raw) =>
      _decodeObjectList(raw, 'series', Series.fromJson);

  static List<Tag> _tagList(List<dynamic> raw) =>
      _decodeObjectList(raw, 'tags', Tag.fromJson);

  static List<TagRelationship> _tagRelationships(List<dynamic> raw) =>
      _decodeObjectList(raw, 'tagRelationships', TagRelationship.fromJson);

  static List<Team> _teams(List<dynamic> raw) =>
      _decodeObjectList(raw, 'teams', Team.fromJson);

  static List<Comment> _commentsList(List<dynamic> raw) =>
      _decodeObjectList(raw, 'comments', Comment.fromJson);

  static List<SportMetadata> _sportsMetadata(List<dynamic> raw) =>
      _decodeObjectList(raw, 'sportsMetadata', SportMetadata.fromJson);

  static List<SportsMarketType> _sportsMarketTypes(List<dynamic> raw) =>
      _decodeObjectList(raw, 'sportsMarketTypes', SportsMarketType.fromJson);
}

List<T> _decodeObjectList<T>(
  List<dynamic> raw,
  String fieldName,
  T Function(Map<String, dynamic>) decode,
) {
  final out = <T>[];
  for (var index = 0; index < raw.length; index++) {
    out.add(decode(_objectCandidateAt(raw, index, fieldName)));
  }
  return List<T>.unmodifiable(out);
}

Map<String, dynamic> _objectCandidateAt(
  List<dynamic> candidates,
  int index,
  String fieldName,
) {
  final raw = candidates[index];
  if (raw is! Map<dynamic, dynamic>) {
    throw FormatException('$fieldName[$index] must be a JSON object');
  }
  return raw.cast<String, dynamic>();
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
      return const {'technology', 'tech', 'ai'};
    case 'entertainment':
    case 'culture':
    case 'pop culture':
      return const {'entertainment', 'culture', 'pop culture', 'movies'};
    case 'elections':
      return const {'elections', 'election', 'politics'};
    case 'world':
      return const {'world', 'global', 'geopolitics'};
    case 'weather':
      return const {'weather', 'climate'};
    default:
      return {category};
  }
}
