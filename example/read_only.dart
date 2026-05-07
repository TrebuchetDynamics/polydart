/// Read-only smoke example.
///
/// Search Gamma, fetch a CLOB book, resolve a slug, and enrich a market.
/// Run:  `dart run example/read_only.dart`
library;

import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();
  try {
    // 1. Gamma search.
    final search = await client.gamma.search(
      const SearchParams(query: 'btc', limitPerType: 3),
    );
    // ignore: avoid_print
    print('search: ${search.events.length} events, ${search.tags.length} tags');

    // 2. Resolve the first event's first market by slug.
    final firstEvent = search.events.isEmpty ? null : search.events.first;
    final firstMarket = firstEvent?.markets.isNotEmpty ?? false
        ? firstEvent!.markets.first
        : null;
    if (firstMarket != null) {
      final resolved = await client.resolver.resolveBySlug(firstMarket.slug);
      // ignore: avoid_print
      print(
        'resolved ${firstMarket.slug}: '
        'available=${resolved?.isAvailable} '
        'tokens=${resolved?.tokenIds.length}',
      );

      // 3. Enrich with CLOB data.
      final enriched = await client.discovery.enrichMarket(firstMarket);
      // ignore: avoid_print
      print(
        '  midpoint=${enriched.midpoint ?? "—"} '
        'spread=${enriched.spread ?? "—"} '
        'last=${enriched.lastPrice ?? "—"}',
      );

      // 4. Read the book directly via the bookreader helper.
      if (enriched.orderBook != null) {
        final reader = BookReader(enriched.orderBook!);
        // ignore: avoid_print
        print(
          '  bookreader best bid=${reader.bestBid?.price ?? "—"} '
          'best ask=${reader.bestAsk?.price ?? "—"}',
        );
      }
    }
  } finally {
    client.close();
  }
}
