import 'package:polydart/src/auth/eth_hex.dart';
import 'package:polydart/src/orders/order_signing.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

const _maker = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';

OrderV2Draft _sample() => const OrderV2Draft(
  salt: '1',
  maker: _maker,
  signer: _maker,
  tokenId: '12345',
  makerAmount: '5500000',
  takerAmount: '10000000',
  side: Side.buy,
  signatureType: SignatureType.eoa,
  timestamp: '1700000000000',
);

void main() {
  group('parity vectors (cross-validated against polygolem)', () {
    test('domain separator (V2, regular exchange)', () {
      expect(
        bytesToHex(orderV2DomainSeparator()),
        '3264e159346253e26a64e00b69032db0e7d32f94628de3e6eecb50304d7af3d2',
      );
    });

    test('Order struct hash for the canonical sample', () {
      expect(
        bytesToHex(orderV2StructHash(draft: _sample())),
        'b5eaafbbae11511d4926ad7ff87107a853cc92b401d9ca12102c5fd0191f83d3',
      );
    });

    test('full EIP-712 digest for the canonical sample', () {
      expect(
        bytesToHex(hashOrderV2(draft: _sample())),
        '0284f0b0ab359521d23fc3c40d4a796c6fb73b650a10e9fcde868240de153a87',
      );
    });
  });

  group('typed-data shape', () {
    test('matches the wallet provider format', () {
      final typed = buildOrderV2TypedData(draft: _sample());
      expect(typed['primaryType'], 'Order');
      expect(typed['domain']['name'], 'Polymarket CTF Exchange');
      expect(typed['domain']['version'], '2');
      expect(typed['domain']['chainId'], 137);
      expect(typed['domain']['verifyingContract'], clobExchangeAddressV2);
      expect(typed['message']['side'], 0);
      expect(typed['message']['signatureType'], 0);
      expect(typed['message']['timestamp'], '1700000000000');
    });

    test('negRisk flips the verifying contract', () {
      final typed = buildOrderV2TypedData(draft: _sample(), negRisk: true);
      expect(typed['domain']['verifyingContract'], negRiskExchangeAddressV2);
    });
  });

  group('canonical contentsType length', () {
    test('matches the 186-byte ERC-7739 reference', () {
      expect(orderV2ContentsType.length, 186);
    });
  });

  test('hashOrderV2 changes when negRisk flips', () {
    final regular = hashOrderV2(draft: _sample());
    final neg = hashOrderV2(draft: _sample(), negRisk: true);
    expect(regular, isNot(neg));
  });

  test('hashOrderV2 changes when side flips', () {
    final buy = hashOrderV2(draft: _sample());
    const sellDraft = OrderV2Draft(
      salt: '1',
      maker: _maker,
      signer: _maker,
      tokenId: '12345',
      makerAmount: '5500000',
      takerAmount: '10000000',
      side: Side.sell,
      signatureType: SignatureType.eoa,
      timestamp: '1700000000000',
    );
    final sell = hashOrderV2(draft: sellDraft);
    expect(buy, isNot(sell));
  });
}
