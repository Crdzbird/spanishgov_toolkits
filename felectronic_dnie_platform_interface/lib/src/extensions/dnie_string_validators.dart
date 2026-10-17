import 'package:felectronic_dnie_platform_interface/src/models/dnie_validation_error.dart';

/// Input validation extensions for DNIe operations.
///
/// Surrounding whitespace is ignored, as it is by the operations themselves.
///
/// ```dart
/// final error = controller.text.validateCan();
/// if (error != null) showError(error.message);
/// ```
extension DnieStringValidators on String {
  static final _digits = RegExp(r'^\d+$');
  static final _nif = RegExp(r'^([XYZ]?)(\d{7,8})([A-Z])$');
  static const _nifLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';

  /// Whether this string is a valid 6-digit CAN.
  bool get isValidCan => validateCan() == null;

  /// Returns a [DnieValidationError] if this is not a valid CAN, or `null`.
  DnieValidationError? validateCan() {
    final can = trim();
    if (can.isEmpty) return DnieValidationError.canRequired;
    if (can.length != 6) return DnieValidationError.canLength;
    if (!_digits.hasMatch(can)) return DnieValidationError.canFormat;
    return null;
  }

  /// Whether this string is a valid 8-16 character PIN.
  bool get isValidPin => validatePin() == null;

  /// Returns a [DnieValidationError] if this is not a valid PIN, or `null`.
  DnieValidationError? validatePin() {
    final pin = trim();
    if (pin.isEmpty) return DnieValidationError.pinRequired;
    if (pin.length < 8) return DnieValidationError.pinTooShort;
    if (pin.length > 16) return DnieValidationError.pinTooLong;
    return null;
  }

  /// Whether this is a NIF (8 digits and a letter) or NIE (X, Y or Z, 7
  /// digits and a letter) whose control letter matches its number.
  bool get isValidNif {
    final match = _nif.firstMatch(trim().toUpperCase());
    if (match == null) return false;
    final prefix = match.group(1)!;
    final digits = match.group(2)!;
    if (digits.length != (prefix.isEmpty ? 8 : 7)) return false;
    final lead = prefix.isEmpty ? '' : '${'XYZ'.indexOf(prefix)}';
    return _nifLetters[int.parse('$lead$digits') % 23] == match.group(3);
  }
}
