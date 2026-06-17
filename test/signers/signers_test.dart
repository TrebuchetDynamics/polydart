import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'normalizeWalletSignature maps compact recovery ids without mutating input',
    () {
      final input = Uint8List.fromList(
        List<int>.generate(65, (i) => i == 64 ? 1 : i),
      );

      final normalized = normalizeWalletSignature(input);

      expect(normalized[64], 28);
      expect(input[64], 1);
    },
  );

  test('normalizeWalletSignature rejects malformed recovery ids', () {
    final input = Uint8List.fromList(
      List<int>.generate(65, (i) => i == 64 ? 29 : i),
    );

    expect(() => normalizeWalletSignature(input), throwsFormatException);
  });

  test('LocalEoaSigner implements WalletSigner and PolydartSigner', () async {
    final signer = LocalEoaSigner(
      privateKeyHex:
          '0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318',
      chainId: 137,
    );

    expect(signer, isA<WalletSigner>());
    expect(signer, isA<PolydartSigner>());
    expect(signer.address, '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23');
    final headers = await buildL1Headers(
      signer: signer,
      timestamp: 1700000000,
      nonce: 0,
    );
    expect(
      headers['POLY_SIGNATURE'],
      '0xaa541ee28fab54d848c37e4d6c69ce3bca78c3c67bbfe102e9736de2589f18573619c82c113a99cbd31a576b4166a9b2964de7a6845770dc4beb1ad757c4ae1d1b',
    );
  });

  test('WalletMediatedSigner delegates identity and EIP-712 signing', () async {
    final wallet = _FakeWalletSigner();
    final signer = WalletMediatedSigner(wallet);

    expect(signer.address, '0xabc');
    expect(signer.chainId, 137);
    final sig = await signer.signEip712(<String, dynamic>{'primaryType': 'X'});
    expect(sig, Uint8List.fromList(List<int>.filled(65, 7)));
    expect(wallet.lastTypedData, containsPair('primaryType', 'X'));
  });

  test(
    'HttpSigner posts sign_hash payload and redacts token from errors',
    () async {
      late Map<String, dynamic> body;
      late Map<String, String> headers;
      final client = MockClient((request) async {
        headers = request.headers;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, String>{'signature': _hex(65, 1)}),
          200,
        );
      });
      final signer = HttpSigner(
        HttpSignerConfig(
          url: 'https://signer.example/sign',
          bearerToken: 'secret-token',
          address: '0xabc',
          chainId: 137,
          client: client,
        ),
      );

      final sig = await signer.signHash(
        Uint8List.fromList(List<int>.filled(32, 2)),
      );

      expect(sig, hasLength(65));
      expect(headers['authorization'], 'Bearer secret-token');
      expect(body['operation'], 'sign_hash');
      expect(body['address'], '0xabc');
      expect(body['chain_id'], 137);
      expect(body['hash'], startsWith('0x'));
    },
  );

  test('HttpSigner redacts bearer token from HTTP errors', () async {
    const token = 'secret-token';
    final signer = HttpSigner(
      HttpSignerConfig(
        url: 'https://signer.example/sign',
        bearerToken: token,
        address: '0xabc',
        chainId: 137,
        client: MockClient(
          (_) async => http.Response('token should stay remote', 503),
        ),
      ),
    );

    await expectLater(
      signer.signHash(Uint8List(32)),
      throwsA(
        isA<StateError>()
            .having((e) => e.message, 'message', contains('HTTP 503'))
            .having((e) => e.message, 'message', isNot(contains(token)))
            .having(
              (e) => e.message,
              'message',
              isNot(contains('token should stay remote')),
            ),
      ),
    );
  });

  test('HttpSigner closes its HTTP client', () {
    final client = _CloseTrackingClient();
    final signer = HttpSigner(
      HttpSignerConfig(
        url: 'https://signer.example/sign',
        bearerToken: 'token',
        address: '0xabc',
        chainId: 137,
        client: client,
      ),
    );

    signer.close();

    expect(client.closed, isTrue);
  });

  test('HttpSigner decodes typed-data result and rejects bad length', () async {
    final ok = HttpSigner(
      HttpSignerConfig(
        url: 'https://signer.example/sign',
        bearerToken: 'token',
        address: '0xabc',
        chainId: 137,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, String>{'result': _hex(32, 3)}),
            200,
          ),
        ),
      ),
    );
    final result = await ok.signTypedDataHashes(
      domainHash: Uint8List(32),
      structHash: Uint8List(32),
    );
    expect(result, hasLength(32));

    final bad = HttpSigner(
      HttpSignerConfig(
        url: 'https://signer.example/sign',
        bearerToken: 'token',
        address: '0xabc',
        chainId: 137,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, String>{'signature': _hex(64, 4)}),
            200,
          ),
        ),
      ),
    );
    expect(bad.signHash(Uint8List(32)), throwsA(isA<FormatException>()));
  });

  test(
    'KmsSigner and TurnkeySigner delegate to caller-owned backends',
    () async {
      final kmsBackend = _FakeKmsBackend();
      final kms = KmsSigner(
        KmsSignerConfig(
          keyId: 'key-1',
          address: '0xkms',
          chainId: 137,
          backend: kmsBackend,
        ),
      );
      await kms.signHash(Uint8List(32));
      expect(kmsBackend.lastKeyId, 'key-1');

      final turnkeyBackend = _FakeTurnkeyBackend();
      final turnkey = TurnkeySigner(
        TurnkeySignerConfig(
          organizationId: 'org-1',
          walletId: 'wallet-1',
          address: '0xtk',
          chainId: 137,
          backend: turnkeyBackend,
        ),
      );
      await turnkey.signEip712(<String, dynamic>{'primaryType': 'Order'});
      expect(turnkeyBackend.lastOrganizationId, 'org-1');
      expect(turnkeyBackend.lastWalletId, 'wallet-1');
      expect(turnkeyBackend.lastAddress, '0xtk');
    },
  );

  test('remote signer configs validate required custody fields', () {
    expect(
      () => HttpSigner(
        const HttpSignerConfig(
          url: '',
          bearerToken: 'token',
          address: '0xabc',
          chainId: 137,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => TurnkeySigner(
        TurnkeySignerConfig(
          organizationId: '',
          walletId: 'wallet',
          address: '0xabc',
          chainId: 137,
          backend: _FakeTurnkeyBackend(),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(redactSignerSecret('secret-token'), 'secr…oken');
  });
}

String _hex(int length, int value) =>
    '0x${List<String>.filled(length, value.toRadixString(16).padLeft(2, '0')).join()}';

final class _CloseTrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

final class _FakeWalletSigner implements WalletSigner {
  Map<String, dynamic>? lastTypedData;

  @override
  String get address => '0xabc';

  @override
  int get chainId => 137;

  @override
  Future<Uint8List> personalSign(Uint8List message) async =>
      Uint8List.fromList(List<int>.filled(65, 9));

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    lastTypedData = typedData;
    return Uint8List.fromList(List<int>.filled(65, 7));
  }
}

final class _FakeKmsBackend implements KmsSignerBackend {
  String? lastKeyId;

  @override
  Future<Uint8List> signEip712(
    String keyId,
    Map<String, dynamic> typedData,
  ) async {
    lastKeyId = keyId;
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signHash(String keyId, Uint8List hash) async {
    lastKeyId = keyId;
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signTypedDataHashes(
    String keyId,
    Uint8List domainHash,
    Uint8List structHash,
  ) async {
    lastKeyId = keyId;
    return Uint8List(32);
  }
}

final class _FakeTurnkeyBackend implements TurnkeySignerBackend {
  String? lastOrganizationId;
  String? lastWalletId;
  String? lastAddress;

  @override
  Future<Uint8List> signEip712(
    String organizationId,
    String walletId,
    String address,
    Map<String, dynamic> typedData,
  ) async {
    lastOrganizationId = organizationId;
    lastWalletId = walletId;
    lastAddress = address;
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signHash(
    String organizationId,
    String walletId,
    String address,
    Uint8List hash,
  ) async {
    lastOrganizationId = organizationId;
    lastWalletId = walletId;
    lastAddress = address;
    return Uint8List(65);
  }

  @override
  Future<Uint8List> signTypedDataHashes(
    String organizationId,
    String walletId,
    String address,
    Uint8List domainHash,
    Uint8List structHash,
  ) async {
    lastOrganizationId = organizationId;
    lastWalletId = walletId;
    lastAddress = address;
    return Uint8List(32);
  }
}
