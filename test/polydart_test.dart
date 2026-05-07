import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  group('Polydart.readOnly', () {
    test('uses default config when none supplied', () {
      final p = Polydart.readOnly();
      expect(p.mode, PolydartMode.readOnly);
      expect(p.config.gammaBaseUrl, PolydartConfig.defaultGammaBaseUrl);
      expect(p.config.clobBaseUrl, PolydartConfig.defaultClobBaseUrl);
      expect(p.eoaAddress, isEmpty);
      p.close();
    });

    test('honours overrides from PolydartConfig', () {
      const cfg = PolydartConfig(
        gammaBaseUrl: 'https://gamma.test',
        clobBaseUrl: 'https://clob.test',
        requestTimeout: Duration(seconds: 5),
      );
      final p = Polydart.readOnly(config: cfg);
      expect(p.config.gammaBaseUrl, 'https://gamma.test');
      expect(p.config.clobBaseUrl, 'https://clob.test');
      expect(p.mode, PolydartMode.readOnly);
      p.close();
    });

    test('exposes resolver and discovery sharing the underlying clients', () {
      final p = Polydart.readOnly();
      expect(p.resolver, isNotNull);
      expect(p.discovery, isNotNull);
      p.close();
    });
  });

  group('Polydart.paper', () {
    test('requires a non-empty eoa address', () {
      expect(
        () => Polydart.paper(eoaAddress: ''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => Polydart.paper(eoaAddress: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('captures eoa and switches mode', () {
      final p = Polydart.paper(eoaAddress: '0xabc');
      expect(p.mode, PolydartMode.paper);
      expect(p.eoaAddress, '0xabc');
      p.close();
    });
  });
}
