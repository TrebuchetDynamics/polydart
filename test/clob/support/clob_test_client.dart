import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';

ClobClient clobTestClient(
  Future<http.Response> Function(http.BaseRequest) handler, {
  PolydartMode mode = PolydartMode.readOnly,
  bool liveTradingEnabled = false,
  DateTime Function()? clock,
}) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    mode: mode,
    liveTradingEnabled: liveTradingEnabled,
    clock: clock,
  );
}
