/// Live credential discovery helpers.
///
/// These services orchestrate protocol calls while keeping wallet approval and
/// credential persistence application-owned.
library;

import 'package:meta/meta.dart';

import '../auth/clob_auth.dart';
import '../auth/l2.dart';
import '../auth/wallet_signer.dart';
import '../clob/clob_client.dart';
import '../errors/errors.dart';

enum LiveCredentialStatus { cached, created, derived, userRejected, blocked }

enum LiveCredentialAction { none, requestSignature, retry }

@immutable
final class CredentialKey {
  const CredentialKey({required this.eoaAddress, required this.chainId});

  final String eoaAddress;
  final int chainId;

  @override
  bool operator ==(Object other) =>
      other is CredentialKey &&
      other.eoaAddress.toLowerCase() == eoaAddress.toLowerCase() &&
      other.chainId == chainId;

  @override
  int get hashCode => Object.hash(eoaAddress.toLowerCase(), chainId);

  @override
  String toString() {
    return 'CredentialKey(eoaAddress=${eoaAddress.toLowerCase()}, chainId=$chainId)';
  }
}

abstract interface class CredentialStore {
  Future<ApiKey?> readClobApiKey(CredentialKey key);

  Future<void> writeClobApiKey(CredentialKey key, ApiKey value);
}

final class MemoryCredentialStore implements CredentialStore {
  final Map<CredentialKey, ApiKey> _clobApiKeys = <CredentialKey, ApiKey>{};

  @override
  Future<ApiKey?> readClobApiKey(CredentialKey key) async {
    return _clobApiKeys[key];
  }

  @override
  Future<void> writeClobApiKey(CredentialKey key, ApiKey value) async {
    value.validate();
    _clobApiKeys[key] = value;
  }
}

final class WalletSignatureRejectedException implements Exception {
  const WalletSignatureRejectedException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return 'WalletSignatureRejectedException: $message';
    return 'WalletSignatureRejectedException: $message: $cause';
  }
}

@immutable
final class CredentialReadiness<T> {
  const CredentialReadiness({
    required this.status,
    this.action = LiveCredentialAction.none,
    this.value,
    this.reason = '',
  });

  final LiveCredentialStatus status;
  final LiveCredentialAction action;
  final T? value;
  final String reason;

  bool get isReady {
    return switch (status) {
      LiveCredentialStatus.cached ||
      LiveCredentialStatus.created ||
      LiveCredentialStatus.derived => true,
      LiveCredentialStatus.userRejected ||
      LiveCredentialStatus.blocked => false,
    };
  }

  @override
  String toString() {
    final hasValue = value == null ? '<none>' : '<redacted>';
    final reasonPart = reason.isEmpty ? '' : ', reason=$reason';
    return 'CredentialReadiness(status=${status.name}, action=${action.name}, value=$hasValue$reasonPart)';
  }
}

@immutable
final class LiveCredentialReadiness {
  const LiveCredentialReadiness({required this.clobApiKey});

  final CredentialReadiness<ApiKey> clobApiKey;

  bool get ready => clobApiKey.isReady;

  @override
  String toString() => 'LiveCredentialReadiness(clobApiKey=$clobApiKey)';
}

final class LiveCredentialService {
  LiveCredentialService({
    required ClobClient clob,
    CredentialStore? credentialStore,
    int Function()? nowSeconds,
  }) : _clob = clob,
       _credentialStore = credentialStore,
       _nowSeconds = nowSeconds;

  final ClobClient _clob;
  final CredentialStore? _credentialStore;
  final int Function()? _nowSeconds;

  Future<LiveCredentialReadiness> ensure({
    required WalletSigner signer,
    bool forceRefresh = false,
  }) async {
    final key = CredentialKey(
      eoaAddress: signer.address,
      chainId: signer.chainId,
    );

    if (!forceRefresh) {
      final cached = await _credentialStore?.readClobApiKey(key);
      if (cached != null) {
        cached.validate();
        return LiveCredentialReadiness(
          clobApiKey: CredentialReadiness<ApiKey>(
            status: LiveCredentialStatus.cached,
            value: cached,
          ),
        );
      }
    }

    final timestamp =
        _nowSeconds?.call() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final Map<String, String> l1Headers;
    try {
      l1Headers = await buildL1Headers(signer: signer, timestamp: timestamp);
    } on WalletSignatureRejectedException catch (e) {
      return LiveCredentialReadiness(
        clobApiKey: CredentialReadiness<ApiKey>(
          status: LiveCredentialStatus.userRejected,
          action: LiveCredentialAction.requestSignature,
          reason: e.message,
        ),
      );
    } on AuthException catch (e) {
      if (e.code == ErrorCode.unauthorized ||
          e.code == ErrorCode.notAuthorized) {
        return LiveCredentialReadiness(
          clobApiKey: CredentialReadiness<ApiKey>(
            status: LiveCredentialStatus.userRejected,
            action: LiveCredentialAction.requestSignature,
            reason: e.message,
          ),
        );
      }
      rethrow;
    }

    try {
      final created = await _clob.createApiKeyWithL1Headers(l1Headers);
      await _credentialStore?.writeClobApiKey(key, created);
      return LiveCredentialReadiness(
        clobApiKey: CredentialReadiness<ApiKey>(
          status: LiveCredentialStatus.created,
          value: created,
        ),
      );
    } on TransportException {
      try {
        final derived = await _clob.deriveApiKeyWithL1Headers(l1Headers);
        await _credentialStore?.writeClobApiKey(key, derived);
        return LiveCredentialReadiness(
          clobApiKey: CredentialReadiness<ApiKey>(
            status: LiveCredentialStatus.derived,
            value: derived,
          ),
        );
      } on TransportException catch (e) {
        return LiveCredentialReadiness(
          clobApiKey: CredentialReadiness<ApiKey>(
            status: LiveCredentialStatus.blocked,
            action: LiveCredentialAction.retry,
            reason: e.message,
          ),
        );
      }
    }
  }
}
