import 'package:felectronic_dnie_platform_interface/src/errors/dnie_error.dart';

/// Groups [DnieError]s by what the user can do about them.
extension DnieErrorX on DnieError {
  /// Whether trying again, holding the card steady, is likely to succeed.
  bool get isRetryable => switch (this) {
    DnieTimeoutError() || DnieConnectionError() || DnieCardTagError() => true,
    _ => false,
  };

  /// Whether the CAN or PIN is the problem, so the user should check them
  /// rather than retry as they are.
  bool get isCredentialError => switch (this) {
    DnieWrongPinError() || DnieWrongCanError() || DnieLockedPinError() => true,
    _ => false,
  };
}
