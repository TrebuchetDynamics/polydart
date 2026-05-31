// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orders/order_intent.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:polydart/src/types/decimal.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

import '../support/core_order_test_support.dart';

void main() {
  group('OrderIntent.validate', () {
    test('accepts a well-formed buy', () {
      OrderIntent(
        tokenId: '12345',
        side: Side.buy,
        price: Decimal.parse('0.55'),
        size: Decimal.parse('10'),
        tickSize: validTickSize,
      ).validate();
    });

    test('rejects empty token_id', () {
      expect(
        () => OrderIntent(
          tokenId: '',
          side: Side.buy,
          price: Decimal.parse('0.55'),
          size: Decimal.parse('10'),
          tickSize: validTickSize,
        ).validate(),
        throwsValidationException,
      );
    });

    test('rejects missing price and amountUsdc', () {
      expect(
        () => OrderIntent(
          tokenId: '12345',
          side: Side.buy,
          price: Decimal.zero,
          size: Decimal.zero,
          tickSize: validTickSize,
        ).validate(),
        throwsValidationException,
      );
    });

    test('rejects non-positive numeric order fields', () {
      void expectFieldRejected({
        required Decimal price,
        required Decimal size,
        Decimal? amountUsdc,
        required String field,
      }) {
        expect(
          () => OrderIntent(
            tokenId: '12345',
            side: Side.buy,
            price: price,
            size: size,
            amountUsdc: amountUsdc,
            tickSize: validTickSize,
          ).validate(),
          throwsA(
            isA<ValidationException>()
                .having((error) => error.field, 'field', field)
                .having(
                  (error) => error.message,
                  'message',
                  '$field must be positive',
                ),
          ),
        );
      }

      expectFieldRejected(
        price: Decimal.parse('-0.55'),
        size: Decimal.parse('10'),
        field: 'price',
      );
      expectFieldRejected(
        price: Decimal.parse('0.55'),
        size: Decimal.parse('-10'),
        field: 'size',
      );
      expectFieldRejected(
        price: Decimal.zero,
        size: Decimal.zero,
        amountUsdc: Decimal.parse('-25'),
        field: 'amount_usdc',
      );
    });

    test('rejects invalid tick_size values', () {
      for (final tick in <String>['', '0', '-0.01']) {
        expect(
          () => OrderIntent(
            tokenId: '12345',
            side: Side.buy,
            price: Decimal.parse('0.55'),
            size: Decimal.parse('10'),
            tickSize: TickSize(
              minimumTickSize: tick,
              minimumOrderSize: '1',
              tickSize: tick,
            ),
          ).validate(),
          throwsA(
            isA<ValidationException>()
                .having((error) => error.field, 'field', 'tick_size')
                .having(
                  (error) => error.message,
                  'message',
                  'valid tick_size required',
                ),
          ),
        );
      }
    });

    test('rejects negative fee_rate_bps', () {
      expect(
        () => OrderIntent(
          tokenId: '12345',
          side: Side.buy,
          price: Decimal.parse('0.55'),
          size: Decimal.parse('10'),
          tickSize: validTickSize,
          feeRateBps: -1,
        ).validate(),
        throwsValidationException,
      );
    });
  });

  group('LifecycleState.parse', () {
    test('accepts canonical names', () {
      expect(LifecycleState.parse('matched'), LifecycleState.matched);
      expect(LifecycleState.parse(' Live '), LifecycleState.live);
    });

    test('rejects unknown', () {
      expect(
        () => LifecycleState.parse('zombie'),
        throwsValidationException,
      );
    });
  });

  test('SignedOrder.toJson includes V2 fields when present', () {
    const order = SignedOrder(
      salt: '12345',
      maker: '0xabc',
      signer: '0xdef',
      taker: '0x000',
      tokenId: '999',
      makerAmount: '1000000',
      takerAmount: '5000000',
      side: Side.buy,
      signatureType: SignatureType.gnosisSafe,
      expiration: 0,
      nonce: 0,
      feeRateBps: 0,
      signature: '0xsig',
      timestamp: 1700000000,
      metadata: '0x0',
      builder: '0x0',
    );
    final json = order.toJson();
    expect(json['side'], 'BUY');
    expect(json['signatureType'], 2);
    expect(json['timestamp'], '1700000000');
    expect(json['metadata'], '0x0');
  });

  test('OrderResponse.fromJson decodes success and error variants', () {
    final ok = OrderResponse.fromJson(<String, dynamic>{
      'success': true,
      'order_id': 'O-1',
      'status': 'matched',
    });
    expect(ok.success, isTrue);
    expect(ok.orderId, 'O-1');

    final fail = OrderResponse.fromJson(<String, dynamic>{
      'success': false,
      'order_id': '',
      'status': 'rejected',
      'error_msg': 'price out of band',
    });
    expect(fail.success, isFalse);
    expect(fail.errorMessage, 'price out of band');
  });

  test('OrderResponse.fromJson decodes camel response aliases', () {
    final resp = OrderResponse.fromJson(<String, dynamic>{
      'success': true,
      'orderID': 'O-3',
      'status': 'matched',
      'transactionHash': '0xtx',
      'tradeIds': <String>['trade-1'],
    });

    expect(resp.transactionHash, '0xtx');
    expect(resp.transactionHashes, ['0xtx']);
    expect(resp.tradeIds, ['trade-1']);
  });

  test('OrderResponse.fromJson decodes transactionHashes alias', () {
    final resp = OrderResponse.fromJson(<String, dynamic>{
      'success': true,
      'orderID': 'O-2',
      'status': 'matched',
      'transactionHashes': <String>['0xtx'],
    });

    expect(resp.transactionHashes, ['0xtx']);
  });

  test('OrderResponse.fromJson stringifies numeric list aliases', () {
    final resp = OrderResponse.fromJson(<String, dynamic>{
      'success': true,
      'orderID': 'O-4',
      'status': 'matched',
      'transactionHashes': <Object>[1, '0xtx'],
      'tradeIDs': <Object>[2, 'trade-3'],
    });

    expect(resp.transactionHashes, ['1', '0xtx']);
    expect(resp.tradeIds, ['2', 'trade-3']);
  });
}
