/// Local preflight helpers.
///
/// Mirrors Polygolem's `internal/preflight` surface without signing or live
/// writes. Probes are intentionally caller-provided and run sequentially.
library;

import 'dart:async';

typedef Probe = FutureOr<void> Function();

final class PreflightCheck {
  const PreflightCheck({required this.name, required this.probe});

  final String name;
  final Probe probe;
}

final class PreflightCheckResult {
  const PreflightCheckResult({
    required this.name,
    required this.status,
    this.message,
  });

  final String name;
  final String status;
  final String? message;

  Map<String, Object?> toJson() => {
    'name': name,
    'status': status,
    if (message != null && message!.isNotEmpty) 'message': message,
  };
}

final class PreflightResult {
  const PreflightResult({required this.ok, required this.checks});

  final bool ok;
  final List<PreflightCheckResult> checks;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'checks': checks.map((check) => check.toJson()).toList(),
  };
}

Future<PreflightResult> runPreflight(Iterable<PreflightCheck> checks) async {
  var ok = true;
  final results = <PreflightCheckResult>[];

  for (final check in checks) {
    try {
      await check.probe();
      results.add(PreflightCheckResult(name: check.name, status: 'pass'));
    } catch (error) {
      ok = false;
      results.add(
        PreflightCheckResult(
          name: check.name,
          status: 'fail',
          message: error.toString(),
        ),
      );
    }
  }

  return PreflightResult(ok: ok, checks: List.unmodifiable(results));
}
