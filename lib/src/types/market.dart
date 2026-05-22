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
import 'clob.dart' show Token;

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

@immutable
final class OptimizedImage {
  const OptimizedImage({
    required this.id,
    required this.imageUrlSource,
    required this.imageUrlOptimized,
    required this.imageSizeKbSource,
    required this.imageSizeKbOptimized,
    required this.imageOptimizedComplete,
    this.imageOptimizedLastUpdated,
    required this.relId,
    required this.field,
    required this.relName,
  });

  factory OptimizedImage.fromJson(Map<String, dynamic> json) => OptimizedImage(
    id: json['id']?.toString() ?? '',
    imageUrlSource: json['imageUrlSource']?.toString() ?? '',
    imageUrlOptimized: json['imageUrlOptimized']?.toString() ?? '',
    imageSizeKbSource: _int(json['imageSizeKbSource']),
    imageSizeKbOptimized: _int(json['imageSizeKbOptimized']),
    imageOptimizedComplete: json['imageOptimizedComplete'] == true,
    imageOptimizedLastUpdated: parseNormalizedDateTime(
      json['imageOptimizedLastUpdated'],
    ),
    relId: _int(json['relID']),
    field: json['field']?.toString() ?? '',
    relName: json['relname']?.toString() ?? '',
  );

  final String id;
  final String imageUrlSource;
  final String imageUrlOptimized;
  final int imageSizeKbSource;
  final int imageSizeKbOptimized;
  final bool imageOptimizedComplete;
  final DateTime? imageOptimizedLastUpdated;
  final int relId;
  final String field;
  final String relName;
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
    this.resolutionSource = '',
    this.groupItemTitle = '',
    this.groupItemThreshold = '',
    this.groupItemRange = '',
    required this.category,
    required this.startDate,
    required this.endDate,
    this.startDateIso = '',
    this.endDateIso = '',
    this.umaEndDate,
    this.closedTime,
    this.createdAt,
    this.updatedAt,
    this.gameStartTime,
    this.eventStartTime,
    this.readyTimestamp,
    this.acceptingOrdersTimestamp,
    required this.outcomes,
    required this.outcomePrices,
    required this.active,
    required this.closed,
    required this.archived,
    this.isNew = false,
    this.featured = false,
    this.restricted = false,
    this.ready = false,
    this.funded = false,
    this.marketType = '',
    this.umaResolutionStatus = '',
    required this.acceptingOrders,
    required this.enableOrderBook,
    this.orderMinSize = 0,
    this.orderPriceMinTickSize = 0,
    this.makerBaseFee = 0,
    this.takerBaseFee = 0,
    this.volume = '',
    this.liquidity = '',
    required this.liquidityNum,
    required this.volumeNum,
    this.volume24hr = 0,
    this.volume1wk = 0,
    this.volume1mo = 0,
    this.volume1yr = 0,
    this.volumeClob = 0,
    this.liquidityClob = 0,
    required this.lastTradePrice,
    required this.bestBid,
    required this.bestAsk,
    this.spread = 0,
    this.rewardsMinSize = 0,
    this.rewardsMaxSpread = 0,
    this.negRisk = false,
    this.negRiskMarketId = '',
    this.negRiskFeeBips = 0,
    this.rfqEnabled = false,
    required this.clobTokenIds,
    required this.tags,
    this.status = '',
    this.closeTimestamp,
    this.eventEndTime,
    this.resolvedTimestamp,
    this.closedAt,
    this.fetchedAt,
    this.commentsCount = 0,
    this.tokens = const <Token>[],
    this.tokenIds = const <String>[],
    required this.raw,
  });

  factory Market.fromJson(Map<String, dynamic> json) => Market(
    id: json['id']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    conditionId: _field(json, 'conditionId', 'condition_id')?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    questionId: _field(json, 'questionID', 'question_id')?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    resolutionSource: json['resolutionSource']?.toString() ?? '',
    groupItemTitle:
        _field(json, 'groupItemTitle', 'group_item_title')?.toString() ?? '',
    groupItemThreshold:
        _field(
          json,
          'groupItemThreshold',
          'group_item_threshold',
        )?.toString() ??
        '',
    groupItemRange: json['groupItemRange']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    endDate: parseNormalizedDateTime(json['endDate']),
    startDateIso: json['startDateIso']?.toString() ?? '',
    endDateIso: _field(json, 'endDateIso', 'end_date_iso')?.toString() ?? '',
    umaEndDate: parseNormalizedDateTime(json['umaEndDate']),
    closedTime: parseNormalizedDateTime(
      _field(json, 'closedTime', 'closed_time'),
    ),
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(_field(json, 'updatedAt', 'updated_at')),
    gameStartTime: parseNormalizedDateTime(
      _field(json, 'gameStartTime', 'game_start_time'),
    ),
    eventStartTime: parseNormalizedDateTime(json['eventStartTime']),
    readyTimestamp: parseNormalizedDateTime(json['readyTimestamp']),
    acceptingOrdersTimestamp: parseNormalizedDateTime(
      json['acceptingOrdersTimestamp'],
    ),
    outcomes: parseStringOrArray(json['outcomes']),
    outcomePrices: parseStringOrArray(json['outcomePrices']),
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    isNew: json['new'] == true,
    featured: json['featured'] == true,
    restricted: json['restricted'] == true,
    ready: json['ready'] == true,
    funded: json['funded'] == true,
    marketType: json['marketType']?.toString() ?? '',
    umaResolutionStatus: json['umaResolutionStatus']?.toString() ?? '',
    acceptingOrders:
        _field(json, 'acceptingOrders', 'accepting_orders') == true,
    enableOrderBook:
        _field(json, 'enableOrderBook', 'enable_order_book') == true,
    orderMinSize: _double(json['orderMinSize']),
    orderPriceMinTickSize: _double(json['orderPriceMinTickSize']),
    makerBaseFee: _int(json['makerBaseFee']),
    takerBaseFee: _int(json['takerBaseFee']),
    volume: json['volume']?.toString() ?? '',
    liquidity: json['liquidity']?.toString() ?? '',
    liquidityNum: _double(_field(json, 'liquidityNum', 'liquidity_num')),
    volumeNum: _double(json['volumeNum']),
    volume24hr: _double(json['volume24hr']),
    volume1wk: _double(json['volume1wk']),
    volume1mo: _double(json['volume1mo']),
    volume1yr: _double(json['volume1yr']),
    volumeClob: _double(json['volumeClob']),
    liquidityClob: _double(json['liquidityClob']),
    lastTradePrice: _double(json['lastTradePrice']),
    bestBid: _double(json['bestBid']),
    bestAsk: _double(json['bestAsk']),
    spread: _double(json['spread']),
    rewardsMinSize: _double(json['rewardsMinSize']),
    rewardsMaxSpread: _double(json['rewardsMaxSpread']),
    negRisk: json['negRisk'] == true,
    negRiskMarketId: json['negRiskMarketID']?.toString() ?? '',
    negRiskFeeBips: _int(json['negRiskFeeBips']),
    rfqEnabled: json['rfqEnabled'] == true,
    clobTokenIds: json['clobTokenIds']?.toString() ?? '',
    tags: _tags(json['tags']),
    status: _field(json, 'status', 'status')?.toString() ?? '',
    closeTimestamp: parseNormalizedDateTime(
      _field(json, 'closeTimestamp', 'close_timestamp'),
    ),
    eventEndTime: parseNormalizedDateTime(
      _field(json, 'eventEndTime', 'event_end_time'),
    ),
    resolvedTimestamp: parseNormalizedDateTime(
      _field(json, 'resolvedTimestamp', 'resolved_timestamp'),
    ),
    closedAt: parseNormalizedDateTime(_field(json, 'closedAt', 'closed_at')),
    fetchedAt: parseNormalizedDateTime(_field(json, 'fetchedAt', 'fetched_at')),
    commentsCount: _int(_field(json, 'commentCount', 'comment_count')),
    tokens: _tokens(json['tokens']),
    tokenIds: _stringList(_field(json, 'tokenIds', 'token_ids')),
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
  final String resolutionSource;
  final String groupItemTitle;
  final String groupItemThreshold;
  final String groupItemRange;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final String startDateIso;
  final String endDateIso;
  final DateTime? umaEndDate;
  final DateTime? closedTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? gameStartTime;
  final DateTime? eventStartTime;
  final DateTime? readyTimestamp;
  final DateTime? acceptingOrdersTimestamp;
  final List<String> outcomes;
  final List<String> outcomePrices;
  final bool active;
  final bool closed;
  final bool archived;
  final bool isNew;
  final bool featured;
  final bool restricted;
  final bool ready;
  final bool funded;
  final String marketType;
  final String umaResolutionStatus;
  final bool acceptingOrders;
  final bool enableOrderBook;
  final double orderMinSize;
  final double orderPriceMinTickSize;
  final int makerBaseFee;
  final int takerBaseFee;
  final String volume;
  final String liquidity;
  final double liquidityNum;
  final double volumeNum;
  final double volume24hr;
  final double volume1wk;
  final double volume1mo;
  final double volume1yr;
  final double volumeClob;
  final double liquidityClob;
  final double lastTradePrice;
  final double bestBid;
  final double bestAsk;
  final double spread;
  final double rewardsMinSize;
  final double rewardsMaxSpread;
  final bool negRisk;
  final String negRiskMarketId;
  final int negRiskFeeBips;
  final bool rfqEnabled;
  final String clobTokenIds;
  final List<Tag> tags;
  final String status;
  final DateTime? closeTimestamp;
  final DateTime? eventEndTime;
  final DateTime? resolvedTimestamp;
  final DateTime? closedAt;
  final DateTime? fetchedAt;
  final int commentsCount;
  final List<Token> tokens;
  final List<String> tokenIds;

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
    this.subtitle = '',
    required this.description,
    this.resolutionSource = '',
    this.category = '',
    this.subcategory = '',
    required this.image,
    required this.icon,
    required this.startDate,
    required this.endDate,
    this.creationDate,
    this.publishedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
    this.closedTime,
    this.eventDate,
    this.startTime,
    required this.active,
    required this.closed,
    required this.archived,
    this.isNew = false,
    required this.featured,
    this.featuredImage = '',
    this.imageOptimized,
    this.iconOptimized,
    this.featuredImageOptimized,
    this.disqusThread = '',
    this.parentEvent = '',
    this.restricted = false,
    this.commentsEnabled = false,
    this.cyom = false,
    this.showAllOutcomes = false,
    this.showMarketImages = false,
    this.automaticallyResolved = false,
    this.enableNegRisk = false,
    this.automaticallyActive = false,
    this.seriesSlug = '',
    this.eventWeek = 0,
    this.competitive = 0,
    this.commentCount = 0,
    this.openInterest = 0,
    this.sortBy = '',
    this.isTemplate = false,
    this.templateVariables = '',
    this.enableOrderBook = false,
    required this.liquidity,
    required this.volume,
    this.liquidityAmm = 0,
    this.liquidityClob = 0,
    this.volume24hr = 0,
    this.volume1wk = 0,
    this.volume1mo = 0,
    this.volume1yr = 0,
    this.negRisk = false,
    this.negRiskMarketId = '',
    this.negRiskFeeBips = 0,
    required this.markets,
    this.series = const <Series>[],
    required this.tags,
    required this.raw,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id']?.toString() ?? '',
    ticker: json['ticker']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    resolutionSource: json['resolutionSource']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    subcategory: json['subcategory']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    endDate: parseNormalizedDateTime(json['endDate']),
    creationDate: parseNormalizedDateTime(json['creationDate']),
    publishedAt: parseNormalizedDateTime(json['published_at']),
    createdBy: json['createdBy']?.toString() ?? '',
    updatedBy: json['updatedBy']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
    closedTime: parseNormalizedDateTime(json['closedTime']),
    eventDate: parseNormalizedDateTime(json['eventDate']),
    startTime: parseNormalizedDateTime(json['startTime']),
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    isNew: json['new'] == true,
    featured: json['featured'] == true,
    featuredImage: json['featuredImage']?.toString() ?? '',
    imageOptimized: _optimizedImage(json['imageOptimized']),
    iconOptimized: _optimizedImage(json['iconOptimized']),
    featuredImageOptimized: _optimizedImage(json['featuredImageOptimized']),
    disqusThread: json['disqusThread']?.toString() ?? '',
    parentEvent: json['parentEvent']?.toString() ?? '',
    restricted: json['restricted'] == true,
    commentsEnabled: json['commentsEnabled'] == true,
    cyom: json['cyom'] == true,
    showAllOutcomes: json['showAllOutcomes'] == true,
    showMarketImages: json['showMarketImages'] == true,
    automaticallyResolved: json['automaticallyResolved'] == true,
    enableNegRisk: json['enableNegRisk'] == true,
    automaticallyActive: json['automaticallyActive'] == true,
    seriesSlug: json['seriesSlug']?.toString() ?? '',
    eventWeek: _int(json['eventWeek']),
    competitive: _double(json['competitive']),
    commentCount: _int(json['commentCount']),
    openInterest: _double(json['openInterest']),
    sortBy: json['sortBy']?.toString() ?? '',
    isTemplate: json['isTemplate'] == true,
    templateVariables: json['templateVariables']?.toString() ?? '',
    enableOrderBook: json['enableOrderBook'] == true,
    liquidity: _double(json['liquidity']),
    volume: _double(json['volume']),
    liquidityAmm: _double(json['liquidityAmm']),
    liquidityClob: _double(json['liquidityClob']),
    volume24hr: _double(json['volume24hr']),
    volume1wk: _double(json['volume1wk']),
    volume1mo: _double(json['volume1mo']),
    volume1yr: _double(json['volume1yr']),
    negRisk: json['negRisk'] == true,
    negRiskMarketId: json['negRiskMarketID']?.toString() ?? '',
    negRiskFeeBips: _int(json['negRiskFeeBips']),
    markets: _markets(json['markets']),
    series: _seriesList(json['series']),
    tags: _tags(json['tags']),
    raw: Map.unmodifiable(json),
  );

  final String id;
  final String ticker;
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final String resolutionSource;
  final String category;
  final String subcategory;
  final String image;
  final String icon;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? creationDate;
  final DateTime? publishedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedTime;
  final DateTime? eventDate;
  final DateTime? startTime;
  final bool active;
  final bool closed;
  final bool archived;
  final bool isNew;
  final bool featured;
  final String featuredImage;
  final OptimizedImage? imageOptimized;
  final OptimizedImage? iconOptimized;
  final OptimizedImage? featuredImageOptimized;
  final String disqusThread;
  final String parentEvent;
  final bool restricted;
  final bool commentsEnabled;
  final bool cyom;
  final bool showAllOutcomes;
  final bool showMarketImages;
  final bool automaticallyResolved;
  final bool enableNegRisk;
  final bool automaticallyActive;
  final String seriesSlug;
  final int eventWeek;
  final double competitive;
  final int commentCount;
  final double openInterest;
  final String sortBy;
  final bool isTemplate;
  final String templateVariables;
  final bool enableOrderBook;
  final double liquidity;
  final double volume;
  final double liquidityAmm;
  final double liquidityClob;
  final double volume24hr;
  final double volume1wk;
  final double volume1mo;
  final double volume1yr;
  final bool negRisk;
  final String negRiskMarketId;
  final int negRiskFeeBips;
  final List<Market> markets;
  final List<Series> series;
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

/// A series of events (Gamma view). Stores the raw payload for fields the
/// SDK has not typed yet.
@immutable
final class Series {
  const Series({
    required this.id,
    required this.ticker,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.seriesType,
    required this.recurrence,
    required this.description,
    this.category = '',
    required this.image,
    required this.icon,
    required this.active,
    required this.closed,
    required this.archived,
    required this.featured,
    required this.startDate,
    required this.volume,
    required this.volume24hr,
    required this.liquidity,
    required this.commentCount,
    required this.events,
    required this.tags,
    required this.raw,
  });

  factory Series.fromJson(Map<String, dynamic> json) => Series(
    id: json['id']?.toString() ?? '',
    ticker: json['ticker']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    seriesType: json['seriesType']?.toString() ?? '',
    recurrence: json['recurrence']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    featured: json['featured'] == true,
    startDate: parseNormalizedDateTime(json['startDate']),
    volume: _double(json['volume']),
    volume24hr: _double(json['volume24hr']),
    liquidity: _double(json['liquidity']),
    commentCount: _int(json['commentCount']),
    events: _events(json['events']),
    tags: _tags(json['tags']),
    raw: Map.unmodifiable(json),
  );

  final String id;
  final String ticker;
  final String slug;
  final String title;
  final String subtitle;
  final String seriesType;
  final String recurrence;
  final String description;
  final String category;
  final String image;
  final String icon;
  final bool active;
  final bool closed;
  final bool archived;
  final bool featured;
  final DateTime? startDate;
  final double volume;
  final double volume24hr;
  final double liquidity;
  final int commentCount;
  final List<Event> events;
  final List<Tag> tags;
  final Map<String, dynamic> raw;
}

/// Comment author identity.
@immutable
final class CommentUser {
  const CommentUser({
    required this.address,
    required this.pseudonym,
    required this.profileImage,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) => CommentUser(
    address:
        json['address']?.toString() ?? json['baseAddress']?.toString() ?? '',
    pseudonym: json['pseudonym']?.toString() ?? json['name']?.toString() ?? '',
    profileImage: json['profileImage']?.toString() ?? '',
  );

  final String address;
  final String pseudonym;
  final String profileImage;
}

/// A Polymarket comment.
@immutable
final class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
    required this.parentId,
    required this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = _commentUser(json);
    return Comment(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      user: user,
      createdAt: parseNormalizedDateTime(json['createdAt']),
      updatedAt: parseNormalizedDateTime(json['updatedAt']),
      parentId: _nullableInt(json['parentId'] ?? json['parentEntityID']),
      replies: _comments(json['replies']),
    );
  }

  final String id;
  final String body;
  final CommentUser user;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? parentId;
  final List<Comment> replies;
}

/// A sports team (Gamma view).
@immutable
final class Team {
  const Team({
    required this.id,
    required this.name,
    required this.league,
    required this.record,
    required this.logo,
    required this.abbreviation,
    required this.alias,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    league: json['league']?.toString() ?? '',
    record: json['record']?.toString() ?? '',
    logo: json['logo']?.toString() ?? '',
    abbreviation: json['abbreviation']?.toString() ?? '',
    alias: json['alias']?.toString() ?? '',
  );

  final int id;
  final String name;
  final String league;
  final String record;
  final String logo;
  final String abbreviation;
  final String alias;
}

/// Metadata for a sport (Gamma).
@immutable
final class SportMetadata {
  const SportMetadata({
    required this.sport,
    required this.image,
    required this.resolution,
    required this.ordering,
    required this.tags,
    required this.series,
  });

  factory SportMetadata.fromJson(Map<String, dynamic> json) => SportMetadata(
    sport: json['sport']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    resolution: json['resolution']?.toString() ?? '',
    ordering: json['ordering']?.toString() ?? '',
    tags: json['tags']?.toString() ?? '',
    series: json['series']?.toString() ?? '',
  );

  final String sport;
  final String image;
  final String resolution;
  final String ordering;
  final String tags;
  final String series;
}

/// A valid sports market type (Gamma).
@immutable
final class SportsMarketType {
  const SportsMarketType({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory SportsMarketType.fromJson(Map<String, dynamic> json) =>
      SportsMarketType(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
      );

  final String id;
  final String name;
  final String slug;
}

/// A relationship edge between two tags.
@immutable
final class TagRelationship {
  const TagRelationship({
    required this.id,
    required this.tagId,
    required this.relatedTagId,
    required this.rank,
  });

  factory TagRelationship.fromJson(Map<String, dynamic> json) =>
      TagRelationship(
        id: json['id']?.toString() ?? '',
        tagId: _int(json['tagID']),
        relatedTagId: _int(json['relatedTagID']),
        rank: _int(json['rank']),
      );

  final String id;
  final int tagId;
  final int relatedTagId;
  final int rank;
}

/// A market resolved by CLOB token id.
@immutable
final class MarketByTokenResponse {
  const MarketByTokenResponse({
    required this.market,
    required this.tokenId,
    required this.outcome,
  });

  factory MarketByTokenResponse.fromJson(Map<String, dynamic> json) {
    final m = json['market'];
    return MarketByTokenResponse(
      market: m is Map
          ? Market.fromJson(m.cast<String, dynamic>())
          : Market.fromJson(const <String, dynamic>{}),
      tokenId: json['token_id']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
    );
  }

  final Market market;
  final String tokenId;
  final String outcome;
}

// ---- helpers ----

/// Resolve a JSON value, trying [camelKey] first then [snakeKey].
Object? _field(Map<String, dynamic> json, String camelKey, String snakeKey) =>
    json[camelKey] ?? json[snakeKey];

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

int? _nullableInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

CommentUser _commentUser(Map<String, dynamic> json) {
  final rawUser = json['user'];
  final rawProfile = json['profile'];
  final user = rawUser is Map
      ? CommentUser.fromJson(rawUser.cast<String, dynamic>())
      : rawProfile is Map
      ? CommentUser.fromJson(rawProfile.cast<String, dynamic>())
      : const CommentUser(address: '', pseudonym: '', profileImage: '');
  final fallbackAddress = json['userAddress']?.toString() ?? '';
  if (user.address.isNotEmpty || fallbackAddress.isEmpty) return user;
  return CommentUser(
    address: fallbackAddress,
    pseudonym: user.pseudonym,
    profileImage: user.profileImage,
  );
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

OptimizedImage? _optimizedImage(Object? raw) {
  if (raw is! Map) return null;
  return OptimizedImage.fromJson(raw.cast<String, dynamic>());
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

List<Series> _seriesList(Object? raw) {
  if (raw is! List) return const <Series>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Series.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Comment> _comments(Object? raw) {
  if (raw is! List) return const <Comment>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Comment.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Token> _tokens(Object? raw) {
  if (raw is! List) return const <Token>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Token.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map((e) => e.toString()).toList(growable: false);
}
