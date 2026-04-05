import 'package:flutter/foundation.dart';

/// {@template clave_auth_result}
/// The result of a successful Cl@ve authentication.
/// {@endtemplate}
@immutable
class ClaveAuthResult {
  /// {@macro clave_auth_result}
  const ClaveAuthResult({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  /// The OAuth access token.
  final String accessToken;

  /// The OAuth refresh token, if available.
  final String? refreshToken;

  /// Token expiry in seconds from issuance.
  final int? expiresIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaveAuthResult &&
          other.accessToken == accessToken &&
          other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);

  @override
  String toString() => 'ClaveAuthResult(expiresIn: $expiresIn)';
}
