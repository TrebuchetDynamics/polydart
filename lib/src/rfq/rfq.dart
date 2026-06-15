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

/// A placeholder RFQ client. It validates inputs but refuses live submission
/// until endpoint shape, auth requirements, and safety gates are captured in
/// fixtures. Mirrors `rfq.Client`.
final class RfqClient {
  const RfqClient();

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

RfqMetadata _metadata(Object? raw) =>
    raw is Map ? RfqMetadata.fromJson(raw.cast<String, dynamic>()) : const RfqMetadata();

DateTime? _dateTime(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

String _formatDateTime(DateTime value) => value.toUtc().toIso8601String();

String _string(Map<String, dynamic> json, String first, [String? second]) {
  final a = json[first];
  if (a != null && a.toString().isNotEmpty) return a.toString();
  if (second != null) {
    final b = json[second];
    if (b != null && b.toString().isNotEmpty) return b.toString();
  }
  return '';
}
