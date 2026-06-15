import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test('StreamStats records lifecycle counters and JSON snapshot', () {
    final stats = StreamStats('market')
      ..setSubscriptions(assetIds: const <String>['token-1', 'token-2'])
      ..markConnected(DateTime.fromMillisecondsSinceEpoch(100000, isUtc: true))
      ..recordMessage(DateTime.fromMillisecondsSinceEpoch(101000, isUtc: true))
      ..recordDuplicate()
      ..recordInvalid()
      ..recordReconnect(
        DateTime.fromMillisecondsSinceEpoch(102000, isUtc: true),
      )
      ..markDisconnected(
        DateTime.fromMillisecondsSinceEpoch(103000, isUtc: true),
      );

    final snap = stats.snapshot();
    expect(snap.type, 'stream_stats');
    expect(snap.stream, 'market');
    expect(snap.state, 'disconnected');
    expect(snap.assetIds, const <String>['token-1', 'token-2']);
    expect(snap.messagesReceived, 1);
    expect(snap.duplicateMessages, 1);
    expect(snap.invalidMessages, 1);
    expect(snap.reconnects, 1);
    expect(snap.connectedAt, isNotNull);
    expect(snap.lastMessageAt, isNotNull);
    expect(snap.lastReconnectAt, isNotNull);
    expect(snap.disconnectedAt, isNotNull);

    expect(snap.toJson(), containsPair('type', 'stream_stats'));
    expect(
      snap.toJson(),
      containsPair('asset_ids', <String>['token-1', 'token-2']),
    );
  });

  test('StreamStatsSnapshot decodes snake and camel aliases', () {
    final snap = StreamStatsSnapshot.fromJson(const <String, dynamic>{
      'type': 'stream_stats',
      'stream': 'user',
      'state': 'connected',
      'assetIds': <String>['a'],
      'markets': <String>['m'],
      'messagesReceived': '2',
      'duplicateMessages': 3,
      'invalid_messages': 4,
      'reconnects': 5,
      'connectedAt': '1970-01-01T00:00:01.000Z',
    });

    expect(snap.stream, 'user');
    expect(snap.assetIds, const <String>['a']);
    expect(snap.markets, const <String>['m']);
    expect(snap.messagesReceived, 2);
    expect(snap.duplicateMessages, 3);
    expect(snap.invalidMessages, 4);
    expect(snap.reconnects, 5);
    expect(snap.connectedAt, DateTime.utc(1970, 1, 1, 0, 0, 1));
  });
}
