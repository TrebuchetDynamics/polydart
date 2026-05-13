/// CLOB write paths — order placement and cancellation.
///
/// Mirrors the auth-required POST / DELETE endpoints in
/// `internal/clob/orders.go` (placement) and the cancel surface from the
/// Polymarket Rust client. Every method is gated by [requireLive] so a
/// caller cannot accidentally hit live endpoints from a `read-only` or
/// `paper` client.
///
/// Endpoints:
///   * POST   /order        — place a signed order.
///   * DELETE /order        — cancel a single order by id.
///   * DELETE /orders       — cancel a batch of orders by id.
///   * DELETE /cancel-all   — cancel every open order for the API-key user.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../auth/l2.dart';
import '../errors/errors.dart';
import '../modes/modes.dart';
import '../orders/order_intent.dart';
import '../transport/http_transport.dart';
import '../types/enums.dart';

/// Wire payload for `POST /order`. Mirrors `sendOrderPayload` in polygolem.
@immutable
final class CreateOrderRequest {
  const CreateOrderRequest({
    required this.order,
    required this.owner,
    required this.orderType,
    this.postOnly = false,
    this.deferExec = false,
  });

  final SignedOrder order;
  final String owner;
  final OrderType orderType;
  final bool postOnly;
  final bool deferExec;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'order': order.toJson(),
      'owner': owner,
      'orderType': orderType.label,
      'postOnly': postOnly,
      'deferExec': deferExec,
    };
  }
}

/// Maximum batch size accepted by the upstream `POST /orders` endpoint.
const int maxBatchPostSize = 15;

/// Maximum cancellation batch size accepted by the upstream `DELETE /orders`
/// endpoint.
const int maxCancelBatchSize = 3000;

/// Response shape for `POST /orders`.
@immutable
final class BatchOrderResponse {
  const BatchOrderResponse({required this.orders});

  factory BatchOrderResponse.fromJsonList(List<dynamic> json) {
    return BatchOrderResponse(
      orders: json
          .whereType<Map<String, dynamic>>()
          .map(OrderResponse.fromJson)
          .toList(growable: false),
    );
  }

  final List<OrderResponse> orders;
}

/// Response shape for the cancel endpoints. Lists every order id that was
/// removed and a reason map for those that were not.
@immutable
final class CancelResponse {
  const CancelResponse({required this.canceled, required this.notCanceled});

  factory CancelResponse.fromJson(Map<String, dynamic> json) {
    final canceledRaw = json['canceled'];
    final canceled = canceledRaw is List
        ? canceledRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final notRaw = json['not_canceled'] ?? json['notCanceled'];
    final notCanceled = <String, String>{};
    if (notRaw is Map) {
      notRaw.forEach((k, v) => notCanceled[k.toString()] = v.toString());
    }
    return CancelResponse(canceled: canceled, notCanceled: notCanceled);
  }

  final List<String> canceled;
  final Map<String, String> notCanceled;
}

/// Live-mode CLOB writes. Held by [ClobClient] and exposed via its
/// `writes` getter.
final class ClobWrites {
  ClobWrites({
    required HttpTransport transport,
    required PolydartMode mode,
    required bool liveTradingEnabled,
    DateTime Function()? clock,
  }) : _transport = transport,
       _mode = mode,
       _liveTradingEnabled = liveTradingEnabled,
       _clock = clock ?? DateTime.now;

  final HttpTransport _transport;
  final PolydartMode _mode;
  final bool _liveTradingEnabled;
  final DateTime Function() _clock;

  /// Places a signed order via `POST /order`.
  ///
  /// [order] must already be signed (use the order signing helpers in
  /// `lib/src/orders/order_signing.dart` and the wallet signer of your
  /// choice). [owner] is the API-key id, returned by Polymarket's
  /// `/auth/api-key` flow.
  Future<OrderResponse> createOrder({
    required SignedOrder order,
    required String owner,
    required ApiKey apiKey,
    OrderType orderType = OrderType.gtc,
    bool postOnly = false,
    bool deferExec = false,
    String polyAddress = '',
  }) async {
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final req = CreateOrderRequest(
      order: order,
      owner: owner,
      orderType: orderType,
      postOnly: postOnly,
      deferExec: deferExec,
    );
    final body = req.toJson();
    final headers = _l2Headers(
      method: 'POST',
      path: '/order',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.postJson('/order', body, headers: headers);
    return OrderResponse.fromJson(resp);
  }

  /// Places a batch of signed orders via `POST /orders`.
  Future<BatchOrderResponse> createOrders({
    required List<CreateOrderRequest> requests,
    required ApiKey apiKey,
    String polyAddress = '',
  }) async {
    if (requests.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'requests must not be empty',
        field: 'requests',
      );
    }
    if (requests.length > maxBatchPostSize) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'requests exceeds maxBatchPostSize',
        field: 'requests',
      );
    }
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final body = requests.map((r) => r.toJson()).toList(growable: false);
    final headers = _l2Headers(
      method: 'POST',
      path: '/orders',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.postJsonList(
      '/orders',
      body,
      headers: headers,
    );
    return BatchOrderResponse.fromJsonList(resp);
  }

  /// Cancels a single open order by id. Returns the cancel report.
  Future<CancelResponse> cancelOrder({
    required String orderId,
    required ApiKey apiKey,
    String polyAddress = '',
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'orderId is required',
        field: 'orderId',
      );
    }
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final body = <String, dynamic>{'orderID': id};
    final headers = _l2Headers(
      method: 'DELETE',
      path: '/order',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.delete(
      '/order',
      body: body,
      headers: headers,
    );
    return CancelResponse.fromJson(resp);
  }

  /// Cancels multiple open orders by id in a single request.
  Future<CancelResponse> cancelOrders({
    required List<String> orderIds,
    required ApiKey apiKey,
    String polyAddress = '',
  }) async {
    final ids = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'orderIds must not be empty',
        field: 'orderIds',
      );
    }
    if (ids.length > maxCancelBatchSize) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'orderIds exceeds max cancel batch size',
        field: 'orderIds',
      );
    }
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final body = <String, dynamic>{'orderIDs': ids};
    final headers = _l2Headers(
      method: 'DELETE',
      path: '/orders',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.delete(
      '/orders',
      body: body,
      headers: headers,
    );
    return CancelResponse.fromJson(resp);
  }

  /// Cancels every open order for the authenticated user.
  Future<CancelResponse> cancelAllOrders({
    required ApiKey apiKey,
    String polyAddress = '',
  }) async {
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final headers = _l2Headers(
      method: 'DELETE',
      path: '/cancel-all',
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.delete('/cancel-all', headers: headers);
    return CancelResponse.fromJson(resp);
  }

  /// Cancels every open order matching a market or asset filter. At least
  /// one of [market] or [assetId] must be supplied. Mirrors
  /// `internal/clob/orders.go::CancelMarket`.
  Future<CancelResponse> cancelMarket({
    required ApiKey apiKey,
    String market = '',
    String assetId = '',
    String polyAddress = '',
  }) async {
    final m = market.trim();
    final a = assetId.trim();
    if (m.isEmpty && a.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'market or assetId filter is required',
      );
    }
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final body = <String, String>{};
    if (m.isNotEmpty) body['market'] = m;
    if (a.isNotEmpty) body['asset_id'] = a;
    final headers = _l2Headers(
      method: 'DELETE',
      path: '/cancel-market-orders',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    final resp = await _transport.delete(
      '/cancel-market-orders',
      body: body,
      headers: headers,
    );
    return CancelResponse.fromJson(resp);
  }

  /// Sends the live CLOB heartbeat used by long-running makers.
  Future<void> heartbeat({
    required ApiKey apiKey,
    String heartbeatId = '',
    String polyAddress = '',
  }) async {
    requireLive(_mode, liveTradingEnabled: _liveTradingEnabled);
    final id = heartbeatId.trim();
    final body = <String, dynamic>{'heartbeat_id': id.isEmpty ? null : id};
    final headers = _l2Headers(
      method: 'POST',
      path: '/v1/heartbeats',
      body: body,
      apiKey: apiKey,
      polyAddress: polyAddress,
    );
    await _transport.postJson('/v1/heartbeats', body, headers: headers);
  }

  Map<String, String> _l2Headers({
    required String method,
    required String path,
    required ApiKey apiKey,
    Object? body,
    String polyAddress = '',
  }) {
    final ts = (_clock().millisecondsSinceEpoch / 1000).floor();
    final compact = body == null ? null : compactJson(jsonEncode(body));
    final headers = buildL2Headers(
      apiKey: apiKey,
      timestamp: ts,
      method: method,
      path: path,
      body: compact,
    );
    final address = polyAddress.trim();
    if (address.isNotEmpty) {
      headers['POLY_ADDRESS'] = address;
    }
    return headers;
  }
}
