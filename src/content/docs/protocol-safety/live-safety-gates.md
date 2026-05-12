---
title: Live Safety Gates
description: Evaluate the environment, configuration, user confirmation, and preflight checks required before live workflows.
sidebar:
  order: 3
---

Polydart models live access as an explicit gate result. Applications must make every live precondition visible and auditable before they make any live-only path reachable.

## Required Gates

`validateLiveGates()` mirrors the four gate categories:

| Gate | Input | Meaning |
| --- | --- | --- |
| Environment | `envEnabled` | A deployment or process-level live profile is enabled. |
| Configuration | `configEnabled` | `PolydartConfig.liveTradingEnabled` is true. |
| Confirmation | `confirmLive` | The user or operator made an explicit live confirmation. |
| Preflight | `preflightOk` | Required health, wallet, allowance, or risk checks passed. |

## Run Preflight

`runPreflight()` accepts caller-provided probes. Keep the checks specific to your application before marking `preflightOk`.

```dart
import 'package:polydart/polydart.dart';

Future<PreflightResult> runReadinessChecks(Polydart client) {
  return runPreflight([
    PreflightCheck(name: 'gamma-health', probe: client.gamma.health),
    PreflightCheck(name: 'clob-health', probe: client.clob.health),
  ]);
}
```

## Evaluate Live Gates

Configuration is data. It does not become permission until all gates pass.

```dart
import 'package:polydart/polydart.dart';

Future<LiveGateResult> evaluateGates({
  required Map<String, String> env,
  required bool confirmLive,
}) async {
  final config = PolydartConfig.fromEnv(env);
  final client = Polydart.readOnly(config: config);

  try {
    final preflight = await runReadinessChecks(client);

    return validateLiveGates(
      LiveGateInput(
        envEnabled: env['POLYMARKET_LIVE_PROFILE'] == 'on',
        configEnabled: config.liveTradingEnabled,
        confirmLive: confirmLive,
        preflightOk: preflight.ok,
      ),
    );
  } finally {
    client.close();
  }
}
```

## Block On Failures

Do not collapse gate failures into a boolean with no detail. The failure codes are intended for logs and UI.

```dart
import 'package:polydart/polydart.dart';

void requireAllowed(LiveGateResult gates) {
  if (gates.allowed) return;

  final codes = gates.failures.map((failure) => failure.code).join(', ');
  throw SafetyException(
    code: ErrorCode.liveDisabled,
    message: 'live mode blocked by: $codes',
  );
}
```

## Write Surfaces Are Gated

The CLOB write surface calls `requireLive()` internally. Read-only and paper clients cannot place or cancel live orders.

```dart
import 'package:polydart/polydart.dart';

void demonstrateGate() {
  try {
    requireLive(PolydartMode.paper, liveTradingEnabled: false);
  } on SafetyException catch (error) {
    print(error.code.value); // SAFETY-001
  }
}
```

These docs intentionally avoid live order submission snippets. Use the gate result as the boundary between planning and any application-owned live execution path.
