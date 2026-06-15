/// JSON-friendly lifecycle and counter telemetry for Polymarket WebSocket streams.
///
/// Mirrors polygolem `internal/stream.StreamStats` / `StreamStatsSnapshot`.
library;

import 'package:meta/meta.dart';

/// Immutable snapshot emitted by SDK clients for stream health inspection.
@immutable
final class StreamStatsSnapshot {
  const StreamStatsSnapshot({
    required this.type,
    required this.stream,
    required this.state,
    this.assetIds = const <String>[],
    this.markets = const <String>[],
    this.messagesReceived = 0,
    this.duplicateMessages = 0,
    this.invalidMessages = 0,
    this.reconnects = 0,
    this.connectedAt,
    this.disconnectedAt,
    this.lastReconnectAt,
    this.lastMessageAt,
  });

  factory StreamStatsSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => StreamStatsSnapshot(
    type: _string(json, 'type'),
    stream: _string(json, 'stream'),
    state: _string(json, 'state'),
    assetIds: _stringList(json['asset_ids'] ?? json['assetIds']),
    markets: _stringList(json['markets']),
    messagesReceived: _int(
      json['messages_received'] ?? json['messagesReceived'],
    ),
    duplicateMessages: _int(
      json['duplicate_messages'] ?? json['duplicateMessages'],
    ),
    invalidMessages: _int(json['invalid_messages'] ?? json['invalidMessages']),
    reconnects: _int(json['reconnects']),
    connectedAt: _dateTime(json['connected_at'] ?? json['connectedAt']),
    disconnectedAt: _dateTime(
      json['disconnected_at'] ?? json['disconnectedAt'],
    ),
    lastReconnectAt: _dateTime(
      json['last_reconnect_at'] ?? json['lastReconnectAt'],
    ),
    lastMessageAt: _dateTime(json['last_message_at'] ?? json['lastMessageAt']),
  );

  final String type;
  final String stream;
  final String state;
  final List<String> assetIds;
  final List<String> markets;
  final int messagesReceived;
  final int duplicateMessages;
  final int invalidMessages;
  final int reconnects;
  final DateTime? connectedAt;
  final DateTime? disconnectedAt;
  final DateTime? lastReconnectAt;
  final DateTime? lastMessageAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'stream': stream,
    'state': state,
    if (assetIds.isNotEmpty) 'asset_ids': assetIds,
    if (markets.isNotEmpty) 'markets': markets,
    'messages_received': messagesReceived,
    'duplicate_messages': duplicateMessages,
    'invalid_messages': invalidMessages,
    'reconnects': reconnects,
    if (connectedAt != null) 'connected_at': _formatTime(connectedAt!),
    if (disconnectedAt != null) 'disconnected_at': _formatTime(disconnectedAt!),
    if (lastReconnectAt != null)
      'last_reconnect_at': _formatTime(lastReconnectAt!),
    if (lastMessageAt != null) 'last_message_at': _formatTime(lastMessageAt!),
  };
}

/// Mutable counters for one WebSocket stream kind (`market` or `user`).
final class StreamStats {
  StreamStats(String stream) : _stream = stream;

  final String _stream;
  String _state = 'idle';
  List<String> _assetIds = const <String>[];
  List<String> _markets = const <String>[];
  int _messages = 0;
  int _duplicates = 0;
  int _invalid = 0;
  int _reconnects = 0;
  DateTime? _connectedAt;
  DateTime? _disconnectedAt;
  DateTime? _lastReconnectAt;
  DateTime? _lastMessageAt;

  void setSubscriptions({
    List<String> assetIds = const <String>[],
    List<String> markets = const <String>[],
  }) {
    _assetIds = List<String>.unmodifiable(assetIds);
    _markets = List<String>.unmodifiable(markets);
  }

  void markConnected([DateTime? at]) {
    _state = 'connected';
    _connectedAt = _utc(at);
    _disconnectedAt = null;
  }

  void markDisconnected([DateTime? at]) {
    _state = 'disconnected';
    _disconnectedAt = _utc(at);
  }

  void recordMessage([DateTime? at]) {
    _messages += 1;
    _lastMessageAt = _utc(at);
  }

  void recordDuplicate() {
    _duplicates += 1;
  }

  void recordInvalid() {
    _invalid += 1;
  }

  void recordReconnect([DateTime? at]) {
    _reconnects += 1;
    _lastReconnectAt = _utc(at);
  }

  StreamStatsSnapshot snapshot() => StreamStatsSnapshot(
    type: 'stream_stats',
    stream: _stream,
    state: _state,
    assetIds: List<String>.unmodifiable(_assetIds),
    markets: List<String>.unmodifiable(_markets),
    messagesReceived: _messages,
    duplicateMessages: _duplicates,
    invalidMessages: _invalid,
    reconnects: _reconnects,
    connectedAt: _connectedAt,
    disconnectedAt: _disconnectedAt,
    lastReconnectAt: _lastReconnectAt,
    lastMessageAt: _lastMessageAt,
  );
}

DateTime _utc(DateTime? at) => (at ?? DateTime.now()).toUtc();

String _formatTime(DateTime value) => value.toUtc().toIso8601String();

DateTime? _dateTime(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _stringList(Object? value) => value is List
    ? List<String>.unmodifiable(value.map((v) => v.toString()))
    : const <String>[];
