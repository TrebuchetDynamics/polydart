class PaperOrder {
  const PaperOrder({
    required this.marketId,
    required this.tokenId,
    required this.price,
    required this.size,
  });

  factory PaperOrder.fromJson(Map<String, Object?> json) => PaperOrder(
    marketId: json['market_id']! as String,
    tokenId: json['token_id']! as String,
    price: (json['price']! as num).toDouble(),
    size: (json['size']! as num).toDouble(),
  );

  final String marketId;
  final String tokenId;
  final double price;
  final double size;

  Map<String, Object> toJson() => {
    'market_id': marketId,
    'token_id': tokenId,
    'price': price,
    'size': size,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperOrder &&
          marketId == other.marketId &&
          tokenId == other.tokenId &&
          price == other.price &&
          size == other.size;

  @override
  int get hashCode => Object.hash(marketId, tokenId, price, size);
}

class PaperFill {
  const PaperFill({
    required this.marketId,
    required this.tokenId,
    required this.price,
    required this.size,
    required this.live,
  });

  factory PaperFill.fromJson(Map<String, Object?> json) => PaperFill(
    marketId: json['market_id']! as String,
    tokenId: json['token_id']! as String,
    price: (json['price']! as num).toDouble(),
    size: (json['size']! as num).toDouble(),
    live: json['live']! as bool,
  );

  final String marketId;
  final String tokenId;
  final double price;
  final double size;
  final bool live;

  Map<String, Object> toJson() => {
    'market_id': marketId,
    'token_id': tokenId,
    'price': price,
    'size': size,
    'live': live,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperFill &&
          marketId == other.marketId &&
          tokenId == other.tokenId &&
          price == other.price &&
          size == other.size &&
          live == other.live;

  @override
  int get hashCode => Object.hash(marketId, tokenId, price, size, live);
}

class PaperPosition {
  const PaperPosition({
    required this.tokenId,
    required this.size,
    required this.cost,
  });

  factory PaperPosition.fromJson(Map<String, Object?> json) => PaperPosition(
    tokenId: json['token_id']! as String,
    size: (json['size']! as num).toDouble(),
    cost: (json['cost']! as num).toDouble(),
  );

  final String tokenId;
  final double size;
  final double cost;

  Map<String, Object> toJson() => {
    'token_id': tokenId,
    'size': size,
    'cost': cost,
  };

  PaperPosition add({required double size, required double cost}) =>
      PaperPosition(
        tokenId: tokenId,
        size: this.size + size,
        cost: this.cost + cost,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperPosition &&
          tokenId == other.tokenId &&
          size == other.size &&
          cost == other.cost;

  @override
  int get hashCode => Object.hash(tokenId, size, cost);
}

class PaperState {
  PaperState({
    required this.currency,
    required this.cash,
    Map<String, PaperPosition>? positions,
    List<PaperFill>? fills,
  }) : positions = positions ?? <String, PaperPosition>{},
       fills = fills ?? <PaperFill>[];

  PaperState.newState(String currency, double cash)
    : this(currency: currency, cash: cash);

  factory PaperState.fromJson(Map<String, Object?> json) => PaperState(
    currency: json['currency']! as String,
    cash: (json['cash']! as num).toDouble(),
    positions: (json['positions']! as Map<String, Object?>).map(
      (tokenId, value) => MapEntry(
        tokenId,
        PaperPosition.fromJson(value! as Map<String, Object?>),
      ),
    ),
    fills: (json['fills']! as List<Object?>)
        .map((value) => PaperFill.fromJson(value! as Map<String, Object?>))
        .toList(),
  );

  final String currency;
  double cash;
  final Map<String, PaperPosition> positions;
  final List<PaperFill> fills;

  PaperFill buy(PaperOrder order) {
    final cost = order.price * order.size;
    if (cost > cash) {
      throw StateError('insufficient paper cash');
    }

    cash -= cost;
    positions[order.tokenId] =
        positions[order.tokenId]?.add(size: order.size, cost: cost) ??
        PaperPosition(tokenId: order.tokenId, size: order.size, cost: cost);

    final fill = PaperFill(
      marketId: order.marketId,
      tokenId: order.tokenId,
      price: order.price,
      size: order.size,
      live: false,
    );
    fills.add(fill);
    return fill;
  }

  Map<String, Object> toJson() => {
    'currency': currency,
    'cash': cash,
    'positions': positions.map(
      (tokenId, position) => MapEntry(tokenId, position.toJson()),
    ),
    'fills': fills.map((fill) => fill.toJson()).toList(),
  };
}
