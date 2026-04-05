import 'package:flutter/foundation.dart';

/// {@template clave_mobile_session}
/// An active Cl@ve Movil session awaiting user confirmation
/// on the Cl@ve mobile app.
///
/// Use `ClaveRepository.validateNotificationCode` to poll for completion.
/// {@endtemplate}
@immutable
class ClaveMobileSession {
  /// {@macro clave_mobile_session}
  const ClaveMobileSession({
    required this.token,
    required this.verificationCode,
    required this.document,
  });

  /// The Cl@ve Movil session token for polling.
  final String token;

  /// The verification code displayed to the user for confirmation.
  final String verificationCode;

  /// The DNI or NIE document used to initiate the session.
  final String document;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaveMobileSession && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() =>
      'ClaveMobileSession(code: $verificationCode, doc: $document)';
}
