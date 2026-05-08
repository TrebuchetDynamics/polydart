import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/types/decimal.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

void main() {
  test('fluent path builds a valid intent', () {
    final intent = OrderBuilder(tokenId: 'tok-123', side: Side.buy)
        .price('0.55')
        .size('10')
        .tickSize('0.01')
        .feeRateBps(0)
        .orderType(OrderType.gtc)
        .signatureType(SignatureType.eoa)
        .build();
    expect(intent.tokenId, 'tok-123');
    expect(intent.side, Side.buy);
    expect(intent.price, Decimal.parse('0.55'));
    expect(intent.size, Decimal.parse('10'));
    expect(intent.tickSize.tickSize, '0.01');
    expect(intent.orderType, OrderType.gtc);
  });

  test('build throws when validation fails', () {
    expect(
      () => OrderBuilder(tokenId: '', side: Side.buy).build(),
      throwsA(isA<ValidationException>()),
    );
  });

  test('amountUsdc satisfies validation without a nominal price', () {
    // amountUsdc is set even if price/size are zero — the CLOB will derive
    // size at fill time. Builder should accept this combo.
    final intent = OrderBuilder(
      tokenId: 'tok-1',
      side: Side.buy,
    ).amountUsdc('25').tickSize('0.01').build();
    expect(intent.amountUsdc, isNotNull);
  });

  test('chains builder mutations on the same instance', () {
    final builder = OrderBuilder(tokenId: 'tok-1', side: Side.sell);
    expect(builder.price('0.5').size('1').tickSize('0.01'), same(builder));
  });
}
