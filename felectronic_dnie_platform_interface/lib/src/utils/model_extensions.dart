import 'package:felectronic_dnie_platform_interface/src/models/certificate_info.dart';
import 'package:felectronic_dnie_platform_interface/src/models/nfc_status.dart';
import 'package:felectronic_dnie_platform_interface/src/models/personal_data.dart';
import 'package:felectronic_dnie_platform_interface/src/models/signed_data.dart';
import 'package:felectronic_dnie_platform_interface/src/utils/dnie_validators.dart';
import 'package:felectronic_x509/felectronic_x509.dart';

/// Convenience extensions on [CertificateInfo].
extension CertificateInfoX on CertificateInfo {
  /// Days remaining until the certificate expires.
  /// Negative if already expired.
  int get daysUntilExpiry =>
      notValidAfter.difference(DateTime.now()).inDays;

  /// Whether the certificate expires within 30 days.
  bool get isExpiringSoon =>
      !isExpired && daysUntilExpiry <= 30;

  /// Whether the certificate is currently valid for signing.
  bool get isValidForSigning =>
      isCurrentlyValid && !isExpired && !isNotYetValid;

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
  String get expiryStatus {
    final type = expiryStatusType;
    return type == CertificateExpiryStatus.valid
        ? type.withDays(daysUntilExpiry)
        : type.message;
  }
}

/// Convenience extensions on [SignedData].
extension SignedDataX on SignedData {
  /// Whether the signed data bytes are present.
  bool get hasSignature => signedData.isNotEmpty;

  /// Whether the certificate string is present.
  bool get hasCertificate => certificate.isNotEmpty;

  /// Whether both signature and certificate are present.
  bool get isComplete => hasSignature && hasCertificate;

  /// The size of the signature in bytes.
  int get signatureSizeBytes => signedData.length;

  /// Parses the full X.509 certificate from the base64-encoded
  /// [certificate] string.
  ///
  /// Returns `null` if the certificate is empty or malformed.
  X509Certificate? get parsedCertificate {
    if (certificate.isEmpty) return null;
    try {
      return X509Parser.fromBase64(certificate);
    } on FormatException {
      return null;
    }
  }
}

/// Convenience extensions on [NfcStatus].
extension NfcStatusX on NfcStatus {
  /// Whether NFC is available and enabled — ready for operations.
  bool get isReady => isAvailable && isEnabled;

  /// The structured NFC status as an enum value.
  NfcStatusType get statusType {
    if (!isAvailable) return NfcStatusType.unavailable;
    if (!isEnabled) return NfcStatusType.disabled;
    return NfcStatusType.ready;
  }

  /// Human-readable NFC status message.
  String get statusMessage => statusType.message;
}

/// Convenience extensions on [PersonalData].
extension PersonalDataX on PersonalData {
  /// Initials from the given name and surnames (e.g. "J.G.").
  String get initials {
    final parts = <String>[];
    if (givenName.isNotEmpty) parts.add(givenName[0]);
    if (surnames.isNotEmpty) parts.add(surnames[0]);
    return parts.map((c) => '$c.').join();
  }

  /// Whether this is a signing (FIRMA) certificate.
  bool get isSigningCert =>
      certificateType.toUpperCase() == 'FIRMA';

  /// Whether this is an authentication certificate.
  bool get isAuthCert =>
      certificateType.toUpperCase() == 'AUTENTICACION';
}
