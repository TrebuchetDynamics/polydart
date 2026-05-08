/// Polymarket Builder Relayer V2 HTTP client.
///
/// Mirrors `internal/relayer/client.go`. Authenticates every request with
/// the `POLY_BUILDER_*` HMAC-SHA256 header set (see [BuilderConfig]) and
/// exposes deposit-wallet deploy/proxy and lifecycle queries used in the
/// headless onboarding flow documented in
/// `polygolem/docs/BUILDER-AUTO.md`.
library;

import 'dart:convert';

import '../auth/l2.dart';
import '../errors/errors.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import 'relayer_types.dart';

/// Polymarket DepositWallet factory address — the canonical `to:` for
/// `WALLET-CREATE` and `WALLET` batches.
const String depositWalletFactoryAddr =
    '0x00000000000Fb5C9ADea0298D729A0CB3823Cc07';

/// Default base URL for the Builder Relayer V2.
const String defaultRelayerBaseUrl = 'https://relayer-v2.polymarket.com';

final class RelayerClient {
  RelayerClient({
    required BuilderConfig builderConfig,
    int chainId = 137,
    HttpTransport? transport,
    DateTime Function()? clock,
  }) : _builder = builderConfig,
       _chainId = chainId,
       _transport =
           transport ??
           HttpTransport(
             config: const TransportConfig(baseUrl: defaultRelayerBaseUrl),
           ),
       _clock = clock ?? DateTime.now {
    if (!_builder.isValid) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message:
            'relayer: builder credentials are required (key, secret, passphrase)',
      );
    }
  }

  final HttpTransport _transport;
  final BuilderConfig _builder;
  final int _chainId;
  final DateTime Function() _clock;

  int get chainId => _chainId;

  void close() => _transport.close();

  Map<String, String> _authHeaders({
    required String method,
    required String path,
    String? body,
  }) {
    final ts = (_clock().millisecondsSinceEpoch / 1000).floor();
    return buildBuilderHeaders(
      config: _builder,
      timestamp: ts,
      method: method,
      path: path,
      body: body,
    );
  }

  /// `POST /submit` with `type: "WALLET-CREATE"` — deploys a deposit wallet
  /// for [ownerAddress]. Relayer pays gas; returns the tracked transaction.
  Future<RelayerTransaction> submitWalletCreate({
    required String ownerAddress,
  }) async {
    final owner = ownerAddress.trim();
    if (owner.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: owner address is required for WALLET-CREATE',
        field: 'ownerAddress',
      );
    }
    final body = <String, dynamic>{
      'type': 'WALLET-CREATE',
      'from': owner,
      'to': depositWalletFactoryAddr,
    };
    final compact = compactJson(jsonEncode(body));
    final headers = _authHeaders(
      method: 'POST',
      path: '/submit',
      body: compact,
    );
    final resp = await _transport.postJson(
      '/submit',
      body,
      headers: headers,
    );
    return RelayerTransaction.fromJson(resp);
  }

  /// `POST /submit` with `type: "WALLET"` — submits a signed wallet batch.
  Future<RelayerTransaction> submitWalletBatch({
    required String ownerAddress,
    required String walletAddress,
    required String nonce,
    required String signature,
    required String deadline,
    required List<DepositWalletCall> calls,
  }) async {
    final owner = ownerAddress.trim();
    final wallet = walletAddress.trim();
    if (owner.isEmpty || wallet.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: owner and wallet addresses are required',
      );
    }
    if (calls.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: at least one call is required',
        field: 'calls',
      );
    }
    final body = <String, dynamic>{
      'type': 'WALLET',
      'from': owner,
      'to': depositWalletFactoryAddr,
      'nonce': nonce,
      'signature': signature,
      'depositWalletParams': <String, dynamic>{
        'depositWallet': wallet,
        'deadline': deadline,
        'calls': calls.map((c) => c.toJson()).toList(growable: false),
      },
    };
    final compact = compactJson(jsonEncode(body));
    final headers = _authHeaders(
      method: 'POST',
      path: '/submit',
      body: compact,
    );
    final resp = await _transport.postJson(
      '/submit',
      body,
      headers: headers,
    );
    return RelayerTransaction.fromJson(resp);
  }

  /// `GET /nonce?address=…&type=WALLET` — current nonce for [ownerAddress].
  Future<String> getNonce({required String ownerAddress}) async {
    final owner = ownerAddress.trim();
    if (owner.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: owner address is required',
        field: 'ownerAddress',
      );
    }
    final path = '/nonce?address=$owner&type=WALLET';
    final headers = _authHeaders(method: 'GET', path: path);
    final resp = await _transport.getJson(path, headers: headers);
    final n = NonceResponse.fromJson(resp).nonce.trim();
    if (n.isEmpty) {
      throw const TransportException(
        code: ErrorCode.invalidValue,
        message: 'relayer: empty nonce response',
      );
    }
    return n;
  }

  /// `GET /deployed?address=…` — has [ownerAddress]'s deposit wallet been
  /// deployed yet?
  Future<DeployedResponse> isDeployed({required String ownerAddress}) async {
    final owner = ownerAddress.trim();
    if (owner.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: owner address is required',
        field: 'ownerAddress',
      );
    }
    final path = '/deployed?address=$owner';
    final headers = _authHeaders(method: 'GET', path: path);
    final resp = await _transport.getJson(path, headers: headers);
    return DeployedResponse.fromJson(resp);
  }

  /// `GET /transaction?id=…` — single tracked transaction by id.
  Future<RelayerTransaction> getTransaction({required String txId}) async {
    final id = txId.trim();
    if (id.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'relayer: transaction id is required',
        field: 'txId',
      );
    }
    final path = '/transaction?id=$id';
    final headers = _authHeaders(method: 'GET', path: path);
    final resp = await _transport.getJson(path, headers: headers);
    return RelayerTransaction.fromJson(resp);
  }

  /// Polls `getTransaction` until the state is terminal or [maxAttempts] is
  /// reached. Defaults to 50 attempts × 2 s ≈ 100 s.
  Future<RelayerTransaction> pollTransaction({
    required String txId,
    int maxAttempts = 50,
    Duration interval = const Duration(seconds: 2),
    Future<void> Function(Duration)? sleep,
  }) async {
    final wait = sleep ?? Future<void>.delayed;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final tx = await getTransaction(txId: txId);
      final state = tx.parsedState;
      if (state.isTerminal) {
        if (!state.isSuccess) {
          throw TransportException(
            code: ErrorCode.invalidValue,
            message:
                'relayer: transaction $txId reached terminal state ${tx.state}',
          );
        }
        return tx;
      }
      await wait(interval);
    }
    throw TransportException(
      code: ErrorCode.timeout,
      message:
          'relayer: timed out waiting for transaction $txId after $maxAttempts attempts',
    );
  }
}
