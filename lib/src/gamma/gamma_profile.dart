/// Safe Gamma profile creation helper.
///
/// Mirrors `polygolem/internal/gamma/profile.go`. The supplied HTTP client is
/// session-owned by the caller and must already carry any SIWE cookies needed
/// by Gamma.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Email notification defaults sent by the Polymarket web UI at signup.
const String defaultEmailNotificationPreferences =
    '{"generalEmail":{"sendEmails":false},"marketEmails":{"sendEmails":false},'
    '"newsletterEmails":{"sendEmails":false},'
    '"promotionalEmails":{"sendEmails":false},'
    '"eventEmails":{"sendEmails":false,"tagIds":[]},'
    '"orderFillEmails":{"sendEmails":false,"hideSmallFills":true},'
    '"resolutionEmails":{"sendEmails":false}}';

/// App notification defaults sent by the Polymarket web UI at signup.
const String defaultAppNotificationPreferences =
    '{"eventApp":{"sendApp":true,"tagIds":[]},'
    '"marketPriceChangeApp":{"sendApp":true},'
    '"orderFillApp":{"sendApp":true,"hideSmallFills":true},'
    '"resolutionApp":{"sendApp":true}}';

/// Returns the single `preferences` array element used by web UI signups.
Map<String, Object?> defaultPreferencesBlock() => const <String, Object?>{
  'preferencesStatus': 'New/Existing - Created Prefs',
  'subscriptionStatus': false,
  'emailNotificationPreferences': defaultEmailNotificationPreferences,
  'appNotificationPreferences': defaultAppNotificationPreferences,
  'marketInterests': '[]',
};

/// Returns the single `walletPreferences` array element used by web UI signups.
Map<String, Object?> defaultWalletPreferencesBlock() => const <String, Object?>{
  'advancedMode': false,
  'customGasPrice': '30',
  'gasPreference': 'fast',
  'walletPreferencesStatus': 'New/Existing - Created Wallet Prefs',
};

@immutable
final class CreateProfileRequest {
  const CreateProfileRequest({
    required this.displayUsernamePublic,
    required this.emailOptIn,
    required this.walletActivated,
    required this.name,
    required this.pseudonym,
    required this.proxyWallet,
    required this.users,
  });

  final bool displayUsernamePublic;
  final bool emailOptIn;
  final bool walletActivated;
  final String name;
  final String pseudonym;
  final String proxyWallet;
  final List<CreateProfileUser> users;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'displayUsernamePublic': displayUsernamePublic,
    'emailOptIn': emailOptIn,
    'walletActivated': walletActivated,
    'name': name,
    'pseudonym': pseudonym,
    'proxyWallet': proxyWallet,
    'users': users.map((user) => user.toJson()).toList(growable: false),
  };
}

@immutable
final class CreateProfileUser {
  const CreateProfileUser({
    required this.address,
    required this.email,
    required this.isExternalAuth,
    required this.proxyWallet,
    required this.username,
    required this.provider,
    this.preferences = const <Map<String, Object?>>[],
    this.walletPreferences = const <Map<String, Object?>>[],
  });

  final String address;
  final String email;
  final bool isExternalAuth;
  final String proxyWallet;
  final String username;
  final String provider;
  final List<Map<String, Object?>> preferences;
  final List<Map<String, Object?>> walletPreferences;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'address': address,
      'email': email,
      'isExternalAuth': isExternalAuth,
      'proxyWallet': proxyWallet,
      'username': username,
      'provider': provider,
    };
    if (preferences.isNotEmpty) {
      json['preferences'] = preferences;
    }
    if (walletPreferences.isNotEmpty) {
      json['walletPreferences'] = walletPreferences;
    }
    return json;
  }
}

@immutable
final class CreateProfileResponse {
  const CreateProfileResponse({
    required this.id,
    required this.name,
    required this.proxyWallet,
    required this.pseudonym,
    required this.raw,
  });

  factory CreateProfileResponse.fromJson(Map<String, dynamic> json) =>
      CreateProfileResponse(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        proxyWallet: json['proxyWallet']?.toString() ?? '',
        pseudonym: json['pseudonym']?.toString() ?? '',
        raw: Map<String, dynamic>.unmodifiable(json),
      );

  final String id;
  final String name;
  final String proxyWallet;
  final String pseudonym;

  /// The original response object. Read-only; useful for server defaults that
  /// polydart has not typed yet.
  final Map<String, dynamic> raw;
}

/// Error returned for Gamma profile request, response, and decode failures.
final class GammaProfileException implements Exception {
  const GammaProfileException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.url,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final Uri? url;
  final Object? cause;

  @override
  String toString() => 'GammaProfileException: $message';
}

/// Builds the profile creation payload captured from the Polymarket web UI.
CreateProfileRequest newCreateProfileRequest({
  required String eoaAddress,
  required String proxyWallet,
  required String provider,
  required int nowMillis,
}) {
  final username = '$proxyWallet-$nowMillis';
  return CreateProfileRequest(
    displayUsernamePublic: true,
    emailOptIn: false,
    walletActivated: false,
    name: username,
    pseudonym: proxyWallet,
    proxyWallet: proxyWallet,
    users: <CreateProfileUser>[
      CreateProfileUser(
        address: eoaAddress,
        email: '',
        isExternalAuth: true,
        proxyWallet: proxyWallet,
        username: username,
        provider: provider,
        preferences: <Map<String, Object?>>[defaultPreferencesBlock()],
        walletPreferences: <Map<String, Object?>>[
          defaultWalletPreferencesBlock(),
        ],
      ),
    ],
  );
}

/// Registers a fresh EOA plus proxy wallet pair with Gamma.
///
/// The [client] must already carry the caller's SIWE session cookie.
Future<CreateProfileResponse> createProfile({
  required http.Client? client,
  required String gammaBaseUrl,
  required CreateProfileRequest body,
}) async {
  if (client == null) {
    throw ArgumentError.notNull('client');
  }
  final url = _profilesUrl(gammaBaseUrl);
  if (body.proxyWallet.trim().isEmpty) {
    throw ArgumentError.value(body.proxyWallet, 'body.proxyWallet', 'required');
  }
  if (body.users.isEmpty || body.users.first.address.trim().isEmpty) {
    throw ArgumentError.value(
      body.users,
      'body.users',
      'must contain a first user with an address',
    );
  }

  final payload = _encodeProfileBody(body);
  late final http.Response response;
  try {
    response = await client.post(
      url,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: payload,
    );
  } on Exception catch (e) {
    throw GammaProfileException('create profile: $e', url: url, cause: e);
  }

  if (response.statusCode < 200 || response.statusCode > 299) {
    throw GammaProfileException(
      'HTTP ${response.statusCode} $url: ${response.body}',
      statusCode: response.statusCode,
      responseBody: response.body,
      url: url,
    );
  }

  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return CreateProfileResponse.fromJson(decoded);
    }
    if (decoded is Map) {
      return CreateProfileResponse.fromJson(decoded.cast<String, dynamic>());
    }
    throw GammaProfileException(
      'decode profile response: expected JSON object, got '
      '${decoded.runtimeType}',
      statusCode: response.statusCode,
      responseBody: response.body,
      url: url,
    );
  } on FormatException catch (e) {
    throw GammaProfileException(
      'decode profile response: $e',
      statusCode: response.statusCode,
      responseBody: response.body,
      url: url,
      cause: e,
    );
  }
}

String _encodeProfileBody(CreateProfileRequest body) {
  try {
    return jsonEncode(body.toJson());
  } on JsonUnsupportedObjectError catch (e) {
    throw GammaProfileException('marshal body: $e', cause: e);
  } on UnsupportedError catch (e) {
    throw GammaProfileException('marshal body: $e', cause: e);
  }
}

Uri _profilesUrl(String gammaBaseUrl) {
  final trimmed = gammaBaseUrl.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(gammaBaseUrl, 'gammaBaseUrl', 'required');
  }
  final base = Uri.tryParse(trimmed);
  if (base == null ||
      !base.hasScheme ||
      !base.hasAuthority ||
      (base.scheme != 'http' && base.scheme != 'https') ||
      base.hasQuery ||
      base.hasFragment) {
    throw ArgumentError.value(
      gammaBaseUrl,
      'gammaBaseUrl',
      'must be an http(s) base URL without query or fragment',
    );
  }
  return Uri.parse('${trimmed.replaceFirst(RegExp(r'/+$'), '')}/profiles');
}
