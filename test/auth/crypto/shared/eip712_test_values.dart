import 'package:polydart/src/auth/eip712.dart';

const eip712TestDomainPolygon = Eip712Domain(
  name: 'X',
  version: '1',
  chainId: 137,
);

const eip712TestDomainMainnet = Eip712Domain(
  name: 'X',
  version: '1',
  chainId: 1,
);
