import 'package:polydart/src/gamma/gamma_params.dart';
import 'package:test/test.dart';

void main() {
  group('GetMarketsParams.toQuery', () {
    test('default emits empty map', () {
      expect(const GetMarketsParams().toQuery(), <String, dynamic>{});
    });

    test('skips zero limit/offset', () {
      const p = GetMarketsParams(limit: 0, offset: 0);
      expect(p.toQuery(), isEmpty);
    });

    test('encodes scalar filters', () {
      const p = GetMarketsParams(
        limit: 10,
        offset: 5,
        order: 'volume24hr',
        ascending: false,
        closed: false,
        active: true,
        tagId: 7,
        liquidityNumMin: 1000,
        volumeNumMax: 99999,
      );
      final q = p.toQuery();
      expect(q['limit'], '10');
      expect(q['offset'], '5');
      expect(q['order'], 'volume24hr');
      expect(q['ascending'], 'false');
      expect(q['closed'], 'false');
      expect(q['active'], 'true');
      expect(q['tag_id'], '7');
      expect(q['liquidity_num_min'], '1000.0');
      expect(q['volume_num_max'], '99999.0');
    });

    test('list filters preserved as Iterable', () {
      const p = GetMarketsParams(
        slug: ['btc-1', 'btc-2'],
        conditionIds: ['0xabc'],
      );
      final q = p.toQuery();
      expect(q['slug'], ['btc-1', 'btc-2']);
      expect(q['condition_ids'], ['0xabc']);
    });
  });

  group('SearchParams.toQuery', () {
    test('q always present', () {
      const p = SearchParams(query: 'btc 5m');
      expect(p.toQuery(), {'q': 'btc 5m'});
    });

    test('full set encoded', () {
      const p = SearchParams(
        query: 'eth',
        limitPerType: 5,
        page: 1,
        eventsTag: ['ethereum'],
        eventsStatus: 'active',
        ascending: true,
        sort: 'volume',
        searchProfiles: false,
      );
      final q = p.toQuery();
      expect(q['q'], 'eth');
      expect(q['limit_per_type'], '5');
      expect(q['page'], '1');
      expect(q['events_tag'], ['ethereum']);
      expect(q['events_status'], 'active');
      expect(q['ascending'], 'true');
      expect(q['sort'], 'volume');
      expect(q['search_profiles'], 'false');
    });
  });
}
