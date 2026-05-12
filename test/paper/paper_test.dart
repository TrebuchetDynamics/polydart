import 'package:polydart/src/paper/paper.dart' as paper;
import 'package:test/test.dart';

void main() {
  group('State', () {
    test(
      'newState initializes local paper cash with empty positions and fills',
      () {
        final state = paper.PaperState.newState('USD', 100);

        expect(state.currency, 'USD');
        expect(state.cash, 100);
        expect(state.positions, isEmpty);
        expect(state.fills, isEmpty);
        expect(state.toJson(), {
          'currency': 'USD',
          'cash': 100.0,
          'positions': <String, Map<String, Object>>{},
          'fills': <Map<String, Object>>[],
        });
      },
    );

    test('buy updates local position without external execution', () {
      final state = paper.PaperState.newState('USD', 100);

      final fill = state.buy(
        const paper.PaperOrder(
          marketId: 'market-1',
          tokenId: 'yes-token',
          price: 0.25,
          size: 10,
        ),
      );

      expect(fill.live, isFalse);
      expect(fill.toJson(), {
        'market_id': 'market-1',
        'token_id': 'yes-token',
        'price': 0.25,
        'size': 10.0,
        'live': false,
      });
      expect(state.cash, 97.5);
      expect(state.positions['yes-token']?.size, 10);
      expect(state.positions['yes-token']?.cost, 2.5);
      expect(state.fills, [fill]);
    });

    test(
      'buy accumulates existing positions and rejects insufficient cash',
      () {
        final state = paper.PaperState.newState('USD', 3);

        state.buy(
          const paper.PaperOrder(
            marketId: 'market-1',
            tokenId: 'yes-token',
            price: 0.25,
            size: 10,
          ),
        );
        state.buy(
          const paper.PaperOrder(
            marketId: 'market-1',
            tokenId: 'yes-token',
            price: 0.10,
            size: 5,
          ),
        );

        expect(state.cash, 0);
        expect(state.positions['yes-token']?.size, 15);
        expect(state.positions['yes-token']?.cost, 3);
        expect(state.fills, hasLength(2));
        expect(
          () => state.buy(
            const paper.PaperOrder(
              marketId: 'market-1',
              tokenId: 'no-token',
              price: 0.01,
              size: 1,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'insufficient paper cash',
            ),
          ),
        );
        expect(state.cash, 0);
        expect(state.positions, isNot(contains('no-token')));
        expect(state.fills, hasLength(2));
      },
    );
  });
}
