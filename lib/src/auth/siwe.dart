/// Sign-In With Ethereum (EIP-4361) message construction and bearer-token
/// packaging for the Polymarket gamma-api login flow.
///
/// Mirrors `internal/auth/siwe.go` in polygolem. The Polymarket frontend
/// uses viem's `createSiweMessage` plus a `useSignIn` mutation that ships
/// the same fields as `base64(JSON(fields) + ":::" + signature)` to
/// `gamma-api.polymarket.com/login`. See
/// `docs/HEADLESS-BUILDER-KEYS-INVESTIGATION.md`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'eth_hex.dart' show keccak256Utf8;

/// Polymarket SIWE constants. Matches the strings the frontend bundle
/// sends today; if Polymarket changes them upstream we'll need to update
/// these.
const String polymarketSIWEDomain = 'polymarket.com';
const String polymarketSIWEStatement =
    'Welcome to Polymarket! Sign to connect.';
const String polymarketSIWEURI = 'https://polymarket.com';
const String siweVersion = '1';

/// Structured EIP-4361 fields. Field names match the JSON shape that ships
/// to /login as the bearer payload.
@immutable
final class SIWEMessage {
  const SIWEMessage({
    required this.domain,
    required this.address,
    required this.statement,
    required this.uri,
    required this.version,
    required this.chainId,
    required this.nonce,
    required this.issuedAt,
    required this.expirationTime,
  });

  final String domain;
  final String address;
  final String statement;
  final String uri;
  final String version;
  final int chainId;
  final String nonce;
  final String issuedAt;
  final String expirationTime;

  /// Renders the message in EIP-4361 plaintext form. This is the blob
  /// that gets personal_sign-hashed.
  @override
  String toString() {
    final b = StringBuffer()
      ..write('$domain wants you to sign in with your Ethereum account:\n')
      ..write('$address\n\n');
    if (statement.isNotEmpty) {
      b
        ..write(statement)
        ..write('\n\n');
    }
    b
      ..write('URI: $uri\n')
      ..write('Version: $version\n')
      ..write('Chain ID: $chainId\n')
      ..write('Nonce: $nonce\n')
      ..write('Issued At: $issuedAt');
    if (expirationTime.isNotEmpty) {
      b
        ..write('\nExpiration Time: ')
        ..write(expirationTime);
    }
    return b.toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'domain': domain,
      'address': address,
      'statement': statement,
      'uri': uri,
      'version': version,
      'chainId': chainId,
      'nonce': nonce,
      'issuedAt': issuedAt,
      'expirationTime': expirationTime,
    };
  }
}

/// Builds a Polymarket-shaped [SIWEMessage] with the canonical domain,
/// statement, and URI. [address] is checksummed; [nonce] comes from
/// `GET gamma-api.polymarket.com/nonce`. The expiration window defaults
/// to 7 days unless [now] is overridden in tests.
SIWEMessage buildPolymarketSIWE({
  required String address,
  required String nonce,
  required int chainId,
  DateTime? now,
}) {
  final ts = (now ?? DateTime.now().toUtc()).toUtc();
  final exp = ts.add(const Duration(days: 7));
  return SIWEMessage(
    domain: polymarketSIWEDomain,
    address: toEIP55Checksum(address),
    statement: polymarketSIWEStatement,
    uri: polymarketSIWEURI,
    version: siweVersion,
    chainId: chainId,
    nonce: nonce,
    issuedAt: _rfc3339(ts),
    expirationTime: _rfc3339(exp),
  );
}

/// Assembles the Polymarket /login bearer token:
/// `base64( JSON(fields) + ":::" + 0x-prefixed signature hex )`.
String buildSIWEBearerToken(SIWEMessage msg, Uint8List signature) {
  final fieldsJson = jsonEncode(msg.toJson());
  final sigHex = '0x${_hex(signature)}';
  final combined = '$fieldsJson:::$sigHex';
  return base64.encode(utf8.encode(combined));
}

/// Returns the EIP-55 mixed-case checksum form of [address]. Throws
/// [ArgumentError] for malformed input.
String toEIP55Checksum(String address) {
  var clean = address.trim();
  if (clean.startsWith('0x') || clean.startsWith('0X')) {
    clean = clean.substring(2);
  }
  if (clean.length != 40) {
    throw ArgumentError(
      'address must be 40 hex chars (got ${clean.length}): $address',
    );
  }
  final lower = clean.toLowerCase();
  final hash = keccak256Utf8(lower);
  // Each byte of the hash maps to two address chars; for each address
  // hex char, look at the corresponding hash nibble. If the address
  // char is a-f and the nibble is >= 8, uppercase it.
  final out = StringBuffer('0x');
  for (var i = 0; i < lower.length; i++) {
    final c = lower.codeUnitAt(i);
    final hashByte = hash[i ~/ 2];
    final nibble = (i.isEven) ? (hashByte >> 4) & 0xf : hashByte & 0xf;
    if (c >= 0x61 && c <= 0x66 && nibble >= 8) {
      // uppercase a..f
      out.writeCharCode(c - 0x20);
    } else {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

String _rfc3339(DateTime t) {
  final u = t.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}T'
      '${u.hour.toString().padLeft(2, '0')}:'
      '${u.minute.toString().padLeft(2, '0')}:'
      '${u.second.toString().padLeft(2, '0')}Z';
}

String _hex(Uint8List bytes) {
  const chars = '0123456789abcdef';
  final out = StringBuffer();
  for (final b in bytes) {
    out
      ..writeCharCode(chars.codeUnitAt((b >> 4) & 0xf))
      ..writeCharCode(chars.codeUnitAt(b & 0xf));
  }
  return out.toString();
}
