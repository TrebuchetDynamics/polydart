/// Plain-Dart read-only pattern for a Flutter app.
///
/// This file intentionally imports no Flutter libraries. In an app, own this
/// repository from a Provider, bloc, Riverpod notifier, or State object and
/// call [dispose] from that owner's disposal hook.
///
/// Analyze: `dart analyze example/flutter_read_only.dart`
library;

import 'package:polydart/polydart.dart';

final class FlutterMarketReadRepository {
  FlutterMarketReadRepository({Polydart? client})
    : _client = client ?? Polydart.readOnly();

  final Polydart _client;

  Future<List<String>> searchEventTitles(String query) async {
    final results = await _client.gamma.search(
      SearchParams(query: query, limitPerType: 5),
    );
    return results.events
        .map((event) => event.title)
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
  }

  Future<String?> midpointForFirstTokenBySlug(String slug) async {
    final resolved = await _client.resolver.resolveBySlug(slug);
    final tokenIds = resolved?.tokenIds ?? const <String>[];
    if (tokenIds.isEmpty) return null;
    return _client.clob.midpoint(tokenIds.first);
  }

  void dispose() {
    _client.close();
  }
}

Future<void> main() async {
  final markets = FlutterMarketReadRepository();
  try {
    final titles = await markets.searchEventTitles('btc');
    for (final title in titles.take(3)) {
      // ignore: avoid_print
      print(title);
    }
  } finally {
    markets.dispose();
  }
}
