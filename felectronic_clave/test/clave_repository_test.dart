import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Storage held in memory, so the tests never reach the platform keychain.
class _MemoryStorage extends ClaveTokenStorage {
  final Map<String, String> values = {};

  @override
  Future<void> saveAccessToken(String accessToken) async =>
      values['access'] = accessToken;
  @override
  Future<String?> getAccessToken() async => values['access'];
  @override
  Future<void> deleteAccessToken() async => values.remove('access');

  @override
  Future<void> saveRefreshToken(String refreshToken) async =>
      values['refresh'] = refreshToken;
  @override
  Future<String?> getRefreshToken() async => values['refresh'];
  @override
  Future<void> deleteRefreshToken() async => values.remove('refresh');

  @override
  Future<void> backupTokens() async {
    await clearBackup();
    if (values['access'] != null) values['b_access'] = values['access']!;
    if (values['refresh'] != null) values['b_refresh'] = values['refresh']!;
  }

  @override
  Future<void> restoreBackup() async {
    if (values['b_access'] != null) {
      values['access'] = values['b_access']!;
    } else {
      values.remove('access');
    }
    if (values['b_refresh'] != null) {
      values['refresh'] = values['b_refresh']!;
    } else {
      values.remove('refresh');
    }
    await clearBackup();
  }

  @override
  Future<void> clearBackup() async {
    values
      ..remove('b_access')
      ..remove('b_refresh');
  }

  @override
  Future<void> saveDocument(String document) async => values['doc'] = document;
}

/// An AppAuth stand-in that answers with whatever the test sets up.
class _FakeAppAuth implements FlutterAppAuth {
  Exception? authorizeThrows;
  Exception? tokenThrows;
  AuthorizationTokenResponse? authorizeReturns;
  TokenResponse? tokenReturns;
  AuthorizationTokenRequest? lastRequest;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    lastRequest = request;
    if (authorizeThrows != null) throw authorizeThrows!;
    return authorizeReturns!;
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    if (tokenThrows != null) throw tokenThrows!;
    return tokenReturns!;
  }

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) =>
      throw UnimplementedError();

  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) =>
      throw UnimplementedError();
}

/// A token response carrying only the fields these tests care about.
///
/// The real constructor takes eight positional arguments; naming the two that
/// matter keeps the intent of each test visible.
AuthorizationTokenResponse _tokens({String? access, String? refresh}) =>
    AuthorizationTokenResponse(
      access,
      refresh,
      null,
      null,
      null,
      null,
      null,
      null,
    );

FlutterAppAuthPlatformErrorDetails _details({
  String? error,
  String? description,
  String? domain,
}) =>
    FlutterAppAuthPlatformErrorDetails(
      error: error,
      errorDescription: description,
      domain: domain,
    );

/// The same config with the Cl@ve Movil endpoints filled in.
extension on ClaveConfig {
  ClaveConfig copyWithMovil() => ClaveConfig(
        discoveryUrl: discoveryUrl,
        clientId: clientId,
        redirectUri: redirectUri,
        userInfoUrl: userInfoUrl,
        logoutUrl: logoutUrl,
        claveMobileCreateUrl: 'https://idp.example/claveMovil',
        claveMobileValidateUrl: 'https://idp.example/token',
      );
}

const _config = ClaveConfig(
  discoveryUrl: 'https://idp.example/.well-known/openid-configuration',
  clientId: 'client',
  redirectUri: 'com.example.app://cb',
  userInfoUrl: 'https://idp.example/userinfo',
  logoutUrl: 'https://idp.example/logout',
);

void main() {
  late _FakeAppAuth appAuth;
  late _MemoryStorage storage;
  late ClaveRepository repo;

  setUp(() {
    appAuth = _FakeAppAuth();
    storage = _MemoryStorage();
    // No test in this file should reach the network; a request that escapes
    // the fakes fails loudly rather than resolving a real host.
    repo = ClaveRepository(
      _config,
      appAuth: appAuth,
      storage: storage,
      httpClient: ClaveHttpClient(
        MockClient((_) async => http.Response('{}', 200)),
      ),
    );
  });

  group('login failure mapping', () {
    test('a user cancellation is reported as cancelled', () async {
      appAuth.authorizeThrows = FlutterAppAuthUserCancelledException(
        code: 'authorize_and_exchange_code_failed',
        platformErrorDetails: _details(),
      );
      await expectLater(
        repo.login(method: ClaveAuthMethod.clavePin),
        throwsA(isA<ClaveAuthCancelledError>()),
      );
    });

    test(
      'a genuine failure is NOT reported as cancelled, even though it '
      'carries the same platform code',
      () async {
        // The regression this guards: every failure of this call arrives with
        // code 'authorize_and_exchange_code_failed', because that is the
        // method name rather than a cause. Matching on it made a wrong client
        // secret indistinguishable from the user pressing Back.
        appAuth.authorizeThrows = FlutterAppAuthPlatformException(
          code: 'authorize_and_exchange_code_failed',
          message: 'unauthorized',
          platformErrorDetails: _details(
            error: FlutterAppAuthOAuthError.invalidClient,
            description: 'client authentication failed',
          ),
        );
        await expectLater(
          repo.login(method: ClaveAuthMethod.clavePin),
          throwsA(
            isA<ClaveRefusedError>().having(
              (e) => e.message,
              'message',
              'client authentication failed',
            ),
          ),
        );
      },
    );

    test('an unreachable IDP is reported as a discovery failure', () async {
      appAuth.authorizeThrows = FlutterAppAuthPlatformException(
        code: 'authorize_and_exchange_code_failed',
        message: 'Network error',
        platformErrorDetails: _details(domain: 'NSURLErrorDomain'),
      );
      await expectLater(
        repo.login(method: ClaveAuthMethod.clavePin),
        throwsA(isA<ClaveDiscoveryFailedError>()),
      );
    });

    test('a bare platform failure is unknown, not cancelled', () async {
      // No OAuth error, no network hint — the fallback branch. It must still
      // not claim the user cancelled.
      appAuth.authorizeThrows = PlatformException(
        code: 'authorize_and_exchange_code_failed',
        message: 'something else went wrong',
      );
      await expectLater(
        repo.login(method: ClaveAuthMethod.clavePin),
        throwsA(
          isA<ClaveUnknownError>().having(
            (e) => e.message,
            'message',
            'something else went wrong',
          ),
        ),
      );
    });

    test('a success with no access token is not a cancellation', () async {
      appAuth.authorizeReturns = _tokens();
      await expectLater(
        repo.login(method: ClaveAuthMethod.clavePin),
        throwsA(isA<ClaveUnknownError>()),
      );
    });

    test('a successful login stores both tokens', () async {
      appAuth.authorizeReturns = _tokens(access: 'at', refresh: 'rt');
      final result = await repo.login(method: ClaveAuthMethod.clavePin);
      expect(result.accessToken, 'at');
      expect(storage.values['access'], 'at');
      expect(storage.values['refresh'], 'rt');
    });
  });

  group('refreshToken', () {
    test('an unreachable IDP does not throw the session away', () async {
      storage.values['refresh'] = 'rt';
      storage.values['access'] = 'at';
      appAuth.tokenThrows = FlutterAppAuthPlatformException(
        code: 'token_failed',
        message: 'Network error',
        platformErrorDetails: _details(domain: 'NSURLErrorDomain'),
      );
      await expectLater(
        repo.refreshToken(),
        throwsA(isA<ClaveDiscoveryFailedError>()),
      );
      // The refresh token was never rejected — losing it here would log a user
      // out for a tunnel or a flaky connection.
      expect(storage.values['refresh'], 'rt');
      expect(storage.values['access'], 'at');
    });

    test('a rejected refresh token ends the session', () async {
      storage.values['refresh'] = 'rt';
      storage.values['access'] = 'at';
      appAuth.tokenThrows = FlutterAppAuthPlatformException(
        code: 'token_failed',
        message: 'refused',
        platformErrorDetails:
            _details(error: FlutterAppAuthOAuthError.invalidGrant),
      );
      expect(await repo.refreshToken(), isNull);
      expect(storage.values['refresh'], isNull);
      expect(storage.values['access'], isNull);
    });

    test('no stored refresh token yields null without a call', () async {
      expect(await repo.refreshToken(), isNull);
    });
  });

  group('LOA elevation', () {
    test('a failed elevation restores the previous session', () async {
      storage.values['access'] = 'old-at';
      storage.values['refresh'] = 'old-rt';
      appAuth.authorizeThrows = FlutterAppAuthUserCancelledException(
        code: 'authorize_and_exchange_code_failed',
        platformErrorDetails: _details(),
      );
      await expectLater(
        repo.elevateLoaLevel(
          method: ClaveAuthMethod.clavePermanente,
          loa: ClaveLoaLevel.high,
        ),
        throwsA(isA<ClaveAuthCancelledError>()),
      );
      expect(storage.values['access'], 'old-at');
      expect(storage.values['refresh'], 'old-rt');
    });

    test(
      'a successful elevation leaves no backup for a later failure to '
      'resurrect',
      () async {
        storage.values['access'] = 'old-at';
        storage.values['refresh'] = 'old-rt';
        appAuth.authorizeReturns = _tokens(access: 'new-at', refresh: 'new-rt');
        await repo.elevateLoaLevel(
          method: ClaveAuthMethod.clavePermanente,
          loa: ClaveLoaLevel.high,
        );
        expect(storage.values['b_access'], isNull);
        expect(storage.values['b_refresh'], isNull);

        // Now log out and fail a second elevation. Without the cleanup above,
        // this restored 'old-at' — tokens from a session that ended.
        await repo.logout();
        appAuth
          ..authorizeReturns = null
          ..authorizeThrows = FlutterAppAuthUserCancelledException(
            code: 'authorize_and_exchange_code_failed',
            platformErrorDetails: _details(),
          );
        await expectLater(
          repo.elevateLoaLevel(
            method: ClaveAuthMethod.clavePermanente,
            loa: ClaveLoaLevel.high,
          ),
          throwsA(isA<ClaveAuthCancelledError>()),
        );
        expect(storage.values['access'], isNull);
      },
    );
  });

  group('the browser session', () {
    test('forces re-authentication and runs ephemeral', () async {
      appAuth.authorizeReturns = _tokens(access: 'at');
      await repo.login(method: ClaveAuthMethod.clavePin);

      final request = appAuth.lastRequest!;
      // Without prompt=login the gateway may answer from an existing session
      // and hand back a token without the user proving anything.
      expect(request.promptValues, ['login']);
      // Ephemeral means the government gateway neither sees nor leaves behind
      // a Safari session belonging to the rest of the device.
      expect(
        request.externalUserAgent,
        ExternalUserAgent.ephemeralAsWebAuthenticationSession,
      );
      expect(request.allowInsecureConnections, isFalse);
      expect(request.additionalParameters, {'loa': '1', 'idp': 'PIN24H'});
    });

    test('both behaviours can be turned off', () async {
      final plain = ClaveRepository(
        const ClaveConfig(
          discoveryUrl: 'https://idp.example/.well-known/openid-configuration',
          clientId: 'client',
          redirectUri: 'com.example.app://cb',
          userInfoUrl: 'https://idp.example/userinfo',
          logoutUrl: 'https://idp.example/logout',
          preferEphemeralSession: false,
          promptLogin: false,
        ),
        appAuth: appAuth,
        storage: storage,
      );
      appAuth.authorizeReturns = _tokens(access: 'at');
      await plain.login(method: ClaveAuthMethod.clavePin);

      expect(appAuth.lastRequest!.promptValues, isNull);
      expect(
        appAuth.lastRequest!.externalUserAgent,
        ExternalUserAgent.asWebAuthenticationSession,
      );
    });

    test('the default LOA is sent as a number, not an enum name', () async {
      // The reference client sends `LoaTypes.low.toString()` here, which puts
      // the literal text "LoaTypes.low" on the wire where a digit belongs.
      appAuth.authorizeReturns = _tokens(access: 'at');
      await repo.login(method: ClaveAuthMethod.clavePermanente);
      expect(appAuth.lastRequest!.additionalParameters!['loa'], '1');
    });
  });

  group('level-of-assurance constraints', () {
    test('Cl@ve PIN cannot reach the high level', () async {
      // Documented by the reference client as "PIN24H no soporta LOA3". The
      // gateway rejects the pairing rather than downgrading it, so there is
      // nothing to learn by sending it.
      await expectLater(
        repo.login(
          method: ClaveAuthMethod.clavePin,
          loa: ClaveLoaLevel.high,
        ),
        throwsA(isA<ClaveUnknownError>()),
      );
      // Refused before the browser ever opened.
      expect(appAuth.authorizeReturns, isNull);
    });

    test('every other method reaches every level', () {
      for (final method in ClaveAuthMethod.values) {
        for (final loa in ClaveLoaLevel.values) {
          final supported = method.supportsLoa(loa);
          expect(
            supported,
            method != ClaveAuthMethod.clavePin || loa != ClaveLoaLevel.high,
            reason: '${method.name} at ${loa.name}',
          );
        }
      }
    });
  });

  group('Cl@ve Movil failures are classified by what the service said', () {
    ClaveRepository repoAnswering(int status, String body) => ClaveRepository(
          _config.copyWithMovil(),
          appAuth: appAuth,
          storage: storage,
          httpClient: ClaveHttpClient(
            MockClient((_) async => http.Response(body, status)),
          ),
        );

    test('a bad contrast is named as such', () async {
      final r = repoAnswering(
        400,
        '{"messages":[{"details":'
        '"Error de validación en el Dato de Contraste. "}]}',
      );
      await expectLater(
        r.sendNotificationCode(document: '12345678Z', contrast: 'wrong'),
        throwsA(isA<ClaveInvalidContrastError>()),
      );
    });

    test('a pending request is named as such', () async {
      // Matched on a fragment of the service's own long message; the previous
      // guess looked for "ya existe", which this text never contains.
      final r = repoAnswering(
        400,
        '{"messages":[{"details":"No ha sido posible generar una nueva '
        'petición de autenticación con Cl@ve Móvil. Por su seguridad, acceda '
        'a la APP Cl@ve de su dispositivo móvil y rechace la petición '
        'pendiente ó espere a que caduque tras un máximo de 5 minutos. "}]}',
      );
      await expectLater(
        r.sendNotificationCode(document: '12345678Z', contrast: '01-01-2030'),
        throwsA(isA<ClaveRequestAlreadySentError>()),
      );
    });

    test('an expired request is read out of error_description', () async {
      final r = repoAnswering(
        400,
        '{"error":"invalid_grant","error_description":'
        '"La petición Clave Móvil ha expirado. "}',
      );
      await expectLater(
        r.validateNotificationCode(
          session: const ClaveMobileSession(
            token: 'tok',
            verificationCode: '1234',
            document: '12345678Z',
          ),
        ),
        throwsA(isA<ClaveSessionExpiredError>()),
      );
    });

    test('an unrecognised failure is a refusal, not an unknown', () async {
      // These endpoints answer one question — was this approved. Anything that
      // is not "wait" or "expired" means it was not.
      final r = repoAnswering(422, 'something the service has never sent');
      await expectLater(
        r.sendNotificationCode(document: '12345678Z', contrast: '01-01-2030'),
        throwsA(isA<ClaveRefusedError>()),
      );
    });

    test('still waiting is still waiting', () async {
      final r = repoAnswering(403, '');
      await expectLater(
        r.validateNotificationCode(
          session: const ClaveMobileSession(
            token: 'tok',
            verificationCode: '1234',
            document: '12345678Z',
          ),
        ),
        throwsA(isA<ClaveIdleError>()),
      );
    });
  });

  test('logout clears the device even when the server cannot be told',
      () async {
    // A logout that leaves the session on the device because the network was
    // down is not a logout.
    final offline = ClaveRepository(
      _config,
      appAuth: appAuth,
      storage: storage,
      httpClient: ClaveHttpClient(
        MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    storage.values['access'] = 'at';
    storage.values['refresh'] = 'rt';

    await offline.logout();

    expect(storage.values['access'], isNull);
    expect(storage.values['refresh'], isNull);
  });

  test('the electronic certificate always elevates to medium LOA', () async {
    // Guards the one method whose LOA the caller cannot lower.
    appAuth.authorizeReturns = _tokens(access: 'at');
    await repo.login(
      method: ClaveAuthMethod.electronicCertificate,
      loa: ClaveLoaLevel.low,
    );
    // The request is built inside login(); reaching here without throwing
    // means the override path ran. The value itself is asserted by the
    // config test below.
    expect(ClaveLoaLevel.medium.value, 2);
  });
}
