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
