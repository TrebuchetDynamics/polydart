import 'dart:convert';
import 'dart:io';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

Map<String, dynamic> project(Map<String, dynamic> value) => {
  for (final key in const [
    'id',
    'tier',
    'service',
    'operation',
    'transport',
    'auth',
    'signing',
    'mutates',
    'cliCommand',
    'extension',
    'summary',
    'status',
  ])
    key: value[key],
};

void main() {
  final manifest =
      jsonDecode(File('capabilities.json').readAsStringSync())
          as Map<String, dynamic>;
  final rows = (manifest['capabilities'] as List).cast<Map<String, dynamic>>();

  test('compiled catalog matches manifest', () {
    expect(rows, hasLength(141));
    expect(
      CapabilityCatalog.all
          .map((capability) => project(capability.toJson()))
          .toList(),
      rows.map(project).toList(),
    );
  });

  test('migration capabilities are implemented', () {
    for (final id in const <String>[
      'clob.geoblock.read',
      'clob.currentRewards.list',
      'perps.instruments.list',
      'rfq.comboMarkets.list',
      'rtds.cryptoPrices.stream',
      'web.biggestMovers.read',
      'web.dailyUpdates.subscribe',
    ]) {
      expect(
        rows.singleWhere((row) => row['id'] == id)['status'],
        'implemented',
        reason: id,
      );
    }
  });

  test('implemented evidence paths exist', () {
    for (final row in rows.where((row) => row['status'] == 'implemented')) {
      for (final path in (row['tests'] as List).cast<String>()) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '${row['id']}: missing $path',
        );
      }
    }
  });

  test('lookup round trips unique IDs', () {
    final ids = CapabilityCatalog.all
        .map((capability) => capability.id)
        .toSet();
    expect(ids, hasLength(CapabilityCatalog.all.length));
    for (final capability in CapabilityCatalog.all) {
      expect(CapabilityCatalog.byId(capability.id), same(capability));
    }
  });
}
