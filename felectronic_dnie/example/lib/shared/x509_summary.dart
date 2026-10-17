import 'package:felectronic_dnie/felectronic_dnie.dart';

/// A readable dump of every field the X.509 parser extracts.
extension X509Summary on X509Certificate {
  String get summary {
    String day(DateTime date) => date.toIso8601String().split('T').first;
    String list(List<String> values) =>
        values.isEmpty ? '-' : values.join(', ');
    return [
      'Subject: ${subject.distinguishedName}',
      'Issuer: ${issuer.distinguishedName}',
      'Serial: $serialNumber',
      'Algorithm: $signatureAlgorithmName',
      'Key: $publicKeyAlgorithm $publicKeySize-bit',
      'Valid: ${day(notValidBefore)} to ${day(notValidAfter)}',
      'Days left: $daysUntilExpiry',
      'Self-signed: $isSelfSigned, CA: $isCA',
      'Key usage: ${list(keyUsage)}',
      'Extended key usage: ${list(extendedKeyUsage)}',
      'Subject alt names: ${list(subjectAltNames)}',
      'OCSP: ${list(ocspUrls)}',
      'CRL: ${list(crlDistributionPoints)}',
      'Policies: ${list(certificatePolicies)}',
    ].join('\n');
  }
}
