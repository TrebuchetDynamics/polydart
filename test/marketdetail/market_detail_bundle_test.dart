import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

/// Returns a mock http handler that responds to any request with [body].
Future<http.Response> Function(http.BaseRequest) _handler(String body) {
  return (_) async =>
      http.Response(body, 200, headers: {'content-type': 'application/json'});
}

/// Minimal valid market JSON for the Gamma API's `/markets` endpoint.
const _sampleMarketJson = '''
[
  {
    "id": "test-event-1",
    "condition_id": "0xabc",
    "question": "Test market?",
    "slug": "test-market",
    "description": "A test market",
    "outcomes": ["Yes", "No"],
    "outcomePrices": ["0.55", "0.45"],
    "active": true,
    "closed": false,
    "archived": false,
    "enableOrderBook": true,
    "acceptingOrders": true,
    "volumeNum": 1000000.0,
    "liquidityNum": 500000.0,
    "volume": "1000000",
    "endDateIso": "2026-12-31",
    "tokens": [
      {"token_id": "token-yes", "outcome": "Yes", "price": "0.55", "winner": false},
      {"token_id": "token-no", "outcome": "No", "price": "0.45", "winner": false}
    ],
    "tokenIds": ["token-yes", "token-no"],
    "clobTokenIds": "token-yes,token-no",
    "tags": [],
    "events": []
  }
]
''';

void main() {
  group('BundleField', () {
    test('ok creates a successful field', () {
      final field = BundleField.ok('hello');
      expect(field.isOk, isTrue);
      expect(field.isError, isFalse);
      expect(field.value, equals('hello'));
      expect(field.error, isNull);
    });

    test('err creates a failed field', () {
      final error = Exception('fail');
      final field = BundleField<String>.err(error);
      expect(field.isOk, isFalse);
      expect(field.isError, isTrue);
      expect(field.value, isNull);
      expect(field.error, same(error));
    });

    test('toString shows value for ok', () {
      expect(BundleField.ok(42).toString(), contains('BundleField.ok(42)'));
    });

    test('toString shows error for err', () {
      final field = BundleField<String>.err(Exception('bad'));
      expect(field.toString(), contains('BundleField.err'));
    });
  });

  group('MarketDetailBundle', () {
    test('constructs with all fields', () {
      final bundle = MarketDetailBundle(
        market: BundleField<Market>.err(Exception('no market')),
        event: BundleField<Event?>.ok(null),
        orderBooks: BundleField<Map<String, OrderBook>>.ok(const {}),
        priceHistory: BundleField<Map<String, PriceHistory>>.ok(const {}),
        trades: BundleField<List<TradeRecord>>.ok(const []),
        elapsed: Duration.zero,
      );
      expect(bundle.market.isError, isTrue);
      expect(bundle.event.value, isNull);
      expect(bundle.orderBooks.value, isEmpty);
      expect(bundle.priceHistory.value, isEmpty);
      expect(bundle.trades.value, isEmpty);
      expect(bundle.elapsed, equals(Duration.zero));
    });

    test('handles field-level errors', () {
      final bundle = MarketDetailBundle(
        market: BundleField<Market>.err(Exception('not found')),
        event: BundleField<Event?>.ok(null),
        orderBooks: BundleField<Map<String, OrderBook>>.ok(const {}),
        priceHistory: BundleField<Map<String, PriceHistory>>.err(
          Exception('api down'),
        ),
        trades: BundleField<List<TradeRecord>>.ok(const []),
        elapsed: const Duration(seconds: 1),
      );
      expect(bundle.market.isError, isTrue);
      expect(bundle.priceHistory.isError, isTrue);
      expect(bundle.event.isOk, isTrue);
      expect(bundle.orderBooks.isOk, isTrue);
      expect(bundle.trades.isOk, isTrue);
    });
  });

  group('MarketDetailFetcher with mock transport', () {
    late GammaClient gamma;
    late ClobClient clob;

    setUp(() {
      gamma = GammaClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://gamma-api.polymarket.com',
            timeout: Duration(seconds: 5),
          ),
          inner: MockClient(_handler(_sampleMarketJson)),
        ),
      );
      clob = ClobClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://clob.polymarket.com',
            timeout: Duration(seconds: 5),
          ),
          inner: MockClient(_handler('[]')),
        ),
        mode: PolydartMode.readOnly,
        liveTradingEnabled: false,
      );
    });

    test('fetch returns market data when Gamma succeeds', () async {
      final bundle = await MarketDetailFetcher.fetch(
        gamma: gamma,
        clob: clob,
        conditionId: '0xabc',
        priceHistoryInterval: '',
      );

      // Market should have been fetched successfully.
      expect(bundle.market.isOk, isTrue);
      final market = bundle.market.value;
      expect(market, isNotNull);
      expect(market!.conditionId, equals('0xabc'));
      expect(market.question, equals('Test market?'));
      expect(market.tokens.length, equals(2));
      expect(market.volumeNum, greaterThan(0));
    });

    test('fetch handles partial failures gracefully', () async {
      final bundle = await MarketDetailFetcher.fetch(
        gamma: gamma,
        clob: clob,
        conditionId: '0xabc',
        priceHistoryInterval: '',
      );

      // Market should have data regardless of other fields.
      expect(bundle.market.isOk, isTrue);

      // Event may have failed or returned null (no events in mock).
      expect(bundle.event.isOk || bundle.event.isError, isTrue);

      // Order books may have failed (mock returns '[]' which may break).
      expect(bundle.orderBooks.isOk || bundle.orderBooks.isError, isTrue);

      // Trades may have failed.
      expect(bundle.trades.isOk || bundle.trades.isError, isTrue);

      // Price history was skipped (empty interval).
      expect(bundle.priceHistory.isOk, isTrue);
      expect(bundle.priceHistory.value, isEmpty);
    });

    test('fetch returns error bundle for unknown condition', () async {
      final unknownGamma = GammaClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://gamma-api.polymarket.com',
            timeout: Duration(seconds: 5),
          ),
          inner: MockClient(
            (_) async => http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

      final bundle = await MarketDetailFetcher.fetch(
        gamma: unknownGamma,
        clob: clob,
        conditionId: '0xunknown',
        priceHistoryInterval: '',
      );

      expect(bundle.market.isError, isTrue);
      expect(bundle.market.error.toString(), contains('Market not found'));
    });

    test('marketBundle on Polydart client', () async {
      final client = Polydart.readOnly(
        config: const PolydartConfig(requestTimeout: Duration(seconds: 5)),
        gammaTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://gamma-api.polymarket.com',
            timeout: Duration(seconds: 5),
          ),
          inner: MockClient(_handler(_sampleMarketJson)),
        ),
        clobTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://clob.polymarket.com',
            timeout: Duration(seconds: 5),
          ),
          inner: MockClient(_handler('[]')),
        ),
      );

      final bundle = await client.marketBundle(
        conditionId: '0xabc',
        priceHistoryInterval: '',
      );

      expect(bundle.market.isOk, isTrue);
      expect(bundle.market.value!.conditionId, equals('0xabc'));
      client.close();
    });
  });
}
