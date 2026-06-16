// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:polydart/src/dataapi/dataapi_types.dart';
import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

void main() {
  group('Position.toJson', () {
    test('round-trips through fromJson on canonical keys', () {
      const p = Position(
        tokenId: 'tok',
        conditionId: 'cond',
        marketId: 'mkt',
        side: 'YES',
        avgPrice: 0.5,
        size: 100,
        currentPrice: 0.6,
        unrealizedPnl: 9,
        eventId: 'ev',
        percentRealized: 1.5,
        outcomeIndex: 2,
        redeemable: true,
      );
      final back = Position.fromJson(p.toJson());
      expect(back.tokenId, 'tok');
      expect(back.conditionId, 'cond');
      expect(back.marketId, 'mkt');
      expect(back.side, 'YES');
      expect(back.currentPrice, 0.6);
      expect(back.unrealizedPnl, 9);
      expect(back.percentRealized, 1.5);
      expect(back.outcomeIndex, 2);
      expect(back.redeemable, isTrue);
    });

    test('omits empty market/side and zero unrealizedPnl (Go omitempty)', () {
      const p = Position(
        tokenId: 't',
        conditionId: 'c',
        marketId: '',
        side: '',
        avgPrice: 0,
        size: 0,
        currentPrice: 0,
        unrealizedPnl: 0,
      );
      final json = p.toJson();
      expect(json.containsKey('market'), isFalse);
      expect(json.containsKey('side'), isFalse);
      expect(json.containsKey('unrealizedPnl'), isFalse);
      // Encodes without throwing.
      expect(() => jsonEncode(json), returnsNormally);
    });
  });

  group('SearchResponse.toJson', () {
    test('encodes and round-trips nested events/tags/profiles/pagination', () {
      final resp = SearchResponse.fromJson(<String, dynamic>{
        'events': [
          <String, dynamic>{'id': 'ev-1', 'title': 'BTC up?'},
        ],
        'tags': [
          <String, dynamic>{
            'id': 't1',
            'label': 'Crypto',
            'slug': 'crypto',
            'event_count': 5,
          },
        ],
        'profiles': [
          <String, dynamic>{
            'id': 'p1',
            'name': 'alice',
            'proxyWallet': '0xabc',
            'profileImage': 'img',
          },
        ],
        'pagination': <String, dynamic>{'hasMore': true, 'totalResults': 9},
      });

      // The whole structure marshals without throwing.
      final encoded = jsonEncode(resp.toJson());
      final back = SearchResponse.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(back.events.single.raw['id'], 'ev-1');
      expect(back.events.single.raw['title'], 'BTC up?');
      expect(back.tags.single.label, 'Crypto');
      expect(back.tags.single.eventCount, 5);
      expect(back.profiles.single.name, 'alice');
      expect(back.profiles.single.proxyWallet, '0xabc');
      expect(back.pagination.hasMore, isTrue);
      expect(back.pagination.totalResults, 9);
    });

    test('serializes a profile optimized image and dates', () {
      final profile = Profile.fromJson(<String, dynamic>{
        'id': 'p1',
        'name': 'alice',
        'createdAt': '2026-01-02T03:04:05Z',
        'profileImageOptimized': <String, dynamic>{
          'id': 'img-1',
          'imageUrlOptimized': 'https://x/opt.png',
        },
      });
      final json = profile.toJson();
      expect(() => jsonEncode(json), returnsNormally);
      final back = Profile.fromJson(json);
      expect(back.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(
        back.profileImageOptimized!.imageUrlOptimized,
        'https://x/opt.png',
      );
    });
  });
}
