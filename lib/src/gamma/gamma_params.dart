/// Query parameter shapes for the Gamma client.
///
/// Mirrors the relevant `polytypes.Get*Params` records. Phase 1 covers the
/// shapes used by `markets` and `search`; events / series / tags / teams
/// land alongside their corresponding client methods in a later commit.
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
