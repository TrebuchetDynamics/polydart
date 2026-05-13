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
      expect(ErrorCode.timeout.hashCode, const ErrorCode('NET-001').hashCode);
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
        responseBody: '{"error":"slow down"}',
      );
      expect(e.httpStatus, 429);
      expect(e.responseBody, '{"error":"slow down"}');
    });

    test('ClobErrorResponse decodes live CLOB error fields', () {
      final err = ClobErrorResponse.fromBody(
        '{"type":"validation","code":"order_invalid","error":"maker address not allowed, please use the deposit wallet flow"}',
        httpStatus: 400,
      );

      expect(err.httpStatus, 400);
      expect(err.type, 'validation');
      expect(err.code, 'order_invalid');
      expect(
        err.message,
        'maker address not allowed, please use the deposit wallet flow',
      );
      expect(err.details['error'], contains('deposit wallet'));
    });

    test('ClobException carries structured upstream CLOB error', () {
      final upstream = ClobErrorResponse.fromBody(
        '{"error":"insufficient balance"}',
        httpStatus: 400,
      );
      final e = ClobException(
        code: ErrorCode.insufficientFunds,
        message: upstream.message,
        httpStatus: 400,
        upstream: upstream,
      );

      expect(e.upstream, upstream);
      expect(e.toString(), contains('[CLOB-002] insufficient balance'));
    });
  });
}
