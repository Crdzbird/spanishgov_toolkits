/// {@template certificate_expiry_status}
/// The expiry state of a certificate.
/// {@endtemplate}
enum CertificateExpiryStatus {
  /// Certificate validity period has not started yet.
  notYetValid,

  /// Certificate has expired.
  expired,

  /// Certificate expires today.
  expiresToday,

  /// Certificate expires tomorrow.
  expiresTomorrow,

  /// Certificate is valid with more than a day remaining.
  valid;

  /// A short English description of this status, using [daysLeft] for
  /// [valid].
  String describe(int daysLeft) => switch (this) {
    notYetValid => 'Not yet valid',
    expired => 'Expired',
    expiresToday => 'Expires today',
    expiresTomorrow => 'Expires tomorrow',
    valid => 'Expires in $daysLeft days',
  };
}
