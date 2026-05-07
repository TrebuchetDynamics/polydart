/// Gamma API data types.
///
/// Subset of `internal/polytypes/market.go` covering what the search and
/// markets endpoints actually return for browsing flows. Full field coverage
/// arrives incrementally as later phases need it; uncommon fields are
/// preserved on the [Market.raw] map for power-user access.
library;

import 'package:meta/meta.dart';

import 'normalized_date_time.dart';
import 'string_or_array.dart';

@immutable
final class Pagination {
  const Pagination({required this.hasMore, required this.totalResults});

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    hasMore: json['hasMore'] == true,
    totalResults: _int(json['totalResults']),
  );

  final bool hasMore;
  final int totalResults;
}

@immutable
final class Tag {
  const Tag({
    required this.id,
    required this.label,
    required this.slug,
    this.forceShow = false,
    this.forceHide = false,
    this.isCarousel = false,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    forceShow: json['forceShow'] == true,
    forceHide: json['forceHide'] == true,
    isCarousel: json['isCarousel'] == true,
  );

  final String id;
  final String label;
  final String slug;
  final bool forceShow;
  final bool forceHide;
  final bool isCarousel;
}

@immutable
final class SearchTag {
  const SearchTag({
    required this.id,
    required this.label,
    required this.slug,
    required this.eventCount,
  });

  factory SearchTag.fromJson(Map<String, dynamic> json) => SearchTag(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    eventCount: _int(json['event_count']),
  );

  final String id;
  final String label;
  final String slug;
  final int eventCount;
}

@immutable
final class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.proxyWallet,
    required this.profileImage,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    proxyWallet: json['proxyWallet']?.toString() ?? '',
    profileImage: json['profileImage']?.toString() ?? '',
  );

  final String id;
  final String name;
  final String proxyWallet;
  final String profileImage;
}

/// A market (Gamma view). Stores the full raw payload so callers can read
/// fields polydart hasn't typed yet without losing data.
@immutable
final class Market {
  const Market({
    required this.id,
    required this.question,
    required this.conditionId,
    required this.slug,
    required this.questionId,
    required this.image,
    required this.icon,
    required this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.outcomes,
    required this.outcomePrices,
    required this.active,
    required this.closed,
    required this.archived,
    required this.acceptingOrders,
    required this.enableOrderBook,
    required this.liquidityNum,
    required this.volumeNum,
    required this.lastTradePrice,
    required this.bestBid,
    required this.bestAsk,
    required this.clobTokenIds,
    required this.tags,
    required this.raw,
  });

  factory Market.fromJson(Map<String, dynamic> json) => Market(
    id: json['id']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    conditionId: json['conditionId']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    questionId: json['questionID']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    endDate: parseNormalizedDateTime(json['endDate']),
    outcomes: parseStringOrArray(json['outcomes']),
    outcomePrices: parseStringOrArray(json['outcomePrices']),
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    acceptingOrders: json['acceptingOrders'] == true,
    enableOrderBook: json['enableOrderBook'] == true,
    liquidityNum: _double(json['liquidityNum']),
    volumeNum: _double(json['volumeNum']),
    lastTradePrice: _double(json['lastTradePrice']),
    bestBid: _double(json['bestBid']),
    bestAsk: _double(json['bestAsk']),
    clobTokenIds: json['clobTokenIds']?.toString() ?? '',
    tags: _tags(json['tags']),
    raw: Map.unmodifiable(json),
  );

  final String id;
  final String question;
  final String conditionId;
  final String slug;
  final String questionId;
  final String image;
  final String icon;
  final String description;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> outcomes;
  final List<String> outcomePrices;
  final bool active;
  final bool closed;
  final bool archived;
  final bool acceptingOrders;
  final bool enableOrderBook;
  final double liquidityNum;
  final double volumeNum;
  final double lastTradePrice;
  final double bestBid;
  final double bestAsk;
  final String clobTokenIds;
  final List<Tag> tags;

  /// The original payload. Read-only; useful for fields polydart hasn't
  /// typed yet. Do not mutate.
  final Map<String, dynamic> raw;
}

@immutable
final class Event {
  const Event({
    required this.id,
    required this.ticker,
    required this.slug,
    required this.title,
    required this.description,
    required this.image,
    required this.icon,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.closed,
    required this.archived,
    required this.featured,
    required this.liquidity,
    required this.volume,
    required this.markets,
    required this.tags,
    required this.raw,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id']?.toString() ?? '',
    ticker: json['ticker']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    endDate: parseNormalizedDateTime(json['endDate']),
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    featured: json['featured'] == true,
    liquidity: _double(json['liquidity']),
    volume: _double(json['volume']),
    markets: _markets(json['markets']),
    tags: _tags(json['tags']),
    raw: Map.unmodifiable(json),
  );

  final String id;
  final String ticker;
  final String slug;
  final String title;
  final String description;
  final String image;
  final String icon;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final bool closed;
  final bool archived;
  final bool featured;
  final double liquidity;
  final double volume;
  final List<Market> markets;
  final List<Tag> tags;
  final Map<String, dynamic> raw;
}

@immutable
final class SearchResponse {
  const SearchResponse({
    required this.events,
    required this.tags,
    required this.profiles,
    required this.pagination,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
    events: _events(json['events']),
    tags: _searchTags(json['tags']),
    profiles: _profiles(json['profiles']),
    pagination: json['pagination'] is Map
        ? Pagination.fromJson(
            (json['pagination'] as Map).cast<String, dynamic>(),
          )
        : const Pagination(hasMore: false, totalResults: 0),
  );

  final List<Event> events;
  final List<SearchTag> tags;
  final List<Profile> profiles;
  final Pagination pagination;
}

@immutable
final class HealthResponse {
  const HealthResponse({required this.data});

  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      HealthResponse(data: json['data']?.toString() ?? '');

  final String data;
}

// ---- helpers ----

double _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}

int _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

List<Tag> _tags(Object? raw) {
  if (raw is! List) return const <Tag>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Tag.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<SearchTag> _searchTags(Object? raw) {
  if (raw is! List) return const <SearchTag>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => SearchTag.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Profile> _profiles(Object? raw) {
  if (raw is! List) return const <Profile>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Profile.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Market> _markets(Object? raw) {
  if (raw is! List) return const <Market>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Market.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Event> _events(Object? raw) {
  if (raw is! List) return const <Event>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Event.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}
