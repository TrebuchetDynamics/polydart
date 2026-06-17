/// Builder Relayer transaction lifecycle and request/response types.
///
/// Mirrors `internal/relayer/types.go`. Wire shapes match the Polymarket
/// Builder Relayer V2 (`https://relayer-v2.polymarket.com`) — see
/// `polygolem/docs/BUILDER-AUTO.md` for the canonical onboarding flow.
library;

import 'package:meta/meta.dart';

import '../wallet/deposit_wallet_signing.dart' show WalletBatchCall;

/// Structured error returned by the Relayer API.
@immutable
final class RelayerError {
  const RelayerError({required this.error, this.code});

  factory RelayerError.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code'];
    return RelayerError(
      error: (json['error'] ?? '').toString(),
      code: rawCode is num ? rawCode.toInt() : int.tryParse('$rawCode'),
    );
  }

  final String error;
  final int? code;
}

/// Relayer transaction state machine.
enum RelayerTransactionState {
  newState('STATE_NEW'),
  executed('STATE_EXECUTED'),
  mined('STATE_MINED'),
  invalid('STATE_INVALID'),
  confirmed('STATE_CONFIRMED'),
  failed('STATE_FAILED'),
  unknown('');

  const RelayerTransactionState(this.wire);

  final String wire;

  static RelayerTransactionState fromWire(String? raw) {
    if (raw == null) return RelayerTransactionState.unknown;
    for (final s in RelayerTransactionState.values) {
      if (s.wire == raw) return s;
    }
    return RelayerTransactionState.unknown;
  }

  bool get isTerminal {
    switch (this) {
      case RelayerTransactionState.mined:
      case RelayerTransactionState.confirmed:
      case RelayerTransactionState.failed:
      case RelayerTransactionState.invalid:
        return true;
      case RelayerTransactionState.newState:
      case RelayerTransactionState.executed:
      case RelayerTransactionState.unknown:
        return false;
    }
  }

  bool get isSuccess =>
      this == RelayerTransactionState.mined ||
      this == RelayerTransactionState.confirmed;
}

/// One call within a deposit-wallet batch — the wire-shape variant of
/// [WalletBatchCall].
@immutable
final class DepositWalletCall {
  const DepositWalletCall({
    required this.target,
    required this.value,
    required this.data,
  });

  factory DepositWalletCall.fromBatchCall(WalletBatchCall c) {
    return DepositWalletCall(target: c.target, value: c.value, data: c.data);
  }

  final String target;
  final String value;
  final String data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'target': target,
    'value': value,
    'data': data,
  };

  WalletBatchCall toBatchCall() {
    return WalletBatchCall(target: target, value: value, data: data);
  }
}

/// Tracked transaction state on the relayer side.
@immutable
final class RelayerTransaction {
  const RelayerTransaction({
    required this.transactionId,
    required this.state,
    this.transactionHash = '',
    this.from = '',
    this.to = '',
    this.proxyAddress = '',
    this.data = '',
    this.nonce = '',
    this.value = '',
    this.type = '',
    this.metadata = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory RelayerTransaction.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value.toString();
      }
      return '';
    }

    return RelayerTransaction(
      transactionId: pick(const [
        'transactionID',
        'transactionId',
        'transaction_id',
      ]),
      transactionHash: pick(const ['transactionHash', 'transaction_hash']),
      from: pick(const ['from']),
      to: pick(const ['to']),
      proxyAddress: pick(const ['proxyAddress', 'proxy_address']),
      data: pick(const ['data']),
      nonce: pick(const ['nonce']),
      value: pick(const ['value']),
      state: pick(const ['state']),
      type: pick(const ['type']),
      metadata: pick(const ['metadata']),
      createdAt: pick(const ['createdAt', 'created_at']),
      updatedAt: pick(const ['updatedAt', 'updated_at']),
    );
  }

  final String transactionId;
  final String transactionHash;
  final String from;
  final String to;
  final String proxyAddress;
  final String data;
  final String nonce;
  final String value;
  final String state;
  final String type;
  final String metadata;
  final String createdAt;
  final String updatedAt;

  RelayerTransactionState get parsedState =>
      RelayerTransactionState.fromWire(state);
}

/// Response shape for `GET /nonce?address=…&type=WALLET`.
@immutable
final class NonceResponse {
  const NonceResponse({required this.nonce});

  factory NonceResponse.fromJson(Map<String, dynamic> json) {
    for (final key in const <String>['nonce', 'walletNonce', 'wallet_nonce']) {
      final value = json[key];
      if (value != null) return NonceResponse(nonce: value.toString());
    }
    return const NonceResponse(nonce: '');
  }

  factory NonceResponse.fromJsonValue(Object? json) {
    if (json is Map<String, dynamic>) return NonceResponse.fromJson(json);
    if (json is Map) {
      return NonceResponse.fromJson(json.cast<String, dynamic>());
    }
    if (json == null) return const NonceResponse(nonce: '');
    return NonceResponse(nonce: json.toString());
  }

  final String nonce;
}

/// Response shape for `GET /deployed?address=…`.
@immutable
final class DeployedResponse {
  const DeployedResponse({required this.deployed, this.address = ''});

  factory DeployedResponse.fromJson(Map<String, dynamic> json) {
    Object? pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value;
      }
      return null;
    }

    return DeployedResponse(
      deployed: _bool(pick(const ['deployed', 'isDeployed'])),
      address:
          (pick(const [
                    'address',
                    'walletAddress',
                    'wallet_address',
                    'depositWallet',
                    'deposit_wallet',
                    'proxyAddress',
                    'proxy_address',
                  ]) ??
                  '')
              .toString(),
    );
  }

  final bool deployed;
  final String address;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase() ?? '';
  return text == 'true' || text == '1';
}
