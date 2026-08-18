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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hasMore': hasMore,
    'totalResults': totalResults,
  };
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
    this.activeEventsCount = 0,
    this.publishedAt,
    this.createdBy = 0,
    this.updatedBy = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    forceShow: json['forceShow'] == true,
    forceHide: json['forceHide'] == true,
    isCarousel: json['isCarousel'] == true,
    activeEventsCount: _int(json['activeEventsCount']),
    publishedAt: parseNormalizedDateTime(json['publishedAt']),
    createdBy: _int(json['createdBy']),
    updatedBy: _int(json['updatedBy']),
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
  );

  final String id;
  final String label;
  final String slug;
  final bool forceShow;
  final bool forceHide;
  final bool isCarousel;
  final int activeEventsCount;
  final DateTime? publishedAt;
  final int createdBy;
  final int updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class Category {
  const Category({
    required this.id,
    required this.label,
    this.parentCategory = '',
    required this.slug,
    this.publishedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    parentCategory: json['parentCategory']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    publishedAt: parseNormalizedDateTime(json['publishedAt']),
    createdBy: json['createdBy']?.toString() ?? '',
    updatedBy: json['updatedBy']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
  );

  final String id;
  final String label;
  final String parentCategory;
  final String slug;
  final DateTime? publishedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class Collection {
  const Collection({
    required this.id,
    required this.ticker,
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.collectionType = '',
    this.description = '',
    this.tags = '',
    this.image = '',
    this.icon = '',
    this.headerImage = '',
    this.layout = '',
    this.active = false,
    this.closed = false,
    this.archived = false,
    this.isNew = false,
    this.featured = false,
    this.restricted = false,
    this.isTemplate = false,
    this.templateVariables = '',
    this.publishedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
    this.commentsEnabled = false,
    this.imageOptimized,
    this.iconOptimized,
    this.headerImageOptimized,
  });

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: json['id']?.toString() ?? '',
    ticker: json['ticker']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    collectionType: json['collectionType']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    tags: json['tags']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    headerImage: json['headerImage']?.toString() ?? '',
    layout: json['layout']?.toString() ?? '',
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    isNew: json['new'] == true,
    featured: json['featured'] == true,
    restricted: json['restricted'] == true,
    isTemplate: json['isTemplate'] == true,
    templateVariables: json['templateVariables']?.toString() ?? '',
    publishedAt: parseNormalizedDateTime(json['publishedAt']),
    createdBy: json['createdBy']?.toString() ?? '',
    updatedBy: json['updatedBy']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
    commentsEnabled: json['commentsEnabled'] == true,
    imageOptimized: _optimizedImage(json['imageOptimized']),
    iconOptimized: _optimizedImage(json['iconOptimized']),
    headerImageOptimized: _optimizedImage(json['headerImageOptimized']),
  );

  final String id;
  final String ticker;
  final String slug;
  final String title;
  final String subtitle;
  final String collectionType;
  final String description;
  final String tags;
  final String image;
  final String icon;
  final String headerImage;
  final String layout;
  final bool active;
  final bool closed;
  final bool archived;
  final bool isNew;
  final bool featured;
  final bool restricted;
  final bool isTemplate;
  final String templateVariables;
  final DateTime? publishedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool commentsEnabled;
  final OptimizedImage? imageOptimized;
  final OptimizedImage? iconOptimized;
  final OptimizedImage? headerImageOptimized;
}

@immutable
final class EventCreator {
  const EventCreator({
    required this.id,
    required this.creatorName,
    required this.creatorHandle,
    required this.creatorUrl,
    required this.creatorImage,
    this.createdAt,
    this.updatedAt,
  });

  factory EventCreator.fromJson(Map<String, dynamic> json) => EventCreator(
    id: json['id']?.toString() ?? '',
    creatorName: json['creatorName']?.toString() ?? '',
    creatorHandle: json['creatorHandle']?.toString() ?? '',
    creatorUrl: json['creatorUrl']?.toString() ?? '',
    creatorImage: json['creatorImage']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
  );

  final String id;
  final String creatorName;
  final String creatorHandle;
  final String creatorUrl;
  final String creatorImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'slug': slug,
    'event_count': eventCount,
  };
}

@immutable
final class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.proxyWallet,
    required this.profileImage,
    this.user = 0,
    this.referral = '',
    this.createdBy = 0,
    this.updatedBy = 0,
    this.createdAt,
    this.updatedAt,
    this.utmSource = '',
    this.utmMedium = '',
    this.utmCampaign = '',
    this.utmContent = '',
    this.utmTerm = '',
    this.walletActivated = false,
    this.pseudonym = '',
    this.displayUsernamePublic = false,
    this.bio = '',
    this.profileImageOptimized,
    this.isCloseOnly = false,
    this.isCertReq = false,
    this.certReqDate,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    proxyWallet: json['proxyWallet']?.toString() ?? '',
    profileImage: json['profileImage']?.toString() ?? '',
    user: _int(json['user']),
    referral: json['referral']?.toString() ?? '',
    createdBy: _int(json['createdBy']),
    updatedBy: _int(json['updatedBy']),
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
    utmSource: json['utmSource']?.toString() ?? '',
    utmMedium: json['utmMedium']?.toString() ?? '',
    utmCampaign: json['utmCampaign']?.toString() ?? '',
    utmContent: json['utmContent']?.toString() ?? '',
    utmTerm: json['utmTerm']?.toString() ?? '',
    walletActivated: json['walletActivated'] == true,
    pseudonym: json['pseudonym']?.toString() ?? '',
    displayUsernamePublic: json['displayUsernamePublic'] == true,
    bio: json['bio']?.toString() ?? '',
    profileImageOptimized: _optimizedImage(json['profileImageOptimized']),
    isCloseOnly: json['isCloseOnly'] == true,
    isCertReq: json['isCertReq'] == true,
    certReqDate: parseNormalizedDateTime(json['certReqDate']),
  );

  final String id;
  final String name;
  final String proxyWallet;
  final String profileImage;
  final int user;
  final String referral;
  final int createdBy;
  final int updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;
  final String utmContent;
  final String utmTerm;
  final bool walletActivated;
  final String pseudonym;
  final bool displayUsernamePublic;
  final String bio;
  final OptimizedImage? profileImageOptimized;
  final bool isCloseOnly;
  final bool isCertReq;
  final DateTime? certReqDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'proxyWallet': proxyWallet,
    'profileImage': profileImage,
    'user': user,
    'referral': referral,
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'createdAt': encodeNormalizedDateTime(createdAt),
    'updatedAt': encodeNormalizedDateTime(updatedAt),
    'utmSource': utmSource,
    'utmMedium': utmMedium,
    'utmCampaign': utmCampaign,
    'utmContent': utmContent,
    'utmTerm': utmTerm,
    'walletActivated': walletActivated,
    'pseudonym': pseudonym,
    'displayUsernamePublic': displayUsernamePublic,
    'bio': bio,
    if (profileImageOptimized != null)
      'profileImageOptimized': profileImageOptimized!.toJson(),
    'isCloseOnly': isCloseOnly,
    'isCertReq': isCertReq,
    'certReqDate': encodeNormalizedDateTime(certReqDate),
  };
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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'imageUrlSource': imageUrlSource,
    'imageUrlOptimized': imageUrlOptimized,
    'imageSizeKbSource': imageSizeKbSource,
    'imageSizeKbOptimized': imageSizeKbOptimized,
    'imageOptimizedComplete': imageOptimizedComplete,
    'imageOptimizedLastUpdated': encodeNormalizedDateTime(
      imageOptimizedLastUpdated,
    ),
    'relID': relId,
    'field': field,
    'relname': relName,
  };
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
    this.twitterCardImage = '',
    required this.image,
    required this.icon,
    required this.description,
    this.resolutionSource = '',
    this.ammType = '',
    this.fee = '',
    this.denominationToken = '',
    this.sponsorName = '',
    this.sponsorImage = '',
    this.xAxisValue = '',
    this.yAxisValue = '',
    this.marketMakerAddress = '',
    this.mailchimpTag = '',
    this.resolvedBy = '',
    this.disqusThread = '',
    this.creator = '',
    this.pastSlugs = '',
    this.groupItemTitle = '',
    this.groupItemThreshold = '',
    this.groupItemRange = '',
    required this.category,
    required this.startDate,
    required this.endDate,
    this.startDateIso = '',
    this.endDateIso = '',
    this.umaEndDate,
    this.umaEndDateIso = '',
    this.lowerBoundDate,
    this.upperBoundDate,
    this.closedTime,
    this.createdAt,
    this.updatedAt,
    this.createdBy = 0,
    this.updatedBy = 0,
    this.gameStartTime,
    this.eventStartTime,
    this.readyTimestamp,
    this.fundedTimestamp,
    this.acceptingOrdersTimestamp,
    required this.outcomes,
    required this.outcomePrices,
    this.shortOutcomes = const <String>[],
    required this.active,
    required this.closed,
    required this.archived,
    this.isNew = false,
    this.featured = false,
    this.restricted = false,
    this.ready = false,
    this.funded = false,
    this.wideFormat = false,
    this.marketType = '',
    this.formatType = '',
    this.lowerBound = '',
    this.upperBound = '',
    this.umaResolutionStatus = '',
    this.umaResolutionStatuses = '',
    this.umaBond = '',
    this.umaReward = '',
    this.marketGroup = 0,
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
    this.volume24hrAmm = 0,
    this.volume1wkAmm = 0,
    this.volume1moAmm = 0,
    this.volume1yrAmm = 0,
    this.volume24hrClob = 0,
    this.volume1wkClob = 0,
    this.volume1moClob = 0,
    this.volume1yrClob = 0,
    this.volumeAmm = 0,
    this.volumeClob = 0,
    this.liquidityAmm = 0,
    this.liquidityClob = 0,
    required this.lastTradePrice,
    required this.bestBid,
    required this.bestAsk,
    this.spread = 0,
    this.competitive = 0,
    this.oneDayPriceChange = 0,
    this.oneHourPriceChange = 0,
    this.oneWeekPriceChange = 0,
    this.oneMonthPriceChange = 0,
    this.oneYearPriceChange = 0,
    this.rewardsMinSize = 0,
    this.rewardsMaxSpread = 0,
    this.negRisk = false,
    this.negRiskMarketId = '',
    this.negRiskFeeBips = 0,
    this.automaticallyResolved = false,
    this.automaticallyActive = false,
    this.clearBookOnStart = false,
    this.manualActivation = false,
    this.chartColor = '',
    this.seriesColor = '',
    this.showGmpSeries = false,
    this.showGmpOutcome = false,
    this.negRiskOther = false,
    this.pendingDeployment = false,
    this.deploying = false,
    this.deployingTimestamp,
    this.scheduledDeploymentTimestamp,
    this.rfqEnabled = false,
    this.notificationsEnabled = false,
    this.hasReviewedDates = false,
    this.readyForCron = false,
    this.commentsEnabled = false,
    this.curationOrder = 0,
    this.score = 0,
    this.imageOptimized,
    this.iconOptimized,
    this.teamAId = '',
    this.teamBId = '',
    this.gameId = '',
    this.sportsMarketType = '',
    this.line = 0,
    this.secondsDelay = 0,
    this.fpmmLive = false,
    this.customLiveness = 0,
    required this.clobTokenIds,
    required this.tags,
    this.categories = const <Category>[],
    this.events = const <Event>[],
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
    twitterCardImage: json['twitterCardImage']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    resolutionSource: json['resolutionSource']?.toString() ?? '',
    ammType: json['ammType']?.toString() ?? '',
    fee: json['fee']?.toString() ?? '',
    denominationToken: json['denominationToken']?.toString() ?? '',
    sponsorName: json['sponsorName']?.toString() ?? '',
    sponsorImage: json['sponsorImage']?.toString() ?? '',
    xAxisValue: json['xAxisValue']?.toString() ?? '',
    yAxisValue: json['yAxisValue']?.toString() ?? '',
    marketMakerAddress: json['marketMakerAddress']?.toString() ?? '',
    mailchimpTag: json['mailchimpTag']?.toString() ?? '',
    resolvedBy: json['resolvedBy']?.toString() ?? '',
    disqusThread: json['disqusThread']?.toString() ?? '',
    creator: json['creator']?.toString() ?? '',
    pastSlugs: json['pastSlugs']?.toString() ?? '',
    groupItemTitle:
        _field(json, 'groupItemTitle', 'group_item_title')?.toString() ?? '',
    groupItemThreshold:
        (json['groupItemThreshold'] ?? json['group_item_threshold'])
            ?.toString() ??
        '',
    groupItemRange: json['groupItemRange']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    endDate: parseNormalizedDateTime(json['endDate']),
    startDateIso: json['startDateIso']?.toString() ?? '',
    endDateIso: _field(json, 'endDateIso', 'end_date_iso')?.toString() ?? '',
    umaEndDate: parseNormalizedDateTime(json['umaEndDate']),
    umaEndDateIso: json['umaEndDateIso']?.toString() ?? '',
    lowerBoundDate: parseNormalizedDateTime(json['lowerBoundDate']),
    upperBoundDate: parseNormalizedDateTime(json['upperBoundDate']),
    closedTime: parseNormalizedDateTime(
      _field(json, 'closedTime', 'closed_time'),
    ),
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(_field(json, 'updatedAt', 'updated_at')),
    createdBy: _int(json['createdBy']),
    updatedBy: _int(json['updatedBy']),
    gameStartTime: parseNormalizedDateTime(
      _field(json, 'gameStartTime', 'game_start_time'),
    ),
    eventStartTime: parseNormalizedDateTime(json['eventStartTime']),
    readyTimestamp: parseNormalizedDateTime(json['readyTimestamp']),
    fundedTimestamp: parseNormalizedDateTime(json['fundedTimestamp']),
    acceptingOrdersTimestamp: parseNormalizedDateTime(
      json['acceptingOrdersTimestamp'],
    ),
    outcomes: parseStringOrArray(json['outcomes']),
    outcomePrices: parseStringOrArray(json['outcomePrices']),
    shortOutcomes: parseStringOrArray(json['shortOutcomes']),
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    isNew: json['new'] == true,
    featured: json['featured'] == true,
    restricted: json['restricted'] == true,
    ready: json['ready'] == true,
    funded: json['funded'] == true,
    wideFormat: json['wideFormat'] == true,
    marketType: json['marketType']?.toString() ?? '',
    formatType: json['formatType']?.toString() ?? '',
    lowerBound: json['lowerBound']?.toString() ?? '',
    upperBound: json['upperBound']?.toString() ?? '',
    umaResolutionStatus: json['umaResolutionStatus']?.toString() ?? '',
    umaResolutionStatuses: json['umaResolutionStatuses']?.toString() ?? '',
    umaBond: json['umaBond']?.toString() ?? '',
    umaReward: json['umaReward']?.toString() ?? '',
    marketGroup: _int(json['marketGroup']),
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
    volume24hrAmm: _double(json['volume24hrAmm']),
    volume1wkAmm: _double(json['volume1wkAmm']),
    volume1moAmm: _double(json['volume1moAmm']),
    volume1yrAmm: _double(json['volume1yrAmm']),
    volume24hrClob: _double(json['volume24hrClob']),
    volume1wkClob: _double(json['volume1wkClob']),
    volume1moClob: _double(json['volume1moClob']),
    volume1yrClob: _double(json['volume1yrClob']),
    volumeAmm: _double(json['volumeAmm']),
    volumeClob: _double(json['volumeClob']),
    liquidityAmm: _double(json['liquidityAmm']),
    liquidityClob: _double(json['liquidityClob']),
    lastTradePrice: _double(json['lastTradePrice']),
    bestBid: _double(json['bestBid']),
    bestAsk: _double(json['bestAsk']),
    spread: _double(json['spread']),
    competitive: _double(json['competitive']),
    oneDayPriceChange: _double(json['oneDayPriceChange']),
    oneHourPriceChange: _double(json['oneHourPriceChange']),
    oneWeekPriceChange: _double(json['oneWeekPriceChange']),
    oneMonthPriceChange: _double(json['oneMonthPriceChange']),
    oneYearPriceChange: _double(json['oneYearPriceChange']),
    rewardsMinSize: _double(json['rewardsMinSize']),
    rewardsMaxSpread: _double(json['rewardsMaxSpread']),
    negRisk: json['negRisk'] == true,
    negRiskMarketId: json['negRiskMarketID']?.toString() ?? '',
    negRiskFeeBips: _int(json['negRiskFeeBips']),
    automaticallyResolved: json['automaticallyResolved'] == true,
    automaticallyActive: json['automaticallyActive'] == true,
    clearBookOnStart: json['clearBookOnStart'] == true,
    manualActivation: json['manualActivation'] == true,
    chartColor: json['chartColor']?.toString() ?? '',
    seriesColor: json['seriesColor']?.toString() ?? '',
    showGmpSeries: json['showGmpSeries'] == true,
    showGmpOutcome: json['showGmpOutcome'] == true,
    negRiskOther: json['negRiskOther'] == true,
    pendingDeployment: json['pendingDeployment'] == true,
    deploying: json['deploying'] == true,
    deployingTimestamp: parseNormalizedDateTime(json['deployingTimestamp']),
    scheduledDeploymentTimestamp: parseNormalizedDateTime(
      json['scheduledDeploymentTimestamp'],
    ),
    rfqEnabled: json['rfqEnabled'] == true,
    notificationsEnabled: json['notificationsEnabled'] == true,
    hasReviewedDates: json['hasReviewedDates'] == true,
    readyForCron: json['readyForCron'] == true,
    commentsEnabled: json['commentsEnabled'] == true,
    curationOrder: _int(json['curationOrder']),
    score: _double(json['score']),
    imageOptimized: _optimizedImage(json['imageOptimized']),
    iconOptimized: _optimizedImage(json['iconOptimized']),
    teamAId: json['teamAID']?.toString() ?? '',
    teamBId: json['teamBID']?.toString() ?? '',
    gameId: json['gameId']?.toString() ?? '',
    sportsMarketType: json['sportsMarketType']?.toString() ?? '',
    line: _double(json['line']),
    secondsDelay: _int(json['secondsDelay']),
    fpmmLive: json['fpmmLive'] == true,
    customLiveness: _int(json['customLiveness']),
    clobTokenIds: json['clobTokenIds']?.toString() ?? '',
    tags: _tags(json['tags']),
    categories: _categories(json['categories']),
    events: _events(json['events']),
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
  final String twitterCardImage;
  final String image;
  final String icon;
  final String description;
  final String resolutionSource;
  final String ammType;
  final String fee;
  final String denominationToken;
  final String sponsorName;
  final String sponsorImage;
  final String xAxisValue;
  final String yAxisValue;
  final String marketMakerAddress;
  final String mailchimpTag;
  final String resolvedBy;
  final String disqusThread;
  final String creator;
  final String pastSlugs;
  final String groupItemTitle;
  final String groupItemThreshold;
  final String groupItemRange;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final String startDateIso;
  final String endDateIso;
  final DateTime? umaEndDate;
  final String umaEndDateIso;
  final DateTime? lowerBoundDate;
  final DateTime? upperBoundDate;
  final DateTime? closedTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int createdBy;
  final int updatedBy;
  final DateTime? gameStartTime;
  final DateTime? eventStartTime;
  final DateTime? readyTimestamp;
  final DateTime? fundedTimestamp;
  final DateTime? acceptingOrdersTimestamp;
  final List<String> outcomes;
  final List<String> outcomePrices;
  final List<String> shortOutcomes;
  final bool active;
  final bool closed;
  final bool archived;
  final bool isNew;
  final bool featured;
  final bool restricted;
  final bool ready;
  final bool funded;
  final bool wideFormat;
  final String marketType;
  final String formatType;
  final String lowerBound;
  final String upperBound;
  final String umaResolutionStatus;
  final String umaResolutionStatuses;
  final String umaBond;
  final String umaReward;
  final int marketGroup;
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
  final double volume24hrAmm;
  final double volume1wkAmm;
  final double volume1moAmm;
  final double volume1yrAmm;
  final double volume24hrClob;
  final double volume1wkClob;
  final double volume1moClob;
  final double volume1yrClob;
  final double volumeAmm;
  final double volumeClob;
  final double liquidityAmm;
  final double liquidityClob;
  final double lastTradePrice;
  final double bestBid;
  final double bestAsk;
  final double spread;
  final double competitive;
  final double oneDayPriceChange;
  final double oneHourPriceChange;
  final double oneWeekPriceChange;
  final double oneMonthPriceChange;
  final double oneYearPriceChange;
  final double rewardsMinSize;
  final double rewardsMaxSpread;
  final bool negRisk;
  final String negRiskMarketId;
  final int negRiskFeeBips;
  final bool automaticallyResolved;
  final bool automaticallyActive;
  final bool clearBookOnStart;
  final bool manualActivation;
  final String chartColor;
  final String seriesColor;
  final bool showGmpSeries;
  final bool showGmpOutcome;
  final bool negRiskOther;
  final bool pendingDeployment;
  final bool deploying;
  final DateTime? deployingTimestamp;
  final DateTime? scheduledDeploymentTimestamp;
  final bool rfqEnabled;
  final bool notificationsEnabled;
  final bool hasReviewedDates;
  final bool readyForCron;
  final bool commentsEnabled;
  final int curationOrder;
  final double score;
  final OptimizedImage? imageOptimized;
  final OptimizedImage? iconOptimized;
  final String teamAId;
  final String teamBId;
  final String gameId;
  final String sportsMarketType;
  final double line;
  final int secondsDelay;
  final bool fpmmLive;
  final int customLiveness;
  final String clobTokenIds;
  final List<Tag> tags;
  final List<Category> categories;
  final List<Event> events;
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
    this.score = '',
    this.elapsed = '',
    this.period = '',
    this.live = false,
    this.ended = false,
    this.finishedTimestamp,
    this.gmpChartMode = '',
    this.tweetCount = 0,
    this.featuredOrder = 0,
    this.estimateValue = false,
    this.cantEstimate = false,
    this.estimatedValue = '',
    this.spreadsMainLine = 0,
    this.totalsMainLine = 0,
    this.carouselMap = '',
    this.pendingDeployment = false,
    this.deploying = false,
    this.deployingTimestamp,
    this.scheduledDeploymentTimestamp,
    this.gameStatus = '',
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
    this.categories = const <Category>[],
    this.collections = const <Collection>[],
    this.eventCreators = const <EventCreator>[],
    this.subEvents = const <String>[],
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
    score: json['score']?.toString() ?? '',
    elapsed: json['elapsed']?.toString() ?? '',
    period: json['period']?.toString() ?? '',
    live: json['live'] == true,
    ended: json['ended'] == true,
    finishedTimestamp: parseNormalizedDateTime(json['finishedTimestamp']),
    gmpChartMode: json['gmpChartMode']?.toString() ?? '',
    tweetCount: _int(json['tweetCount']),
    featuredOrder: _int(json['featuredOrder']),
    estimateValue: json['estimateValue'] == true,
    cantEstimate: json['cantEstimate'] == true,
    estimatedValue: json['estimatedValue']?.toString() ?? '',
    spreadsMainLine: _double(json['spreadsMainLine']),
    totalsMainLine: _double(json['totalsMainLine']),
    carouselMap: json['carouselMap']?.toString() ?? '',
    pendingDeployment: json['pendingDeployment'] == true,
    deploying: json['deploying'] == true,
    deployingTimestamp: parseNormalizedDateTime(json['deployingTimestamp']),
    scheduledDeploymentTimestamp: parseNormalizedDateTime(
      json['scheduledDeploymentTimestamp'],
    ),
    gameStatus: json['gameStatus']?.toString() ?? '',
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
    categories: _categories(json['categories']),
    collections: _collections(json['collections']),
    eventCreators: _eventCreators(json['eventCreators']),
    subEvents: _stringList(json['subEvents']),
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
  final String score;
  final String elapsed;
  final String period;
  final bool live;
  final bool ended;
  final DateTime? finishedTimestamp;
  final String gmpChartMode;
  final int tweetCount;
  final int featuredOrder;
  final bool estimateValue;
  final bool cantEstimate;
  final String estimatedValue;
  final double spreadsMainLine;
  final double totalsMainLine;
  final String carouselMap;
  final bool pendingDeployment;
  final bool deploying;
  final DateTime? deployingTimestamp;
  final DateTime? scheduledDeploymentTimestamp;
  final String gameStatus;
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
  final List<Category> categories;
  final List<Collection> collections;
  final List<EventCreator> eventCreators;
  final List<String> subEvents;
  final List<Tag> tags;
  final Map<String, dynamic> raw;

  /// Re-emits the original decoded payload. The Event DTO retains every Gamma
  /// field in [raw], so this is a faithful round-trip and lets search results
  /// marshal cleanly for read-only MCP/agent output.
  Map<String, dynamic> toJson() => raw;
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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'events': events.map((e) => e.toJson()).toList(growable: false),
    'tags': tags.map((t) => t.toJson()).toList(growable: false),
    'profiles': profiles.map((p) => p.toJson()).toList(growable: false),
    'pagination': pagination.toJson(),
  };
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
    this.layout = '',
    required this.active,
    required this.closed,
    required this.archived,
    this.isNew = false,
    required this.featured,
    this.restricted = false,
    this.isTemplate = false,
    this.templateVariables = false,
    this.publishedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
    this.commentsEnabled = false,
    this.competitive = '',
    required this.startDate,
    this.pythTokenId = '',
    this.cgAssetName = '',
    this.score = 0,
    required this.volume,
    required this.volume24hr,
    required this.liquidity,
    required this.commentCount,
    required this.events,
    this.collections = const <Collection>[],
    this.categories = const <Category>[],
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
    layout: json['layout']?.toString() ?? '',
    active: json['active'] == true,
    closed: json['closed'] == true,
    archived: json['archived'] == true,
    isNew: json['new'] == true,
    featured: json['featured'] == true,
    restricted: json['restricted'] == true,
    isTemplate: json['isTemplate'] == true,
    templateVariables: json['templateVariables'] == true,
    publishedAt: parseNormalizedDateTime(json['publishedAt']),
    createdBy: json['createdBy']?.toString() ?? '',
    updatedBy: json['updatedBy']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
    commentsEnabled: json['commentsEnabled'] == true,
    competitive: json['competitive']?.toString() ?? '',
    startDate: parseNormalizedDateTime(json['startDate']),
    pythTokenId: json['pythTokenID']?.toString() ?? '',
    cgAssetName: json['cgAssetName']?.toString() ?? '',
    score: _double(json['score']),
    volume: _double(json['volume']),
    volume24hr: _double(json['volume24hr']),
    liquidity: _double(json['liquidity']),
    commentCount: _int(json['commentCount']),
    events: _events(json['events']),
    collections: _collections(json['collections']),
    categories: _categories(json['categories']),
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
  final String layout;
  final bool active;
  final bool closed;
  final bool archived;
  final bool isNew;
  final bool featured;
  final bool restricted;
  final bool isTemplate;
  final bool templateVariables;
  final DateTime? publishedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool commentsEnabled;
  final String competitive;
  final DateTime? startDate;
  final String pythTokenId;
  final String cgAssetName;
  final double score;
  final double volume;
  final double volume24hr;
  final double liquidity;
  final int commentCount;
  final List<Event> events;
  final List<Collection> collections;
  final List<Category> categories;
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
    this.createdAt,
    this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    league: json['league']?.toString() ?? '',
    record: json['record']?.toString() ?? '',
    logo: json['logo']?.toString() ?? '',
    abbreviation: json['abbreviation']?.toString() ?? '',
    alias: json['alias']?.toString() ?? '',
    createdAt: parseNormalizedDateTime(json['createdAt']),
    updatedAt: parseNormalizedDateTime(json['updatedAt']),
  );

  final int id;
  final String name;
  final String league;
  final String record;
  final String logo;
  final String abbreviation;
  final String alias;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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

/// A market clarification (Gamma view).
///
/// Official clarifications posted by Polymarket for a specific market.
@immutable
final class MarketClarification {
  const MarketClarification({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
  });

  factory MarketClarification.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value.toString();
      }
      return '';
    }

    return MarketClarification(
      id: pick(const ['id', 'clarificationId']),
      title: pick(const ['title', 'subject']),
      body: pick(const ['body', 'content', 'description', 'clarification']),
      createdAt: parseNormalizedDateTime(
        json['createdAt'] ?? json['created_at'],
      ),
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
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

List<Category> _categories(Object? raw) {
  if (raw is! List) return const <Category>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Category.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<Collection> _collections(Object? raw) {
  if (raw is! List) return const <Collection>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Collection.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

List<EventCreator> _eventCreators(Object? raw) {
  if (raw is! List) return const <EventCreator>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => EventCreator.fromJson(m.cast<String, dynamic>()))
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
