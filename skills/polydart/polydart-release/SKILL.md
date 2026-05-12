---
name: polydart-release
description: Release checklist for Polydart package versions, pub.dev readiness, Polygolem lockstep, changelog quality, and safety verification. Use when cutting, preparing, reviewing, or diagnosing a Polydart release.
---

# Polydart Release

Prepare releases with Polygolem parity and live-trading safety in view.
Follow the shared operating model in `../references/operating-model.md`.

## Release Inputs

Collect:

- Current Polydart version from `pubspec.yaml`.
- Current Polydart commit.
- Current Polygolem commit from `polygolem` or `.reference/polygolem`.
- Polygolem changelog entries since the last recorded parity commit.
- Intended release type: alpha patch, parity minor, or breaking major.
- Current status of `docs/POLYDART-POLYGOLEM-COVERAGE.md`.

## Checklist

1. Confirm `pubspec.yaml`, `CHANGELOG.md`, and README examples agree.
2. Confirm the release notes name the Polygolem commit or tag used for parity.
3. Classify upstream gaps as blocker, parity gap, or intentional Dart
   divergence.
4. Verify no private keys, builder secrets, relayer secrets, or generated
   credential material are committed.
5. Verify live-write paths still require `liveTradingEnabled` and live mode.
6. Block releases on safety or protocol-critical parity gaps. Alpha releases
   may ship documented non-critical gaps.
7. Check new public repo artifacts for non-public deployment/customer language.
8. Run:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
dart pub publish --dry-run
```

9. Run `dart test --tags network` only when the user explicitly wants live
   read smoke coverage.

## Release Notes

Call out:

- Public API changes.
- Polygolem parity commit.
- New or changed protocol surfaces.
- Safety-boundary changes.
- Known parity gaps.
