part of 'dnie_error.dart';

/// {@template dnie_damaged_error}
/// The DNIe is physically damaged or burned.
/// {@endtemplate}
final class DnieDamagedError extends DnieError {
  /// {@macro dnie_damaged_error}
  const factory DnieDamagedError() = DnieDamagedError._;

  const DnieDamagedError._() : super._('The DNIe appears to be damaged.');
}
