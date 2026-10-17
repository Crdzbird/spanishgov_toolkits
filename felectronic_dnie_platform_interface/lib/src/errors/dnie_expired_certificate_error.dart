part of 'dnie_error.dart';

/// {@template dnie_expired_certificate_error}
/// The certificate on the DNIe has expired.
/// {@endtemplate}
final class DnieExpiredCertificateError extends DnieError {
  /// {@macro dnie_expired_certificate_error}
  const factory DnieExpiredCertificateError() = DnieExpiredCertificateError._;

  const DnieExpiredCertificateError._()
    : super._(
        'The DNIe certificate has expired. '
        'Please renew your DNIe.',
      );
}
