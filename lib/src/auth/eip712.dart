/// EIP-712 typed data hashing.
///
/// Mirrors `internal/auth/eip712.go`. Pure compute — no I/O — so it runs
/// on every Flutter target without platform plumbing.
///
/// The supported subset covers what the Polymarket protocol actually uses:
/// `string`, `address`, `bytes32`, `uint256`. Add new field types to
/// [_encodeAtomic] when a future order schema needs them.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import 'eth_hex.dart';

/// EIP-712 domain separator inputs.
@immutable
final class Eip712Domain {
  const Eip712Domain({
    required this.name,
    required this.version,
    required this.chainId,
    this.verifyingContract,
  });

  final String name;
  final String version;
  final int chainId;
  final String? verifyingContract;

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{
      'name': name,
      'version': version,
      'chainId': chainId.toString(),
    };
    if (verifyingContract != null && verifyingContract!.isNotEmpty) {
      out['verifyingContract'] = verifyingContract;
    }
    return out;
  }
}

/// One field in a typed-data struct. Type strings follow the EIP-712
/// canonical type grammar (`address`, `string`, `uint256`, …).
@immutable
final class Eip712Field {
  const Eip712Field(this.name, this.type);
  final String name;
  final String type;
}

/// Computes the canonical EIP-712 type hash for [typeName] + [fields].
///
/// Mirrors `encodeType` from polygolem. Doesn't yet support nested
/// structs; if a future schema needs them, expand this to walk the
/// dependency graph.
Uint8List eip712TypeHash(String typeName, List<Eip712Field> fields) {
  final buf = StringBuffer()
    ..write(typeName)
    ..write('(');
  for (var i = 0; i < fields.length; i++) {
    if (i > 0) buf.write(',');
    buf
      ..write(fields[i].type)
      ..write(' ')
      ..write(fields[i].name);
  }
  buf.write(')');
  return keccak256Utf8(buf.toString());
}

/// Computes `hashStruct(s)` per EIP-712.
Uint8List eip712HashStruct(
  String typeName,
  List<Eip712Field> fields,
  Map<String, Object?> values,
) {
  final typeHash = eip712TypeHash(typeName, fields);
  final encoded = _encodeFields(fields, values);
  return keccak256Bytes(concatBytes([typeHash, encoded]));
}

/// Computes the domain separator for [domain].
Uint8List eip712DomainSeparator(Eip712Domain domain) {
  final fields = <Eip712Field>[
    const Eip712Field('name', 'string'),
    const Eip712Field('version', 'string'),
    const Eip712Field('chainId', 'uint256'),
    if (domain.verifyingContract != null &&
        domain.verifyingContract!.isNotEmpty)
      const Eip712Field('verifyingContract', 'address'),
  ];
  final values = <String, Object?>{
    'name': domain.name,
    'version': domain.version,
    'chainId': BigInt.from(domain.chainId),
  };
  if (domain.verifyingContract != null &&
      domain.verifyingContract!.isNotEmpty) {
    values['verifyingContract'] = domain.verifyingContract;
  }
  return eip712HashStruct('EIP712Domain', fields, values);
}

/// Computes the final EIP-712 digest:
///
/// ```
/// keccak256(0x1901 ‖ domainSeparator ‖ hashStruct(message))
/// ```
Uint8List hashTypedData({
  required Eip712Domain domain,
  required String primaryType,
  required List<Eip712Field> fields,
  required Map<String, Object?> message,
}) {
  final domainSeparator = eip712DomainSeparator(domain);
  final messageHash = eip712HashStruct(primaryType, fields, message);
  return keccak256Bytes(
    concatBytes([
      Uint8List.fromList(<int>[0x19, 0x01]),
      domainSeparator,
      messageHash,
    ]),
  );
}

Uint8List _encodeFields(List<Eip712Field> fields, Map<String, Object?> values) {
  final parts = <List<int>>[];
  for (final f in fields) {
    final v = values[f.name];
    if (v == null) {
      throw ValidationException(
        code: ErrorCode.missingField,
        message: 'EIP-712 field ${f.name} (${f.type}) missing',
        field: f.name,
      );
    }
    parts.add(_encodeAtomic(f.type, v, fieldName: f.name));
  }
  return concatBytes(parts);
}

Uint8List _encodeAtomic(
  String type,
  Object value, {
  required String fieldName,
}) {
  switch (type) {
    case 'string':
      return keccak256Utf8(value.toString());
    case 'bytes':
      if (value is List<int>) return keccak256Bytes(value);
      if (value is String) return keccak256Bytes(hexToBytes(value));
      throw _badType(type, value, fieldName);
    case 'bytes32':
      final bytes = value is List<int> ? value : hexToBytes(value.toString());
      if (bytes.length != 32) {
        throw ValidationException(
          code: ErrorCode.invalidValue,
          message: 'bytes32 expected 32 bytes, got ${bytes.length}',
          field: fieldName,
        );
      }
      return Uint8List.fromList(bytes);
    case 'address':
      final addr = value is String ? value : value.toString();
      final clean = addr.startsWith('0x') || addr.startsWith('0X')
          ? addr.substring(2)
          : addr;
      final bytes = hexToBytes(clean);
      return leftPadBytes(bytes, length: 32);
    case 'uint256':
      return _encodeUint(value, fieldName: fieldName, label: type);
  }
  // Generic uintN (uint8, uint16, …, uint256) — all encode as 32-byte BE.
  if (_uintRegex.hasMatch(type)) {
    return _encodeUint(value, fieldName: fieldName, label: type);
  }
  // Encode bool as uint256(0|1) for forward compatibility.
  if (type == 'bool') {
    final b = value == true || value == 'true' || value == 1;
    return uint256BigEndian(b ? BigInt.one : BigInt.zero);
  }
  throw ValidationException(
    code: ErrorCode.invalidValue,
    message: 'unsupported EIP-712 field type: $type',
    field: fieldName,
  );
}

ValidationException _badType(String type, Object value, String field) =>
    ValidationException(
      code: ErrorCode.invalidValue,
      message: 'cannot encode $value as $type',
      field: field,
    );

Uint8List _encodeUint(
  Object value, {
  required String fieldName,
  required String label,
}) {
  if (value is BigInt) return uint256BigEndian(value);
  if (value is int) return uint256BigEndian(BigInt.from(value));
  if (value is String) {
    final parsed = BigInt.tryParse(value);
    if (parsed == null) throw _badType(label, value, fieldName);
    return uint256BigEndian(parsed);
  }
  throw _badType(label, value, fieldName);
}

final RegExp _uintRegex = RegExp(r'^uint\d+$');
