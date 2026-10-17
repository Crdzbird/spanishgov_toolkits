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
