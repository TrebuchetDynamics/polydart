/// Common enums shared by CLOB and order builder.
///
/// Mirrors the Side / OrderType / SignatureType constants in
/// `polytypes/normalize.go`.
library;

import '../errors/errors.dart';

enum Side {
  buy('BUY', 0),
  sell('SELL', 1);

  const Side(this.label, this.code);
  final String label;
  final int code;

  static Side parse(Object raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return buy;
        case 1:
          return sell;
      }
    }
    final s = raw.toString().toUpperCase().trim();
    switch (s) {
      case 'BUY':
      case '0':
        return buy;
      case 'SELL':
      case '1':
        return sell;
    }
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid side: $raw',
    );
  }
}

enum OrderType {
  gtc('GTC'),
  fok('FOK'),
  gtd('GTD'),
  fak('FAK');

  const OrderType(this.label);
  final String label;

  static OrderType parse(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'GTC':
        return gtc;
      case 'FOK':
        return fok;
      case 'GTD':
        return gtd;
      case 'FAK':
        return fak;
    }
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid order type: $raw',
    );
  }
}

enum SignatureType {
  eoa('EOA', 0),
  proxy('PROXY', 1),
  gnosisSafe('SAFE', 2),
  poly1271('POLY_1271', 3);

  const SignatureType(this.label, this.code);
  final String label;
  final int code;

  static SignatureType parse(Object raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return eoa;
        case 1:
          return proxy;
        case 2:
          return gnosisSafe;
        case 3:
          return poly1271;
      }
    }
    final s = raw.toString().toUpperCase().trim();
    switch (s) {
      case 'EOA':
      case '0':
        return eoa;
      case 'PROXY':
      case '1':
        return proxy;
      case 'SAFE':
      case 'GNOSISSAFE':
      case '2':
        return gnosisSafe;
      case 'POLY_1271':
      case 'POLY1271':
      case '3':
        return poly1271;
    }
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid signature type: $raw',
    );
  }
}
