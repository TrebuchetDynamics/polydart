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

  group('CategoryEventsParams.toQuery', () {
    test('encodes sports and esports keyset filters', () {
      final query = const CategoryEventsParams(
        active: true,
        live: true,
        endDateMin: '2026-08-02T00:00:00.000Z',
        startTimeMin: '2026-08-02T01:00:00.000Z',
        startTimeMax: '2026-08-04T01:00:00.000Z',
      ).toQuery();

      expect(query['active'], 'true');
      expect(query['live'], 'true');
      expect(query['end_date_min'], '2026-08-02T00:00:00.000Z');
      expect(query['start_time_min'], '2026-08-02T01:00:00.000Z');
      expect(query['start_time_max'], '2026-08-04T01:00:00.000Z');
    });
  });

  group('SearchParams.toQuery', () {
    test('q always present', () {
      const p = SearchParams(query: 'btc 5m');
      expect(p.toQuery(), {'q': 'btc 5m'});
    });

    test('preserves non-positive pagination values for search parity', () {
      const p = SearchParams(query: 'btc 5m', limitPerType: 0, page: -1);
      expect(p.toQuery(), {'q': 'btc 5m', 'limit_per_type': '0', 'page': '-1'});
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

  group('shared Gamma query contracts', () {
    test('offset-paginated endpoints drop non-positive limit and offset', () {
      expect(const GetEventsParams(limit: 0, offset: -1).toQuery(), isEmpty);
      expect(const GetSeriesParams(limit: 0, offset: -1).toQuery(), isEmpty);
      expect(const GetTagsParams(limit: 0, offset: -1).toQuery(), isEmpty);
      expect(const GetTeamsParams(limit: 0, offset: -1).toQuery(), isEmpty);
      expect(const CommentQuery(limit: 0, offset: -1).toQuery(), isEmpty);
      expect(const KeysetParams(limit: 0).toQuery(), isEmpty);
    });

    test('keeps boolean false values explicit', () {
      expect(const GetEventsParams(closed: false).toQuery(), {
        'closed': 'false',
      });
      expect(const GetSeriesParams(closed: false).toQuery(), {
        'closed': 'false',
      });
      expect(const KeysetParams(active: false, closed: false).toQuery(), {
        'active': 'false',
        'closed': 'false',
      });
    });
  });
}
