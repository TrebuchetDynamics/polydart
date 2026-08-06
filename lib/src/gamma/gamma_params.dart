/// Query parameter shapes for the Gamma client.
///
/// Mirrors the relevant `polytypes.Get*Params` records and `buildQueryPath`
/// in `internal/gamma/client.go`. Each `toQuery` matches the Go encoder's
/// emitted keys exactly — fields that the Go encoder ignores are omitted
/// here too so the wire shape stays in lockstep.
library;

import 'package:meta/meta.dart';

extension _GammaQueryBuilder on Map<String, dynamic> {
  void addPositiveInt(String key, int? value) {
    if (value != null && value > 0) this[key] = value.toString();
  }

  void addInt(String key, int? value) {
    if (value != null) this[key] = value.toString();
  }

  void addBool(String key, bool? value) {
    if (value != null) this[key] = value.toString();
  }

  void addNonEmptyString(String key, String? value) {
    if (value != null && value.isNotEmpty) this[key] = value;
  }

  void addStringList(String key, List<String> value) {
    if (value.isNotEmpty) this[key] = value;
  }

  void addDouble(String key, double? value) {
    if (value != null) this[key] = value.toString();
  }
}

@immutable
final class GetMarketsParams {
  const GetMarketsParams({
    this.limit,
    this.offset,
    this.order,
    this.ascending,
    this.slug = const <String>[],
    this.conditionIds = const <String>[],
    this.clobTokenIds = const <String>[],
    this.tagId,
    this.relatedTags,
    this.closed,
    this.active,
    this.liquidityNumMin,
    this.liquidityNumMax,
    this.volumeNumMin,
    this.volumeNumMax,
    this.sportsMarketTypes = const <String>[],
  });

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;
  final List<String> slug;
  final List<String> conditionIds;
  final List<String> clobTokenIds;
  final int? tagId;
  final bool? relatedTags;
  final bool? closed;
  final bool? active;
  final double? liquidityNumMin;
  final double? liquidityNumMax;
  final double? volumeNumMin;
  final double? volumeNumMax;
  final List<String> sportsMarketTypes;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending)
      ..addStringList('slug', slug)
      ..addStringList('condition_ids', conditionIds)
      ..addStringList('clob_token_ids', clobTokenIds)
      ..addInt('tag_id', tagId)
      ..addBool('related_tags', relatedTags)
      ..addBool('closed', closed)
      ..addBool('active', active)
      ..addDouble('liquidity_num_min', liquidityNumMin)
      ..addDouble('liquidity_num_max', liquidityNumMax)
      ..addDouble('volume_num_min', volumeNumMin)
      ..addDouble('volume_num_max', volumeNumMax)
      ..addStringList('sports_market_types', sportsMarketTypes);
    return q;
  }
}

@immutable
final class SearchParams {
  const SearchParams({
    required this.query,
    this.limitPerType,
    this.page,
    this.eventsTag = const <String>[],
    this.eventsStatus,
    this.ascending,
    this.sort,
    this.searchProfiles,
  });

  final String query;
  final int? limitPerType;
  final int? page;
  final List<String> eventsTag;
  final String? eventsStatus;
  final bool? ascending;
  final String? sort;
  final bool? searchProfiles;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{'q': query};
    q
      ..addInt('limit_per_type', limitPerType)
      ..addInt('page', page)
      ..addStringList('events_tag', eventsTag)
      ..addNonEmptyString('events_status', eventsStatus)
      ..addBool('ascending', ascending)
      ..addNonEmptyString('sort', sort)
      ..addBool('search_profiles', searchProfiles);
    return q;
  }
}

@immutable
final class GetEventsParams {
  const GetEventsParams({
    this.limit,
    this.offset,
    this.order,
    this.ascending,
    this.slug = const <String>[],
    this.tagId,
    this.closed,
    this.tagSlug,
    this.active,
  });

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;
  final List<String> slug;
  final int? tagId;
  final bool? closed;
  final String? tagSlug;
  final bool? active;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset)
      ..addBool('closed', closed)
      ..addInt('tag_id', tagId)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending)
      ..addStringList('slug', slug)
      ..addNonEmptyString('tag_slug', tagSlug)
      ..addBool('active', active);
    return q;
  }
}

@immutable
final class GetSeriesParams {
  const GetSeriesParams({
    this.limit,
    this.offset,
    this.order,
    this.ascending,
    this.closed,
  });

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;
  final bool? closed;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset)
      ..addBool('closed', closed)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending);
    return q;
  }
}

@immutable
final class GetTagsParams {
  const GetTagsParams({this.limit, this.offset, this.order, this.ascending});

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending);
    return q;
  }
}

@immutable
final class GetTeamsParams {
  const GetTeamsParams({
    this.limit,
    this.offset,
    this.order,
    this.ascending,
    this.league = const <String>[],
    this.name = const <String>[],
  });

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;
  final List<String> league;
  final List<String> name;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending)
      ..addStringList('league', league)
      ..addStringList('name', name);
    return q;
  }
}

/// Query for `GET /comments`. Mirrors `buildCommentPath` in polygolem.
@immutable
final class CommentQuery {
  const CommentQuery({this.entityId, this.entityType, this.limit, this.offset});

  final int? entityId;
  final String? entityType;
  final int? limit;
  final int? offset;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addInt('parent_entity_id', entityId)
      ..addNonEmptyString('parent_entity_type', entityType)
      ..addPositiveInt('limit', limit)
      ..addPositiveInt('offset', offset);
    return q;
  }
}

/// Keyset pagination params. Mirrors `buildKeysetPath` in polygolem.
@immutable
final class CategoryEventsParams {
  const CategoryEventsParams({
    this.limit = 20,
    this.cursor,
    this.order = 'volume24hr',
    this.ascending = false,
    this.closed = false,
    this.active,
    this.live,
    this.endDateMin,
    this.startTimeMin,
    this.startTimeMax,
  });

  final int? limit;
  final String? cursor;
  final String? order;
  final bool? ascending;
  final bool? closed;
  final bool? active;
  final bool? live;
  final String? endDateMin;
  final String? startTimeMin;
  final String? startTimeMax;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addNonEmptyString('after_cursor', cursor)
      ..addNonEmptyString('order', order)
      ..addBool('ascending', ascending)
      ..addBool('closed', closed)
      ..addBool('active', active)
      ..addBool('live', live)
      ..addNonEmptyString('end_date_min', endDateMin)
      ..addNonEmptyString('start_time_min', startTimeMin)
      ..addNonEmptyString('start_time_max', startTimeMax);
    return q;
  }
}

@immutable
final class KeysetParams {
  const KeysetParams({
    this.limit,
    this.keysetId,
    this.ascending,
    this.active,
    this.closed,
    this.order,
  });

  final int? limit;
  final String? keysetId;
  final bool? ascending;
  final bool? active;
  final bool? closed;
  final String? order;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    q
      ..addPositiveInt('limit', limit)
      ..addNonEmptyString('keyset_id', keysetId)
      ..addBool('ascending', ascending)
      ..addBool('active', active)
      ..addBool('closed', closed)
      ..addNonEmptyString('order', order);
    return q;
  }
}
