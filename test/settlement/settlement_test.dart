import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polydart/src/auth/eth_hex.dart';
import 'package:polydart/src/contracts/contracts.dart' as contracts;
import 'package:polydart/src/ctf/ctf.dart' as ctf;
import 'package:polydart/src/dataapi/dataapi_types.dart';
import 'package:polydart/src/settlement/settlement.dart';
import 'package:test/test.dart';

void main() {
  const owner = '0x21999a074344610057c9b2B362332388a44502D4';
  const conditionA =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conditionB =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group('findRedeemable', () {
    test(
      'filters current Data API positions and maps settlement fields',
      () async {
        final reader = _Reader(<Position>[
          _position(
            tokenId: 'token-1',
            conditionId: conditionA,
            redeemable: true,
            negativeRisk: true,
            outcome: 'Yes',
            size: 12.5,
            title: 'Question A',
            slug: 'question-a',
            endDate: '2026-06-01T00:00:00Z',
          ),
          _position(
            tokenId: 'token-2',
            conditionId: conditionB,
            redeemable: false,
          ),
        ]);

        final rows = await findRedeemable(reader, owner);

        expect(reader.users, <String>[owner]);
        expect(rows, hasLength(1));
        expect(rows.single.tokenId, 'token-1');
        expect(rows.single.conditionId, conditionA);
        expect(rows.single.negativeRisk, isTrue);
        expect(rows.single.outcome, 'Yes');
        expect(rows.single.size, 12.5);
        expect(rows.single.title, 'Question A');
        expect(rows.single.slug, 'question-a');
        expect(rows.single.endDate, '2026-06-01T00:00:00Z');
      },
    );
  });

  group('buildRedeemCall', () {
    test(
      'builds binary adapter call with zero collateral and empty index sets',
      () {
        final call = buildRedeemCall(
          const RedeemablePosition(
            tokenId: 'token-1',
            conditionId: conditionA,
            size: 1,
            outcome: 'Yes',
          ),
        );

        expect(call.target, contracts.CtfCollateralAdapter);
        expect(call.value, '0');
        expect(
          call.data,
          ctf.redeemPositionsData(
            collateralToken: _addressZero,
            parentCollectionId: ctf.bytes32Zero,
            conditionId: conditionA,
            indexSets: const <BigInt>[],
          ),
        );
        expect(
          call.data.substring(0, 10),
          bytesToHex0x(
            keccak256Utf8(
              'redeemPositions(address,bytes32,bytes32,uint256[])',
            ).sublist(0, 4),
          ),
        );
      },
    );

    test('builds negative-risk adapter call', () {
      final call = buildRedeemCall(
        const RedeemablePosition(
          tokenId: 'token-1',
          conditionId: conditionA,
          size: 1,
          outcome: 'Yes',
          negativeRisk: true,
        ),
      );

      expect(call.target, contracts.NegRiskCtfCollateralAdapter);
      expect(call.value, '0');
    });
  });

  group('redeem batching helpers', () {
    test(
      'dedupes by condition preserving first occurrence and skipping blanks',
      () {
        final rows = <RedeemablePosition>[
          const RedeemablePosition(
            tokenId: 'blank',
            conditionId: '',
            size: 1,
            outcome: 'Yes',
          ),
          const RedeemablePosition(
            tokenId: 'first-a',
            conditionId: conditionA,
            size: 1,
            outcome: 'Yes',
          ),
          const RedeemablePosition(
            tokenId: 'first-b',
            conditionId: conditionB,
            size: 2,
            outcome: 'No',
          ),
          const RedeemablePosition(
            tokenId: 'second-a',
            conditionId: conditionA,
            size: 3,
            outcome: 'No',
          ),
        ];

        final deduped = dedupeRedeemPositionsByCondition(rows);

        expect(deduped.map((p) => p.tokenId), <String>['first-a', 'first-b']);
      },
    );

    test('chunks deduped positions by batch limit', () {
      final chunks = chunkRedeemPositionsByCondition(<RedeemablePosition>[
        for (var i = 0; i < 12; i++)
          RedeemablePosition(
            tokenId: 'token-$i',
            conditionId: '0x${i.toRadixString(16).padLeft(64, '0')}',
            size: 1,
            outcome: 'Yes',
          ),
      ]);

      expect(defaultBatchLimit, 10);
      expect(chunks, hasLength(2));
      expect(chunks.first, hasLength(10));
      expect(chunks.last, hasLength(2));
    });
  });

  group('checkReadiness', () {
    test(
      'returns ready when wallet has code, data reads, approvals, and relayer flag',
      () async {
        final reader = _Reader(<Position>[
          _position(conditionId: conditionA, redeemable: true),
        ]);
        final client = _RpcClient(<String>['0x60016000', _word(1), _word(1)]);

        final readiness = await checkReadiness(
          depositWallet: owner,
          owner: owner,
          reader: reader,
          relayerConfigured: true,
          rpcUrl: 'http://rpc.test',
          httpClient: client,
        );

        expect(readiness.ready, isTrue);
        expect(readiness.status, settlementStatusReady);
        expect(readiness.depositWalletDeployed, isTrue);
        expect(readiness.relayerConfigured, isTrue);
        expect(readiness.redeemableCount, 1);
        expect(readiness.requiredAdapters, <String>[
          contracts.CtfCollateralAdapter,
          contracts.NegRiskCtfCollateralAdapter,
        ]);
        expect(readiness.missingApprovals, isEmpty);
        expect(client.methods, <String>['eth_getCode', 'eth_call', 'eth_call']);
      },
    );

    test('returns missing approval status', () async {
      final readiness = await checkReadiness(
        depositWallet: owner,
        relayerConfigured: true,
        rpcUrl: 'http://rpc.test',
        httpClient: _RpcClient(<String>['0x60016000', _word(1), _word(0)]),
      );

      expect(readiness.ready, isFalse);
      expect(readiness.status, settlementStatusMissingAdapterApproval);
      expect(readiness.missingApprovals, <String>[
        contracts.NegRiskCtfCollateralAdapter,
      ]);
      expect(readiness.reason, contains('adapter approval'));
      expect(readiness.nextAction, isNot(contains('polygolem')));
    });

    test('returns deposit wallet not deployed before later probes', () async {
      final client = _RpcClient(<String>['0x']);

      final readiness = await checkReadiness(
        depositWallet: owner,
        relayerConfigured: true,
        rpcUrl: 'http://rpc.test',
        httpClient: client,
      );

      expect(readiness.ready, isFalse);
      expect(readiness.status, settlementStatusDepositWalletNotDeployed);
      expect(client.methods, <String>['eth_getCode']);
    });

    test('returns data API unavailable when optional reader fails', () async {
      final readiness = await checkReadiness(
        depositWallet: owner,
        reader: _FailingReader(),
        relayerConfigured: true,
        rpcUrl: 'http://rpc.test',
        httpClient: _RpcClient(<String>['0x60016000']),
      );

      expect(readiness.ready, isFalse);
      expect(readiness.status, settlementStatusDataApiUnavailable);
      expect(readiness.reason, contains('positions unavailable'));
    });

    test('requires a non-empty deposit wallet', () async {
      await expectLater(
        checkReadiness(depositWallet: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

const String _addressZero = '0x0000000000000000000000000000000000000000';

Position _position({
  String tokenId = 'token',
  String conditionId = conditionDefault,
  bool redeemable = false,
  bool negativeRisk = false,
  String outcome = 'Yes',
  double size = 1,
  String endDate = '',
  String title = '',
  String slug = '',
}) {
  return Position(
    tokenId: tokenId,
    conditionId: conditionId,
    marketId: 'market',
    side: outcome,
    avgPrice: 0,
    size: size,
    currentPrice: 0,
    unrealizedPnl: 0,
    redeemable: redeemable,
    negativeRisk: negativeRisk,
    outcome: outcome,
    endDate: endDate,
    title: title,
    slug: slug,
  );
}

const conditionDefault =
    '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

final class _Reader implements SettlementDataReader {
  _Reader(this.positions);

  final List<Position> positions;
  final List<String> users = <String>[];

  @override
  Future<List<Position>> currentPositions(String owner) async {
    users.add(owner);
    return positions;
  }
}

final class _FailingReader implements SettlementDataReader {
  @override
  Future<List<Position>> currentPositions(String owner) {
    throw StateError('positions unavailable');
  }
}

final class _RpcClient extends http.BaseClient {
  _RpcClient(List<String> results) : _results = List<String>.of(results);

  final List<String> _results;
  final List<String> methods = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    methods.add(body['method'] as String);
    final response = http.Response(
      jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'id': 1,
        'result': _results.removeAt(0),
      }),
      200,
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

String _word(int value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}
