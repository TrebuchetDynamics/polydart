/// Public signing seams and optional remote-custody adapters.
///
/// Mirrors polygolem `pkg/signers`, `pkg/signers/http`, `pkg/signers/kms`,
/// and `pkg/signers/turnkey` while supporting Polydart's normal app path
/// (EOA signer with ReownWallet or equivalent wallet-provider adapter) plus
/// explicit private-key EOA signing for CLI tests, headless tools, alpha/test
/// apps, server automation, and paper-mode trials.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart' show PrivateKeyParameter;
import 'package:pointycastle/ecc/api.dart'
    show ECDomainParameters, ECPrivateKey, ECPoint, ECSignature;
import 'package:pointycastle/digests/sha256.dart' show SHA256Digest;
import 'package:pointycastle/macs/hmac.dart' show HMac;
import 'package:pointycastle/signers/ecdsa_signer.dart' show ECDSASigner;

import '../auth/eip712.dart' show Eip712Domain, Eip712Field, hashTypedData;
import '../auth/eth_hex.dart'
    show bytesToHex0x, hexToBytes, keccak256Bytes, leftPadBytes;
import '../auth/siwe.dart' show toEIP55Checksum;
import '../auth/wallet_signer.dart' show WalletSigner;
import '../wallet/deposit_wallet_signing.dart'
    show WalletBatchCall, hashWalletBatchTypedData;

const Duration defaultRemoteSignerTimeout = Duration(seconds: 10);

/// Stable public signing seam for SDK consumers.
abstract interface class PolydartSigner {
  String get address;
  int get chainId;

  Future<Uint8List> signHash(Uint8List hash);

  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  });

  Future<Uint8List> signEip712(Map<String, dynamic> typedData);
}

/// Explicit local private-key EOA signer for tests, headless tools, and
/// server-side users who choose local custody.
final class LocalEoaSigner implements WalletSigner, PolydartSigner {
  LocalEoaSigner({required String privateKeyHex, required this.chainId})
    : _domain = ECDomainParameters('secp256k1'),
      _privateKey = ECPrivateKey(
        _privateScalar(privateKeyHex),
        ECDomainParameters('secp256k1'),
      ) {
    _publicPoint = (_domain.G * _privateKey.d)!;
    final uncompressed = _publicPoint.getEncoded(false);
    final hash = keccak256Bytes(uncompressed.sublist(1));
    address = toEIP55Checksum(bytesToHex0x(hash.sublist(12)));
  }

  final ECDomainParameters _domain;
  final ECPrivateKey _privateKey;
  late final ECPoint _publicPoint;

  @override
  late final String address;

  @override
  final int chainId;

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    final prefix = ascii.encode(
      '\x19Ethereum Signed Message:\n${message.length}',
    );
    return _signDigest(
      keccak256Bytes(Uint8List.fromList(<int>[...prefix, ...message])),
    );
  }

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async =>
      _signDigest(_hashTypedDataMap(typedData));

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    _requireLength(hash, 32, 'hash');
    return _signDigest(hash);
  }

  @override
  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  }) async {
    _requireLength(domainHash, 32, 'domainHash');
    _requireLength(structHash, 32, 'structHash');
    return _signDigest(
      keccak256Bytes(
        Uint8List.fromList(<int>[0x19, 0x01, ...domainHash, ...structHash]),
      ),
    );
  }

  @override
  Future<Uint8List> signEip712(Map<String, dynamic> typedData) =>
      signTypedData(typedData);

  Uint8List _signDigest(Uint8List digest) {
    _requireLength(digest, 32, 'digest');
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(_privateKey));
    final signature = (signer.generateSignature(digest) as ECSignature)
        .normalize(_domain);
    final recoveryId = _recoveryId(signature, digest);
    return Uint8List.fromList(<int>[
      ..._bigInt32(signature.r),
      ..._bigInt32(signature.s),
      27 + recoveryId,
    ]);
  }

  int _recoveryId(ECSignature signature, Uint8List digest) {
    final encodedPublic = _publicPoint.getEncoded(false);
    final e = _decodeBigInt(digest);
    for (var recId = 0; recId < 4; recId += 1) {
      final candidate = _recoverPublicPoint(signature, e, recId);
      if (candidate != null &&
          _listEquals(candidate.getEncoded(false), encodedPublic)) {
        return recId;
      }
    }
    throw StateError('could not recover ECDSA public key');
  }

  ECPoint? _recoverPublicPoint(ECSignature signature, BigInt e, int recId) {
    final n = _domain.n;
    final x = signature.r + BigInt.from(recId >> 1) * n;
    if (x >= _secp256k1P) return null;
    final rPoint = _domain.curve.decompressPoint(recId & 1, x);
    if (!((rPoint * n)?.isInfinity ?? false)) return null;
    final rInv = signature.r.modInverse(n);
    final eNeg = (-e) % n;
    return ((rPoint * ((signature.s * rInv) % n))! +
        (_domain.G * ((eNeg * rInv) % n)))!;
  }
}

/// Wallet-mediated signer adapter.
final class WalletMediatedSigner implements PolydartSigner {
  const WalletMediatedSigner(this.wallet);

  final WalletSigner wallet;

  @override
  String get address => wallet.address;

  @override
  int get chainId => wallet.chainId;

  @override
  Future<Uint8List> signHash(Uint8List hash) {
    _requireLength(hash, 32, 'hash');
    return wallet.personalSign(Uint8List.fromList(hash));
  }

  @override
  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  }) {
    _requireLength(domainHash, 32, 'domainHash');
    _requireLength(structHash, 32, 'structHash');
    return signHash(Uint8List.fromList(<int>[...domainHash, ...structHash]));
  }

  @override
  Future<Uint8List> signEip712(Map<String, dynamic> typedData) =>
      wallet.signTypedData(typedData);
}

final class HttpSignerConfig {
  const HttpSignerConfig({
    required this.url,
    required this.bearerToken,
    required this.address,
    required this.chainId,
    this.timeout = defaultRemoteSignerTimeout,
    this.client,
  });

  final String url;
  final String bearerToken;
  final String address;
  final int chainId;
  final Duration timeout;
  final http.Client? client;
}

/// HTTP-backed signer for operator-owned local/KMS/custody bridges.
final class HttpSigner implements PolydartSigner {
  HttpSigner(HttpSignerConfig config)
    : _config = _validateHttpConfig(config),
      _client = config.client ?? http.Client();

  final HttpSignerConfig _config;
  final http.Client _client;

  @override
  String get address => _config.address;

  @override
  int get chainId => _config.chainId;

  @override
  Future<Uint8List> signHash(Uint8List hash) async {
    _requireLength(hash, 32, 'hash');
    final response = await _post(<String, Object?>{
      'operation': 'sign_hash',
      'address': address,
      'chain_id': chainId,
      'hash': bytesToHex0x(hash),
    });
    return _decodeHexBytes(
      response['signature']?.toString() ?? '',
      65,
      'signature',
    );
  }

  @override
  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  }) async {
    _requireLength(domainHash, 32, 'domainHash');
    _requireLength(structHash, 32, 'structHash');
    final response = await _post(<String, Object?>{
      'operation': 'sign_typed_data_hashes',
      'address': address,
      'chain_id': chainId,
      'domain_hash': bytesToHex0x(domainHash),
      'struct_hash': bytesToHex0x(structHash),
    });
    return _decodeHexBytes(
      _firstNonEmpty(<String?>[
        response['result']?.toString(),
        response['signature']?.toString(),
      ]),
      32,
      'typed-data result',
    );
  }

  @override
  Future<Uint8List> signEip712(Map<String, dynamic> typedData) async {
    final response = await _post(<String, Object?>{
      'operation': 'sign_eip712',
      'address': address,
      'chain_id': chainId,
      'typed_data': typedData,
    });
    return _decodeHexBytes(
      response['signature']?.toString() ?? '',
      65,
      'signature',
    );
  }

  /// Closes the underlying HTTP client used by this signer.
  void close() => _client.close();

  Future<Map<String, Object?>> _post(Map<String, Object?> payload) async {
    final uri = Uri.parse(_config.url);
    final future = _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${_config.bearerToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final response = await future.timeout(_config.timeout);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StateError('remote signer returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('decode remote signer response');
    }
    return decoded.cast<String, Object?>();
  }
}

abstract interface class KmsSignerBackend {
  Future<Uint8List> signHash(String keyId, Uint8List hash);
  Future<Uint8List> signTypedDataHashes(
    String keyId,
    Uint8List domainHash,
    Uint8List structHash,
  );
  Future<Uint8List> signEip712(String keyId, Map<String, dynamic> typedData);
}

final class KmsSignerConfig {
  const KmsSignerConfig({
    required this.keyId,
    required this.address,
    required this.chainId,
    required this.backend,
    this.timeout = defaultRemoteSignerTimeout,
  });

  final String keyId;
  final String address;
  final int chainId;
  final KmsSignerBackend backend;
  final Duration timeout;
}

/// KMS-style adapter boundary. No provider SDK is imported by Polydart.
final class KmsSigner implements PolydartSigner {
  KmsSigner(KmsSignerConfig config) : _config = _validateKmsConfig(config);

  final KmsSignerConfig _config;

  @override
  String get address => _config.address;

  @override
  int get chainId => _config.chainId;

  @override
  Future<Uint8List> signHash(Uint8List hash) {
    _requireLength(hash, 32, 'hash');
    return _config.backend
        .signHash(_config.keyId, hash)
        .timeout(_config.timeout);
  }

  @override
  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  }) {
    _requireLength(domainHash, 32, 'domainHash');
    _requireLength(structHash, 32, 'structHash');
    return _config.backend
        .signTypedDataHashes(_config.keyId, domainHash, structHash)
        .timeout(_config.timeout);
  }

  @override
  Future<Uint8List> signEip712(Map<String, dynamic> typedData) => _config
      .backend
      .signEip712(_config.keyId, typedData)
      .timeout(_config.timeout);
}

abstract interface class TurnkeySignerBackend {
  Future<Uint8List> signHash(
    String organizationId,
    String walletId,
    String address,
    Uint8List hash,
  );
  Future<Uint8List> signTypedDataHashes(
    String organizationId,
    String walletId,
    String address,
    Uint8List domainHash,
    Uint8List structHash,
  );
  Future<Uint8List> signEip712(
    String organizationId,
    String walletId,
    String address,
    Map<String, dynamic> typedData,
  );
}

final class TurnkeySignerConfig {
  const TurnkeySignerConfig({
    required this.organizationId,
    required this.walletId,
    required this.address,
    required this.chainId,
    required this.backend,
    this.timeout = defaultRemoteSignerTimeout,
  });

  final String organizationId;
  final String walletId;
  final String address;
  final int chainId;
  final TurnkeySignerBackend backend;
  final Duration timeout;
}

/// Turnkey-style adapter seam. Callers own Turnkey SDK/API credentials.
final class TurnkeySigner implements PolydartSigner {
  TurnkeySigner(TurnkeySignerConfig config)
    : _config = _validateTurnkeyConfig(config);

  final TurnkeySignerConfig _config;

  @override
  String get address => _config.address;

  @override
  int get chainId => _config.chainId;

  @override
  Future<Uint8List> signHash(Uint8List hash) {
    _requireLength(hash, 32, 'hash');
    return _config.backend
        .signHash(_config.organizationId, _config.walletId, address, hash)
        .timeout(_config.timeout);
  }

  @override
  Future<Uint8List> signTypedDataHashes({
    required Uint8List domainHash,
    required Uint8List structHash,
  }) {
    _requireLength(domainHash, 32, 'domainHash');
    _requireLength(structHash, 32, 'structHash');
    return _config.backend
        .signTypedDataHashes(
          _config.organizationId,
          _config.walletId,
          address,
          domainHash,
          structHash,
        )
        .timeout(_config.timeout);
  }

  @override
  Future<Uint8List> signEip712(Map<String, dynamic> typedData) => _config
      .backend
      .signEip712(_config.organizationId, _config.walletId, address, typedData)
      .timeout(_config.timeout);
}

String redactSignerSecret(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= 8) return '***';
  return '${trimmed.substring(0, 4)}…${trimmed.substring(trimmed.length - 4)}';
}

HttpSignerConfig _validateHttpConfig(HttpSignerConfig config) {
  if (config.url.trim().isEmpty) {
    throw ArgumentError('remote signer URL is required');
  }
  if (config.bearerToken.trim().isEmpty) {
    throw ArgumentError('remote signer bearer token is required');
  }
  if (config.timeout <= Duration.zero) {
    return HttpSignerConfig(
      url: config.url,
      bearerToken: config.bearerToken,
      address: config.address,
      chainId: config.chainId,
      timeout: defaultRemoteSignerTimeout,
      client: config.client,
    );
  }
  return config;
}

KmsSignerConfig _validateKmsConfig(KmsSignerConfig config) {
  if (config.keyId.trim().isEmpty) {
    throw ArgumentError('kms signer key id is required');
  }
  return config.timeout <= Duration.zero
      ? KmsSignerConfig(
          keyId: config.keyId,
          address: config.address,
          chainId: config.chainId,
          backend: config.backend,
        )
      : config;
}

TurnkeySignerConfig _validateTurnkeyConfig(TurnkeySignerConfig config) {
  if (config.organizationId.trim().isEmpty) {
    throw ArgumentError('turnkey organization id is required');
  }
  if (config.walletId.trim().isEmpty) {
    throw ArgumentError('turnkey wallet id is required');
  }
  if (config.address.trim().isEmpty) {
    throw ArgumentError('turnkey address is required');
  }
  return config.timeout <= Duration.zero
      ? TurnkeySignerConfig(
          organizationId: config.organizationId,
          walletId: config.walletId,
          address: config.address,
          chainId: config.chainId,
          backend: config.backend,
        )
      : config;
}

void _requireLength(Uint8List value, int want, String label) {
  if (value.length != want) {
    throw ArgumentError('$label length=${value.length} want $want');
  }
}

Uint8List _decodeHexBytes(String value, int wantLen, String label) {
  try {
    final decoded = Uint8List.fromList(hexToBytes(value));
    _requireLength(decoded, wantLen, label);
    return decoded;
  } on Object catch (error) {
    throw FormatException('invalid remote signer $label hex: $error');
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return '';
}

final BigInt _secp256k1P = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
  radix: 16,
);

BigInt _privateScalar(String privateKeyHex) {
  final scalar = _decodeBigInt(hexToBytes(privateKeyHex));
  if (scalar <= BigInt.zero) {
    throw ArgumentError('private key must be a positive secp256k1 scalar');
  }
  final n = ECDomainParameters('secp256k1').n;
  if (scalar >= n) {
    throw ArgumentError('private key is outside secp256k1 range');
  }
  return scalar;
}

Uint8List _hashTypedDataMap(Map<String, dynamic> typedData) {
  final domainJson = (typedData['domain'] as Map).cast<String, dynamic>();
  final primaryType = typedData['primaryType'].toString();
  if (primaryType == 'Batch' && domainJson['name'] == 'DepositWallet') {
    return _hashDepositWalletBatchTypedData(typedData, domainJson);
  }
  final allTypes = (typedData['types'] as Map).cast<String, dynamic>();
  final rawFields = (allTypes[primaryType] as List<dynamic>);
  final fields = rawFields
      .map((raw) {
        final field = (raw as Map).cast<String, dynamic>();
        return Eip712Field(field['name'].toString(), field['type'].toString());
      })
      .toList(growable: false);
  final message = (typedData['message'] as Map).cast<String, dynamic>();
  return hashTypedData(
    domain: Eip712Domain(
      name: domainJson['name']?.toString() ?? '',
      version: domainJson['version']?.toString() ?? '',
      chainId: int.parse(domainJson['chainId'].toString()),
      verifyingContract: domainJson['verifyingContract']?.toString(),
    ),
    primaryType: primaryType,
    fields: fields,
    message: <String, Object?>{
      for (final field in fields)
        field.name: _coerceTypedDataValue(field.type, message[field.name]),
    },
  );
}

Uint8List _hashDepositWalletBatchTypedData(
  Map<String, dynamic> typedData,
  Map<String, dynamic> domainJson,
) {
  final message = (typedData['message'] as Map).cast<String, dynamic>();
  final rawCalls = (message['calls'] as List<dynamic>);
  return hashWalletBatchTypedData(
    walletAddress: message['wallet'].toString(),
    nonce: message['nonce'].toString(),
    deadline: message['deadline'].toString(),
    calls: rawCalls
        .map((raw) {
          final call = (raw as Map).cast<String, dynamic>();
          return WalletBatchCall(
            target: call['target'].toString(),
            value: call['value'].toString(),
            data: call['data'].toString(),
          );
        })
        .toList(growable: false),
    chainId: int.parse(domainJson['chainId'].toString()),
  );
}

Object? _coerceTypedDataValue(String type, Object? value) {
  if (value == null) return null;
  if (type.startsWith('uint')) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    return BigInt.parse(value.toString());
  }
  if (type == 'bytes' || type == 'bytes32') {
    if (value is List<int>) return value;
    return hexToBytes(value.toString());
  }
  return value;
}

Uint8List _bigInt32(BigInt value) =>
    Uint8List.fromList(leftPadBytes(_unsignedBigIntBytes(value), length: 32));

Uint8List _unsignedBigIntBytes(BigInt value) {
  if (value == BigInt.zero) return Uint8List(0);
  final bytes = <int>[];
  var current = value;
  while (current > BigInt.zero) {
    bytes.insert(0, (current & BigInt.from(0xff)).toInt());
    current >>= 8;
  }
  return Uint8List.fromList(bytes);
}

BigInt _decodeBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
