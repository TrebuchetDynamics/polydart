/// Ethereum hex / address utilities used by the auth and order modules.
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:pointycastle/digests/keccak.dart';

import '../errors/errors.dart';

/// 0x-prefixed lowercase hex of [bytes].
String bytesToHex0x(List<int> bytes) => '0x${hex.encode(bytes)}';

/// Bare lowercase hex (no `0x` prefix).
String bytesToHex(List<int> bytes) => hex.encode(bytes);

/// Removes a lowercase or uppercase `0x` prefix when present.
String stripHexPrefix(String input) {
  final clean = input.trim();
  return clean.startsWith('0x') || clean.startsWith('0X')
      ? clean.substring(2)
      : clean;
}

/// Decodes a 0x-prefixed or bare hex string to bytes.
///
/// Accepts mixed-case input. Throws [ValidationException] on malformed
/// (non-hex) input.
Uint8List hexToBytes(String input) {
  var clean = input.trim();
  if (clean.startsWith('0x') || clean.startsWith('0X')) {
    clean = clean.substring(2);
  }
  if (clean.isEmpty) return Uint8List(0);
  if (clean.length.isOdd) clean = '0$clean';
  try {
    return Uint8List.fromList(hex.decode(clean));
  } on FormatException catch (e) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid hex: $input',
      cause: e,
    );
  }
}

/// Returns a lowercase, 0x-prefixed, 40-hex-char Ethereum address.
///
/// Throws [ValidationException] for inputs that can't fit a 20-byte
/// address (wrong length / non-hex chars).
String normalizeAddress(String address) {
  final cleanRaw = address.trim();
  var clean = cleanRaw.startsWith('0x') || cleanRaw.startsWith('0X')
      ? cleanRaw.substring(2)
      : cleanRaw;
  if (clean.length > 40) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'address too long',
    );
  }
  // Validate hex.
  for (final code in clean.codeUnits) {
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLower = code >= 0x61 && code <= 0x66;
    final isUpper = code >= 0x41 && code <= 0x46;
    if (!isDigit && !isLower && !isUpper) {
      throw ValidationException(
        code: ErrorCode.invalidValue,
        message: 'invalid address: $address',
      );
    }
  }
  clean = clean.toLowerCase().padLeft(40, '0');
  return '0x$clean';
}

/// Keccak-256 of [bytes] (32-byte digest).
Uint8List keccak256Bytes(List<int> bytes) {
  final digest = KeccakDigest(256);
  return digest.process(Uint8List.fromList(bytes));
}

/// Keccak-256 of UTF-8 [text].
Uint8List keccak256Utf8(String text) {
  return keccak256Bytes(utf8.encode(text));
}

/// Concatenates [parts] into a single Uint8List.
Uint8List concatBytes(Iterable<List<int>> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  var pos = 0;
  for (final p in parts) {
    out.setRange(pos, pos + p.length, p);
    pos += p.length;
  }
  return out;
}

/// Encodes a non-negative integer as a 32-byte big-endian buffer
/// (uint256 ABI form).
Uint8List uint256BigEndian(BigInt value) {
  if (value.isNegative) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'uint256 cannot be negative',
    );
  }
  final out = Uint8List(32);
  var n = value;
  for (var i = 31; i >= 0; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n = n >> 8;
    if (n == BigInt.zero) break;
  }
  return out;
}

/// Left-pads [bytes] with leading zeros to [length] (default 32).
Uint8List leftPadBytes(List<int> bytes, {int length = 32}) {
  if (bytes.length >= length) return Uint8List.fromList(bytes);
  final out = Uint8List(length);
  out.setRange(length - bytes.length, length, bytes);
  return out;
}
