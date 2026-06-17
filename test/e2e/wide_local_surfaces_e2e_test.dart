import 'dart:convert';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'wide local surfaces e2e covers auth, config, books, streams, paper, and safety helpers',
    () async {
      final config = PolydartConfig.fromEnv(const <String, String>{
        'POLYMARKET_MODE': 'paper',
        'POLYMARKET_REQUEST_TIMEOUT': '750ms',
        'POLYMARKET_LIVE_TRADING_ENABLED': 'false',
        'POLYMARKET_PAPER_STATE_PATH': '/tmp/paper.json',
      });
      expect(config.mode, PolydartMode.paper);
      expect(config.requestTimeout, const Duration(milliseconds: 750));
      expect(config.toString(), isNot(contains('/tmp/paper.json')));

      final typed = buildClobAuthTypedData(
        address: '0xabc',
        chainId: polymarketChainId,
        timestamp: 1700000000,
        nonce: 0,
      );
      final digest = hashClobAuth(
        address: '0x${'a' * 40}',
        chainId: polymarketChainId,
        timestamp: 1700000000,
        nonce: 0,
      );
      final l2Headers = buildL2Headers(
        apiKey: const ApiKey(key: 'key', secret: 'secret', passphrase: 'pass'),
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      expect(typed['primaryType'], 'ClobAuth');
      expect(digest, hasLength(32));
      expect(l2Headers['POLY_API_KEY'], 'key');
      expect(
        signHmac(secret: 'secret', timestamp: 1, method: 'GET', path: '/x'),
        isNotEmpty,
      );
      expect(
        redactSignerSecret('super-secret-token'),
        isNot(contains('secret')),
      );
      expect(
        const RedactableValue('1234567890abcdef').toString(),
        '1234...cdef',
      );

      const book = OrderBook(
        market: 'market-1',
        assetId: 'token-1',
        timestamp: '1000',
        hash: 'hash-1',
        bids: <OrderBookLevel>[
          OrderBookLevel(price: '0.49', size: '10'),
          OrderBookLevel(price: '0.51', size: '5'),
        ],
        asks: <OrderBookLevel>[
          OrderBookLevel(price: '0.55', size: '4'),
          OrderBookLevel(price: '0.53', size: '8'),
        ],
      );
      final reader = BookReader(book);
      expect(reader.bestBid!.price, '0.51');
      expect(reader.bestAsk!.price, '0.53');
      expect(reader.midpoint, closeTo(0.52, 1e-9));

      final tracker = MarketDataTracker();
      final snapshot = tracker.applyBook(
        const BookMessage(
          eventType: 'book',
          assetId: 'token-1',
          market: 'market-1',
          timestamp: '1000',
          hash: 'book-hash',
          bids: <PriceLevel>[PriceLevel(price: '0.50', size: '6')],
          asks: <PriceLevel>[PriceLevel(price: '0.54', size: '7')],
        ),
      );
      expect(snapshot.midpoint, '0.52');

      final dedup = Deduplicator(size: 8, ttl: const Duration(seconds: 5));
      final frame = utf8.encode(
        jsonEncode(<String, Object?>{
          'event_type': 'book',
          'hash': 'book-hash',
        }),
      );
      expect(dedup.process(frame), isTrue);
      expect(dedup.process(frame), isFalse);
      expect(dedup.dupCount, 1);
      final stats = StreamStats('market')..recordMessage();
      expect(stats.snapshot().messagesReceived, 1);

      final cursorItems = await CursorPager<int>(
        fetch: (cursor) async => switch (cursor) {
          null => const CursorPage(items: <int>[1, 2], nextCursor: 'next'),
          'next' => const CursorPage(items: <int>[3], nextCursor: null),
          _ => const CursorPage(items: <int>[], nextCursor: null),
        },
      ).toList();
      final offsetItems = await OffsetPager<int>(
        pageSize: 2,
        fetch: (offset, limit) async => offset >= 3
            ? const <int>[]
            : List<int>.generate(
                limit,
                (i) => offset + i,
              ).where((i) => i < 3).toList(),
      ).take(10);
      expect(cursorItems, <int>[1, 2, 3]);
      expect(offsetItems, <int>[0, 1, 2]);

      final paper = PaperState.newState('USD', 10);
      final fill = paper.buy(
        const PaperOrder(
          marketId: 'market-1',
          tokenId: 'token-1',
          price: 0.25,
          size: 4,
        ),
      );
      expect(fill.live, isFalse);
      expect(paper.cash, 9);
      expect(paper.positions['token-1']!.size, 4);

      final marketPlugin = _MarketPlugin();
      final riskPlugin = _RiskPlugin();
      final market = await marketPlugin.resolve(asset: 'BTC', timeframe: '5m');
      expect(await marketPlugin.filter(market), isTrue);
      await expectLater(
        riskPlugin.checkOrder(
          const PluginOrder(tokenId: 'token-1', side: 'BUY'),
        ),
        throwsA(isA<StateError>()),
      );

      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxConsecutiveErrors: 1),
      );
      expect(breaker.canProceed(), isTrue);
      expect(breaker.recordError(), isTrue);
      expect(breaker.status().tripReason, TripReason.consecutiveErrors);

      validatePriceAgainstTick('0.50', '0.01');
      final amounts = computeAmounts(
        OrderIntent(
          tokenId: 'token-1',
          side: Side.buy,
          price: Decimal.parse('0.50'),
          size: Decimal.parse('2'),
          tickSize: const TickSize(
            minimumTickSize: '0.01',
            minimumOrderSize: '5',
            tickSize: '0.01',
          ),
        ),
      );
      expect(amounts.makerAmount, BigInt.from(1000000));
      expect(roundToTick('0.529', '0.01'), '0.52');

      final logger = _RecordingLogger();
      final telemetry = TelemetryLogger(logger);
      telemetry.request(
        method: 'GET',
        path: '/markets',
        status: 200,
        duration: const Duration(milliseconds: 1),
      );
      telemetry.circuitOpen(method: 'POST', path: '/order');
      expect(logger.records.map((r) => r.message), <String>[
        'request',
        'circuit breaker open',
      ]);

      final gate = validateLiveGates(
        const LiveGateInput(
          envEnabled: false,
          configEnabled: false,
          confirmLive: false,
          preflightOk: true,
        ),
      );
      expect(gate.allowed, isFalse);
      expect(gate.failures, isNotEmpty);
    },
  );
}

final class _MarketPlugin implements MarketDataPlugin {
  @override
  Future<Market> resolve({
    required String asset,
    required String timeframe,
  }) async {
    return Market.fromJson(<String, dynamic>{
      'id': 'market-1',
      'slug': '$asset-$timeframe',
      'active': true,
      'closed': false,
    });
  }

  @override
  Future<bool> filter(Market market) async => market.active && !market.closed;
}

final class _RiskPlugin implements RiskPlugin {
  @override
  Future<void> checkOrder(PluginOrder order) async {
    throw StateError('blocked by plugin');
  }
}

final class _RecordingLogger implements Logger {
  final records =
      <({LogLevel level, String message, Map<String, Object?> fields})>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    records.add((
      level: level,
      message: message,
      fields: fields ?? const <String, Object?>{},
    ));
  }
}
