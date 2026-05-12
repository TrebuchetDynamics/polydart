import 'package:polydart/src/auth/eth_hex.dart';
import 'package:polydart/src/ctf/ctf.dart';
import 'package:test/test.dart';

void main() {
  group('CTF calldata', () {
    const conditionId =
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    final partition = <BigInt>[BigInt.one, BigInt.two];
    final amount = BigInt.from(1000000);

    test('splitPositionData encodes selector and dynamic partition', () {
      final data = splitPositionData(
        collateralToken: usdcAddress,
        parentCollectionId: bytes32Zero,
        conditionId: conditionId,
        partition: partition,
        amount: amount,
      );

      expect(
        data.substring(0, 10),
        bytesToHex0x(
          keccak256Utf8(
            'splitPosition(address,bytes32,bytes32,uint256[],uint256)',
          ).sublist(0, 4),
        ),
      );
      expect(data, contains(conditionId.substring(2)));
      expect(data, contains(amount.toRadixString(16).padLeft(64, '0')));
      expect(data, endsWith('1'.padLeft(64, '0') + '2'.padLeft(64, '0')));
    });

    test('mergePositionsData encodes selector', () {
      final data = mergePositionsData(
        collateralToken: usdcAddress,
        parentCollectionId: bytes32Zero,
        conditionId: conditionId,
        partition: partition,
        amount: amount,
      );

      expect(
        data.substring(0, 10),
        bytesToHex0x(
          keccak256Utf8(
            'mergePositions(address,bytes32,bytes32,uint256[],uint256)',
          ).sublist(0, 4),
        ),
      );
    });

    test('redeemPositionsData encodes selector and index sets', () {
      final data = redeemPositionsData(
        collateralToken: usdcAddress,
        parentCollectionId: bytes32Zero,
        conditionId: conditionId,
        indexSets: partition,
      );

      expect(
        data.substring(0, 10),
        bytesToHex0x(
          keccak256Utf8(
            'redeemPositions(address,bytes32,bytes32,uint256[])',
          ).sublist(0, 4),
        ),
      );
      expect(data, endsWith('1'.padLeft(64, '0') + '2'.padLeft(64, '0')));
    });
  });

  group('CTF ids', () {
    test('positionId hashes collateral bytes and collection id', () {
      const collectionId =
          '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

      final expected = bytesToHex0x(
        keccak256Bytes([
          ...hexToBytes(usdcAddress),
          ...hexToBytes(collectionId),
        ]),
      );

      expect(positionId(usdcAddress, collectionId), expected);
    });

    test('collectionId hashes parent, condition, and minimal index bytes', () {
      const conditionId =
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      final expected = bytesToHex0x(
        keccak256Bytes([
          ...hexToBytes(bytes32Zero),
          ...hexToBytes(conditionId),
          1,
        ]),
      );

      expect(collectionId(bytes32Zero, conditionId, BigInt.one), expected);
    });
  });
}
