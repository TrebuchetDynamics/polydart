/// Analytics-flavored CLOB types: rewards configuration, raw rewards,
/// user/total earnings, reward percentages, per-market user rewards, and
/// rebated fees.
///
/// Mirrors the structs in polygolem `internal/polytypes/comments.go`
/// (lines 46-100). JSON keys match the Go struct tags exactly so
/// payloads round-trip without a translation layer.
library;

import 'package:meta/meta.dart';

import 'shared/clob_json.dart';

/// Active rewards configuration for a market.
@immutable
final class RewardsConfig {
  const RewardsConfig({
    required this.market,
    required this.assetAddress,
    required this.rewardsMinSize,
    required this.rewardsMaxSpread,
    required this.active,
  });

  factory RewardsConfig.fromJson(Map<String, dynamic> json) => RewardsConfig(
    market: clobStringOf(json, const ['market']),
    assetAddress: clobStringOf(json, const ['asset_address', 'assetAddress']),
    rewardsMinSize: clobDouble(
      clobFirstOf(json, const ['rewards_min_size', 'rewardsMinSize']),
    ),
    rewardsMaxSpread: clobDouble(
      clobFirstOf(json, const ['rewards_max_spread', 'rewardsMaxSpread']),
    ),
    active: clobBool(json['active']),
  );

  final String market;
  final String assetAddress;
  final double rewardsMinSize;
  final double rewardsMaxSpread;
  final bool active;
}

/// Raw rewards for a market on a given date.
@immutable
final class RawRewards {
  const RawRewards({
    required this.market,
    required this.date,
    required this.rewardsPaid,
    required this.volume,
  });

  factory RawRewards.fromJson(Map<String, dynamic> json) => RawRewards(
    market: clobStringOf(json, const ['market']),
    date: clobStringOf(json, const ['date']),
    rewardsPaid: clobDouble(
      clobFirstOf(json, const ['rewards_paid', 'rewardsPaid']),
    ),
    volume: clobDouble(json['volume']),
  );

  final String market;
  final String date;
  final double rewardsPaid;
  final double volume;
}

/// Earnings for a user, optionally scoped to a single market.
@immutable
final class UserEarnings {
  const UserEarnings({required this.date, required this.earnings, this.market});

  factory UserEarnings.fromJson(Map<String, dynamic> json) {
    final market = json['market']?.toString();
    return UserEarnings(
      date: json['date']?.toString() ?? '',
      earnings: clobDouble(json['earnings']),
      market: (market == null || market.isEmpty) ? null : market,
    );
  }

  final String date;
  final double earnings;

  /// Optional — present only when the API segments earnings per market.
  final String? market;
}

/// Aggregated earnings on a date.
@immutable
final class TotalEarnings {
  const TotalEarnings({required this.date, required this.earnings});

  factory TotalEarnings.fromJson(Map<String, dynamic> json) => TotalEarnings(
    date: json['date']?.toString() ?? '',
    earnings: clobDouble(json['earnings']),
  );

  final String date;
  final double earnings;
}

/// Per-market reward percentage.
@immutable
final class RewardPercentages {
  const RewardPercentages({
    required this.market,
    required this.rewardPercentage,
  });

  factory RewardPercentages.fromJson(Map<String, dynamic> json) =>
      RewardPercentages(
        market: clobStringOf(json, const ['market']),
        rewardPercentage: clobDouble(
          clobFirstOf(json, const ['reward_percentage', 'rewardPercentage']),
        ),
      );

  final String market;
  final double rewardPercentage;
}

/// One row of the user-rewards-by-market endpoint.
@immutable
final class UserRewardsMarket {
  const UserRewardsMarket({
    required this.market,
    required this.totalRewards,
    required this.rewardPercentage,
  });

  factory UserRewardsMarket.fromJson(Map<String, dynamic> json) =>
      UserRewardsMarket(
        market: clobStringOf(json, const ['market']),
        totalRewards: clobDouble(
          clobFirstOf(json, const ['total_rewards', 'totalRewards']),
        ),
        rewardPercentage: clobDouble(
          clobFirstOf(json, const ['reward_percentage', 'rewardPercentage']),
        ),
      );

  final String market;
  final double totalRewards;
  final double rewardPercentage;
}

/// Query parameters for `GET /rewards/markets`.
///
/// All three fields are optional — fields with their zero value are
/// omitted from the wire request, matching polygolem's `omitempty`
/// JSON tags.
@immutable
final class UserRewardsByMarketRequest {
  const UserRewardsByMarketRequest({
    this.date,
    this.orderBy,
    this.noCompetition,
  });

  /// Optional `YYYY-MM-DD` date filter.
  final String? date;

  /// Optional sort key (e.g. `total_rewards`).
  final String? orderBy;

  /// Optional flag to exclude markets in competition.
  final bool? noCompetition;

  Map<String, String> toQuery() {
    final out = <String, String>{};
    if (date != null && date!.isNotEmpty) out['date'] = date!;
    if (orderBy != null && orderBy!.isNotEmpty) out['order_by'] = orderBy!;
    if (noCompetition == true) out['no_competition'] = 'true';
    return out;
  }
}

/// Current rebated fees for a maker.
@immutable
final class RebatedFees {
  const RebatedFees({
    required this.makerAddress,
    required this.totalRebated,
    required this.date,
    this.market,
  });

  factory RebatedFees.fromJson(Map<String, dynamic> json) {
    final market = json['market']?.toString();
    return RebatedFees(
      makerAddress: clobStringOf(json, const ['maker_address', 'makerAddress']),
      market: (market == null || market.isEmpty) ? null : market,
      totalRebated: clobDouble(
        clobFirstOf(json, const ['total_rebated', 'totalRebated']),
      ),
      date: json['date']?.toString() ?? '',
    );
  }

  final String makerAddress;
  final String? market;
  final double totalRebated;
  final String date;
}
