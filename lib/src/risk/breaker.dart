/// Local risk breaker helpers.
///
/// Mirrors Polygolem's `internal/risk` breaker behavior for consumer-side
/// checks. This file is read-only/local state only and performs no live writes.
library;

enum TripReason {
  consecutiveErrors('consecutive_errors'),
  dailyLossLimit('daily_loss_limit'),
  positionPerMarket('position_per_market'),
  totalPosition('total_position'),
  manualHalt('manual_halt');

  const TripReason(this.value);

  final String value;
}

TripReason? tripReasonFromString(String value) {
  for (final reason in TripReason.values) {
    if (reason.value == value) {
      return reason;
    }
  }
  return null;
}

final class Policy {
  const Policy({
    required this.maxOrderUsd,
    required this.maxOpenOrders,
    required this.dailyLossLimitUsd,
    required this.dailyPnlResetHour,
    required this.maxConsecutiveErrors,
    required this.cooldownSecs,
    required this.maxPositionPerMarket,
    required this.maxTotalPosition,
  });

  final double maxOrderUsd;
  final int maxOpenOrders;
  final double dailyLossLimitUsd;
  final int dailyPnlResetHour;
  final int maxConsecutiveErrors;
  final int cooldownSecs;
  final double maxPositionPerMarket;
  final double maxTotalPosition;

  Policy copyWith({
    double? maxOrderUsd,
    int? maxOpenOrders,
    double? dailyLossLimitUsd,
    int? dailyPnlResetHour,
    int? maxConsecutiveErrors,
    int? cooldownSecs,
    double? maxPositionPerMarket,
    double? maxTotalPosition,
  }) => Policy(
    maxOrderUsd: maxOrderUsd ?? this.maxOrderUsd,
    maxOpenOrders: maxOpenOrders ?? this.maxOpenOrders,
    dailyLossLimitUsd: dailyLossLimitUsd ?? this.dailyLossLimitUsd,
    dailyPnlResetHour: dailyPnlResetHour ?? this.dailyPnlResetHour,
    maxConsecutiveErrors: maxConsecutiveErrors ?? this.maxConsecutiveErrors,
    cooldownSecs: cooldownSecs ?? this.cooldownSecs,
    maxPositionPerMarket: maxPositionPerMarket ?? this.maxPositionPerMarket,
    maxTotalPosition: maxTotalPosition ?? this.maxTotalPosition,
  );

  Map<String, Object?> toJson() => {
    'max_order_usd': maxOrderUsd,
    'max_open_orders': maxOpenOrders,
    'daily_loss_limit_usd': dailyLossLimitUsd,
    'daily_pnl_reset_hour': dailyPnlResetHour,
    'max_consecutive_errors': maxConsecutiveErrors,
    'cooldown_secs': cooldownSecs,
    'max_position_per_market': maxPositionPerMarket,
    'max_total_position': maxTotalPosition,
  };
}

Policy defaultPolicy() => const Policy(
  maxOrderUsd: 10,
  maxOpenOrders: 5,
  dailyLossLimitUsd: 100,
  dailyPnlResetHour: 0,
  maxConsecutiveErrors: 5,
  cooldownSecs: 300,
  maxPositionPerMarket: 50,
  maxTotalPosition: 200,
);

final class RiskStatus {
  const RiskStatus({
    required this.halted,
    required this.tripReason,
    required this.tripReasonMessage,
    required this.lastBreak,
    required this.consecutiveErrors,
    required this.dailyLossUsd,
    required this.totalPositionUsd,
    required this.positions,
    required this.cooldownReady,
  });

  final bool halted;
  final TripReason? tripReason;
  final String tripReasonMessage;
  final DateTime? lastBreak;
  final int consecutiveErrors;
  final double dailyLossUsd;
  final double totalPositionUsd;
  final Map<String, double> positions;
  final bool cooldownReady;

  Map<String, Object?> toJson() => {
    'halted': halted,
    'trip_reason': tripReason?.value,
    'trip_reason_message': tripReasonMessage,
    'last_break': lastBreak?.toUtc().toIso8601String(),
    'consecutive_errors': consecutiveErrors,
    'daily_loss_usd': dailyLossUsd,
    'total_position_usd': totalPositionUsd,
    'positions': positions,
    'cooldown_ready': cooldownReady,
  };
}

final class Breaker {
  Breaker({Policy? policy, DateTime Function()? now})
    : _policy = policy ?? defaultPolicy(),
      _now = now ?? DateTime.now;

  final Policy _policy;
  final DateTime Function() _now;
  final Map<String, double> _positions = <String, double>{};

  var _consecutiveErrors = 0;
  var _dailyLoss = 0.0;
  DateTime? _dailyLossReset;
  DateTime? _lastBreak;
  var _halted = false;
  TripReason? _tripReason;

  bool recordError() {
    _checkDailyReset();
    _consecutiveErrors++;
    if (_consecutiveErrors >= _policy.maxConsecutiveErrors) {
      _trip(TripReason.consecutiveErrors);
      return true;
    }
    return false;
  }

  void recordSuccess() {
    _consecutiveErrors = 0;
  }

  bool recordLoss(num amount) {
    _checkDailyReset();
    _dailyLoss += amount.toDouble();
    if (_dailyLoss >= _policy.dailyLossLimitUsd) {
      _trip(TripReason.dailyLossLimit);
      return true;
    }
    return false;
  }

  bool recordPosition(String tokenId, num size) {
    final sizeValue = size.toDouble();
    _positions[tokenId] = sizeValue;
    final total = _totalPosition();

    if (_policy.maxPositionPerMarket > 0 &&
        sizeValue.abs() > _policy.maxPositionPerMarket) {
      _trip(TripReason.positionPerMarket);
      return true;
    }
    if (_policy.maxTotalPosition > 0 && total > _policy.maxTotalPosition) {
      _trip(TripReason.totalPosition);
      return true;
    }
    return false;
  }

  void halt() {
    _trip(TripReason.manualHalt);
  }

  RiskStatus status() {
    _checkDailyReset();
    return RiskStatus(
      halted: _halted,
      tripReason: _tripReason,
      tripReasonMessage: _tripReason?.value ?? 'unknown',
      lastBreak: _lastBreak,
      consecutiveErrors: _consecutiveErrors,
      dailyLossUsd: _dailyLoss,
      totalPositionUsd: _totalPosition(),
      positions: Map.unmodifiable(_positions),
      cooldownReady: _cooldownReady(),
    );
  }

  bool canProceed() {
    _checkDailyReset();
    if (!_halted) {
      return true;
    }
    if (_policy.cooldownSecs > 0 && _cooldownReady()) {
      _halted = false;
      _consecutiveErrors = 0;
      _tripReason = null;
      return true;
    }
    return false;
  }

  bool halted() => _halted;

  void reset() {
    _halted = false;
    _tripReason = null;
    _consecutiveErrors = 0;
    _dailyLoss = 0;
    _lastBreak = null;
    _dailyLossReset = null;
    _positions.clear();
  }

  void _trip(TripReason reason) {
    _halted = true;
    _tripReason = reason;
    _lastBreak = _now();
  }

  bool _cooldownReady() {
    final lastBreak = _lastBreak;
    if (!_halted || _policy.cooldownSecs <= 0 || lastBreak == null) {
      return false;
    }
    return _now().difference(lastBreak) >
        Duration(seconds: _policy.cooldownSecs);
  }

  void _checkDailyReset() {
    if (_policy.dailyLossLimitUsd <= 0) {
      return;
    }
    final now = _now().toUtc();
    final previous = _dailyLossReset;
    if (previous == null) {
      _dailyLossReset = now;
      return;
    }
    final previousUtc = previous.toUtc();
    final differentDay =
        now.year != previousUtc.year ||
        now.month != previousUtc.month ||
        now.day != previousUtc.day;
    if (differentDay && now.hour >= _policy.dailyPnlResetHour) {
      _dailyLoss = 0;
      _dailyLossReset = now;
    }
  }

  double _totalPosition() {
    var total = 0.0;
    for (final position in _positions.values) {
      total += position.abs();
    }
    return total;
  }
}
