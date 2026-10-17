part of 'dnie_error.dart';

/// {@template dnie_card_tag_error}
/// Could not read the NFC tag from the card.
/// {@endtemplate}
final class DnieCardTagError extends DnieError {
  /// {@macro dnie_card_tag_error}
  const factory DnieCardTagError() = DnieCardTagError._;

  const DnieCardTagError._()
    : super._(
        'Could not get NFC tag from the card. '
        'Please try again.',
      );
}
