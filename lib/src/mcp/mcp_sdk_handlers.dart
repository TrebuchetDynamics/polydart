/// Wires concrete read-only Polydart SDK clients into the safe MCP handler set.
///
/// Mirrors `pkg/mcp/sdk_handlers.go`. Nil clients are skipped so deployments
/// expose only the surfaces they have configured. Every wired tool is
/// read-only — health checks, Gamma search, Data API positions, CLOB order
/// books, and in-memory market-data snapshots. No credentialed or mutating
/// operation is reachable through these handlers.
library;

import 'dart:async';

import '../clob/clob_client.dart';
import '../dataapi/dataapi_client.dart';
import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../marketdata/marketdata_tracker.dart';
import 'mcp.dart';

/// Builds the safe read-only handler set backed by concrete SDK clients. Any
/// adapter already present on [config] wins over the SDK-derived one (matching
/// `mergeReadOnlyAdapters`). Mirrors `mcp.NewSDKReadOnlyHandlers`.
Map<String, McpToolHandler> newSdkReadOnlyMcpHandlers({
  McpHandlerConfig config = const McpHandlerConfig(),
  GammaClient? gamma,
  DataApiClient? data,
  ClobClient? clob,
}) {
  FutureOr<Object?> Function()? health;
  if (gamma != null || clob != null) {
    health = () async {
      final out = <String, String>{};
      if (gamma != null) {
        try {
          await gamma.health();
          out['gamma'] = 'ok';
        } catch (e) {
          out['gamma'] = 'error: $e';
        }
      }
      if (clob != null) {
        try {
          await clob.health();
          out['clob'] = 'ok';
        } catch (e) {
          out['clob'] = 'error: $e';
        }
      }
      return out;
    };
  }

  McpToolHandler? discoverSearch;
  if (gamma != null) {
    discoverSearch = (args) {
      final limit = _intArg(args, 'limit');
      return gamma.search(
        SearchParams(
          query: _stringArg(args, 'query'),
          limitPerType: limit > 0 ? limit : null,
        ),
      );
    };
  }

  McpToolHandler? dataPositions;
  if (data != null) {
    dataPositions = (args) => data.currentPositions(
      _stringArg(args, 'user'),
      limit: _intArg(args, 'limit'),
    );
  }

  McpToolHandler? orderBook;
  if (clob != null) {
    orderBook = (args) => clob.orderBook(_stringArg(args, 'token_id'));
  }

  final merged = _mergeReadOnlyAdapters(
    config.adapters,
    McpReadOnlyAdapters(
      health: health,
      discoverSearch: discoverSearch,
      dataPositions: dataPositions,
      orderBook: orderBook,
    ),
  );
  return newReadOnlyMcpHandlers(
    McpHandlerConfig(timeout: config.timeout, adapters: merged),
  );
}

/// Returns an MCP handler backed by an in-memory [MarketDataTracker]. It is
/// read-only: callers feed the tracker from their own websocket flow and MCP
/// only reads the latest snapshot. Returns null when [tracker] is null.
///
/// Mirrors `mcp.NewMarketDataSnapshotHandler`.
McpToolHandler? newMarketDataSnapshotMcpHandler(MarketDataTracker? tracker) {
  if (tracker == null) return null;
  return (args) {
    var assetId = _stringArg(args, 'token_id');
    if (assetId.isEmpty) assetId = _stringArg(args, 'asset_id');
    if (assetId.isEmpty) {
      throw ArgumentError('token_id is required');
    }
    final snapshot = tracker.snapshot(assetId);
    if (snapshot == null) {
      throw StateError('marketdata snapshot for $assetId is not available');
    }
    return snapshot;
  };
}

/// Base-wins merge of two adapter sets. Mirrors `mergeReadOnlyAdapters`.
McpReadOnlyAdapters _mergeReadOnlyAdapters(
  McpReadOnlyAdapters base,
  McpReadOnlyAdapters add,
) => McpReadOnlyAdapters(
  health: base.health ?? add.health,
  discoverSearch: base.discoverSearch ?? add.discoverSearch,
  dataPositions: base.dataPositions ?? add.dataPositions,
  orderBook: base.orderBook ?? add.orderBook,
  marketDataSnapshot: base.marketDataSnapshot ?? add.marketDataSnapshot,
);

String _stringArg(Map<String, Object?> args, String name) {
  final value = args[name];
  return value is String ? value : '';
}

int _intArg(Map<String, Object?> args, String name) {
  final value = args[name];
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
