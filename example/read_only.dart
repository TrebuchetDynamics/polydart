/// Smoke example: search for liquid markets and print their slugs.
///
/// Run: `dart run example/read_only.dart`
library;

import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();
  try {
    final result = await client.gamma.search(
      const SearchParams(query: 'btc 5m', limitPerType: 5),
    );
    // ignore: avoid_print
    print('events=${result.events.length} tags=${result.tags.length}');
    for (final e in result.events.take(5)) {
      // ignore: avoid_print
      print('  - ${e.slug.padRight(40)} liquidity=${e.liquidity}');
    }
  } finally {
    client.close();
  }
}
