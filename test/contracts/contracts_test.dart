import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/contracts/contracts.dart';
import 'package:test/test.dart';

void main() {
  // Parity source: polygolem 2b7cde7 pkg/contracts/contracts.go.
  group('polygonMainnet', () {
    test('returns the Polygolem contract registry', () {
      final registry = polygonMainnet();

      expect(PolygonChainID, 137);
      expect(PolygonRPC, 'https://polygon-bor-rpc.publicnode.com');
      expect(
        registry,
        const Registry(
          chainID: 137,
          depositWalletFactory: '0x00000000000Fb5C9ADea0298D729A0CB3823Cc07',
          proxyFactory: '0xaB45c5A4B0c941a2F231C04C3f49182e1A254052',
          gnosisSafeFactory: '0xaacFeEa03eb1561C4e67d661e40682Bd20E3541b',
          ctfExchangeV2: '0xE111180000d2663C0091e4f400237545B87B996B',
          negRiskExchangeV2: '0xe2222d279d744050d28e00520010520000310F59',
          negRiskAdapterV2: '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296',
          ctfCollateralAdapter: '0xAdA100Db00Ca00073811820692005400218FcE1f',
          negRiskCtfCollateralAdapter:
              '0xadA2005600Dec949baf300f4C6120000bDB6eAab',
          collateralOnramp: '0x93070a847efEf7F70739046A929D47a521F5B8ee',
          collateralOfframp: '0x2957922Eb93258b93368531d39fAcCA3B4dC5854',
          permissionedRamp: '0xebC2459Ec962869ca4c0bd1E06368272732BCb08',
          pusd: '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
          ctf: '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
          usdce: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
        ),
      );
    });

    test('serializes with Polygolem JSON field names', () {
      expect(polygonMainnet().toJson(), <String, Object>{
        'chainID': 137,
        'depositWalletFactory': DepositWalletFactory,
        'proxyFactory': ProxyFactory,
        'gnosisSafeFactory': GnosisSafeFactory,
        'ctfExchangeV2': CTFExchangeV2,
        'negRiskExchangeV2': NegRiskExchangeV2,
        'negRiskAdapterV2': NegRiskAdapterV2,
        'ctfCollateralAdapter': CtfCollateralAdapter,
        'negRiskCtfCollateralAdapter': NegRiskCtfCollateralAdapter,
        'collateralOnramp': CollateralOnramp,
        'collateralOfframp': CollateralOfframp,
        'permissionedRamp': PermissionedRamp,
        'pusd': PUSD,
        'ctf': CTF,
        'usdce': USDCE,
      });
    });
  });

  test('redeemAdapterFor selects the V2 collateral adapter', () {
    expect(redeemAdapterFor(false), CtfCollateralAdapter);
    expect(redeemAdapterFor(true), NegRiskCtfCollateralAdapter);
  });

  group('contractDeployed', () {
    test('reports deployed when eth_getCode returns bytecode', () async {
      final client = _codeClient((request) {
        expect(request['method'], 'eth_getCode');
        expect(request['params'], <String>[
          '0x21999a074344610057c9b2B362332388a44502D4',
          'latest',
        ]);
        return '0x60016000';
      });

      final status = await contractDeployed(
        ' 0x21999a074344610057c9b2B362332388a44502D4 ',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(
        status,
        const DeploymentStatus(
          address: '0x21999a074344610057c9b2B362332388a44502D4',
          deployed: true,
          source: 'polygon_eth_getCode',
        ),
      );
      expect(status.toJson(), <String, Object>{
        'address': '0x21999a074344610057c9b2B362332388a44502D4',
        'deployed': true,
        'source': 'polygon_eth_getCode',
      });
    });

    test('reports not deployed when eth_getCode returns empty code', () async {
      final client = _codeClient((_) => '0x');

      final status = await depositWalletDeployed(
        '0x21999a074344610057c9b2B362332388a44502D4',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(status.deployed, isFalse);
      expect(status.source, 'polygon_eth_getCode');
    });

    test('throws FormatException when RPC response is not an object', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(<Object>['not-an-object']), 200),
      );

      await expectLater(
        contractDeployed(
          '0x21999a074344610057c9b2B362332388a44502D4',
          rpcUrl: 'http://rpc.test',
          client: client,
        ),
        throwsFormatException,
      );
    });

    test('throws on invalid address before calling RPC', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      await expectLater(
        contractDeployed('not-an-address', client: client),
        throwsA(isA<ArgumentError>()),
      );
      expect(called, isFalse);
    });
  });
}

MockClient _codeClient(String Function(Map<String, dynamic>) resultFor) {
  return MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url, Uri.parse('http://rpc.test'));
    expect(request.headers['content-type'], contains('application/json'));

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['jsonrpc'], '2.0');
    expect(body['id'], 1);

    return http.Response(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': body['id'],
        'result': resultFor(body),
      }),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  });
}
