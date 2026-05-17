/// Network-tagged smoke test against the real Polymarket Gamma API.
///
/// Disabled by default — opt in with:
///   dart test --tags network
@Tags(['network'])
library;

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test('search returns events for a common query', () async {
    final client = Polydart.readOnly();
    try {
      final r = await client.gamma.search(
        const SearchParams(query: 'btc', limitPerType: 3),
      );
      expect(r.events, isNotEmpty);
    } finally {
      client.close();
    }
  });

  test('search finds the Fed decision event', () async {
    final client = Polydart.readOnly();
    try {
      final r = await client.gamma.search(
        const SearchParams(query: 'fed decision in june', limitPerType: 10),
      );
      final event = r.events.firstWhere(
        (event) => event.slug == 'fed-decision-in-june-825',
      );
      expect(event.id, '101772');
      expect(event.title, 'Fed Decision in June?');
      expect(event.markets, hasLength(5));
    } finally {
      client.close();
    }
  });
}
