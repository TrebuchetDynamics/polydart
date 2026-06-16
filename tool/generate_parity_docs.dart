// Generates `docs/POLYDART-POLYGOLEM-PARITY.md` from its YAML source
// `docs/parity/polydart-polygolem.yaml`.
//
// Usage:
//   dart run tool/generate_parity_docs.dart          # write the matrix
//   dart run tool/generate_parity_docs.dart --check   # verify it is current
//
// `--check` regenerates in memory and compares against the committed file,
// exiting non-zero when they differ. CI uses this to catch a stale matrix.
import 'dart:io';

import 'package:yaml/yaml.dart';

const _sourcePath = 'docs/parity/polydart-polygolem.yaml';
const _outputPath = 'docs/POLYDART-POLYGOLEM-PARITY.md';

/// Emoji prefix per status word. Only `implemented`, `intentional`, and
/// `safety_gated` appear today; the rest are defined for forward use.
const _statusEmoji = <String, String>{
  'implemented': '✅',
  'partial': '🟡',
  'missing': '❌',
  'intentional': '🧭',
  'safety_gated': '🛑',
  'not_applicable': '➖',
};

/// Status counts rendered in the summary line, in this order.
const _summaryOrder = <String>[
  'implemented',
  'intentional',
  'safety_gated',
  'missing',
];

void main(List<String> args) {
  final check = args.contains('--check');
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Missing parity source: $_sourcePath');
    exit(2);
  }

  final data = loadYaml(source.readAsStringSync()) as YamlMap;
  final generated = _render(data);

  if (check) {
    final current = File(_outputPath).existsSync()
        ? File(_outputPath).readAsStringSync()
        : '';
    if (current != generated) {
      stderr.writeln(
        'ERROR: $_outputPath is out of date with $_sourcePath.\n'
        'Run: dart run tool/generate_parity_docs.dart',
      );
      exit(1);
    }
    stdout.writeln('$_outputPath is up to date.');
    return;
  }

  File(_outputPath).writeAsStringSync(generated);
  stdout.writeln('Wrote $_outputPath from $_sourcePath.');
}

String _render(YamlMap data) {
  final rows = (data['rows'] as YamlList).cast<YamlMap>();
  final tracking = data['tracking_commit'] as String;
  final lastSync = data['last_sync_commit'] as String;
  final generated = data['generated'] as String;

  final counts = <String, int>{for (final s in _summaryOrder) s: 0};
  for (final row in rows) {
    final status = row['status'] as String;
    counts[status] = (counts[status] ?? 0) + 1;
  }
  final summary = _summaryOrder.map((s) => '$s: ${counts[s]}').join(', ');

  final b = StringBuffer()
    ..writeln('# Polydart ↔ Polygolem parity matrix')
    ..writeln()
    ..writeln('<!-- GENERATED FILE — do not edit by hand.')
    ..writeln('     Source: $_sourcePath')
    ..writeln('     Regenerate: dart run tool/generate_parity_docs.dart')
    ..writeln(
      '     CI freshness check: dart run tool/generate_parity_docs.dart --check -->',
    )
    ..writeln()
    ..writeln('Source: `$_sourcePath`')
    ..writeln('Generated: $generated')
    ..writeln()
    ..writeln(
      'Tracking against Polygolem HEAD `$tracking`; '
      'last full fidelity sync at `$lastSync`.',
    )
    ..writeln()
    ..writeln(
      'Status vocabulary: `implemented`, `partial`, `missing`, '
      '`intentional`, `safety_gated`, `not_applicable`.',
    )
    ..writeln()
    ..writeln('Summary: $summary.')
    ..writeln()
    ..writeln(
      '| ID | Domain | Feature | Status | Gated | Polygolem APIs/tests | '
      'Polydart APIs/tests | Evidence | Notes |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|');

  for (final row in rows) {
    b.writeln(_renderRow(row));
  }

  b
    ..writeln()
    ..writeln('## Governance rules')
    ..writeln()
    ..writeln(
      '- Add or update a row whenever a public feature is added, removed, '
      'intentionally omitted, or safety-gated. Edit the YAML source '
      '`$_sourcePath`, then regenerate this matrix with '
      '`dart run tool/generate_parity_docs.dart`.',
    )
    ..writeln(
      '- Prefer local/mock tests for parity evidence. Do not use this matrix '
      'as approval for live trades, custody mutations, deployments, '
      'publishing, or secret handling.',
    )
    ..writeln(
      '- CI runs `dart run tool/generate_parity_docs.dart --check` to ensure '
      'this file matches its YAML source.',
    )
    ..writeln(
      '- `partial` and `missing` rows should include an explicit note '
      'explaining whether the gap is intentional, safety-gated, or still '
      'planned, plus the upstream commit that introduced it.',
    );

  return b.toString();
}

String _renderRow(YamlMap row) {
  final id = row['id'] as String;
  final domain = row['domain'] as String;
  final feature = row['feature'] as String;
  final status = row['status'] as String;
  final emoji = _statusEmoji[status] ?? '';
  final gated = (row['gated'] as bool) ? 'yes' : 'no';
  final polygolem = _renderColumn(row['polygolem'] as YamlMap?);
  final polydart = _renderColumn(row['polydart'] as YamlMap?);
  final evidence = ((row['evidence'] as YamlList?) ?? const [])
      .cast<String>()
      .join('<br>');
  final notes = row['notes'] as String;

  return '| `$id` | $domain | $feature | $emoji $status | $gated | '
      '$polygolem | $polydart | $evidence | $notes |';
}

String _renderColumn(YamlMap? column) {
  if (column == null) return '';
  const labels = <String, String>{
    'apis': 'APIs',
    'internal': 'Internal',
    'tests': 'Tests',
  };
  final groups = <String>[];
  for (final key in const ['apis', 'internal', 'tests']) {
    final items = (column[key] as YamlList?)?.cast<String>();
    if (items != null && items.isNotEmpty) {
      final rendered = items.map((e) => '`$e`').join('<br>');
      groups.add('${labels[key]}:<br>$rendered');
    }
  }
  return groups.join('<br><br>');
}
