/// Typed request-for-quote (RFQ) models for future Polymarket RFQ integration.
///
/// Mirrors `pkg/rfq`. RFQ live submission is intentionally not implemented:
/// the module gives SDK consumers stable DTOs and validation so fixtures and
/// UI can be built before authenticated upstream behavior is captured from
/// reference clients. [RfqClient.submit] validates input and then refuses,
/// throwing a [SafetyException] — there is no live mutation path, consistent
/// with `docs/adr/0001-wallet-mediated-eoa-signing.md`.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';

/// Canonical RFQ side values. Mirrors `rfq.SideBuy`/`rfq.SideSell`.
const String rfqSideBuy = 'BUY';
const String rfqSideSell = 'SELL';

/// Optional attribution/debug context that does not affect the canonical RFQ
/// fields. Mirrors `rfq.Metadata`.
@immutable
final class RfqMetadata {
  const RfqMetadata({
    this.clientOrderId = '',
    this.builderCode = '',
    this.notes = '',
  });

  factory RfqMetadata.fromJson(Map<String, dynamic> json) => RfqMetadata(
    clientOrderId: _string(json, 'client_order_id', 'clientOrderId'),
    builderCode: _string(json, 'builder_code', 'builderCode'),
    notes: _string(json, 'notes'),
  );

  final String clientOrderId;
  final String builderCode;
  final String notes;

  /// True when no attribution context is present.
  bool get isEmpty =>
      clientOrderId.isEmpty && builderCode.isEmpty && notes.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (clientOrderId.isNotEmpty) 'client_order_id': clientOrderId,
    if (builderCode.isNotEmpty) 'builder_code': builderCode,
    if (notes.isNotEmpty) 'notes': notes,
  };
}

/// A typed RFQ intent. [amount] is an opaque decimal string so callers do not
/// lose precision before protocol-specific rounding rules are known. Mirrors
/// `rfq.Request`.
@immutable
final class RfqRequest {
  const RfqRequest({
    this.marketId = '',
    this.tokenId = '',
    this.side = '',
    this.amount = '',
    this.expiration,
    this.maker = '',
    this.metadata = const RfqMetadata(),
  });

  factory RfqRequest.fromJson(Map<String, dynamic> json) => RfqRequest(
    marketId: _string(json, 'market_id', 'marketId'),
    tokenId: _string(json, 'token_id', 'tokenId'),
    side: _string(json, 'side'),
    amount: _string(json, 'amount'),
    expiration: _dateTime(json['expiration']),
    maker: _string(json, 'maker'),
    metadata: _metadata(json['metadata']),
  );

  final String marketId;
  final String tokenId;
  final String side;
  final String amount;
  final DateTime? expiration;
  final String maker;
  final RfqMetadata metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'market_id': marketId,
    'token_id': tokenId,
    'side': side,
    'amount': amount,
    if (expiration != null) 'expiration': _formatDateTime(expiration!),
    if (maker.isNotEmpty) 'maker': maker,
    if (!metadata.isEmpty) 'metadata': metadata.toJson(),
  };
}

/// The future typed response shape for a received RFQ quote. Mirrors
/// `rfq.Quote`.
@immutable
final class RfqQuote {
  const RfqQuote({
    this.id = '',
    this.requestId = '',
    this.price = '',
    this.size = '',
    this.expiresAt,
    this.counterparty = '',
  });

  factory RfqQuote.fromJson(Map<String, dynamic> json) => RfqQuote(
    id: _string(json, 'id'),
    requestId: _string(json, 'request_id', 'requestId'),
    price: _string(json, 'price'),
    size: _string(json, 'size'),
    expiresAt: _dateTime(json['expires_at'] ?? json['expiresAt']),
    counterparty: _string(json, 'counterparty'),
  );

  final String id;
  final String requestId;
  final String price;
  final String size;
  final DateTime? expiresAt;
  final String counterparty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'request_id': requestId,
    'price': price,
    'size': size,
    if (expiresAt != null) 'expires_at': _formatDateTime(expiresAt!),
    if (counterparty.isNotEmpty) 'counterparty': counterparty,
  };
}

/// Reserved for future live submission responses. Mirrors `rfq.Response`.
@immutable
final class RfqResponse {
  const RfqResponse({
    this.requestId = '',
    this.status = '',
    this.quotes = const <RfqQuote>[],
  });

  factory RfqResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['quotes'];
    final quotes = (raw is List)
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => RfqQuote.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
        : const <RfqQuote>[];
    return RfqResponse(
      requestId: _string(json, 'request_id', 'requestId'),
      status: _string(json, 'status'),
      quotes: quotes,
    );
  }

  final String requestId;
  final String status;
  final List<RfqQuote> quotes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'request_id': requestId,
    'status': status,
    if (quotes.isNotEmpty)
      'quotes': quotes.map((q) => q.toJson()).toList(growable: false),
  };
}

/// Validates a request's stable fields without contacting upstream. Throws a
/// [ValidationException] on the first failure. [now] defaults to the wall
/// clock and is injectable for deterministic expiration checks.
///
/// Mirrors `rfq.ValidateRequest`.
void validateRfqRequest(RfqRequest req, {DateTime? now}) {
  if (req.marketId.trim().isEmpty && req.tokenId.trim().isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'market_id or token_id is required',
      field: 'market_id',
    );
  }
  if (!_isPositiveDecimalString(req.amount)) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be a positive decimal string',
      field: 'amount',
    );
  }
  final side = req.side.trim().toUpperCase();
  if (side != rfqSideBuy && side != rfqSideSell) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'side must be BUY or SELL',
      field: 'side',
    );
  }
  final expiration = req.expiration;
  if (expiration != null && !expiration.isAfter(now ?? DateTime.now())) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'expiration must be in the future',
      field: 'expiration',
    );
  }
}

@immutable
final class ComboMarket {
  const ComboMarket({
    required this.id,
    required this.conditionId,
    required this.positionIds,
    required this.slug,
    required this.title,
    required this.outcomes,
    required this.outcomePrices,
    required this.image,
    required this.volume,
    required this.tags,
  });

  factory ComboMarket.fromJson(Map<String, dynamic> json) => ComboMarket(
    id: json['id']?.toString() ?? '',
    conditionId: json['condition_id']?.toString() ?? '',
    positionIds: _stringList(json['position_ids']),
    slug: json['slug']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    outcomes: _stringList(json['outcomes']),
    outcomePrices: _stringList(json['outcome_prices']),
    image: json['image']?.toString() ?? '',
    volume: json['volume']?.toString() ?? '',
    tags: _stringList(json['tags']),
  );

  final String id;
  final String conditionId;
  final List<String> positionIds;
  final String slug;
  final String title;
  final List<String> outcomes;
  final List<String> outcomePrices;
  final String image;
  final String volume;
  final List<String> tags;
}

@immutable
final class ComboMarketsPage {
  const ComboMarketsPage({required this.markets, required this.nextCursor});

  factory ComboMarketsPage.fromJson(Map<String, dynamic> json) {
    final markets = json['markets'];
    final cursor = json['next_cursor'];
    return ComboMarketsPage(
      markets: markets is List
          ? markets
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (market) =>
                      ComboMarket.fromJson(market.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const <ComboMarket>[],
      nextCursor: cursor?.toString(),
    );
  }

  final List<ComboMarket> markets;
  final String? nextCursor;
}

/// RFQ client. Public catalog reads are supported; live submission is not.
final class RfqClient {
  const RfqClient({HttpTransport? transport}) : _transport = transport;

  static const String defaultBaseUrl = 'https://combos-rfq-api.polymarket.com';

  final HttpTransport? _transport;

  void close() => _transport?.close();

  Future<ComboMarketsPage> comboMarkets({
    int limit = 50,
    String? cursor,
    List<String> exclude = const <String>[],
  }) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    return _comboMarkets(limit, cursor, exclude);
  }

  Future<ComboMarketsPage> _comboMarkets(
    int limit,
    String? cursor,
    List<String> exclude,
  ) async {
    final transport =
        _transport ??
        HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));
    final excluded = exclude
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .join(',');
    try {
      final body = await transport.getJson(
        '/v1/rfq/combo-markets',
        query: <String, dynamic>{
          'limit': limit,
          if (cursor?.isNotEmpty == true) 'cursor': cursor,
          if (excluded.isNotEmpty) 'exclude': excluded,
        },
      );
      return ComboMarketsPage.fromJson(body);
    } finally {
      if (_transport == null) transport.close();
    }
  }

  /// Validates [req] and then refuses: a valid request throws a
  /// [SafetyException] ([ErrorCode.liveDisabled]); an invalid one throws a
  /// [ValidationException] first. There is no live mutation path. Mirrors
  /// `rfq.Client.Submit` returning `ErrSubmitUnsupported`.
  RfqResponse submit(RfqRequest req, {DateTime? now}) {
    validateRfqRequest(req, now: now);
    throw const SafetyException(
      code: ErrorCode.liveDisabled,
      message:
          'RFQ live submission is not supported; use validateRfqRequest and '
          'fixtures until upstream behavior is captured',
    );
  }
}

/// Strict positive-decimal check: rejects empty, signed (`+`/`-`), non-digit
/// (including exponents like `1e3`), multi-dot, and all-zero values. Mirrors
/// `rfq.isPositiveDecimalString`.
bool _isPositiveDecimalString(String value) {
  value = value.trim();
  if (value.isEmpty || value.startsWith('+') || value.startsWith('-')) {
    return false;
  }
  var seenDigit = false;
  var seenDot = false;
  var seenNonZero = false;
  for (final rune in value.runes) {
    if (rune == 0x2e) {
      // '.'
      if (seenDot) return false;
      seenDot = true;
    } else if (rune >= 0x30 && rune <= 0x39) {
      // '0'..'9'
      seenDigit = true;
      if (rune != 0x30) seenNonZero = true;
    } else {
      return false;
    }
  }
  return seenDigit && seenNonZero;
}

RfqMetadata _metadata(Object? raw) => raw is Map
    ? RfqMetadata.fromJson(raw.cast<String, dynamic>())
    : const RfqMetadata();

DateTime? _dateTime(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

String _formatDateTime(DateTime value) => value.toUtc().toIso8601String();

List<String> _stringList(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const <String>[];

String _string(Map<String, dynamic> json, String first, [String? second]) {
  final a = json[first];
  if (a != null && a.toString().isNotEmpty) return a.toString();
  if (second != null) {
    final b = json[second];
    if (b != null && b.toString().isNotEmpty) return b.toString();
  }
  return '';
}
