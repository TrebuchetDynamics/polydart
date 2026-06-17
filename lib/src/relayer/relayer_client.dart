/// Polymarket Builder Relayer V2 HTTP client.
///
/// Mirrors `internal/relayer/client.go`. Supports the legacy
/// `POLY_BUILDER_*` HMAC-SHA256 header set (see [BuilderConfig]) and the V2
/// `RELAYER_API_KEY` plain-header mode. Exposes deposit-wallet deploy/proxy
/// and lifecycle queries used in the headless onboarding flow documented in
/// `polygolem/docs/BUILDER-AUTO.md`.
library;

import 'dart:convert';

import '../auth/l2.dart';
import '../errors/errors.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import 'relayer_errors.dart';
import 'relayer_types.dart';
import 'v2_auth.dart';

/// Polymarket DepositWallet factory address — the canonical `to:` for
/// `WALLET-CREATE` and `WALLET` batches.
const String depositWalletFactoryAddr =
    '0x00000000000Fb5C9ADea0298D729A0CB3823Cc07';

/// Default base URL for the Builder Relayer V2.
const String defaultRelayerBaseUrl = 'https://relayer-v2.polymarket.com';

const int _defaultPollMaxAttempts = 50;
const Duration _defaultPollInterval = Duration(seconds: 2);

typedef _AuthHeaderBuilder =
    Map<String, String> Function({
      required String method,
      required String path,
      String? body,
    });

final class RelayerClient {
  RelayerClient({
    required BuilderConfig builderConfig,
    int chainId = 137,
    HttpTransport? transport,
    DateTime Function()? clock,
  }) : _chainId = chainId,
       _transport =
           transport ??
           HttpTransport(
             config: const TransportConfig(baseUrl: defaultRelayerBaseUrl),
           ),
       _authHeaders = _builderAuthHeaders(builderConfig, clock ?? DateTime.now);

  RelayerClient.v2({
    required V2APIKey apiKey,
    int chainId = 137,
    HttpTransport? transport,
  }) : _chainId = chainId,
       _transport =
           transport ??
           HttpTransport(
             config: const TransportConfig(baseUrl: defaultRelayerBaseUrl),
           ),
       _authHeaders = _v2AuthHeaders(apiKey);

  final HttpTransport _transport;
  final _AuthHeaderBuilder _authHeaders;
  final int _chainId;

  int get chainId => _chainId;

  void close() => _transport.close();

  static _AuthHeaderBuilder _builderAuthHeaders(
    BuilderConfig builderConfig,
    DateTime Function() clock,
  ) {
    if (!builderConfig.isValid) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message:
            'relayer: builder credentials are required (key, secret, passphrase)',
      );
    }
    return ({required String method, required String path, String? body}) {
      final ts = (clock().millisecondsSinceEpoch / 1000).floor();
      return buildBuilderHeaders(
        config: builderConfig,
        timestamp: ts,
        method: method,
        path: path,
        body: body,
      );
    };
  }

  static _AuthHeaderBuilder _v2AuthHeaders(V2APIKey apiKey) {
    final key = apiKey.key.trim();
    final address = apiKey.address.trim();
    if (key.isEmpty || address.isEmpty) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message: 'relayer: V2APIKey requires both key and address',
      );
    }
    final normalized = V2APIKey(key: key, address: address);
    return ({required String method, required String path, String? body}) {
      return normalized.v2Headers();
    };
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
    final Map<String, dynamic> resp;
    try {
      resp = await _transport.postJson('/submit', body, headers: headers);
    } catch (e) {
      throw classifyRelayerAllowlistError(e) ?? e;
    }
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
    final Map<String, dynamic> resp;
    try {
      resp = await _transport.postJson('/submit', body, headers: headers);
    } catch (e) {
      throw classifyRelayerAllowlistError(e) ?? e;
    }
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
    final path = _pathWithQuery('/nonce', <String, String>{
      'address': owner,
      'type': 'WALLET',
    });
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
    final path = _pathWithQuery('/deployed', <String, String>{
      'address': owner,
    });
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
    final path = _pathWithQuery('/transaction', <String, String>{'id': id});
    final headers = _authHeaders(method: 'GET', path: path);
    final body = await _transport.getJsonValue(path, headers: headers);
    if (body is Map<String, dynamic>) {
      return RelayerTransaction.fromJson(body);
    }
    if (body is Map) {
      return RelayerTransaction.fromJson(body.cast<String, dynamic>());
    }
    if (body is! List) {
      throw TransportException(
        code: ErrorCode.connectionFailed,
        message: 'relayer: transaction $id response was ${body.runtimeType}',
      );
    }
    if (body.isEmpty) {
      throw TransportException(
        code: ErrorCode.invalidValue,
        message: 'relayer: transaction $id not found',
      );
    }
    final first = body.first;
    if (first is Map<String, dynamic>) {
      return RelayerTransaction.fromJson(first);
    }
    if (first is Map) {
      return RelayerTransaction.fromJson(first.cast<String, dynamic>());
    }
    throw TransportException(
      code: ErrorCode.connectionFailed,
      message:
          'relayer: transaction $id response item was ${first.runtimeType}',
    );
  }

  /// Polls `getTransaction` until the state is terminal or [maxAttempts] is
  /// reached. Defaults to 50 attempts × 2 s ≈ 100 s.
  Future<RelayerTransaction> pollTransaction({
    required String txId,
    int maxAttempts = 50,
    Duration interval = const Duration(seconds: 2),
    Future<void> Function(Duration)? sleep,
  }) async {
    final attempts = maxAttempts <= 0 ? _defaultPollMaxAttempts : maxAttempts;
    final pollInterval = interval <= Duration.zero
        ? _defaultPollInterval
        : interval;
    final wait = sleep ?? Future<void>.delayed;
    for (var attempt = 0; attempt < attempts; attempt++) {
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
      await wait(pollInterval);
    }
    throw TransportException(
      code: ErrorCode.timeout,
      message:
          'relayer: timed out waiting for transaction $txId after $attempts attempts',
    );
  }
}

String _pathWithQuery(String path, Map<String, String> query) {
  return Uri(path: path, queryParameters: query).toString();
}
