import 'package:polydart/src/plugins/plugins.dart';
import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

void main() {
  group('MarketDataPlugin', () {
    test('can resolve and filter markets through the interface', () async {
      const plugin = _NoopMarketDataPlugin();

      final market = await plugin.resolve(asset: 'BTC', timeframe: '5m');
      final accepted = await plugin.filter(market);

      expect(market.slug, 'BTC-5m');
      expect(accepted, isTrue);
    });
  });

  group('RiskPlugin', () {
    test('can block an order through the interface', () async {
      const plugin = _BlockingRiskPlugin();

      await expectLater(
        () => plugin.checkOrder(const PluginOrder(tokenId: '123', side: 'BUY')),
        throwsA(isA<StateError>()),
      );
    });
  });
}

final class _NoopMarketDataPlugin implements MarketDataPlugin {
  const _NoopMarketDataPlugin();

  @override
  Future<Market> resolve({
    required String asset,
    required String timeframe,
  }) async {
    return Market.fromJson(<String, dynamic>{
      'id': 'market-1',
      'slug': '$asset-$timeframe',
    });
  }

  @override
  Future<bool> filter(Market market) async => true;
}

final class _BlockingRiskPlugin implements RiskPlugin {
  const _BlockingRiskPlugin();

  @override
  Future<void> checkOrder(PluginOrder order) async {
    throw StateError('blocked by plugin');
  }
}
