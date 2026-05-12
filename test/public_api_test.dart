import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test('package root exports current public API return types', () {
    const order = OrderResponse(
      success: true,
      orderId: 'O-1',
      status: 'live',
      transactionHashes: <String>['0xtx'],
      tradeIds: <String>['trade-1'],
    );
    const batch = BatchOrderResponse(orders: <OrderResponse>[order]);
    expect(batch.orders.single.orderId, 'O-1');
    expect(maxBatchPostSize, 15);

    const liveVolumeMarket = LiveVolumeMarket(market: '0xmarket', value: 42.5);
    expect(liveVolumeMarket.value, 42.5);

    const newMarket = NewMarketMessage(
      eventType: 'new_market',
      id: 'M-1',
      question: 'Question?',
      market: '0xmarket',
      slug: 'question',
      description: 'Description',
      assetIds: <String>['YES', 'NO'],
      outcomes: <String>['Yes', 'No'],
      timestamp: 'T',
      tags: <String>['tag'],
      conditionId: 'C',
      clobTokenIds: <String>['YES', 'NO'],
      active: true,
    );
    expect(newMarket.assetIds, <String>['YES', 'NO']);

    const resolved = MarketResolvedMessage(
      eventType: 'market_resolved',
      id: 'R-1',
      market: '0xmarket',
      assetIds: <String>['YES', 'NO'],
      winningAssetId: 'YES',
      winningOutcome: 'Yes',
      timestamp: 'T',
      tags: <String>['resolved'],
    );
    expect(resolved.winningOutcome, 'Yes');

    const relayerError = RelayerError(
      error: 'invalid authorization',
      code: 401,
    );
    expect(relayerError.code, 401);

    const credentialKey = CredentialKey(
      eoaAddress: '0x0000000000000000000000000000000000001234',
      chainId: 137,
    );
    expect(credentialKey.chainId, 137);

    const clobKey = ApiKey(
      key: 'clob-key',
      secret: 'clob-secret',
      passphrase: 'clob-pass',
    );
    const credentials = LiveCredentialReadiness(
      clobApiKey: CredentialReadiness<ApiKey>(
        status: LiveCredentialStatus.cached,
        value: clobKey,
      ),
      builderFeeKey: CredentialReadiness<ApiKey>(
        status: LiveCredentialStatus.created,
        value: clobKey,
      ),
      relayerApiKey: CredentialReadiness<V2APIKey>(
        status: LiveCredentialStatus.created,
        value: V2APIKey(
          key: 'relayer-key',
          address: '0x0000000000000000000000000000000000001234',
        ),
      ),
    );
    expect(credentials.ready, isTrue);
    expect(credentials.toString(), isNot(contains('clob-secret')));
    expect(credentials.toString(), isNot(contains('relayer-key')));
  });
}
