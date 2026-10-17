part of 'dnie_error.dart';

/// {@template dnie_provider_error}
/// Failed to create the DNIe cryptographic provider.
/// {@endtemplate}
final class DnieProviderError extends DnieError {
  /// {@macro dnie_provider_error}
  const factory DnieProviderError() = DnieProviderError._;

  const DnieProviderError._()
    : super._(
        'Failed to create DNIe provider. '
        'The card may not be a valid DNIe.',
      );
}
