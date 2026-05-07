/// Cursor and offset pagers.
///
/// Mirrors `pkg/pagination`. Both pagers expose a [Stream] so Flutter
/// consumers can iterate lazily — the stream emits items, not pages.
library;

import 'package:meta/meta.dart';

@immutable
final class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  /// Items returned by this page.
  final List<T> items;

  /// Cursor for the next page. `null` or empty signals the end of the
  /// sequence.
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Iterates a cursor-paginated endpoint.
final class CursorPager<T> {
  CursorPager({required Future<CursorPage<T>> Function(String? cursor) fetch})
    : _fetch = fetch;

  final Future<CursorPage<T>> Function(String? cursor) _fetch;

  /// Emits every item by walking pages until no cursor remains.
  Stream<T> all() async* {
    String? cursor;
    while (true) {
      final page = await _fetch(cursor);
      for (final item in page.items) {
        yield item;
      }
      if (!page.hasMore) return;
      cursor = page.nextCursor;
    }
  }

  /// Materializes at most [limit] items.
  Future<List<T>> take(int limit) async {
    if (limit <= 0) return const [];
    final out = <T>[];
    await for (final item in all()) {
      out.add(item);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Materializes the entire sequence into a list. Use carefully — the
  /// upstream may return many pages.
  Future<List<T>> toList() async => [await for (final item in all()) item];
}

/// Iterates an offset-paginated endpoint.
final class OffsetPager<T> {
  OffsetPager({
    required Future<List<T>> Function(int offset, int limit) fetch,
    this.pageSize = 50,
  }) : _fetch = fetch,
       assert(pageSize > 0, 'pageSize must be positive');

  final Future<List<T>> Function(int offset, int limit) _fetch;
  final int pageSize;

  Stream<T> all() async* {
    var offset = 0;
    while (true) {
      final batch = await _fetch(offset, pageSize);
      if (batch.isEmpty) return;
      for (final item in batch) {
        yield item;
      }
      if (batch.length < pageSize) return;
      offset += batch.length;
    }
  }

  Future<List<T>> take(int limit) async {
    if (limit <= 0) return const [];
    final out = <T>[];
    await for (final item in all()) {
      out.add(item);
      if (out.length >= limit) break;
    }
    return out;
  }
}
