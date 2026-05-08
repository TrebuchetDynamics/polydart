/// Query parameter shapes for the Gamma client.
///
/// Mirrors the relevant `polytypes.Get*Params` records and `buildQueryPath`
/// in `internal/gamma/client.go`. Each `toQuery` matches the Go encoder's
/// emitted keys exactly — fields that the Go encoder ignores are omitted
/// here too so the wire shape stays in lockstep.
library;

import 'package:meta/meta.dart';

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
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    if (ascending != null) q['ascending'] = ascending!.toString();
    if (slug.isNotEmpty) q['slug'] = slug;
    if (conditionIds.isNotEmpty) q['condition_ids'] = conditionIds;
    if (clobTokenIds.isNotEmpty) q['clob_token_ids'] = clobTokenIds;
    if (tagId != null) q['tag_id'] = tagId!.toString();
    if (relatedTags != null) q['related_tags'] = relatedTags!.toString();
    if (closed != null) q['closed'] = closed!.toString();
    if (active != null) q['active'] = active!.toString();
    if (liquidityNumMin != null) {
      q['liquidity_num_min'] = liquidityNumMin!.toString();
    }
    if (liquidityNumMax != null) {
      q['liquidity_num_max'] = liquidityNumMax!.toString();
    }
    if (volumeNumMin != null) {
      q['volume_num_min'] = volumeNumMin!.toString();
    }
    if (volumeNumMax != null) {
      q['volume_num_max'] = volumeNumMax!.toString();
    }
    if (sportsMarketTypes.isNotEmpty) {
      q['sports_market_types'] = sportsMarketTypes;
    }
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
    if (limitPerType != null) q['limit_per_type'] = limitPerType!.toString();
    if (page != null) q['page'] = page!.toString();
    if (eventsTag.isNotEmpty) q['events_tag'] = eventsTag;
    if (eventsStatus != null && eventsStatus!.isNotEmpty) {
      q['events_status'] = eventsStatus;
    }
    if (ascending != null) q['ascending'] = ascending!.toString();
    if (sort != null && sort!.isNotEmpty) q['sort'] = sort;
    if (searchProfiles != null) {
      q['search_profiles'] = searchProfiles!.toString();
    }
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
  });

  final int? limit;
  final int? offset;
  final String? order;
  final bool? ascending;
  final List<String> slug;
  final int? tagId;
  final bool? closed;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    if (closed != null) q['closed'] = closed!.toString();
    if (tagId != null) q['tag_id'] = tagId!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    if (ascending != null) q['ascending'] = ascending!.toString();
    if (slug.isNotEmpty) q['slug'] = slug;
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
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    if (closed != null) q['closed'] = closed!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    if (ascending != null) q['ascending'] = ascending!.toString();
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
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    if (ascending != null) q['ascending'] = ascending!.toString();
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
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    if (ascending != null) q['ascending'] = ascending!.toString();
    if (league.isNotEmpty) q['league'] = league;
    if (name.isNotEmpty) q['name'] = name;
    return q;
  }
}

/// Query for `GET /comments`. Mirrors `buildCommentPath` in polygolem.
@immutable
final class CommentQuery {
  const CommentQuery({
    this.entityId,
    this.entityType,
    this.limit,
    this.offset,
  });

  final int? entityId;
  final String? entityType;
  final int? limit;
  final int? offset;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (entityId != null) q['entity_id'] = entityId!.toString();
    if (entityType != null && entityType!.isNotEmpty) {
      q['entity_type'] = entityType;
    }
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (offset != null && offset! > 0) q['offset'] = offset!.toString();
    return q;
  }
}

/// Keyset pagination params. Mirrors `buildKeysetPath` in polygolem.
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
    if (limit != null && limit! > 0) q['limit'] = limit!.toString();
    if (keysetId != null && keysetId!.isNotEmpty) q['keyset_id'] = keysetId;
    if (ascending != null) q['ascending'] = ascending!.toString();
    if (active != null) q['active'] = active!.toString();
    if (closed != null) q['closed'] = closed!.toString();
    if (order != null && order!.isNotEmpty) q['order'] = order;
    return q;
  }
}
