import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/contracts/contracts.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orderfills/orderfills.dart';
import 'package:test/test.dart';

// Parity reference: polygolem/pkg/orderfills/orderfills_test.go at 91876cf.
void main() {
  group('orderfills', () {
    test('validates required block range', () {
      expect(
        () => validateOrderFillsQuery(const OrderFillsQuery()),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('block range'),
          ),
        ),
      );

      expect(
        () => validateOrderFillsQuery(
          const OrderFillsQuery(fromBlock: 10, toBlock: 9),
        ),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('from block must be <= to block'),
          ),
        ),
      );
    });

    test('normalizes side and source', () {
      final normalized = normalizeOrderFill(
        _validFill(side: ' buy ', source: ''),
      );

      expect(normalized.side, orderFillSideBuy);
      expect(normalized.source, orderFillSourceOnchainOrderFilled);

      expect(
        () => normalizeOrderFill(_validFill(side: 'HOLD')),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('side must be BUY or SELL'),
          ),
        ),
      );

      expect(
        () => normalizeOrderFill(_validFill(source: 'clob_trades')),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains(orderFillSourceOnchainOrderFilled),
          ),
        ),
      );
    });

    test(
      'reader interface uses typed query and fills without auth fields',
      () async {
        final reader = _StubOrderFillsReader(<OrderFill>[_validFill()]);

        final fills = await reader.orderFilled(
          const OrderFillsQuery(fromBlock: 1, toBlock: 2),
        );

        expect(fills, hasLength(1));
        expect(fills.single.source, orderFillSourceOnchainOrderFilled);
        expect(fills.single.txHash, '0xtx');
      },
    );

    test('RPC reader decodes OrderFilled buy and sell logs', () async {
      final observedAt = DateTime.utc(2026, 5, 16, 12, 30);
      final methods = <String>[];
      final client = MockClient((request) async {
        final body = _jsonBody(request);
        final method = body['method'] as String;
        methods.add(method);

        switch (method) {
          case 'eth_getLogs':
            expect(request.url.toString(), 'http://polygon.invalid');
            final params = body['params'] as List<dynamic>;
            final filter = (params.single as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
            expect(filter['fromBlock'], '0xa');
            expect(filter['toBlock'], '0xa');
            expect(filter['address'], <String>[
              CTFExchangeV2.toLowerCase(),
              NegRiskExchangeV2.toLowerCase(),
            ]);
            final topics = filter['topics'] as List<dynamic>;
            final eventTopic =
                ((topics.single as List<dynamic>).single as String);
            expect(eventTopic, startsWith('0x'));
            expect(eventTopic, hasLength(66));
            return _rpcResult(<Map<String, dynamic>>[
              _orderFilledLog(
                eventTopic: eventTopic,
                blockNumber: 10,
                logIndex: 8,
                makerAssetId: '0',
                takerAssetId: '222',
                makerAmountFilled: '3000000',
                takerAmountFilled: '5000000',
              ),
              _orderFilledLog(
                eventTopic: eventTopic,
                blockNumber: 10,
                logIndex: 7,
                makerAssetId: '111',
                takerAssetId: '0',
                makerAmountFilled: '10000000',
                takerAmountFilled: '4500000',
              ),
            ]);
          case 'eth_getBlockByNumber':
            final params = body['params'] as List<dynamic>;
            expect(params, <Object>['0xa', false]);
            return _rpcResult(<String, String>{
              'timestamp': _quantity(observedAt.millisecondsSinceEpoch ~/ 1000),
            });
          default:
            fail('unexpected RPC method: $method');
        }
      });

      final reader = RpcOrderFillsReader(
        rpcUrl: 'http://polygon.invalid',
        client: client,
      );

      final fills = await reader.orderFilled(
        const OrderFillsQuery(
          fromBlock: 10,
          toBlock: 10,
          markets: <OrderFillsMarket>[
            OrderFillsMarket(
              marketId: 'market-1',
              conditionId: 'condition-1',
              yesTokenId: '111',
              noTokenId: '222',
            ),
          ],
        ),
      );

      expect(methods, <String>['eth_getLogs', 'eth_getBlockByNumber']);
      expect(fills, hasLength(2));
      expect(fills[0].side, orderFillSideBuy);
      expect(fills[0].marketId, 'market-1');
      expect(fills[0].conditionId, 'condition-1');
      expect(fills[0].tokenId, '111');
      expect(fills[0].price, '0.45');
      expect(fills[0].size, '10');
      expect(fills[0].filledAt, observedAt);
      expect(fills[1].side, orderFillSideSell);
      expect(fills[1].tokenId, '222');
      expect(fills[1].price, '0.6');
      expect(fills[1].size, '5');
    });

    test('RPC reader skips fills outside mapped markets', () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        final body = _jsonBody(request);
        final method = body['method'] as String;
        methods.add(method);
        expect(method, 'eth_getLogs');
        final filter =
            ((body['params'] as List<dynamic>).single as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        final eventTopic =
            (((filter['topics'] as List<dynamic>).single as List<dynamic>)
                    .single
                as String);
        return _rpcResult(<Map<String, dynamic>>[
          _orderFilledLog(
            eventTopic: eventTopic,
            blockNumber: 10,
            logIndex: 7,
            makerAssetId: '999',
            takerAssetId: '0',
            makerAmountFilled: '1000000',
            takerAmountFilled: '500000',
          ),
        ]);
      });

      final reader = RpcOrderFillsReader(
        rpcUrl: 'http://polygon.invalid',
        client: client,
      );

      final fills = await reader.orderFilled(
        const OrderFillsQuery(
          fromBlock: 10,
          toBlock: 10,
          markets: <OrderFillsMarket>[
            OrderFillsMarket(
              marketId: 'market-1',
              yesTokenId: '111',
              noTokenId: '222',
            ),
          ],
        ),
      );

      expect(fills, isEmpty);
      expect(methods, <String>['eth_getLogs']);
    });

    test('RPC reader returns latest block number', () async {
      final client = MockClient((request) async {
        final body = _jsonBody(request);
        expect(body['method'], 'eth_blockNumber');
        expect(body['params'], isEmpty);
        return _rpcResult('0x3039');
      });

      final reader = RpcOrderFillsReader(
        rpcUrl: 'http://polygon.invalid',
        client: client,
      );

      expect(await reader.latestBlockNumber(), 12345);
    });
  });
}

OrderFill _validFill({
  String side = orderFillSideSell,
  String source = orderFillSourceOnchainOrderFilled,
}) {
  return OrderFill(
    txHash: '0xtx',
    logIndex: 7,
    exchange: '0xexchange',
    marketId: 'market-1',
    conditionId: 'condition-1',
    tokenId: 'token-1',
    side: side,
    price: '0.42',
    size: '10',
    blockNumber: 12,
    filledAt: DateTime.utc(2026, 5, 16, 12),
    source: source,
  );
}

final class _StubOrderFillsReader implements OrderFillsReader {
  const _StubOrderFillsReader(this.fills);

  final List<OrderFill> fills;

  @override
  Future<List<OrderFill>> orderFilled(OrderFillsQuery query) async {
    validateOrderFillsQuery(query);
    return fills.map(normalizeOrderFill).toList(growable: false);
  }
}

Map<String, dynamic> _jsonBody(http.Request request) {
  final decoded = jsonDecode(request.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('RPC request body is not a JSON object');
  }
  return decoded;
}

http.Response _rpcResult(Object? result) {
  return http.Response(
    jsonEncode(<String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': result}),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _orderFilledLog({
  required String eventTopic,
  required int blockNumber,
  required int logIndex,
  required String makerAssetId,
  required String takerAssetId,
  required String makerAmountFilled,
  required String takerAmountFilled,
}) {
  return <String, dynamic>{
    'address': CTFExchangeV2,
    'topics': <String>[
      eventTopic,
      '0x${'01'.padLeft(64, '0')}',
      '0x${'02'.padLeft(64, '0')}',
      '0x${'03'.padLeft(64, '0')}',
    ],
    'data':
        '0x${<String>[makerAssetId, takerAssetId, makerAmountFilled, takerAmountFilled, '0'].map(_word).join()}',
    'blockNumber': _quantity(blockNumber),
    'transactionHash': '0x${'ab' * 32}',
    'logIndex': _quantity(logIndex),
  };
}

String _quantity(int value) => '0x${value.toRadixString(16)}';

String _word(String value) {
  return BigInt.parse(value).toRadixString(16).padLeft(64, '0');
}
