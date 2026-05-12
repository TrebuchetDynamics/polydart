import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/rpc/rpc.dart';
import 'package:test/test.dart';

void main() {
  group('hasCode', () {
    test('returns true when eth_getCode returns bytecode', () async {
      final client = MockClient((request) async {
        final body = _jsonBody(request);

        expect(request.url.toString(), 'http://rpc.test');
        expect(body['method'], 'eth_getCode');
        expect(body['params'], <Object>[
          '0x21999a074344610057c9b2b362332388a44502d4',
          'latest',
        ]);

        return _rpcResult('0x60016000');
      });

      final deployed = await hasCode(
        '0x21999a074344610057c9b2B362332388a44502D4',
        rpcUrl: ' http://rpc.test ',
        client: client,
      );

      expect(deployed, isTrue);
    });

    test('returns false when eth_getCode returns empty code', () async {
      final client = MockClient((_) async => _rpcResult('0x'));

      final deployed = await hasCode(
        '0x21999a074344610057c9b2B362332388a44502D4',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(deployed, isFalse);
    });

    test('uses the Polygon RPC default when rpcUrl is blank', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), polygonRpc);
        return _rpcResult('0x');
      });

      await hasCode(
        '0x21999a074344610057c9b2B362332388a44502D4',
        rpcUrl: ' ',
        client: client,
      );
    });
  });

  group('isApprovedForAll', () {
    test('calls eth_call with the ERC-1155 approval selector', () async {
      final client = MockClient((request) async {
        final body = _jsonBody(request);

        expect(body['method'], 'eth_call');
        final params = body['params'] as List<Object?>;
        expect(params[1], 'latest');
        final call = params[0] as Map<String, dynamic>;
        expect(call['to'], '0x4d97dcd97ec945f40cf65f87097ace5ea0476045');
        expect(
          call['input'],
          '0xe985e9c5'
          '00000000000000000000000021999a074344610057c9b2b362332388a44502d4'
          '000000000000000000000000ada100db00ca00073811820692005400218fce1f',
        );

        return _rpcResult(_word(1));
      });

      final approved = await isApprovedForAll(
        '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
        '0x21999a074344610057c9b2B362332388a44502D4',
        '0xAdA100Db00Ca00073811820692005400218FcE1f',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(approved, isTrue);
    });

    test('returns false for a valid false bool word', () async {
      final client = MockClient((_) async => _rpcResult(_word(0)));

      final approved = await isApprovedForAll(
        '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
        '0x21999a074344610057c9b2B362332388a44502D4',
        '0xAdA100Db00Ca00073811820692005400218FcE1f',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(approved, isFalse);
    });

    test('throws on malformed bool response', () async {
      final client = MockClient((_) async => _rpcResult(_word(2)));

      await expectLater(
        isApprovedForAll(
          '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
          '0x21999a074344610057c9b2B362332388a44502D4',
          '0xAdA100Db00Ca00073811820692005400218FcE1f',
          rpcUrl: 'http://rpc.test',
          client: client,
        ),
        throwsFormatException,
      );
    });

    test('throws on short bool response', () async {
      final client = MockClient((_) async => _rpcResult('0x01'));

      await expectLater(
        isApprovedForAll(
          '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
          '0x21999a074344610057c9b2B362332388a44502D4',
          '0xAdA100Db00Ca00073811820692005400218FcE1f',
          rpcUrl: 'http://rpc.test',
          client: client,
        ),
        throwsFormatException,
      );
    });
  });

  group('erc20Allowance', () {
    test('calls eth_call with the ERC-20 allowance selector', () async {
      final client = MockClient((request) async {
        final body = _jsonBody(request);

        expect(body['method'], 'eth_call');
        final params = body['params'] as List<Object?>;
        expect(params[1], 'latest');
        final call = params[0] as Map<String, dynamic>;
        expect(call['to'], '0xc011a7e12a19f7b1f670d46f03b03f3342e82dfb');
        expect(
          call['input'],
          '0xdd62ed3e'
          '00000000000000000000000021999a074344610057c9b2b362332388a44502d4'
          '000000000000000000000000ada100db00ca00073811820692005400218fce1f',
        );

        return _rpcResult(_word(123456789));
      });

      final allowance = await erc20Allowance(
        '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
        '0x21999a074344610057c9b2B362332388a44502D4',
        '0xAdA100Db00Ca00073811820692005400218FcE1f',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(allowance, BigInt.from(123456789));
    });

    test('throws on short uint256 response', () async {
      final client = MockClient((_) async => _rpcResult('0x01'));

      await expectLater(
        erc20Allowance(
          '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
          '0x21999a074344610057c9b2B362332388a44502D4',
          '0xAdA100Db00Ca00073811820692005400218FcE1f',
          rpcUrl: 'http://rpc.test',
          client: client,
        ),
        throwsFormatException,
      );
    });
  });

  group('erc20BalanceOf', () {
    test('calls eth_call with the ERC-20 balanceOf selector', () async {
      final client = MockClient((request) async {
        final body = _jsonBody(request);

        expect(body['method'], 'eth_call');
        final params = body['params'] as List<Object?>;
        expect(params[1], 'latest');
        final call = params[0] as Map<String, dynamic>;
        expect(call['to'], '0xc011a7e12a19f7b1f670d46f03b03f3342e82dfb');
        expect(
          call['input'],
          '0x70a08231'
          '00000000000000000000000021999a074344610057c9b2b362332388a44502d4',
        );

        return _rpcResult(_word(2500000));
      });

      final balance = await erc20BalanceOf(
        '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
        '0x21999a074344610057c9b2B362332388a44502D4',
        rpcUrl: 'http://rpc.test',
        client: client,
      );

      expect(balance, BigInt.from(2500000));
    });
  });
}

Map<String, dynamic> _jsonBody(http.Request request) {
  return jsonDecode(request.body) as Map<String, dynamic>;
}

http.Response _rpcResult(String result) {
  return http.Response(
    jsonEncode(<String, Object>{'jsonrpc': '2.0', 'id': 1, 'result': result}),
    200,
  );
}

String _word(int value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}
