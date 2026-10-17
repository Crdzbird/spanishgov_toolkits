import 'package:felectronic_certificates/felectronic_certificates.dart'
    as certs;

/// A few readable lines about an installed certificate.
extension CertificateSummary on certs.DeviceCertificate {
  String get summary => [
    displayName,
    '  Serial: $serialNumber',
    '  Issuer: $issuerName',
    '  $expiryStatus',
    '  Usages: $usageSummary',
    if (isExpiringSoon) '  Expiring soon',
    if (canSign) '  Can sign',
    if (canAuthenticate) '  Can authenticate',
  ].join('\n');
}

/// Summaries of several certificates, or how to get one when there are none.
extension CertificateListSummary on List<certs.DeviceCertificate> {
  String get summary => isEmpty
      ? "No certificates in this app's keychain. Import a .p12 or .pfx first: "
            'on iOS a certificate installed as a configuration profile lives '
            'in the system keychain, which apps cannot read.'
      : map((certificate) => certificate.summary).join('\n\n');
}
