// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:polydart/src/dataapi/dataapi_types.dart';
import 'package:test/test.dart';

void main() {
  group('MetaHolder', () {
    test('decodes current holder proxyWallet and amount fields', () {
      final holder = MetaHolder.fromJson(<String, dynamic>{
        'proxyWallet': '0xholder',
        'amount': 7.5,
        'pnl': 1.25,
        'volume': 100,
      });

      expect(holder.address, '0xholder');
      expect(holder.shares, 7.5);
      expect(holder.pnl, 1.25);
      expect(holder.volume, 100);
    });
  });

  group('TotalMarketsTraded', () {
    test('falls back to current traded field', () {
      final total = TotalMarketsTraded.fromJson(<String, dynamic>{
        'user': '0xuser',
        'traded': 3,
      });

      expect(total.user, '0xuser');
      expect(total.marketsTraded, 3);
    });
  });

  group('OpenInterest', () {
    test('decodes current value field', () {
      final interest = OpenInterest.fromJson(<String, dynamic>{
        'market': '0xcondition',
        'value': 42.5,
      });

      expect(interest.market, '0xcondition');
      expect(interest.openValue, 42.5);
    });
  });

  group('LiveVolumeResponse', () {
    test('decodes current markets list and floating total', () {
      final volume = LiveVolumeResponse.fromJson(<String, dynamic>{
        'total': 15000.75,
        'markets': [
          <String, dynamic>{'market': '0xcondition', 'value': 10000.5},
          <String, dynamic>{'market': '0xother', 'value': 5000.25},
        ],
      });

      expect(volume.total, 15000.75);
      final markets = (volume as dynamic).markets as List<dynamic>;
      expect(markets, hasLength(2));
      expect(markets.first.market, '0xcondition');
      expect(markets.first.value, 10000.5);
      expect(markets.last.market, '0xother');
      expect(markets.last.value, 5000.25);
      expect(volume.events, isEmpty);
    });

    test('decodes first item when response is wrapped in a list', () {
      final volume = _liveVolumeFrom(<Object>[
        <String, dynamic>{
          'total': 42,
          'markets': [
            <String, dynamic>{'market': '0xcondition', 'value': 42},
          ],
        },
      ]);

      expect(volume.total, 42);
      final markets = (volume as dynamic).markets as List<dynamic>;
      expect(markets.single.market, '0xcondition');
      expect(markets.single.value, 42);
    });

    test('rejects malformed wrapped response candidates by index', () {
      expect(
        () => _liveVolumeFrom(<Object>[
          'not-a-live-volume-object',
          <String, dynamic>{'total': 42},
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Data API response[0]'),
          ),
        ),
      );
    });

    test('rejects malformed market candidates instead of dropping them', () {
      expect(
        () => _liveVolumeFrom(<String, dynamic>{
          'total': 42,
          'markets': [
            'not-a-market-object',
            <String, dynamic>{'market': '0xcondition', 'value': 42},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Data API live-volume.markets[0]'),
          ),
        ),
      );
    });
  });

  group('TotalValue', () {
    test('decodes object response form', () {
      final value = TotalValue.fromJson(<String, dynamic>{
        'user': '0xuser',
        'value': 1234.56,
        'timestamp': 1714000000,
      });

      expect(value.user, '0xuser');
      expect(value.value, 1234.56);
      expect(value.timestamp, '1714000000');
    });

    test('decodes first item when response is wrapped in a list', () {
      final value = _totalValueFrom(<Object>[
        <String, dynamic>{'user': '0xuser', 'value': 42},
      ]);

      expect(value.user, '0xuser');
      expect(value.value, 42);
      expect(value.timestamp, '');
    });

    test('uses default user for empty list response', () {
      final value = _totalValueFrom(const <Object>[], defaultUser: '0xuser');

      expect(value.user, '0xuser');
      expect(value.value, 0);
      expect(value.timestamp, '');
    });

    test('rejects malformed wrapped response candidates by index', () {
      expect(
        () => _totalValueFrom(<Object>[
          'not-a-total-value-object',
          <String, dynamic>{'user': '0xuser', 'value': 42},
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Data API response[0]'),
          ),
        ),
      );
    });
  });
}

LiveVolumeResponse _liveVolumeFrom(Object? raw) {
  final decode = LiveVolumeResponse.fromJson as dynamic;
  return decode(raw) as LiveVolumeResponse;
}

TotalValue _totalValueFrom(Object? raw, {String defaultUser = ''}) {
  final decode = TotalValue.fromJson as dynamic;
  if (defaultUser.isEmpty) {
    return decode(raw) as TotalValue;
  }
  return decode(raw, defaultUser: defaultUser) as TotalValue;
}
