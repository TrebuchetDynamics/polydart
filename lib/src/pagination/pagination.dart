/// Cursor and offset pagers.
///
/// Mirrors `pkg/pagination`. Both pagers expose a [Stream] so Flutter
/// consumers can iterate lazily — the stream emits items, not pages.
library;

import 'dart:async';

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

/// Fetches one page of cursor-based data.
///
/// The first call receives an empty cursor. Returning a [CursorPage] with a
/// `null` or empty [CursorPage.nextCursor] ends iteration.
typedef Page<T> = Future<CursorPage<T>> Function(String cursor);

/// A single page emitted by [streamPages].
@immutable
final class StreamResult<T> {
  const StreamResult.items(this.items) : error = null, stackTrace = null;

  const StreamResult.error(Object this.error, [this.stackTrace])
    : items = const [];

  final List<T> items;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasError => error != null;
}

/// A single item emitted by [streamItems].
@immutable
final class ItemResult<T> {
  const ItemResult.item(T this.item) : error = null, stackTrace = null;

  const ItemResult.error(Object this.error, [this.stackTrace]) : item = null;

  final T? item;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasError => error != null;
}

/// Streams non-empty cursor pages until the next cursor is empty.
///
/// If [pageFn] throws, the error is emitted as the final [StreamResult].
Stream<StreamResult<T>> streamPages<T>(Page<T> pageFn) async* {
  var cursor = '';
  while (true) {
    final CursorPage<T> page;
    try {
      page = await pageFn(cursor);
    } catch (error, stackTrace) {
      yield StreamResult<T>.error(error, stackTrace);
      return;
    }

    if (page.items.isNotEmpty) {
      yield StreamResult<T>.items(page.items);
    }
    if (!page.hasMore) return;
    cursor = page.nextCursor!;
  }
}

/// Streams individual items from all cursor pages.
///
/// If [pageFn] throws, the error is emitted as the final [ItemResult].
Stream<ItemResult<T>> streamItems<T>(Page<T> pageFn) async* {
  await for (final result in streamPages(pageFn)) {
    if (result.hasError) {
      yield ItemResult<T>.error(result.error!, result.stackTrace);
      return;
    }
    for (final item in result.items) {
      yield ItemResult<T>.item(item);
    }
  }
}

/// Collects every cursor item.
///
/// Throws the first page error and does not return partial results.
Future<List<T>> collectAll<T>(Page<T> pageFn) async {
  final items = <T>[];
  await for (final result in streamPages(pageFn)) {
    if (result.hasError) {
      _throwWithStackTrace(result.error!, result.stackTrace);
    }
    items.addAll(result.items);
  }
  return items;
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

/// Result from a single offset page fetch.
@immutable
final class OffsetPageResult<T> {
  const OffsetPageResult({required this.items, required this.count});

  /// Items returned by this page.
  final List<T> items;

  /// Count returned by the endpoint. A value lower than the requested limit
  /// ends iteration.
  final int count;
}

/// Fetches one page of offset-based data.
typedef OffsetPage<T> =
    Future<OffsetPageResult<T>> Function(int offset, int limit);

/// Collects every offset item.
///
/// Throws the first page error and does not return partial results.
Future<List<T>> collectOffset<T>(OffsetPage<T> pageFn, int limit) async {
  if (limit <= 0) {
    throw ArgumentError.value(limit, 'limit', 'must be positive');
  }

  final items = <T>[];
  var offset = 0;
  while (true) {
    final OffsetPageResult<T> page;
    try {
      page = await pageFn(offset, limit);
    } catch (error, stackTrace) {
      _throwWithStackTrace(error, stackTrace);
    }

    items.addAll(page.items);
    final nextOffset = _nextOffsetOrDone(offset, limit, page);
    if (nextOffset == null) return items;
    offset = nextOffset;
  }
}

int? _nextOffsetOrDone<T>(int offset, int limit, OffsetPageResult<T> page) {
  if (page.count < 0) {
    throw StateError('Offset page count must be non-negative.');
  }
  if (page.count < limit) return null;
  if (page.items.isEmpty) {
    throw StateError(
      'Offset page at offset $offset reported a full page but returned no items.',
    );
  }
  return offset + limit;
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

/// Splits [items] into chunks and runs [fn] for each chunk concurrently.
///
/// Results are returned in input chunk order. Throws the first batch error and
/// does not return partial results.
Future<List<R>> batch<T, R>(
  Iterable<T> items,
  int maxBatchSize,
  FutureOr<R> Function(List<T> items) fn,
) async {
  if (maxBatchSize <= 0) {
    throw ArgumentError.value(maxBatchSize, 'maxBatchSize', 'must be positive');
  }

  final materialized = items.toList(growable: false);
  if (materialized.isEmpty) return <R>[];

  final batches = <List<T>>[];
  for (var start = 0; start < materialized.length; start += maxBatchSize) {
    final end = start + maxBatchSize > materialized.length
        ? materialized.length
        : start + maxBatchSize;
    batches.add(materialized.sublist(start, end));
  }

  final results = await Future.wait<_BatchResult<R>>([
    for (final batchItems in batches) _runBatch<T, R>(batchItems, fn),
  ]);

  final out = <R>[];
  for (final result in results) {
    if (result.hasError) {
      _throwWithStackTrace(result.error!, result.stackTrace);
    }
    out.add(result.value);
  }
  return out;
}

Future<_BatchResult<R>> _runBatch<T, R>(
  List<T> items,
  FutureOr<R> Function(List<T> items) fn,
) async {
  try {
    return _BatchResult<R>.value(await fn(items));
  } catch (error, stackTrace) {
    return _BatchResult<R>.error(error, stackTrace);
  }
}

@immutable
final class _BatchResult<R> {
  const _BatchResult.value(R value)
    : _value = value,
      error = null,
      stackTrace = null;

  const _BatchResult.error(Object this.error, this.stackTrace) : _value = null;

  final R? _value;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasError => error != null;

  R get value => _value as R;
}

Never _throwWithStackTrace(Object error, StackTrace? stackTrace) {
  Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
}
