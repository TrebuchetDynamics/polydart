/// Fluent OrderBuilder.
///
/// Mirrors the chainable pattern in `internal/orders/builder.go`. The
/// builder is mutable; call [build] to get an immutable [OrderIntent].
///
/// ```dart
/// final intent = OrderBuilder(tokenId: '12345', side: Side.buy)
///   .price('0.55')
///   .size('10')
///   .tickSize('0.01')
///   .feeRateBps(0)
///   .build();
/// ```
library;

import '../types/clob.dart';
import '../types/decimal.dart';
import '../types/enums.dart';
import 'order_intent.dart';

final class OrderBuilder {
  OrderBuilder({required String tokenId, required Side side})
    : _tokenId = tokenId,
      _side = side;

  final String _tokenId;
  final Side _side;
  Decimal _price = Decimal.zero;
  Decimal _size = Decimal.zero;
  Decimal? _amountUsdc;
  OrderType _orderType = OrderType.gtc;
  SignatureType _signatureType = SignatureType.eoa;
  TickSize _tickSize = const TickSize(
    minimumTickSize: '',
    minimumOrderSize: '1',
    tickSize: '',
  );
  bool _negRisk = false;
  int _feeRateBps = 0;
  int _nonce = 0;
  int _expiration = 0;
  String _funder = '';
  bool _postOnly = false;

  OrderBuilder price(String s) {
    _price = Decimal.parse(s);
    return this;
  }

  OrderBuilder size(String s) {
    _size = Decimal.parse(s);
    return this;
  }

  OrderBuilder amountUsdc(String s) {
    _amountUsdc = Decimal.parse(s);
    return this;
  }

  OrderBuilder orderType(OrderType t) {
    _orderType = t;
    return this;
  }

  OrderBuilder signatureType(SignatureType t) {
    _signatureType = t;
    return this;
  }

  OrderBuilder tickSize(String s) {
    _tickSize = TickSize(
      minimumTickSize: s,
      minimumOrderSize: _tickSize.minimumOrderSize,
      tickSize: s,
    );
    return this;
  }

  OrderBuilder minimumOrderSize(String s) {
    _tickSize = TickSize(
      minimumTickSize: _tickSize.minimumTickSize,
      minimumOrderSize: s,
      tickSize: _tickSize.tickSize,
    );
    return this;
  }

  OrderBuilder negRisk(bool v) {
    _negRisk = v;
    return this;
  }

  OrderBuilder feeRateBps(int r) {
    _feeRateBps = r;
    return this;
  }

  OrderBuilder nonce(int n) {
    _nonce = n;
    return this;
  }

  OrderBuilder expiration(int unix) {
    _expiration = unix;
    return this;
  }

  OrderBuilder funder(String addr) {
    _funder = addr;
    return this;
  }

  OrderBuilder postOnly(bool v) {
    _postOnly = v;
    return this;
  }

  OrderIntent build() {
    final intent = OrderIntent(
      tokenId: _tokenId,
      side: _side,
      price: _price,
      size: _size,
      amountUsdc: _amountUsdc,
      orderType: _orderType,
      signatureType: _signatureType,
      tickSize: _tickSize,
      negRisk: _negRisk,
      feeRateBps: _feeRateBps,
      nonce: _nonce,
      expiration: _expiration,
      funder: _funder,
      postOnly: _postOnly,
    );
    intent.validate();
    return intent;
  }
}
