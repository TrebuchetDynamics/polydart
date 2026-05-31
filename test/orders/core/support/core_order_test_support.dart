import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:test/test.dart';

const validTickSize = TickSize(
  minimumTickSize: '0.01',
  minimumOrderSize: '5',
  tickSize: '0.01',
);

final Matcher throwsValidationException = throwsA(isA<ValidationException>());
