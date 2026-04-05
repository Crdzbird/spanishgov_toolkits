import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// {@template clave_token_storage}
/// Secure token storage for Cl@ve authentication.
///
/// Wraps [FlutterSecureStorage] to persist access and refresh tokens
/// encrypted on the device.
/// {@endtemplate}
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
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  /// Deletes the stored access token.
  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);

  // --- Refresh Token ---

  /// Saves the [refreshToken] to secure storage.
  Future<void> saveRefreshToken(String refreshToken) =>
      _storage.write(key: _refreshTokenKey, value: refreshToken);

  /// Reads the stored refresh token, or `null` if not set.
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Deletes the stored refresh token.
  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshTokenKey);

  // --- Backup Tokens (for LOA elevation) ---

  /// Backs up the current tokens before attempting a higher LOA login.
  Future<void> backupTokens() async {
    final results = await Future.wait([getAccessToken(), getRefreshToken()]);
    final access = results[0];
    final refresh = results[1];
    final writes = <Future<void>>[];
    if (access != null) {
      writes.add(_storage.write(key: _backupAccessKey, value: access));
    }
    if (refresh != null) {
      writes.add(_storage.write(key: _backupRefreshKey, value: refresh));
    }
    await Future.wait(writes);
  }

  /// Restores tokens from backup (after a failed LOA elevation).
  Future<void> restoreBackup() async {
    final result = await Future.wait<String?>([
      _storage.read(key: _backupAccessKey),
      _storage.read(key: _backupRefreshKey),
    ]);
    await Future.wait([
      if (result[0] != null) saveAccessToken(result[0]!),
      if (result[1] != null) saveRefreshToken(result[1]!),
      _storage.delete(key: _backupAccessKey),
      _storage.delete(key: _backupRefreshKey),
    ]);
  }

  // --- Document (for Cl@ve Movil) ---

  /// Saves the user's document identifier for Cl@ve Movil polling.
  Future<void> saveDocument(String document) =>
      _storage.write(key: _documentKey, value: document);

  /// Reads the stored document identifier.
  Future<String?> getDocument() => _storage.read(key: _documentKey);

  // --- Clear All ---

  /// Deletes all tokens and cached data.
  Future<void> clearAll() => Future.wait([
        deleteAccessToken(),
        deleteRefreshToken(),
        _storage.delete(key: _backupAccessKey),
        _storage.delete(key: _backupRefreshKey),
        _storage.delete(key: _documentKey),
      ]);
}
