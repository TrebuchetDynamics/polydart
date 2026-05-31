import 'dart:convert';

import 'package:polydart/src/stream/dedup.dart';
import 'package:test/test.dart';

List<int> _enc(Map<String, dynamic> m) => utf8.encode(jsonEncode(m));

void main() {
  group('Deduplicator.process', () {
    test('first book message with hash is new', () {
      final dedup = Deduplicator(size: 64, ttl: const Duration(seconds: 1));
      final msg = _enc(<String, dynamic>{
        'event_type': 'book',
        'hash': 'abc',
        'market': 'm1',
      });
      expect(dedup.process(msg), isTrue);
      expect(dedup.inCount, 1);
      expect(dedup.outCount, 1);
      expect(dedup.dupCount, 0);
    });

    test('same hash within TTL is a duplicate', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 64,
        ttl: const Duration(seconds: 5),
        clock: () => fixed,
      );
      final msg = _enc(<String, dynamic>{'event_type': 'book', 'hash': 'abc'});
      expect(dedup.process(msg), isTrue);
      expect(dedup.process(msg), isFalse);
      expect(dedup.inCount, 2);
      expect(dedup.outCount, 1);
      expect(dedup.dupCount, 1);
    });

    test('same hash after TTL expiry is treated as new', () {
      var nowMs = 1700000000000;
      final dedup = Deduplicator(
        size: 64,
        ttl: const Duration(milliseconds: 100),
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      final msg = _enc(<String, dynamic>{'event_type': 'book', 'hash': 'h1'});
      expect(dedup.process(msg), isTrue);
      nowMs += 200;
      expect(dedup.process(msg), isTrue);
      expect(dedup.outCount, 2);
      expect(dedup.dupCount, 0);
    });

    test('size cap evicts oldest live key when no keys have expired', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 1,
        ttl: const Duration(minutes: 5),
        clock: () => fixed,
      );
      final first = _enc(<String, dynamic>{'event_type': 'book', 'hash': 'h1'});
      final second = _enc(<String, dynamic>{'event_type': 'book', 'hash': 'h2'});

      expect(dedup.process(first), isTrue);
      expect(dedup.process(second), isTrue);
      expect(dedup.process(first), isTrue);
      expect(dedup.outCount, 3);
      expect(dedup.dupCount, 0);
    });

    test('empty bytes are counted as new (no key)', () {
      final dedup = Deduplicator(size: 16, ttl: const Duration(seconds: 1));
      expect(dedup.process(const <int>[]), isTrue);
      expect(dedup.inCount, 1);
      expect(dedup.outCount, 1);
    });

    test('unparseable payload is counted as new (no key)', () {
      final dedup = Deduplicator(size: 16, ttl: const Duration(seconds: 1));
      expect(dedup.process(utf8.encode('not json')), isTrue);
      expect(dedup.inCount, 1);
      expect(dedup.outCount, 1);
      expect(dedup.dupCount, 0);
    });

    test('price_change uses hash key when present', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 16,
        ttl: const Duration(seconds: 1),
        clock: () => fixed,
      );
      final msg = _enc(<String, dynamic>{
        'event_type': 'price_change',
        'hash': 'pcH',
        'market': 'm1',
        'timestamp': 't1',
      });
      expect(dedup.process(msg), isTrue);
      expect(dedup.process(msg), isFalse);
    });

    test('price_change falls back to market+timestamp when hash absent', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 16,
        ttl: const Duration(seconds: 1),
        clock: () => fixed,
      );
      final msg = _enc(<String, dynamic>{
        'event_type': 'price_change',
        'market': 'm1',
        'timestamp': 't1',
      });
      expect(dedup.process(msg), isTrue);
      expect(dedup.process(msg), isFalse);
    });

    test('last_trade_price keys on asset+price+size', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 16,
        ttl: const Duration(seconds: 1),
        clock: () => fixed,
      );
      final msg = _enc(<String, dynamic>{
        'event_type': 'last_trade_price',
        'asset_id': 'a1',
        'price': '0.55',
        'size': '10',
      });
      expect(dedup.process(msg), isTrue);
      expect(dedup.process(msg), isFalse);
      expect(dedup.dupCount, 1);
    });

    test('reset clears state and counters', () {
      final fixed = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final dedup = Deduplicator(
        size: 8,
        ttl: const Duration(seconds: 1),
        clock: () => fixed,
      );
      final msg = _enc(<String, dynamic>{'event_type': 'book', 'hash': 'h'});
      dedup.process(msg);
      dedup.process(msg);
      dedup.reset();
      expect(dedup.inCount, 0);
      expect(dedup.outCount, 0);
      expect(dedup.dupCount, 0);
      expect(dedup.process(msg), isTrue);
    });
  });

  group('splitArray', () {
    test('returns each element as bytes when given a JSON array', () {
      final raw = utf8.encode(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'event_type': 'book', 'hash': 'h1'},
          <String, dynamic>{'event_type': 'book', 'hash': 'h2'},
        ]),
      );
      final parts = splitArray(raw);
      expect(parts, hasLength(2));
      final first = jsonDecode(utf8.decode(parts[0])) as Map<String, dynamic>;
      expect(first['hash'], 'h1');
    });

    test('returns empty when input is a JSON object', () {
      final raw = utf8.encode(jsonEncode(<String, dynamic>{'a': 1}));
      expect(splitArray(raw), isEmpty);
    });

    test('returns empty for unparseable bytes', () {
      expect(splitArray(utf8.encode('garbage')), isEmpty);
    });

    test('returns empty for empty input', () {
      expect(splitArray(const <int>[]), isEmpty);
    });
  });
}
