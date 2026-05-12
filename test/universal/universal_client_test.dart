// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart' show DelegatingStreamSink;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/dataapi/dataapi_client.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/stream/stream_config.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/universal/universal_client.dart';
import 'package:stream_channel/stream_channel.dart' show StreamChannelMixin;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('UniversalConfig', () {
    test('defaults match the existing production clients', () {
      const config = UniversalConfig();

      expect(config.gammaBaseUrl, GammaClient.defaultBaseUrl);
      expect(config.clobBaseUrl, ClobClient.defaultBaseUrl);
      expect(config.dataBaseUrl, DataApiClient.defaultBaseUrl);
      expect(config.streamUrl, defaultStreamUrl);
    });
  });

  group('UniversalClient reads', () {
    test(
      'delegates Gamma, CLOB, and Data API calls to injected transports',
      () async {
        Uri? gammaUrl;
        Uri? clobUrl;
        Uri? dataUrl;

        final client = UniversalClient(
          config: UniversalConfig(
            gammaTransport: _transport(GammaClient.defaultBaseUrl, (req) async {
              gammaUrl = req.url;
              return http.Response(
                jsonEncode([
                  <String, dynamic>{
                    'id': 'm1',
                    'question': 'Will BTC close above 100k?',
                    'slug': 'btc-100k',
                    'active': true,
                    'closed': false,
                    'archived': false,
                  },
                ]),
                200,
              );
            }),
            clobTransport: _transport(ClobClient.defaultBaseUrl, (req) async {
              clobUrl = req.url;
              return http.Response(
                jsonEncode(<String, dynamic>{'price': '0.42'}),
                200,
              );
            }),
            dataTransport: _transport(DataApiClient.defaultBaseUrl, (
              req,
            ) async {
              dataUrl = req.url;
              return http.Response(
                jsonEncode([
                  <String, dynamic>{
                    'token_id': 'tok',
                    'condition_id': 'cond',
                    'market_id': 'mkt',
                    'side': 'YES',
                    'avg_price': 0.4,
                    'size': 10,
                    'current_price': 0.5,
                    'unrealized_pnl': 1,
                  },
                ]),
                200,
              );
            }),
          ),
        );

        addTearDown(client.close);

        final markets = await client.activeMarkets();
        final price = await client.price('tok', 'BUY');
        final positions = await client.currentPositions('0xuser', limit: 10);

        expect(markets.single.slug, 'btc-100k');
        expect(gammaUrl!.path, '/markets');
        expect(gammaUrl!.queryParameters['active'], 'true');
        expect(gammaUrl!.queryParameters['closed'], 'false');

        expect(price, '0.42');
        expect(clobUrl!.path, '/price');
        expect(clobUrl!.queryParameters['token_id'], 'tok');
        expect(clobUrl!.queryParameters['side'], 'BUY');

        expect(positions.single.tokenId, 'tok');
        expect(dataUrl!.path, '/positions');
        expect(dataUrl!.queryParameters['user'], '0xuser');
        expect(dataUrl!.queryParameters['limit'], '10');
      },
    );

    test('creates stream clients from the configured stream surface', () async {
      Uri? capturedUrl;
      final channel = _FakeWebSocketChannel();
      final client = UniversalClient(
        config: UniversalConfig(
          streamUrl: 'wss://stream.test/ws/market',
          streamChannelFactory: (url) {
            capturedUrl = url;
            return channel;
          },
        ),
      );

      addTearDown(client.close);

      final stream = client.streamClient();
      await stream.connect();
      await stream.close();

      expect(client.streamConfig.url, 'wss://stream.test/ws/market');
      expect(capturedUrl.toString(), 'wss://stream.test/ws/market');
    });
  });

  group('healthCheck', () {
    test(
      'returns partial health without throwing when at least one API works',
      () async {
        final client = UniversalClient(
          config: UniversalConfig(
            gammaTransport: _transport(
              GammaClient.defaultBaseUrl,
              (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
            ),
            clobTransport: _transport(
              ClobClient.defaultBaseUrl,
              (_) async => http.Response('boom', 500),
            ),
            dataTransport: _transport(
              DataApiClient.defaultBaseUrl,
              (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
            ),
          ),
        );

        addTearDown(client.close);

        final health = await client.healthCheck();

        expect(health.gammaOk, isTrue);
        expect(health.clobOk, isFalse);
        expect(health.dataOk, isTrue);
        expect(health.allOk, isFalse);
        expect(health.anyOk, isTrue);
        expect(health.errors.keys, contains('clob'));
      },
    );

    test(
      'throws a summary exception only when every HTTP API is unreachable',
      () async {
        final client = UniversalClient(
          config: UniversalConfig(
            gammaTransport: _transport(
              GammaClient.defaultBaseUrl,
              (_) async => http.Response('boom', 500),
            ),
            clobTransport: _transport(
              ClobClient.defaultBaseUrl,
              (_) async => http.Response('boom', 500),
            ),
            dataTransport: _transport(
              DataApiClient.defaultBaseUrl,
              (_) async => http.Response('boom', 500),
            ),
          ),
        );

        addTearDown(client.close);

        expect(
          client.healthCheck,
          throwsA(
            isA<UniversalHealthException>()
                .having((e) => e.summary.anyOk, 'summary.anyOk', isFalse)
                .having(
                  (e) => e.summary.errors.keys,
                  'errors',
                  contains('data'),
                ),
          ),
        );
      },
    );
  });

  group('read-only boundary', () {
    test(
      'universal facade source exposes no raw private-key or write surface',
      () {
        final source = File(
          'lib/src/universal/universal_client.dart',
        ).readAsStringSync();

        expect(source, isNot(contains('privateKey')));
        expect(source, isNot(contains('rawPrivateKey')));
        expect(source, isNot(contains('WalletSigner')));
        expect(source, isNot(contains('ClobWrites')));
        expect(source, isNot(contains('createOrder')));
        expect(source, isNot(contains('cancelOrder')));
      },
    );
  });
}

HttpTransport _transport(
  String baseUrl,
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return HttpTransport(
    config: TransportConfig(baseUrl: baseUrl, retryMax: 0),
    inner: MockClient(handler),
  );
}

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel()
    : _incoming = StreamController<dynamic>(),
      _outgoing = StreamController<dynamic>() {
    sink = _FakeWebSocketSink(_outgoing);
  }

  final StreamController<dynamic> _incoming;
  final StreamController<dynamic> _outgoing;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  late final WebSocketSink sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();
}

class _FakeWebSocketSink extends DelegatingStreamSink<dynamic>
    implements WebSocketSink {
  _FakeWebSocketSink(this._controller) : super(_controller.sink);

  final StreamController<dynamic> _controller;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}
