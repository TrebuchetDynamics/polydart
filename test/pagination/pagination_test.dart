import 'dart:async';

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

    test('throws on repeated cursors instead of looping forever', () async {
      final pager = CursorPager<int>(
        fetch: (cursor) async =>
            CursorPage(items: [cursor?.length ?? 0], nextCursor: 'repeat'),
      );

      await expectLater(
        pager.toList(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('returned repeated cursor "repeat"'),
          ),
        ),
      );
    });
  });

  group('OffsetPager', () {
    test('rejects non-positive page size before fetching', () {
      expect(
        () => OffsetPager<int>(
          pageSize: 0,
          fetch: (offset, limit) async => <int>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => OffsetPager<int>(
          pageSize: -1,
          fetch: (offset, limit) async => <int>[],
        ),
        throwsArgumentError,
      );
    });

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

  group('streamPages', () {
    test(
      'streams non-empty cursor pages from an empty initial cursor',
      () async {
        final cursors = <String>[];

        final results = await streamPages<int>((cursor) async {
          cursors.add(cursor);
          return switch (cursor) {
            '' => const CursorPage(items: [1, 2], nextCursor: 'b'),
            'b' => const CursorPage(items: [], nextCursor: 'c'),
            'c' => const CursorPage(items: [3], nextCursor: ''),
            _ => throw StateError('unexpected cursor $cursor'),
          };
        }).toList();

        expect(cursors, ['', 'b', 'c']);
        expect(results.map((result) => result.items).toList(), [
          [1, 2],
          [3],
        ]);
        expect(results.every((result) => !result.hasError), isTrue);
      },
    );

    test('emits the first page error as the final result', () async {
      final error = StateError('cursor failed');
      var calls = 0;

      final results = await streamPages<int>((cursor) async {
        calls++;
        if (calls == 1) {
          return const CursorPage(items: [1], nextCursor: 'next');
        }
        throw error;
      }).toList();

      expect(results, hasLength(2));
      expect(results.first.items, [1]);
      expect(results.last.hasError, isTrue);
      expect(results.last.error, same(error));
    });

    test('reports repeated cursors instead of looping forever', () async {
      final results = await streamPages<int>((cursor) async {
        return CursorPage(items: [cursor.length], nextCursor: 'repeat');
      }).toList();

      expect(
        results
            .where((result) => !result.hasError)
            .map((result) => result.items)
            .toList(),
        [
          [0],
          [6],
        ],
      );
      expect(results.last.hasError, isTrue);
      expect(
        results.last.error,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('returned repeated cursor "repeat"'),
        ),
      );
    });
  });

  group('streamItems', () {
    test('flattens pages into item results', () async {
      final results = await streamItems<int>((cursor) async {
        return switch (cursor) {
          '' => const CursorPage(items: [1, 2], nextCursor: 'b'),
          'b' => const CursorPage(items: [3], nextCursor: ''),
          _ => throw StateError('unexpected cursor $cursor'),
        };
      }).toList();

      expect(results.map((result) => result.item).toList(), [1, 2, 3]);
      expect(results.every((result) => !result.hasError), isTrue);
    });

    test('emits the first page error as the final item result', () async {
      final error = StateError('item stream failed');
      var calls = 0;

      final results = await streamItems<int>((cursor) async {
        calls++;
        if (calls == 1) {
          return const CursorPage(items: [1, 2], nextCursor: 'next');
        }
        throw error;
      }).toList();

      expect(results.map((result) => result.item).toList(), [1, 2, null]);
      expect(results.last.hasError, isTrue);
      expect(results.last.error, same(error));
    });
  });

  group('collectAll', () {
    test('collects all cursor items', () async {
      final items = await collectAll<int>((cursor) async {
        return switch (cursor) {
          '' => const CursorPage(items: [1, 2], nextCursor: 'b'),
          'b' => const CursorPage(items: [3], nextCursor: ''),
          _ => throw StateError('unexpected cursor $cursor'),
        };
      });

      expect(items, [1, 2, 3]);
    });

    test(
      'throws the first cursor error instead of returning partial items',
      () async {
        final error = StateError('collect failed');
        var calls = 0;

        await expectLater(
          collectAll<int>((cursor) async {
            calls++;
            if (calls == 1) {
              return const CursorPage(items: [1, 2], nextCursor: 'next');
            }
            throw error;
          }),
          throwsA(same(error)),
        );
        expect(calls, 2);
      },
    );
  });

  group('collectOffset', () {
    test(
      'collects offset pages until count is shorter than the limit',
      () async {
        final offsets = <int>[];

        final items = await collectOffset<int>((offset, limit) async {
          offsets.add(offset);
          final remaining = 5 - offset;
          final count = remaining < limit ? remaining : limit;
          return OffsetPageResult(
            items: List.generate(count, (i) => offset + i),
            count: count,
          );
        }, 2);

        expect(offsets, [0, 2, 4]);
        expect(items, [0, 1, 2, 3, 4]);
      },
    );

    test(
      'throws the first offset error instead of returning partial items',
      () async {
        final error = StateError('offset failed');
        var calls = 0;

        await expectLater(
          collectOffset<int>((offset, limit) async {
            calls++;
            if (calls == 1) {
              return const OffsetPageResult(items: [1, 2], count: 2);
            }
            throw error;
          }, 2),
          throwsA(same(error)),
        );
        expect(calls, 2);
      },
    );

    test('rejects full empty pages instead of looping forever', () async {
      var calls = 0;

      await expectLater(
        collectOffset<int>((offset, limit) async {
          calls++;
          return const OffsetPageResult(items: [], count: 2);
        }, 2),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('reported a full page but returned no items'),
          ),
        ),
      );
      expect(calls, 1);
    });

    test(
      'rejects a full page count with fewer items before skipping offsets',
      () async {
        var calls = 0;

        await expectLater(
          collectOffset<int>((offset, limit) async {
            calls++;
            if (offset == 0) {
              return const OffsetPageResult(items: [0, 1], count: 3);
            }
            return OffsetPageResult(
              items: List.generate(limit, (i) => offset + i),
              count: limit,
            );
          }, 3),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('reported full page count 3 but returned 2 items'),
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  });

  group('batch', () {
    test('runs batches concurrently and preserves result order', () async {
      final release = Completer<void>();
      final started = <List<int>>[];

      final pending = batch<int, String>([1, 2, 3, 4, 5], 2, (items) async {
        started.add(items);
        if (started.length == 3 && !release.isCompleted) {
          release.complete();
        }
        await release.future;
        return items.join(',');
      });

      await release.future;
      final results = await pending;

      expect(started, [
        [1, 2],
        [3, 4],
        [5],
      ]);
      expect(results, ['1,2', '3,4', '5']);
    });

    test(
      'throws the first batch error and discards successful results',
      () async {
        final error = StateError('batch failed');

        await expectLater(
          batch<int, String>([1, 2, 3], 1, (items) async {
            if (items.single == 2) {
              throw error;
            }
            return '${items.single}';
          }),
          throwsA(same(error)),
        );
      },
    );

    test('rejects non-positive batch size before invoking work', () async {
      var calls = 0;

      await expectLater(
        batch<int, int>([1], 0, (items) async {
          calls++;
          return items.length;
        }),
        throwsArgumentError,
      );
      await expectLater(
        batch<int, int>([1], -1, (items) async {
          calls++;
          return items.length;
        }),
        throwsArgumentError,
      );
      expect(calls, 0);
    });
  });
}

extension on OffsetPager<int> {
  Future<List<int>> toListAsync() async => [await for (final v in all()) v];
}
