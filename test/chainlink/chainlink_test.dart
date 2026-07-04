import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ChainlinkPriceFeedClient calls latestRoundData and decodes price',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.toString(), 'http://rpc.test');
        expect(body['method'], 'eth_call');
        final params = body['params'] as List<dynamic>;
        final call = params.first as Map<String, dynamic>;
        expect(call['to'], polygonChainlinkUsdFeeds['BTC']);
        expect(call['input'], chainlinkLatestRoundDataSelector);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'result': _roundData(70123.45, 1760000000),
          }),
          200,
        );
      });

      final price = await ChainlinkPriceFeedClient(
        httpClient: client,
        rpcUrl: 'http://rpc.test',
      ).price('btc');

      expect(price.hasError, isFalse);
      expect(price.asset, 'BTC');
      expect(price.priceUsd, 70123.45);
      expect(
        price.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
      );
    },
  );

  test('decodeLatestRoundData rejects short responses', () {
    final price = decodeLatestRoundData('BTC', '0x1234');
    expect(price.errorCode, 'response_too_short');
  });
}

String _roundData(double priceUsd, int updatedAtSecs) {
  final answer = BigInt.from((priceUsd * 1e8).round());
  final words = <BigInt>[
    BigInt.one,
    answer,
    BigInt.zero,
    BigInt.from(updatedAtSecs),
    BigInt.one,
  ];
  return '0x${words.map(_word).join()}';
}

String _word(BigInt value) => value.toRadixString(16).padLeft(64, '0');
