import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/forwarding.dart';
import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;

  setUp(() => platform = installMockPlatform());

  test('readCertificateDetails forwards everything', () {
    return expectForwarded<CertificateInfo>(
      (can, pin, timeout, type) => platform.readCertificateDetails(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      (can, pin, timeout, type) => readCertificateDetails(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      CertificateInfo(
        subjectCommonName: 'GARCIA, JUAN (FIRMA)',
        subjectSerialNumber: '12345678Z',
        issuerCommonName: 'AC FNMT Usuarios',
        issuerOrganization: 'FNMT-RCM',
        notValidBefore: DateTime(2024),
        notValidAfter: DateTime(2029),
        serialNumber: '01',
        isCurrentlyValid: true,
      ),
    );
  });

  test('readPersonalData forwards everything', () {
    return expectForwarded<PersonalData>(
      (can, pin, timeout, type) => platform.readPersonalData(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      (can, pin, timeout, type) => readPersonalData(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      const PersonalData(
        fullName: 'JUAN GARCIA',
        givenName: 'JUAN',
        surnames: 'GARCIA',
        nif: '12345678Z',
        country: 'ES',
        certificateType: 'FIRMA',
      ),
    );
  });
}
