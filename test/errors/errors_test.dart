import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorCode', () {
    test('value preserved', () {
      expect(ErrorCode.timeout.value, 'NET-001');
      expect(ErrorCode.invalidOrder.value, 'CLOB-003');
      expect(ErrorCode.marketNotFound.value, 'GAMMA-001');
    });

    test('equality by value', () {
      expect(const ErrorCode('NET-001'), ErrorCode.timeout);
      expect(
        ErrorCode.timeout.hashCode,
        const ErrorCode('NET-001').hashCode,
      );
    });

    test('toString returns code value', () {
      expect(ErrorCode.timeout.toString(), 'NET-001');
    });
  });

  group('PolydartException', () {
    test('formats without cause', () {
      const e = TransportException(
        code: ErrorCode.timeout,
        message: 'request timed out',
      );
      expect(e.toString(), '[NET-001] request timed out');
    });

    test('formats with cause', () {
      final inner = StateError('socket closed');
      final e = TransportException(
        code: ErrorCode.connectionFailed,
        message: 'cannot reach host',
        cause: inner,
      );
      expect(e.toString(), contains('[NET-002] cannot reach host'));
      expect(e.toString(), contains('socket closed'));
    });

    test('subtype hierarchy', () {
      const e = ClobException(
        code: ErrorCode.invalidOrder,
        message: 'bad price',
      );
      expect(e, isA<PolydartException>());
      expect(e, isA<ClobException>());
    });

    test('ValidationException carries field', () {
      const e = ValidationException(
        code: ErrorCode.missingField,
        message: 'price missing',
        field: 'price',
      );
      expect(e.field, 'price');
      expect(e.toString(), contains('field: price'));
    });

    test('httpStatus preserved on transport errors', () {
      const e = TransportException(
        code: ErrorCode.rateLimited,
        message: 'slow down',
        httpStatus: 429,
      );
      expect(e.httpStatus, 429);
    });
  });
}
