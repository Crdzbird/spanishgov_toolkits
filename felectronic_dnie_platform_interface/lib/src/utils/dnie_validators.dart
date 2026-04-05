/// {@template dnie_validation_error}
/// Validation errors for DNIe credential input.
/// {@endtemplate}
enum DnieValidationError {
  /// CAN field is empty.
  canRequired('CAN is required.'),

  /// CAN is not exactly 6 characters.
  canLength('CAN must be exactly 6 digits.'),

  /// CAN contains non-digit characters.
  canFormat('CAN must contain only digits.'),

  /// PIN field is empty.
  pinRequired('PIN is required.'),

  /// PIN is shorter than 8 characters.
  pinTooShort('PIN must be at least 8 characters.'),

  /// PIN is longer than 16 characters.
  pinTooLong('PIN must be at most 16 characters.');

  /// {@macro dnie_validation_error}
  const DnieValidationError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => message;
}

/// {@template nfc_status_type}
/// The current state of the device's NFC hardware.
/// {@endtemplate}
enum NfcStatusType {
  /// NFC hardware is available and enabled.
  ready('NFC is ready.'),

  /// The device does not have NFC hardware.
  unavailable('This device does not have NFC.'),

  /// NFC hardware exists but is disabled in system settings.
  disabled('NFC is disabled. Enable it in Settings.');

  /// {@macro nfc_status_type}
  const NfcStatusType(this.message);

  /// Human-readable status message.
  final String message;

  @override
  String toString() => message;
}

/// {@template certificate_expiry_status}
/// The expiry state of a certificate.
/// {@endtemplate}
enum CertificateExpiryStatus {
  /// Certificate validity period has not started yet.
  notYetValid('Not yet valid'),

  /// Certificate has expired.
  expired('Expired'),

  /// Certificate expires today.
  expiresToday('Expires today'),

  /// Certificate expires tomorrow.
  expiresTomorrow('Expires tomorrow'),

  /// Certificate is valid with days remaining.
  ///
  /// Use [withDays] to get a formatted message.
  valid('');

  /// {@macro certificate_expiry_status}
  const CertificateExpiryStatus(this.message);

  /// Human-readable status message.
  ///
  /// For [valid], use [withDays] instead.
  final String message;

  /// Returns a formatted message for [valid] status with the number of days.
  String withDays(int days) =>
      this == valid ? 'Expires in $days days' : message;

  @override
  String toString() => message;
}

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
    return trimmed.isNotEmpty &&
        trimmed.length >= 8 &&
        trimmed.length <= 16;
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
