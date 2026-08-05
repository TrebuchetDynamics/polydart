// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:polydart/src/config/config.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:test/test.dart';

void main() {
  group('parseDuration', () {
    test('canonical units', () {
      expect(parseDuration('500ms'), const Duration(milliseconds: 500));
      expect(parseDuration('10s'), const Duration(seconds: 10));
      expect(parseDuration('5m'), const Duration(minutes: 5));
      expect(parseDuration('2h'), const Duration(hours: 2));
    });

    test('whitespace tolerated', () {
      expect(parseDuration('  10s '), const Duration(seconds: 10));
    });

    test('returns null on garbage', () {
      expect(parseDuration(''), isNull);
      expect(parseDuration('5'), isNull);
      expect(parseDuration('5seconds'), isNull);
      expect(parseDuration('abc'), isNull);
    });
  });

  group('PolydartConfig.fromEnv', () {
    test('returns defaults when env empty', () {
      final cfg = PolydartConfig.fromEnv(<String, String>{});
      expect(cfg.mode, PolydartMode.readOnly);
      expect(cfg.gammaBaseUrl, PolydartConfig.defaultGammaBaseUrl);
      expect(cfg.clobBaseUrl, PolydartConfig.defaultClobBaseUrl);
      expect(cfg.dataBaseUrl, PolydartConfig.defaultDataBaseUrl);
      expect(cfg.webBaseUrl, PolydartConfig.defaultWebBaseUrl);
      expect(cfg.rfqBaseUrl, PolydartConfig.defaultRfqBaseUrl);
      expect(cfg.perpsBaseUrl, PolydartConfig.defaultPerpsBaseUrl);
      expect(cfg.rtdsUrl, PolydartConfig.defaultRtdsUrl);
      expect(cfg.requestTimeout, const Duration(seconds: 10));
      expect(cfg.liveTradingEnabled, isFalse);
      expect(cfg.paperStatePath, isEmpty);
    });

    test('reads each field', () {
      final cfg = PolydartConfig.fromEnv(<String, String>{
        'POLYMARKET_MODE': 'paper',
        'POLYMARKET_GAMMA_BASE_URL': 'https://gamma.test',
        'POLYMARKET_CLOB_BASE_URL': 'https://clob.test',
        'POLYMARKET_DATA_BASE_URL': 'https://data.test',
        'POLYMARKET_WEB_BASE_URL': 'https://web.test',
        'POLYMARKET_RFQ_BASE_URL': 'https://rfq.test',
        'POLYMARKET_PERPS_BASE_URL': 'https://perps.test',
        'POLYMARKET_RTDS_URL': 'wss://rtds.test',
        'POLYMARKET_REQUEST_TIMEOUT': '500ms',
        'POLYMARKET_LIVE_TRADING_ENABLED': 'true',
        'POLYMARKET_PAPER_STATE_PATH': '/tmp/paper.json',
      });
      expect(cfg.mode, PolydartMode.paper);
      expect(cfg.gammaBaseUrl, 'https://gamma.test');
      expect(cfg.clobBaseUrl, 'https://clob.test');
      expect(cfg.dataBaseUrl, 'https://data.test');
      expect(cfg.webBaseUrl, 'https://web.test');
      expect(cfg.rfqBaseUrl, 'https://rfq.test');
      expect(cfg.perpsBaseUrl, 'https://perps.test');
      expect(cfg.rtdsUrl, 'wss://rtds.test');
      expect(cfg.requestTimeout, const Duration(milliseconds: 500));
      expect(cfg.liveTradingEnabled, isTrue);
      expect(cfg.paperStatePath, '/tmp/paper.json');
    });

    test('respects custom prefix', () {
      final cfg = PolydartConfig.fromEnv(<String, String>{
        'PD_MODE': 'live',
        'PD_LIVE_TRADING_ENABLED': 'true',
      }, prefix: 'PD');
      expect(cfg.mode, PolydartMode.live);
      expect(cfg.liveTradingEnabled, isTrue);
    });

    test('rejects non-positive timeout', () {
      expect(
        () => PolydartConfig.fromEnv(<String, String>{
          'POLYMARKET_REQUEST_TIMEOUT': 'oops',
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects invalid mode', () {
      expect(
        () => PolydartConfig.fromEnv(<String, String>{
          'POLYMARKET_MODE': 'reckless',
        }),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  test('toString does not leak path contents', () {
    const cfg = PolydartConfig(paperStatePath: '/secret/wallet.json');
    expect(cfg.toString(), contains('paperPath=<set>'));
    expect(cfg.toString(), isNot(contains('/secret/wallet.json')));
  });

  test('copyWith overlays fields', () {
    const base = PolydartConfig();
    final updated = base.copyWith(
      mode: PolydartMode.paper,
      dataBaseUrl: 'https://data.test',
      rfqBaseUrl: 'https://rfq.test',
      perpsBaseUrl: 'https://perps.test',
      rtdsUrl: 'wss://rtds.test',
    );
    expect(updated.mode, PolydartMode.paper);
    expect(updated.gammaBaseUrl, base.gammaBaseUrl);
    expect(updated.dataBaseUrl, 'https://data.test');
    expect(updated.rfqBaseUrl, 'https://rfq.test');
    expect(updated.perpsBaseUrl, 'https://perps.test');
    expect(updated.rtdsUrl, 'wss://rtds.test');
  });
}
