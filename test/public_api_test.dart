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

    const depositLimitParams = CreateDepositWalletLimitOrderParams(
      tokenId: '12345',
      side: Side.buy,
      price: '0.50',
      size: '10',
    );
    expect(depositLimitParams.orderType, OrderType.gtc);
    expect(createDepositWalletLimitOrder, isA<Function>());
    expect(signDepositWalletOrderV2, isA<Function>());

    final fundingPlan = buildEoaPusdTransferPlan(
      ownerEoa: '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23',
      depositWallet: '0x21999a074344610057c9b2B362332388a44502D4',
      amountBaseUnits: BigInt.from(1000000),
    );
    expect(fundingPlan, isA<EoaPusdTransferPlan>());
    expect(fundingPlan.value, '0x0');
    PusdFundingRoutePlan? fundingRoute;
    expect(fundingRoute, isNull);
    expect(PusdFundingRouteStatus.ready.name, 'ready');
    expect(planEoaPusdFundingRoute, isA<Function>());

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

    final readiness = DepositWalletReadiness(
      status: DepositWalletReadinessStatus.needsApproval,
      ownerEoa: '0x0000000000000000000000000000000000001234',
      depositWallet: '0xfd5041047be8c192c725a66228f141196fa3cf9c',
      deployed: true,
      approvalsChecked: true,
      fundingChecked: true,
      clobBalance: '1000000',
      missingApprovals: const <String>['pusd:ctfExchangeV2'],
      approvalChecks: const <DepositWalletApprovalCheck>[
        DepositWalletApprovalCheck(
          label: 'pusd:ctfExchangeV2',
          kind: DepositWalletApprovalKind.erc20Allowance,
          token: '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
          spender: '0xE111180000d2663C0091e4f400237545B87B996B',
          ready: false,
          value: '0',
        ),
      ],
    );
    expect(readiness.status, DepositWalletReadinessStatus.needsApproval);
    expect(readiness.fundingChecked, isTrue);
    expect(readiness.approvalChecks.single.ready, isFalse);
  });
}
