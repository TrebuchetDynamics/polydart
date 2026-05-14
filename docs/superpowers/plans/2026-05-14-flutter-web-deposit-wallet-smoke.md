# Flutter Web Deposit-Wallet Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public, mock-only plain-Dart smoke path that proves a Flutter Web app can drive a deposit-wallet limit order without exposing raw EOA private keys.

**Architecture:** Keep Polydart as a Dart package: the example owns a fake app wallet signer, a mock CLOB transport, and a small facade returning app-visible success/rejection outcomes. The test imports the example and verifies observable behavior through public Polydart APIs.

**Tech Stack:** Dart 3.10, `package:polydart/polydart.dart`, `package:http/testing.dart`, `package:test/test.dart`.

---

### Task 1: Smoke Example And Behavior Test

**Files:**
- Create: `example/flutter_deposit_wallet_order.dart`
- Create: `test/example/flutter_deposit_wallet_order_test.dart`

- [ ] **Step 1: Write the failing behavior test**

Create `test/example/flutter_deposit_wallet_order_test.dart`:

```dart
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

import '../../example/flutter_deposit_wallet_order.dart';

void main() {
  test('mock-only deposit-wallet order uses signatureType 3', () async {
    final signer = FakeFlutterWalletSigner(
      address: '0x0000000000000000000000000000000000001234',
    );
    final smoke = FlutterDepositWalletOrderSmoke(signer: signer);

    final outcome = await smoke.run();

    expect(outcome, isA<FlutterDepositWalletOrderSmokeSuccess>());
    final success = outcome as FlutterDepositWalletOrderSmokeSuccess;
    final depositWallet = deriveDepositWallet(signer.address);
    expect(success.response.orderId, 'mock-order-1');
    expect(success.depositWallet, depositWallet);
    expect(success.readinessStatus, 'ready');
    expect(success.orderRequestHeaders['POLY_ADDRESS'], signer.address);
    expect(signer.lastTypedData?['primaryType'], 'TypedDataSign');

    final order = success.orderRequestBody['order'] as Map<String, dynamic>;
    expect(order['maker'], depositWallet);
    expect(order['signer'], depositWallet);
    expect(order['signatureType'], 3);
    expect(order['tokenId'], '12345');
  });

  test('user rejection is returned as an app-visible outcome', () async {
    final signer = FakeFlutterWalletSigner(
      address: '0x0000000000000000000000000000000000001234',
      rejectTypedData: true,
    );
    final smoke = FlutterDepositWalletOrderSmoke(signer: signer);

    final outcome = await smoke.run();

    expect(outcome, isA<FlutterDepositWalletOrderSmokeRejected>());
    final rejected = outcome as FlutterDepositWalletOrderSmokeRejected;
    expect(rejected.reason, contains('rejected'));
  });
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```sh
dart test test/example/flutter_deposit_wallet_order_test.dart --reporter=expanded
```

Expected: fails because `example/flutter_deposit_wallet_order.dart` does not exist.

- [ ] **Step 3: Implement the example facade**

Create `example/flutter_deposit_wallet_order.dart`:

```dart
/// Mock-only Flutter Web deposit-wallet order smoke path.
///
/// This is plain Dart so Polydart remains a Dart package. A Flutter app can own
/// this object from Provider, bloc, Riverpod, or State and replace
/// [FakeFlutterWalletSigner] with its wallet SDK adapter.
///
/// Analyze: `dart analyze example/flutter_deposit_wallet_order.dart`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';

final class FlutterWalletApprovalRejectedException implements Exception {
  const FlutterWalletApprovalRejectedException(this.message);

  final String message;

  @override
  String toString() => 'FlutterWalletApprovalRejectedException: $message';
}

final class FakeFlutterWalletSigner implements WalletSigner {
  FakeFlutterWalletSigner({
    required this.address,
    this.chainId = polymarketChainId,
    this.rejectTypedData = false,
  });

  @override
  final String address;

  @override
  final int chainId;

  final bool rejectTypedData;

  Map<String, dynamic>? lastTypedData;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    lastTypedData = typedData;
    if (rejectTypedData) {
      throw const FlutterWalletApprovalRejectedException(
        'user rejected typed-data approval',
      );
    }
    return _cannedSignature();
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    return _cannedSignature();
  }
}

sealed class FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeOutcome();
}

final class FlutterDepositWalletOrderSmokeSuccess
    extends FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeSuccess({
    required this.response,
    required this.depositWallet,
    required this.readinessStatus,
    required this.orderRequestBody,
    required this.orderRequestHeaders,
  });

  final OrderResponse response;
  final String depositWallet;
  final String readinessStatus;
  final Map<String, dynamic> orderRequestBody;
  final Map<String, String> orderRequestHeaders;
}

final class FlutterDepositWalletOrderSmokeRejected
    extends FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeRejected({required this.reason});

  final String reason;
}

final class FlutterDepositWalletOrderSmoke {
  FlutterDepositWalletOrderSmoke({
    required WalletSigner signer,
    ApiKey apiKey = _mockApiKey,
    CreateDepositWalletLimitOrderParams params = _mockOrderParams,
  }) : _signer = signer,
       _apiKey = apiKey,
       _params = params;

  final WalletSigner _signer;
  final ApiKey _apiKey;
  final CreateDepositWalletLimitOrderParams _params;

  Future<FlutterDepositWalletOrderSmokeOutcome> run() async {
    Map<String, dynamic>? capturedBody;
    Map<String, String>? capturedHeaders;
    final client = _mockLiveClobClient((req) async {
      switch (req.url.path) {
        case '/tick-size':
          return http.Response(
            jsonEncode(<String, dynamic>{
              'minimum_tick_size': '0.01',
              'minimum_order_size': '5',
              'tick_size': '0.01',
            }),
            200,
          );
        case '/order':
          final body = jsonDecode((req as http.Request).body);
          capturedBody = (body as Map<String, dynamic>);
          capturedHeaders = Map<String, String>.of(req.headers);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'order_id': 'mock-order-1',
              'status': 'live',
            }),
            200,
          );
        default:
          return http.Response('not found', 404);
      }
    });

    try {
      final response = await createDepositWalletLimitOrder(
        client: client,
        signer: _signer,
        apiKey: _apiKey,
        params: _params,
      );
      return FlutterDepositWalletOrderSmokeSuccess(
        response: response,
        depositWallet: deriveDepositWallet(_signer.address),
        readinessStatus: 'ready',
        orderRequestBody: capturedBody ?? const <String, dynamic>{},
        orderRequestHeaders: capturedHeaders ?? const <String, String>{},
      );
    } on FlutterWalletApprovalRejectedException catch (e) {
      return FlutterDepositWalletOrderSmokeRejected(reason: e.message);
    } finally {
      client.close();
    }
  }
}

const ApiKey _mockApiKey = ApiKey(
  key: 'mock-clob-key',
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'mock-passphrase',
);

const CreateDepositWalletLimitOrderParams _mockOrderParams =
    CreateDepositWalletLimitOrderParams(
      tokenId: '12345',
      side: Side.buy,
      price: '0.50',
      size: '10',
    );

ClobClient _mockLiveClobClient(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    mode: PolydartMode.live,
    liveTradingEnabled: true,
  );
}

Uint8List _cannedSignature() {
  final bytes = Uint8List(65);
  for (var i = 0; i < 64; i++) {
    bytes[i] = i + 1;
  }
  bytes[64] = 27;
  return bytes;
}

Future<void> main() async {
  final signer = FakeFlutterWalletSigner(
    address: '0x0000000000000000000000000000000000001234',
  );
  final outcome = await FlutterDepositWalletOrderSmoke(signer: signer).run();
  if (outcome is FlutterDepositWalletOrderSmokeSuccess) {
    // ignore: avoid_print
    print(jsonEncode(outcome.orderRequestBody));
  }
}
```

- [ ] **Step 4: Run test to verify GREEN**

Run:

```sh
dart test test/example/flutter_deposit_wallet_order_test.dart --reporter=expanded
```

Expected: both example tests pass.

### Task 2: Public Docs And Changelog

**Files:**
- Modify: `docs/FLUTTER-APP-READINESS.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Link the smoke example from Flutter readiness docs**

In `docs/FLUTTER-APP-READINESS.md`, after the wallet signer example paragraph, add:

```md
For a mock-only deposit-wallet limit-order smoke path, see
[`example/flutter_deposit_wallet_order.dart`](../example/flutter_deposit_wallet_order.dart).
It uses a fake wallet signer, a mock CLOB transport, and a local readiness
state so Flutter Web consumers can validate the `signatureType=3` order path
without live endpoints, private keys, funds, or product-specific code.
```

- [ ] **Step 2: Add changelog entry**

In `CHANGELOG.md` under `[Unreleased] -> Changed`, add:

```md
- Added a mock-only Flutter Web deposit-wallet order smoke example that proves
  the `WalletSigner` approval boundary and `signatureType=3` payload path
  without live endpoints or raw private keys.
```

- [ ] **Step 3: Run docs/package checks for this task**

Run:

```sh
rg -n "Arenaton|arenaton|server-arenaton|private key" example/flutter_deposit_wallet_order.dart test/example/flutter_deposit_wallet_order_test.dart docs/FLUTTER-APP-READINESS.md CHANGELOG.md
dart analyze example/flutter_deposit_wallet_order.dart test/example/flutter_deposit_wallet_order_test.dart
```

Expected: `rg` only finds the intended phrase `private keys` in public safety wording, and analyzer reports no issues.

### Task 3: Release Verification And Commit

**Files:**
- No new source files.

- [ ] **Step 1: Run full verification**

Run:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
dart pub publish --dry-run
```

Expected: format check exits 0, analyzer reports no issues, tests pass, dry-run has 0 warnings.

- [ ] **Step 2: Commit implementation**

Run:

```sh
git add CHANGELOG.md docs/FLUTTER-APP-READINESS.md example/flutter_deposit_wallet_order.dart test/example/flutter_deposit_wallet_order_test.dart
git commit -m "Add Flutter Web deposit wallet smoke example"
```

Expected: a focused implementation commit after the design/plan commits.
