import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:test/test.dart';

void main() {
  group('PolydartMode.parse', () {
    test('empty defaults to read-only', () {
      expect(PolydartMode.parse(''), PolydartMode.readOnly);
      expect(PolydartMode.parse('   '), PolydartMode.readOnly);
    });

    test('canonical labels', () {
      expect(PolydartMode.parse('read-only'), PolydartMode.readOnly);
      expect(PolydartMode.parse('paper'), PolydartMode.paper);
      expect(PolydartMode.parse('live'), PolydartMode.live);
    });

    test('aliases for read-only', () {
      expect(PolydartMode.parse('readonly'), PolydartMode.readOnly);
      expect(PolydartMode.parse('READ_ONLY'), PolydartMode.readOnly);
      expect(PolydartMode.parse('ro'), PolydartMode.readOnly);
    });

    test('rejects garbage', () {
      expect(
        () => PolydartMode.parse('reckless'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('requireLive', () {
    test('passes when live + flag enabled', () {
      requireLive(PolydartMode.live, liveTradingEnabled: true);
    });

    test('throws for paper / read-only', () {
      expect(
        () => requireLive(PolydartMode.paper, liveTradingEnabled: true),
        throwsA(isA<SafetyException>()),
      );
      expect(
        () => requireLive(PolydartMode.readOnly, liveTradingEnabled: true),
        throwsA(isA<SafetyException>()),
      );
    });

    test('throws when flag is off', () {
      expect(
        () => requireLive(PolydartMode.live, liveTradingEnabled: false),
        throwsA(
          isA<SafetyException>().having(
            (e) => e.code,
            'code',
            ErrorCode.liveDisabled,
          ),
        ),
      );
    });
  });

  group('requirePaperOrLive', () {
    test('passes for paper and live', () {
      requirePaperOrLive(PolydartMode.paper);
      requirePaperOrLive(PolydartMode.live);
    });

    test('throws for read-only', () {
      expect(
        () => requirePaperOrLive(PolydartMode.readOnly),
        throwsA(isA<SafetyException>()),
      );
    });
  });

  group('validateLiveGates', () {
    test('requires env, config, confirmation, and preflight gates', () {
      final result = validateLiveGates(
        const LiveGateInput(
          envEnabled: true,
          configEnabled: true,
          confirmLive: false,
          preflightOk: true,
        ),
      );

      expect(result.allowed, isFalse);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.code, 'cli_confirmation_required');
      expect(result.failures.single.message, '--confirm-live is required');
    });

    test('returns all missing gate failures in upstream order', () {
      final result = validateLiveGates(
        const LiveGateInput(
          envEnabled: false,
          configEnabled: false,
          confirmLive: false,
          preflightOk: false,
        ),
      );

      expect(result.allowed, isFalse);
      expect(result.failures.map((f) => f.code), <String>[
        'env_gate_required',
        'config_gate_required',
        'cli_confirmation_required',
        'preflight_required',
      ]);
    });

    test('allows live mode only when every gate is present', () {
      final result = validateLiveGates(
        const LiveGateInput(
          envEnabled: true,
          configEnabled: true,
          confirmLive: true,
          preflightOk: true,
        ),
      );

      expect(result.allowed, isTrue);
      expect(result.failures, isEmpty);
    });
  });
}
