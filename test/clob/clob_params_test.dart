import 'package:polydart/src/clob/clob_params.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

void main() {
  group('BookParams', () {
    test('minimum payload', () {
      expect(const BookParams(tokenId: '12345').toJson(), {
        'token_id': '12345',
      });
    });

    test('with side', () {
      expect(const BookParams(tokenId: '12345', side: Side.buy).toJson(), {
        'token_id': '12345',
        'side': 'BUY',
      });
    });
  });

  group('PriceHistoryParams.toQuery', () {
    test('empty when no fields set', () {
      expect(const PriceHistoryParams().toQuery(), isEmpty);
    });

    test('skips zero / empty values', () {
      const p = PriceHistoryParams(market: '', fidelity: 0);
      expect(p.toQuery(), isEmpty);
    });

    test('encodes set fields', () {
      const p = PriceHistoryParams(
        market: 'm',
        interval: '1d',
        fidelity: 60,
        startTimestamp: 100,
        endTimestamp: 200,
      );
      final q = p.toQuery();
      expect(q['market'], 'm');
      expect(q['interval'], '1d');
      expect(q['fidelity'], '60');
      expect(q['startTs'], '100');
      expect(q['endTs'], '200');
    });
  });
}
