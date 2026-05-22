/// ClobAuth (L1 API key) message and header builder.
///
/// Mirrors `internal/auth/eip712.go` (BuildClobAuthTypedData + L1HeaderMap)
/// and `internal/auth/l1.go` (BuildL1HeadersFromPrivateKey). Signing is
/// delegated to a [WalletSigner].
library;

import 'dart:typed_data';

import '../errors/errors.dart';
import 'eip712.dart';
import 'eth_hex.dart';
import 'wallet_signer.dart';

const int _polymarketChainId = 137;
const String clobAuthDomainName = 'ClobAuthDomain';
const String clobAuthDomainVersion = '1';
const String clobAuthDefaultMessage =
    'This message attests that I control the given wallet';

const List<Eip712Field> _clobAuthFields = <Eip712Field>[
  Eip712Field('address', 'address'),
  Eip712Field('timestamp', 'string'),
  Eip712Field('nonce', 'uint256'),
  Eip712Field('message', 'string'),
];

/// Builds the canonical EIP-712 typed-data payload for a ClobAuth login.
///
/// The payload is the JSON-shaped map that wallet providers expect from
/// `eth_signTypedData_v4`.
Map<String, dynamic> buildClobAuthTypedData({
  required String address,
  required int chainId,
  required int timestamp,
  required int nonce,
  String message = clobAuthDefaultMessage,
}) {
  return <String, dynamic>{
    'types': <String, List<Map<String, String>>>{
      'EIP712Domain': <Map<String, String>>[
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
      ],
      'ClobAuth': <Map<String, String>>[
        {'name': 'address', 'type': 'address'},
        {'name': 'timestamp', 'type': 'string'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'message', 'type': 'string'},
      ],
    },
    'primaryType': 'ClobAuth',
    'domain': <String, Object>{
      'name': clobAuthDomainName,
      'version': clobAuthDomainVersion,
      'chainId': chainId,
    },
    'message': <String, Object>{
      'address': address,
      'timestamp': timestamp.toString(),
      'nonce': nonce,
      'message': message,
    },
  };
}

/// Computes the canonical EIP-712 digest a wallet would sign.
///
/// Useful for consumers that want to short-circuit the signer (e.g. unit
/// tests with a hash-based mock).
Uint8List hashClobAuth({
  required String address,
  required int chainId,
  required int timestamp,
  required int nonce,
  String message = clobAuthDefaultMessage,
}) {
  final domain = Eip712Domain(
    name: clobAuthDomainName,
    version: clobAuthDomainVersion,
    chainId: chainId,
  );
  return hashTypedData(
    domain: domain,
    primaryType: 'ClobAuth',
    fields: _clobAuthFields,
    message: <String, Object?>{
      'address': address,
      'timestamp': timestamp.toString(),
      'nonce': BigInt.from(nonce),
      'message': message,
    },
  );
}

/// Asks [signer] to sign the ClobAuth payload and returns the L1 headers
/// the CLOB API expects on `/auth/api-key` and `/auth/derive-api-key`.
Future<Map<String, String>> buildL1Headers({
  required WalletSigner signer,
  required int timestamp,
  int nonce = 0,
  String message = clobAuthDefaultMessage,
}) async {
  if (signer.chainId != _polymarketChainId) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'CLOB auth signing requires Polygon chainId=137',
      field: 'chainId',
    );
  }
  final typed = buildClobAuthTypedData(
    address: signer.address,
    chainId: signer.chainId,
    timestamp: timestamp,
    nonce: nonce,
    message: message,
  );
  final sig = await signer.signTypedData(typed);
  return <String, String>{
    'POLY_ADDRESS': signer.address,
    'POLY_SIGNATURE': bytesToHex0x(sig),
    'POLY_TIMESTAMP': timestamp.toString(),
    'POLY_NONCE': nonce.toString(),
  };
}
