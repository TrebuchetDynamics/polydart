import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/gamma/gamma_profile.dart';
import 'package:test/test.dart';

void main() {
  group('newCreateProfileRequest', () {
    test('builds the captured Gamma profile payload', () {
      final request = newCreateProfileRequest(
        eoaAddress: '0xeoa',
        proxyWallet: '0xproxy',
        provider: 'metamask',
        nowMillis: 1710000000123,
      );

      expect(request.toJson(), <String, dynamic>{
        'displayUsernamePublic': true,
        'emailOptIn': false,
        'walletActivated': false,
        'name': '0xproxy-1710000000123',
        'pseudonym': '0xproxy',
        'proxyWallet': '0xproxy',
        'users': <Map<String, dynamic>>[
          <String, dynamic>{
            'address': '0xeoa',
            'email': '',
            'isExternalAuth': true,
            'proxyWallet': '0xproxy',
            'username': '0xproxy-1710000000123',
            'provider': 'metamask',
            'preferences': <Map<String, dynamic>>[
              <String, dynamic>{
                'preferencesStatus': 'New/Existing - Created Prefs',
                'subscriptionStatus': false,
                'emailNotificationPreferences':
                    defaultEmailNotificationPreferences,
                'appNotificationPreferences': defaultAppNotificationPreferences,
                'marketInterests': '[]',
              },
            ],
            'walletPreferences': <Map<String, dynamic>>[
              <String, dynamic>{
                'advancedMode': false,
                'customGasPrice': '30',
                'gasPreference': 'fast',
                'walletPreferencesStatus':
                    'New/Existing - Created Wallet Prefs',
              },
            ],
          },
        ],
      });
    });
  });

  group('CreateProfileResponse', () {
    test('decodes typed fields and preserves raw response fields', () {
      final response = CreateProfileResponse.fromJson(const <String, dynamic>{
        'id': 'profile-1',
        'name': '0xproxy-1710000000123',
        'proxyWallet': '0xproxy',
        'pseudonym': '0xproxy',
        'serverDefault': <String, dynamic>{'enabled': true},
      });

      expect(response.id, 'profile-1');
      expect(response.name, '0xproxy-1710000000123');
      expect(response.proxyWallet, '0xproxy');
      expect(response.pseudonym, '0xproxy');
      expect(response.raw['serverDefault'], const <String, dynamic>{
        'enabled': true,
      });
      expect(
        () => response.raw['serverDefault'] = const <String, dynamic>{},
        throwsUnsupportedError,
      );
    });
  });

  group('createProfile', () {
    test('POSTs JSON to /profiles and decodes the created profile', () async {
      late Uri capturedUrl;
      late String capturedBody;
      late Map<String, String> capturedHeaders;
      late String capturedMethod;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        capturedMethod = request.method;
        capturedHeaders = request.headers;
        capturedBody = request.body;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 'profile-1',
            'name': '0xproxy-1710000000123',
            'proxyWallet': '0xproxy',
            'pseudonym': '0xproxy',
            'createdAt': '2026-05-11T00:00:00Z',
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });

      final body = newCreateProfileRequest(
        eoaAddress: '0xeoa',
        proxyWallet: '0xproxy',
        provider: 'metamask',
        nowMillis: 1710000000123,
      );

      final response = await createProfile(
        client: client,
        gammaBaseUrl: 'https://gamma-api.polymarket.com/',
        body: body,
      );

      expect(
        capturedUrl.toString(),
        'https://gamma-api.polymarket.com/profiles',
      );
      expect(capturedMethod, 'POST');
      expect(capturedHeaders['Accept'], 'application/json');
      expect(capturedHeaders['Content-Type'], 'application/json');
      expect(jsonDecode(capturedBody), body.toJson());
      expect(response.id, 'profile-1');
      expect(response.raw['createdAt'], '2026-05-11T00:00:00Z');
    });

    test('surfaces non-2xx status with response body', () async {
      final client = MockClient(
        (_) async => http.Response('profile already exists', 409),
      );

      final call = createProfile(
        client: client,
        gammaBaseUrl: 'https://gamma-api.polymarket.com',
        body: newCreateProfileRequest(
          eoaAddress: '0xeoa',
          proxyWallet: '0xproxy',
          provider: 'metamask',
          nowMillis: 1710000000123,
        ),
      );

      await expectLater(
        call,
        throwsA(
          isA<GammaProfileException>()
              .having((e) => e.message, 'message', contains('HTTP 409'))
              .having((e) => e.message, 'message', contains('/profiles'))
              .having(
                (e) => e.message,
                'message',
                contains('profile already exists'),
              ),
        ),
      );
    });

    test(
      'validates client, base URL, proxy wallet, and user address',
      () async {
        final validBody = newCreateProfileRequest(
          eoaAddress: '0xeoa',
          proxyWallet: '0xproxy',
          provider: 'metamask',
          nowMillis: 1710000000123,
        );
        final client = MockClient((_) async => http.Response('{}', 201));

        await expectLater(
          createProfile(
            client: null,
            gammaBaseUrl: 'https://gamma-api.polymarket.com',
            body: validBody,
          ),
          throwsArgumentError,
        );
        await expectLater(
          createProfile(client: client, gammaBaseUrl: ' ', body: validBody),
          throwsArgumentError,
        );
        await expectLater(
          createProfile(
            client: client,
            gammaBaseUrl: 'not a url',
            body: validBody,
          ),
          throwsArgumentError,
        );
        await expectLater(
          createProfile(
            client: client,
            gammaBaseUrl: 'https://gamma-api.polymarket.com',
            body: CreateProfileRequest(
              displayUsernamePublic: true,
              emailOptIn: false,
              walletActivated: false,
              name: '0xproxy-1710000000123',
              pseudonym: '0xproxy',
              proxyWallet: ' ',
              users: validBody.users,
            ),
          ),
          throwsArgumentError,
        );
        await expectLater(
          createProfile(
            client: client,
            gammaBaseUrl: 'https://gamma-api.polymarket.com',
            body: const CreateProfileRequest(
              displayUsernamePublic: true,
              emailOptIn: false,
              walletActivated: false,
              name: '0xproxy-1710000000123',
              pseudonym: '0xproxy',
              proxyWallet: '0xproxy',
              users: <CreateProfileUser>[],
            ),
          ),
          throwsArgumentError,
        );
        await expectLater(
          createProfile(
            client: client,
            gammaBaseUrl: 'https://gamma-api.polymarket.com',
            body: const CreateProfileRequest(
              displayUsernamePublic: true,
              emailOptIn: false,
              walletActivated: false,
              name: '0xproxy-1710000000123',
              pseudonym: '0xproxy',
              proxyWallet: '0xproxy',
              users: <CreateProfileUser>[
                CreateProfileUser(
                  address: ' ',
                  email: '',
                  isExternalAuth: true,
                  proxyWallet: '0xproxy',
                  username: '0xproxy-1710000000123',
                  provider: 'metamask',
                ),
              ],
            ),
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
