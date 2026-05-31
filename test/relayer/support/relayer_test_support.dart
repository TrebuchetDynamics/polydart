import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/relayer/relayer_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';

const testBuilderConfig = BuilderConfig(
  key: 'aaaaaaaa-bbbb-cccc-dddd-eeeeffff0001',
  // 32 bytes of zeros, base64-encoded.
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'pass',
);

DateTime fixedRelayerClock() =>
    DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

RelayerClient createRelayerClient(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return RelayerClient(
    builderConfig: testBuilderConfig,
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: defaultRelayerBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    clock: fixedRelayerClock,
  );
}
