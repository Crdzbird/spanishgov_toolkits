// ignore_for_file: avoid_print

import 'package:felectronic_clave/felectronic_clave.dart';

Future<void> main() async {
  // 1. Configure the Cl@ve client.
  const config = ClaveConfig(
    discoveryUrl:
        'https://auth-api.redsara.es/auth/realms/.../openid-configuration',
    clientId: 'my-client-id',
    redirectUri: 'com.example.app://login-callback',
    clientSecret: 'my-client-secret',
    userInfoUrl:
        'https://auth-api.redsara.es/auth/realms/.../openid-connect/userinfo',
    logoutUrl:
        'https://auth-api.redsara.es/auth/realms/.../openid-connect/logout',
  );

  final repo = ClaveRepository(config);

  // 2. Login with Cl@ve PIN.
  try {
    final result = await repo.login(method: ClaveAuthMethod.clavePin);
    print('Access token: ${result.accessToken}');
  } on ClaveAuthCancelledError {
    print('User cancelled login');
  } on ClaveError catch (e) {
    print('Login error: ${e.message}');
  }

  // 3. Check stored token.
  final token = await repo.getStoredToken();
  if (token != null) {
    print('Stored token available');
  }

  // 4. Validate a Spanish document number.
  print(DocumentValidator.isValidDni('12345678Z')); // true or false
  print(DocumentValidator.isValidNie('X1234567L')); // true or false

  // 5. Cleanup.
  repo.dispose();
}
