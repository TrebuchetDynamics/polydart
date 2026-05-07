import 'package:polydart/src/pagination/pagination.dart';
import 'package:test/test.dart';

void main() {
  group('CursorPager', () {
    test('walks pages until cursor is empty', () async {
      final pages = <CursorPage<int>>[
        const CursorPage(items: [1, 2], nextCursor: 'b'),
        const CursorPage(items: [3, 4], nextCursor: 'c'),
        const CursorPage(items: [5], nextCursor: null),
      ];
      var i = 0;
      final pager = CursorPager<int>(fetch: (cursor) async => pages[i++]);
      expect(await pager.toList(), [1, 2, 3, 4, 5]);
      expect(i, 3);
    });

    test('take stops early', () async {
      var calls = 0;
      final pager = CursorPager<int>(
        fetch: (cursor) async {
          calls++;
          return CursorPage(
            items: List.generate(10, (idx) => idx + (calls - 1) * 10),
            nextCursor: 'next',
          );
        },
      );
      final first5 = await pager.take(5);
      expect(first5, [0, 1, 2, 3, 4]);
      expect(calls, 1);
    });

    test('empty cursor short-circuits', () async {
      final pager = CursorPager<int>(
        fetch: (cursor) async => const CursorPage(items: [], nextCursor: ''),
      );
      expect(await pager.toList(), isEmpty);
    });
  });

  group('OffsetPager', () {
    test('walks until short page', () async {
      final pager = OffsetPager<int>(
        fetch: (offset, limit) async {
          if (offset >= 5) return const [];
          final end = (offset + limit).clamp(0, 5);
          return List.generate(end - offset, (i) => offset + i);
        },
        pageSize: 3,
      );
      expect(await pager.toListAsync(), [0, 1, 2, 3, 4]);
    });

    test('take limits items', () async {
      final pager = OffsetPager<int>(
        fetch: (offset, limit) async => List.generate(limit, (i) => offset + i),
      );
      expect(await pager.take(7), [0, 1, 2, 3, 4, 5, 6]);
    });
  });
}

extension on OffsetPager<int> {
  Future<List<int>> toListAsync() async => [await for (final v in all()) v];
}
