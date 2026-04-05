import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage for Cl@ve authentication.
///
/// Wraps [FlutterSecureStorage] to persist access and refresh tokens
/// encrypted on the device.
class ClaveTokenStorage {
  /// Creates a token storage with the given [FlutterSecureStorage] instance.
  ClaveTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'felectronic_clave_access_token';
  static const _refreshTokenKey = 'felectronic_clave_refresh_token';
  static const _backupAccessKey = 'felectronic_clave_backup_access';
  static const _backupRefreshKey = 'felectronic_clave_backup_refresh';
  static const _documentKey = 'felectronic_clave_document';

  // --- Access Token ---

  /// Saves the [accessToken] to secure storage.
  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _accessTokenKey, value: accessToken);

  /// Reads the stored access token, or `null` if not set.
  Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  /// Deletes the stored access token.
  Future<void> deleteAccessToken() =>
      _storage.delete(key: _accessTokenKey);

  // --- Refresh Token ---

  /// Saves the [refreshToken] to secure storage.
  Future<void> saveRefreshToken(String refreshToken) =>
      _storage.write(key: _refreshTokenKey, value: refreshToken);

  /// Reads the stored refresh token, or `null` if not set.
  Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  /// Deletes the stored refresh token.
  Future<void> deleteRefreshToken() =>
      _storage.delete(key: _refreshTokenKey);

  // --- Backup Tokens (for LOA elevation) ---

  /// Backs up the current tokens before attempting a higher LOA login.
  Future<void> backupTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    if (access != null) {
      await _storage.write(key: _backupAccessKey, value: access);
    }
    if (refresh != null) {
      await _storage.write(key: _backupRefreshKey, value: refresh);
    }
  }

  /// Restores tokens from backup (after a failed LOA elevation).
  Future<void> restoreBackup() async {
    final access = await _storage.read(key: _backupAccessKey);
    final refresh = await _storage.read(key: _backupRefreshKey);
    if (access != null) await saveAccessToken(access);
    if (refresh != null) await saveRefreshToken(refresh);
    await _storage.delete(key: _backupAccessKey);
    await _storage.delete(key: _backupRefreshKey);
  }

  // --- Document (for Cl@ve Movil) ---

  /// Saves the user's document identifier for Cl@ve Movil polling.
  Future<void> saveDocument(String document) =>
      _storage.write(key: _documentKey, value: document);

  /// Reads the stored document identifier.
  Future<String?> getDocument() =>
      _storage.read(key: _documentKey);

  // --- Clear All ---

  /// Deletes all tokens and cached data.
  Future<void> clearAll() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await _storage.delete(key: _backupAccessKey);
    await _storage.delete(key: _backupRefreshKey);
    await _storage.delete(key: _documentKey);
  }
}
