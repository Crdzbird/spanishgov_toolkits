/// Input validation extensions for DNIe operations.
///
/// ```dart
/// final can = controller.text.trim();
/// final error = can.validateCan();
/// if (error != null) showError(error);
/// ```
extension DnieStringValidators on String {
  static final _canPattern = RegExp(r'^\d{6}$');

  /// Whether this string is a valid 6-digit CAN.
  bool get isValidCan => _canPattern.hasMatch(trim());

  /// Returns an error message if this is not a valid CAN, or `null`.
  String? validateCan() {
    final trimmed = trim();
    if (trimmed.isEmpty) return 'CAN is required.';
    if (trimmed.length != 6) return 'CAN must be exactly 6 digits.';
    if (!_canPattern.hasMatch(trimmed)) return 'CAN must contain only digits.';
    return null;
  }

  /// Whether this string is a valid 8-16 character PIN.
  bool get isValidPin {
    final trimmed = trim();
    return trimmed.isNotEmpty &&
        trimmed.length >= 8 &&
        trimmed.length <= 16;
  }

  /// Returns an error message if this is not a valid PIN, or `null`.
  String? validatePin() {
    final trimmed = trim();
    if (trimmed.isEmpty) return 'PIN is required.';
    if (trimmed.length < 8) return 'PIN must be at least 8 characters.';
    if (trimmed.length > 16) return 'PIN must be at most 16 characters.';
    return null;
  }
}
