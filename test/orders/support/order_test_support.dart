import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/orders/order_intent.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/enums.dart';

import '../../auth/support/auth_test_fixtures.dart';
import '../../auth/support/fake_wallet_signer.dart';

const testOrderApiKey = ApiKey(
  key: 'aaaaaaaa-bbbb-cccc-dddd-eeeeffff0001',
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'pp1',
);

FakeWalletSigner cannedOrderSigner({int chainId = 137, Uint8List? signature}) =>
    FakeWalletSigner(
      chainId: chainId,
      signature: signature ?? deterministicSignature((i) => i == 64 ? 27 : i),
    );

OrderIntent limitBuyIntent({
  String tokenId = '12345',
  String price = '0.50',
  String size = '10',
  String tickSize = '0.01',
}) =>
    (OrderBuilder(tokenId: tokenId, side: Side.buy)
          ..price(price)
          ..size(size)
          ..tickSize(tickSize))
        .build();

http.Response tickSizeResponse({
  String minimumTickSize = '0.01',
  String minimumOrderSize = '5',
  String tickSize = '0.01',
}) => http.Response(
  jsonEncode(<String, dynamic>{
    'minimum_tick_size': minimumTickSize,
    'minimum_order_size': minimumOrderSize,
    'tick_size': tickSize,
  }),
  200,
);

ClobClient orderTestClient(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    mode: PolydartMode.live,
    liveTradingEnabled: true,
  );
}
