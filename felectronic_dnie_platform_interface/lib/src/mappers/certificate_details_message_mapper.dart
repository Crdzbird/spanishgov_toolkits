import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/models/certificate_info.dart';

/// Converts the Pigeon [DnieCertificateDetailsMessage] into a
/// [CertificateInfo].
extension DnieCertificateDetailsMessageMapper on DnieCertificateDetailsMessage {
  /// The [CertificateInfo] this message carries.
  ///
  /// The validity bounds arrive as milliseconds since the epoch.
  CertificateInfo toModel() => CertificateInfo(
    subjectCommonName: subjectCommonName,
    subjectSerialNumber: subjectSerialNumber,
    issuerCommonName: issuerCommonName,
    issuerOrganization: issuerOrganization,
    notValidBefore: DateTime.fromMillisecondsSinceEpoch(notValidBefore),
    notValidAfter: DateTime.fromMillisecondsSinceEpoch(notValidAfter),
    serialNumber: serialNumber,
    isCurrentlyValid: isCurrentlyValid,
  );
}
