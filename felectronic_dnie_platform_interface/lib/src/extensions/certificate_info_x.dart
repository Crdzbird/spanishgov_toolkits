import 'package:felectronic_dnie_platform_interface/src/models/certificate_expiry_status.dart';
import 'package:felectronic_dnie_platform_interface/src/models/certificate_info.dart';

/// Convenience extensions on [CertificateInfo].
extension CertificateInfoX on CertificateInfo {
  /// Days remaining until the certificate expires.
  /// Negative if already expired.
  int get daysUntilExpiry => notValidAfter.difference(DateTime.now()).inDays;

  /// Whether the certificate expires within 30 days.
  bool get isExpiringSoon => !isExpired && daysUntilExpiry <= 30;

  /// Whether the certificate can sign right now.
  bool get isValidForSigning => isValidAt(DateTime.now());

  /// The structured expiry status as an enum value.
  CertificateExpiryStatus get expiryStatusType {
    if (isNotYetValid) return CertificateExpiryStatus.notYetValid;
    if (isExpired) return CertificateExpiryStatus.expired;
    final days = daysUntilExpiry;
    if (days == 0) return CertificateExpiryStatus.expiresToday;
    if (days == 1) return CertificateExpiryStatus.expiresTomorrow;
    return CertificateExpiryStatus.valid;
  }

  /// Human-readable expiry status string.
  String get expiryStatus => expiryStatusType.describe(daysUntilExpiry);
}
