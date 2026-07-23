import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/bridge/bridge_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

BridgeClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
  return BridgeClient(
    transport: HttpTransport(
      config: const TransportConfig(baseUrl: defaultBridgeBaseUrl, retryMax: 0),
      inner: MockClient(handler),
    ),
  );
}

Map<String, dynamic> _body(http.BaseRequest req) {
  final body = (req as http.Request).body;
  return jsonDecode(body) as Map<String, dynamic>;
}

void main() {
  test('uses the production Bridge base URL by default', () {
    expect(defaultBridgeBaseUrl, 'https://bridge.polymarket.com');
  });

  group('createDepositAddress', () {
    test('POSTs /deposit with address and decodes response', () async {
      http.BaseRequest? captured;
      final client = _client((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'address': <String, dynamic>{
              'evm': '0xevm',
              'svm': 'svm-address',
              'btc': 'bc1address',
            },
            'note': 'send only supported assets',
          }),
          200,
        );
      });

      final response = await client.createDepositAddress('0xaccount');

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/deposit');
      expect(_body(captured!), <String, dynamic>{'address': '0xaccount'});
      expect(response.address.evm, '0xevm');
      expect(response.address.svm, 'svm-address');
      expect(response.address.btc, 'bc1address');
      expect(response.note, 'send only supported assets');
    });
  });

  group('createWithdrawalAddress', () {
    test('POSTs /withdraw and decodes the pUSD destination', () async {
      http.BaseRequest? captured;
      final client = _client((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'address': <String, dynamic>{
              'evm': '0xwithdraw',
              'svm': 'svm-withdraw',
              'btc': 'bc1withdraw',
            },
            'note': 'send pUSD to the address for the source chain',
          }),
          201,
        );
      });

      final response = await client.createWithdrawalAddress(
        const CreateWithdrawalAddressRequest(
          address: '0xsource',
          toChainId: '1',
          toTokenAddress: '0xusdc',
          recipientAddress: '0xrecipient',
        ),
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/withdraw');
      expect(_body(captured!), <String, dynamic>{
        'address': '0xsource',
        'toChainId': '1',
        'toTokenAddress': '0xusdc',
        'recipientAddr': '0xrecipient',
      });
      expect(response.address.evm, '0xwithdraw');
      expect(response.address.svm, 'svm-withdraw');
      expect(response.address.btc, 'bc1withdraw');
      expect(response.note, 'send pUSD to the address for the source chain');
    });
  });

  group('supportedAssets', () {
    test('SupportedAsset parses string numeric fields', () {
      final asset = SupportedAsset.fromJson(<String, dynamic>{
        'chainId': 137,
        'chainName': 123,
        'token': <String, dynamic>{
          'name': 456,
          'symbol': 789,
          'address': 101112,
          'decimals': '6',
        },
        'minCheckoutUsd': '5.5',
      });

      expect(asset.chainId, '137');
      expect(asset.chainName, '123');
      expect(asset.token.name, '456');
      expect(asset.token.symbol, '789');
      expect(asset.token.address, '101112');
      expect(asset.token.decimals, 6);
      expect(asset.minCheckoutUsd, 5.5);
    });

    test('GETs /supported-assets and decodes assets', () async {
      http.BaseRequest? captured;
      final client = _client((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'supportedAssets': [
              <String, dynamic>{
                'chainId': '137',
                'chainName': 'Polygon',
                'token': <String, dynamic>{
                  'name': 'USD Coin',
                  'symbol': 'USDC',
                  'address': '0x2791',
                  'decimals': 6,
                },
                'minCheckoutUsd': 5,
              },
            ],
          }),
          200,
        );
      });

      final response = await client.supportedAssets();

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/supported-assets');
      final asset = response.supportedAssets.single;
      expect(asset.chainId, '137');
      expect(asset.chainName, 'Polygon');
      expect(asset.token.name, 'USD Coin');
      expect(asset.token.symbol, 'USDC');
      expect(asset.token.address, '0x2791');
      expect(asset.token.decimals, 6);
      expect(asset.minCheckoutUsd, 5);
    });
  });

  group('depositStatus', () {
    test(
      'DepositTransaction stringifies numeric IDs and parses string millis',
      () {
        final transaction = DepositTransaction.fromJson(<String, dynamic>{
          'fromChainId': 1,
          'fromTokenAddress': 123,
          'fromAmountBaseUnit': 1000000,
          'toChainId': 137,
          'toTokenAddress': '0x2791',
          'txHash': 456,
          'createdTimeMs': '1714000000123',
          'status': 'confirmed',
        });

        expect(transaction.fromChainId, '1');
        expect(transaction.fromTokenAddress, '123');
        expect(transaction.fromAmountBaseUnit, '1000000');
        expect(transaction.toChainId, '137');
        expect(transaction.txHash, '456');
        expect(transaction.createdTimeMs, 1714000000123);
      },
    );

    test('GETs /status/{address} and decodes transactions', () async {
      http.BaseRequest? captured;
      final client = _client((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactions': [
              <String, dynamic>{
                'fromChainId': '1',
                'fromTokenAddress': '0xa0b8',
                'fromAmountBaseUnit': '1000000',
                'toChainId': '137',
                'toTokenAddress': '0x2791',
                'txHash': '0xtx',
                'createdTimeMs': 1714000000123,
                'status': 'confirmed',
              },
            ],
          }),
          200,
        );
      });

      final response = await client.depositStatus('0xdeposit');

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/status/0xdeposit');
      final transaction = response.transactions.single;
      expect(transaction.fromChainId, '1');
      expect(transaction.fromTokenAddress, '0xa0b8');
      expect(transaction.fromAmountBaseUnit, '1000000');
      expect(transaction.toChainId, '137');
      expect(transaction.toTokenAddress, '0x2791');
      expect(transaction.txHash, '0xtx');
      expect(transaction.createdTimeMs, 1714000000123);
      expect(transaction.status, 'confirmed');
    });
  });

  group('quote', () {
    test('QuoteResponse parses string numeric fields', () {
      final response = QuoteResponse.fromJson(<String, dynamic>{
        'estCheckoutTimeMs': '120000',
        'estFeeBreakdown': <String, dynamic>{
          'appFeeLabel': 123,
          'appFeePercent': '0.01',
          'appFeeUsd': '0.10',
          'fillCostPercent': '0.02',
          'fillCostUsd': '0.20',
          'gasUsd': '0.30',
          'maxSlippage': '0.005',
          'minReceived': '99.40',
          'swapImpact': '0.001',
          'swapImpactUsd': '0.10',
          'totalImpact': '0.006',
          'totalImpactUsd': '0.60',
        },
        'estInputUsd': '100.5',
        'estOutputUsd': '99.4',
        'estToTokenBaseUnit': 99400000,
        'quoteId': 123,
      });

      expect(response.estCheckoutTimeMs, 120000);
      expect(response.estInputUsd, 100.5);
      expect(response.estOutputUsd, 99.4);
      expect(response.estToTokenBaseUnit, '99400000');
      expect(response.quoteId, '123');
      expect(response.estFeeBreakdown.appFeeLabel, '123');
      expect(response.estFeeBreakdown.appFeePercent, 0.01);
      expect(response.estFeeBreakdown.minReceived, 99.40);
      expect(response.estFeeBreakdown.totalImpactUsd, 0.60);
    });

    test('POSTs /quote with request and decodes quote response', () async {
      http.BaseRequest? captured;
      const request = QuoteRequest(
        fromAmountBaseUnit: '1000000',
        fromChainId: '1',
        fromTokenAddress: '0xa0b8',
        recipientAddress: '0xrecipient',
        toChainId: '137',
        toTokenAddress: '0x2791',
      );
      final client = _client((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'estCheckoutTimeMs': 120000,
            'estFeeBreakdown': <String, dynamic>{
              'appFeeLabel': 'App fee',
              'appFeePercent': 0.01,
              'appFeeUsd': 0.10,
              'fillCostPercent': 0.02,
              'fillCostUsd': 0.20,
              'gasUsd': 0.30,
              'maxSlippage': 0.005,
              'minReceived': 99.40,
              'swapImpact': 0.001,
              'swapImpactUsd': 0.10,
              'totalImpact': 0.006,
              'totalImpactUsd': 0.60,
            },
            'estInputUsd': 100,
            'estOutputUsd': 99.40,
            'estToTokenBaseUnit': '99400000',
            'quoteId': 'quote-1',
          }),
          200,
        );
      });

      final response = await client.quote(request);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/quote');
      expect(_body(captured!), <String, dynamic>{
        'fromAmountBaseUnit': '1000000',
        'fromChainId': '1',
        'fromTokenAddress': '0xa0b8',
        'recipientAddress': '0xrecipient',
        'toChainId': '137',
        'toTokenAddress': '0x2791',
      });
      expect(response.estCheckoutTimeMs, 120000);
      expect(response.estInputUsd, 100);
      expect(response.estOutputUsd, 99.40);
      expect(response.estToTokenBaseUnit, '99400000');
      expect(response.quoteId, 'quote-1');
      expect(response.estFeeBreakdown.appFeeLabel, 'App fee');
      expect(response.estFeeBreakdown.appFeePercent, 0.01);
      expect(response.estFeeBreakdown.appFeeUsd, 0.10);
      expect(response.estFeeBreakdown.fillCostPercent, 0.02);
      expect(response.estFeeBreakdown.fillCostUsd, 0.20);
      expect(response.estFeeBreakdown.gasUsd, 0.30);
      expect(response.estFeeBreakdown.maxSlippage, 0.005);
      expect(response.estFeeBreakdown.minReceived, 99.40);
      expect(response.estFeeBreakdown.swapImpact, 0.001);
      expect(response.estFeeBreakdown.swapImpactUsd, 0.10);
      expect(response.estFeeBreakdown.totalImpact, 0.006);
      expect(response.estFeeBreakdown.totalImpactUsd, 0.60);
    });
  });
}
