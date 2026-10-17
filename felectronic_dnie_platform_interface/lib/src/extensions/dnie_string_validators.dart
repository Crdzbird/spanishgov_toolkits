import 'package:felectronic_dnie_platform_interface/src/models/dnie_validation_error.dart';

/// Input validation extensions for DNIe operations.
///
/// ```dart
/// final error = controller.text.trim().validateCan();
/// if (error != null) showError(error.message);
/// ```
extension DnieStringValidators on String {
  static final _canPattern = RegExp(r'^\d{6}$');

  /// Whether this string is a valid 6-digit CAN.
  bool get isValidCan => _canPattern.hasMatch(trim());

  /// Returns a [DnieValidationError] if this is not a valid CAN, or `null`.
  DnieValidationError? validateCan() {
    final trimmed = trim();
    if (trimmed.isEmpty) return DnieValidationError.canRequired;
    if (trimmed.length != 6) return DnieValidationError.canLength;
    if (!_canPattern.hasMatch(trimmed)) return DnieValidationError.canFormat;
    return null;
  }

  /// Whether this string is a valid 8-16 character PIN.
  bool get isValidPin {
    final trimmed = trim();
    return trimmed.isNotEmpty && trimmed.length >= 8 && trimmed.length <= 16;
  }

  /// Returns a [DnieValidationError] if this is not a valid PIN, or `null`.
  DnieValidationError? validatePin() {
    final trimmed = trim();
    if (trimmed.isEmpty) return DnieValidationError.pinRequired;
    if (trimmed.length < 8) return DnieValidationError.pinTooShort;
    if (trimmed.length > 16) return DnieValidationError.pinTooLong;
    return null;
  }
}
