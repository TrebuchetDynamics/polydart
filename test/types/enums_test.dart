import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

void main() {
  group('Side', () {
    test('parse from labels and codes', () {
      expect(Side.parse('BUY'), Side.buy);
      expect(Side.parse('buy'), Side.buy);
      expect(Side.parse(0), Side.buy);
      expect(Side.parse('0'), Side.buy);
      expect(Side.parse('SELL'), Side.sell);
      expect(Side.parse(1), Side.sell);
    });

    test('label and code', () {
      expect(Side.buy.label, 'BUY');
      expect(Side.buy.code, 0);
      expect(Side.sell.label, 'SELL');
      expect(Side.sell.code, 1);
    });

    test('parse rejects garbage', () {
      expect(() => Side.parse('HOLD'), throwsA(isA<ValidationException>()));
      expect(() => Side.parse(99), throwsA(isA<ValidationException>()));
    });
  });

  group('OrderType', () {
    test('parses all four', () {
      expect(OrderType.parse('GTC'), OrderType.gtc);
      expect(OrderType.parse('fok'), OrderType.fok);
      expect(OrderType.parse('GTD'), OrderType.gtd);
      expect(OrderType.parse('FAK'), OrderType.fak);
    });

    test('rejects garbage', () {
      expect(
        () => OrderType.parse('NEVER'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('SignatureType', () {
    test('parses labels and codes', () {
      expect(SignatureType.parse('EOA'), SignatureType.eoa);
      expect(SignatureType.parse(0), SignatureType.eoa);
      expect(SignatureType.parse('PROXY'), SignatureType.proxy);
      expect(SignatureType.parse(1), SignatureType.proxy);
      expect(SignatureType.parse('SAFE'), SignatureType.gnosisSafe);
      expect(SignatureType.parse('GnosisSafe'), SignatureType.gnosisSafe);
      expect(SignatureType.parse(2), SignatureType.gnosisSafe);
    });

    test('rejects garbage', () {
      expect(
        () => SignatureType.parse('MULTISIG'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
