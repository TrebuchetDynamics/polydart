// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/dataapi/dataapi_client.dart';
import 'package:polydart/src/dataapi/dataapi_types.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

DataApiClient _client(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return DataApiClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: DataApiClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
  );
}

Map<String, dynamic> _trade(String id, {String side = 'BUY'}) =>
    <String, dynamic>{
      'id': id,
      'market': 'cond-1',
      'asset_id': 'asset-1',
      'side': side,
      'price': 0.5,
      'size': 10.0,
      'fee_rate_bps': 0,
      'created_at': '1714000000',
    };

void main() {
  group('smartWalletTrades', () {
    test('annotates trades with the sourcing wallet and label', () async {
      final calls = <Map<String, String>>[];
      final client = _client((req) async {
        calls.add(req.url.queryParameters);
        final user = req.url.queryParameters['user'];
        return http.Response(jsonEncode([_trade('$user-t1')]), 200);
      });

      final out = await client.smartWalletTrades(
        const SmartWalletTradesQuery(
          wallets: [
            SmartWallet(address: '0xAAA', label: 'whale'),
            SmartWallet(address: '0xBBB'),
          ],
          limitPerWallet: 5,
        ),
      );

      expect(out, hasLength(2));
      expect(out[0].walletAddress, '0xAAA');
      expect(out[0].walletLabel, 'whale');
      expect(out[0].trade.id, '0xAAA-t1');
      expect(out[1].walletAddress, '0xBBB');
      expect(out[1].walletLabel, isEmpty);
      // Per-wallet limit is forwarded to /trades.
      expect(calls.first['user'], '0xAAA');
      expect(calls.first['limit'], '5');
    });

    test('deduplicates a fill seen from two wallets by trade id', () async {
      final client = _client((req) async {
        // Both wallets surface the same trade id.
        return http.Response(jsonEncode([_trade('shared-1')]), 200);
      });

      final out = await client.smartWalletTrades(
        const SmartWalletTradesQuery(
          wallets: [
            SmartWallet(address: '0xAAA'),
            SmartWallet(address: '0xBBB'),
          ],
        ),
      );

      expect(out, hasLength(1));
      expect(out.single.walletAddress, '0xAAA');
      expect(out.single.trade.id, 'shared-1');
    });

    test('skips blank wallet addresses without querying', () async {
      var calls = 0;
      final client = _client((req) async {
        calls++;
        return http.Response(jsonEncode([_trade('t1')]), 200);
      });

      final out = await client.smartWalletTrades(
        const SmartWalletTradesQuery(
          wallets: [
            SmartWallet(address: '   '),
            SmartWallet(address: ''),
          ],
        ),
      );

      expect(out, isEmpty);
      expect(calls, 0);
    });

    test('falls back to a composite key when trade id is empty', () async {
      // Two distinct trades with empty ids but different sides must both
      // survive deduplication.
      final client = _client((req) async {
        return http.Response(
          jsonEncode([_trade('', side: 'BUY'), _trade('', side: 'SELL')]),
          200,
        );
      });

      final out = await client.smartWalletTrades(
        const SmartWalletTradesQuery(wallets: [SmartWallet(address: '0xAAA')]),
      );

      expect(out, hasLength(2));
      expect(out[0].trade.side, 'BUY');
      expect(out[1].trade.side, 'SELL');
    });
  });
}
