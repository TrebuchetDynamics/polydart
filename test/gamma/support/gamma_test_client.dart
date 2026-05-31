import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';

GammaClient gammaTestClient(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return GammaClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: GammaClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
  );
}

http.Response gammaJsonList(List<Map<String, dynamic>> rows) =>
    http.Response(jsonEncode(rows), 200);

http.Response gammaJsonObj(Map<String, dynamic> obj) =>
    http.Response(jsonEncode(obj), 200);
