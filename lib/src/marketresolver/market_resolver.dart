/// Resolves a Polymarket slug or id into the canonical token / condition ids
/// needed to place an order or read a book.
///
/// Mirrors the read-side of `pkg/marketresolver`. Crypto-specific helpers
/// (cryptoQueries, cryptoWindowSlug) are not ported in v0.1 — they're a
/// domain-specific overlay that consumers can build on top of this.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../gamma/gamma_client.dart';
import '../types/market.dart';

@immutable
final class ResolvedMarket {
  const ResolvedMarket({
    required this.conditionId,
    required this.questionId,
    required this.slug,
    required this.question,
    required this.outcomes,
    required this.tokenIds,
    required this.acceptingOrders,
    required this.closed,
    required this.archived,
    required this.enableOrderBook,
  });

  final String conditionId;
  final String questionId;
  final String slug;
  final String question;
  final List<String> outcomes;
  final List<String> tokenIds;
  final bool acceptingOrders;
  final bool closed;
  final bool archived;
  final bool enableOrderBook;

  /// True when [outcomes] and [tokenIds] line up and the market is taking
  /// orders — a strict precondition for live trading flows.
  bool get isAvailable =>
      acceptingOrders &&
      !closed &&
      !archived &&
      enableOrderBook &&
      outcomes.length == tokenIds.length &&
      tokenIds.isNotEmpty;

  /// Token id matching the supplied outcome label (case-insensitive).
  String? tokenIdFor(String outcomeLabel) {
    if (outcomes.length != tokenIds.length) return null;
    final target = outcomeLabel.toLowerCase().trim();
    for (var i = 0; i < outcomes.length; i++) {
      if (outcomes[i].toLowerCase().trim() == target) return tokenIds[i];
    }
    return null;
  }

  /// Token id for the canonical "yes/up" outcome, if present.
  String? get yesTokenId =>
      tokenIdFor('yes') ?? tokenIdFor('up') ?? tokenIdFor('over');

  /// Token id for the canonical "no/down" outcome, if present.
  String? get noTokenId =>
      tokenIdFor('no') ?? tokenIdFor('down') ?? tokenIdFor('under');
}

final class MarketResolver {
  MarketResolver({GammaClient? gamma}) : _gamma = gamma ?? GammaClient();

  final GammaClient _gamma;

  /// Closes the underlying Gamma transport.
  void close() => _gamma.close();

  /// Resolves by Gamma slug. Returns null if Gamma returns no record.
  Future<ResolvedMarket?> resolveBySlug(String slug) async {
    final m = await _gamma.marketBySlug(slug);
    if (m == null) return null;
    return _fromMarket(m);
  }

  /// Resolves by Gamma id.
  Future<ResolvedMarket?> resolveById(String id) async {
    final m = await _gamma.marketById(id);
    if (m == null) return null;
    return _fromMarket(m);
  }

  static ResolvedMarket _fromMarket(Market m) => ResolvedMarket(
    conditionId: m.conditionId,
    questionId: m.questionId,
    slug: m.slug,
    question: m.question,
    outcomes: m.outcomes,
    tokenIds: parseClobTokenIds(m.clobTokenIds),
    acceptingOrders: m.acceptingOrders,
    closed: m.closed,
    archived: m.archived,
    enableOrderBook: m.enableOrderBook,
  );
}

/// Parses Gamma's `clobTokenIds` field — a JSON-encoded array of strings
/// stored as a string. Tolerant of empty / `[]` / malformed input.
List<String> parseClobTokenIds(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '[]' || s == 'null') return const <String>[];

  try {
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList(growable: false);
    }
  } on FormatException {
    // fall through to manual parse for legacy payloads
  }

  final out = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;
  for (final code in s.runes) {
    final c = String.fromCharCode(code);
    if (c == '"') {
      inQuote = !inQuote;
      if (!inQuote) {
        if (buffer.isNotEmpty) out.add(buffer.toString());
        buffer.clear();
      }
    } else if (inQuote) {
      buffer.write(c);
    }
  }
  return out;
}
