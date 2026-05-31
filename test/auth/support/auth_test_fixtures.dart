import 'dart:typed_data';

const canonicalEoaAddress = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';
const canonicalDepositWallet = '0xfd5041047be8c192c725a66228f141196fa3cf9c';
const canonicalSiweAddress = '0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f';
const canonicalHmacSecret = 'c2VjcmV0';

Uint8List deterministicSignature([int Function(int index)? byteAt]) =>
    Uint8List.fromList(List<int>.generate(65, (i) => byteAt?.call(i) ?? i));
