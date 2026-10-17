import 'package:flutter/services.dart';

part 'dnie_cancelled_error.dart';
part 'dnie_card_tag_error.dart';
part 'dnie_connection_error.dart';
part 'dnie_damaged_error.dart';
part 'dnie_error_codes.dart';
part 'dnie_error_names.dart';
part 'dnie_expired_certificate_error.dart';
part 'dnie_locked_pin_error.dart';
part 'dnie_not_dnie_error.dart';
part 'dnie_private_key_error.dart';
part 'dnie_provider_error.dart';
part 'dnie_signing_error.dart';
part 'dnie_timeout_error.dart';
part 'dnie_underage_error.dart';
part 'dnie_unknown_error.dart';
part 'dnie_wrong_can_error.dart';
part 'dnie_wrong_pin_error.dart';

/// {@template dnie_error}
/// Sealed hierarchy of errors that can occur during DNIe NFC operations.
/// {@endtemplate}
sealed class DnieError implements Exception {
  const DnieError._(this.message);

  /// Maps a [PlatformException] from the native side to a typed [DnieError].
  ///
  /// The native plugins use consistent error codes across Android and iOS.
  factory DnieError.fromPlatformException(PlatformException exception) =>
      _fromPlatformException(exception);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => '${_typeName(this)}: $message';
}
