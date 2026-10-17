import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

CertificateInfo certificate({required DateTime from, required DateTime to}) =>
    CertificateInfo(
      subjectCommonName: 'GARCIA LOPEZ, JUAN (FIRMA)',
      subjectSerialNumber: '12345678Z',
      issuerCommonName: 'AC FNMT Usuarios',
      issuerOrganization: 'FNMT-RCM',
      notValidBefore: from,
      notValidAfter: to,
      serialNumber: '01',
      isCurrentlyValid: true,
    );

void main() {
  final from = DateTime(2024);
  final to = DateTime(2029);
  final cert = certificate(from: from, to: to);

  group('CertificateInfo.isValidAt', () {
    test('includes both bounds', () {
      expect(cert.isValidAt(from), isTrue);
      expect(cert.isValidAt(to), isTrue);
    });

    test('excludes the moments either side', () {
      const ms = Duration(milliseconds: 1);
      expect(cert.isValidAt(from.subtract(ms)), isFalse);
      expect(cert.isValidAt(to.add(ms)), isFalse);
    });
  });

  test('equal fields make equal certificates', () {
    expect(certificate(from: from, to: to), cert);
    expect(certificate(from: from, to: to).hashCode, cert.hashCode);
  });

  group('CertificateExpiryStatus.describe', () {
    test('uses the day count only for valid', () {
      expect(CertificateExpiryStatus.valid.describe(12), 'Expires in 12 days');
      expect(CertificateExpiryStatus.expired.describe(12), 'Expired');
    });
  });

  group('expiryStatusType', () {
    test('is expired once the end has passed', () {
      final past = certificate(from: DateTime(2000), to: DateTime(2001));
      expect(past.expiryStatusType, CertificateExpiryStatus.expired);
      expect(past.isValidForSigning, isFalse);
    });

    test('is not yet valid before the start', () {
      final future = certificate(from: DateTime(2999), to: DateTime(3000));
      expect(future.expiryStatusType, CertificateExpiryStatus.notYetValid);
    });
  });
}
