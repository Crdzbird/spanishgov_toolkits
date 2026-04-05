/// Cl@ve authentication for Spanish government services.
///
/// Provides a clean API for authenticating via Spain's Cl@ve identity system
/// using OAuth/OIDC. Supports Cl@ve PIN, Cl@ve Permanente, Electronic
/// Certificate, European Credential (eIDAS), and Cl@ve Movil flows.
///
/// ```dart
/// import 'package:felectronic_clave/felectronic_clave.dart';
///
/// final config = ClaveConfig(
///   discoveryUrl: 'https://auth-api.redsara.es/.../openid-configuration',
///   clientId: 'my-client-id',
///   redirectUri: 'com.example.app://login-callback',
///   clientSecret: 'my-secret',
///   userInfoUrl: 'https://auth-api.redsara.es/.../userinfo',
///   logoutUrl: 'https://auth-api.redsara.es/.../logout',
/// );
///
/// final repo = ClaveRepository(config);
/// final result = await repo.login(method: ClaveAuthMethod.clavePin);
/// print(result.accessToken);
/// ```
library;

export 'src/clave_repository.dart';
export 'src/config/clave_config.dart';
export 'src/errors/clave_error.dart';
export 'src/models/clave_auth_method.dart';
export 'src/models/clave_auth_result.dart';
export 'src/models/clave_loa_level.dart';
export 'src/models/clave_mobile_session.dart';
export 'src/storage/clave_token_storage.dart';
export 'src/utils/clave_extensions.dart';
export 'src/utils/clave_mobile_poller.dart';
export 'src/utils/document_validator.dart';
export 'src/utils/jwt_parser.dart';
