import 'dart:convert';
import 'dart:io';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  group('golden conformance fixtures', () {
    test('builder headers match Polygolem fixture', () async {
      final fixture = await _fixture('builder_headers.json');
      expect(fixture['schema_version'], 1);
      expect(fixture['family'], 'builder-attribution-headers');
      for (final vector in fixture['vectors'] as List<dynamic>) {
        final v = (vector as Map).cast<String, dynamic>();
        final headers = buildBuilderHeaders(
          config: BuilderConfig(
            key: v['api_key'] as String,
            secret: v['secret'] as String,
            passphrase: v['passphrase'] as String,
          ),
          timestamp: v['timestamp'] as int,
          method: v['method'] as String,
          path: v['path'] as String,
          body: v['body'] as String?,
        );
        _expectHeaders(
          headers,
          (v['expected_headers'] as Map).cast<String, dynamic>(),
        );
      }
    });

    test('CLOB auth L2 headers match Polygolem fixture', () async {
      final fixture = await _fixture('clob_auth_v2.json');
      expect(fixture['schema_version'], 1);
      expect(fixture['family'], 'clob-auth-v2');
      for (final vector in fixture['l2_vectors'] as List<dynamic>) {
        final v = (vector as Map).cast<String, dynamic>();
        final headers = buildL2Headers(
          apiKey: ApiKey(
            key: v['api_key'] as String,
            secret: v['secret'] as String,
            passphrase: v['passphrase'] as String,
          ),
          timestamp: v['timestamp'] as int,
          method: v['method'] as String,
          path: v['path'] as String,
          body: v['body'] as String?,
        );
        _expectHeaders(
          headers,
          (v['expected_headers'] as Map).cast<String, dynamic>(),
        );
      }
    });

    test('CLOB auth L1 headers match fixture with local EOA signer', () async {
      final fixture = await _fixture('clob_auth_v2.json');
      for (final vector in fixture['l1_vectors'] as List<dynamic>) {
        final v = (vector as Map).cast<String, dynamic>();
        final expected = (v['expected_headers'] as Map).cast<String, dynamic>();
        final signer = LocalEoaSigner(
          privateKeyHex: v['private_key'] as String,
          chainId: v['chain_id'] as int,
        );
        final headers = await buildL1Headers(
          signer: signer,
          timestamp: v['timestamp'] as int,
          nonce: v['nonce'] as int,
        );
        _expectHeaders(headers, expected);
      }
    });

    test('Order V2 POLY_1271 struct hashes match Polygolem fixture', () async {
      final fixture = await _fixture('order_v2_poly1271.json');
      expect(fixture['schema_version'], 1);
      expect(fixture['family'], 'v2-poly1271-order-eip712');
      final input = (fixture['input'] as Map).cast<String, dynamic>();
      final eoa =
          (await _fixture(
                'clob_auth_v2.json',
              ))['l1_vectors'][0]['expected_headers']['POLY_ADDRESS']
              as String;
      final maker = makerAddressForSignatureType(
        eoaAddress: eoa,
        chainId: input['chain_id'] as int,
        signatureType: 3,
      );
      final draft = OrderV2Draft(
        salt: input['salt'].toString(),
        maker: maker,
        signer: maker,
        tokenId: input['token_id'] as String,
        makerAmount: input['maker_amount'] as String,
        takerAmount: input['taker_amount'] as String,
        side: Side.parse(input['side'] as String),
        signatureType: SignatureType.poly1271,
        timestamp: input['timestamp_millis'].toString(),
      );
      for (final vector in fixture['vectors'] as List<dynamic>) {
        final v = (vector as Map).cast<String, dynamic>();
        final structHash = bytesToHex0x(
          eip712HashStruct('Order', orderV2Fields, <String, Object?>{
            'salt': BigInt.parse(draft.salt),
            'maker': draft.maker,
            'signer': draft.signer,
            'tokenId': BigInt.parse(draft.tokenId),
            'makerAmount': BigInt.parse(draft.makerAmount),
            'takerAmount': BigInt.parse(draft.takerAmount),
            'side': BigInt.from(draft.side.code),
            'signatureType': BigInt.from(draft.signatureType.code),
            'timestamp': BigInt.parse(draft.timestamp),
            'metadata': hexToBytes(draft.metadata),
            'builder': hexToBytes(draft.builder),
          }),
        );
        expect(
          structHash,
          v['expected_struct_hash'],
          reason: v['name'] as String,
        );
      }
    });

    test('CTF calldata matches Polygolem fixture byte-for-byte', () async {
      final fixture = await _fixture('ctf_calldata.json');
      expect(fixture['schema_version'], 1);
      expect(fixture['family'], 'ctf-calldata');
      final input = (fixture['input'] as Map).cast<String, dynamic>();
      final partition = (input['partition'] as List<dynamic>)
          .map((v) => BigInt.parse(v.toString()))
          .toList(growable: false);
      final amount = BigInt.parse(input['amount'] as String);
      for (final vector in fixture['vectors'] as List<dynamic>) {
        final v = (vector as Map).cast<String, dynamic>();
        final data = switch (v['operation'] as String) {
          'split' => splitPositionData(
            collateralToken: input['collateral_token'] as String,
            parentCollectionId: input['parent_collection_id'] as String,
            conditionId: input['condition_id'] as String,
            partition: partition,
            amount: amount,
          ),
          'merge' => mergePositionsData(
            collateralToken: input['collateral_token'] as String,
            parentCollectionId: input['parent_collection_id'] as String,
            conditionId: input['condition_id'] as String,
            partition: partition,
            amount: amount,
          ),
          'redeem' => redeemPositionsData(
            collateralToken: input['collateral_token'] as String,
            parentCollectionId: input['parent_collection_id'] as String,
            conditionId: input['condition_id'] as String,
            indexSets: partition,
          ),
          final op => throw StateError('unknown operation $op'),
        };
        expect(data.substring(0, 10), v['expected_selector']);
        expect(data, v['expected_calldata'], reason: v['name'] as String);
      }
    });
  });
}

Future<Map<String, dynamic>> _fixture(String name) async {
  final raw = await File('test/fixtures/conformance/$name').readAsString();
  return (jsonDecode(raw) as Map).cast<String, dynamic>();
}

void _expectHeaders(Map<String, String> actual, Map<String, dynamic> expected) {
  for (final entry in expected.entries) {
    expect(actual[entry.key], entry.value, reason: entry.key);
  }
}
