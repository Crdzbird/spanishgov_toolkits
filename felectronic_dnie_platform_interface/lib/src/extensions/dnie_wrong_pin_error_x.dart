import 'package:felectronic_dnie_platform_interface/src/errors/dnie_error.dart';

/// Convenience extensions on [DnieWrongPinError].
extension DnieWrongPinErrorX on DnieWrongPinError {
  /// Whether one more wrong PIN will lock the card.
  bool get isLastAttempt => remainingRetries == 1;
}
