import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// The canonical serial form is implemented three times — here, in
/// `KeychainCertificateManager.canonicalSerial` (Swift) and in
/// `ElectronicCertificatesPlugin.canonicalSerial` (Kotlin). This suite is the
/// specification those three have to agree on; the native copies are ported
/// line for line from it.
void main() {
  group('CertificateSerial.canonical', () {
    test('strips the DER sign-padding byte iOS reports', () {
      // SecCertificateCopySerialNumberData returns the DER INTEGER content
      // octets, which keep the 0x00 pad when the top bit is set.
      expect(CertificateSerial.canonical('00b5a1c3'), 'b5a1c3');
    });

    test('leaves the Android spelling unchanged', () {
      expect(CertificateSerial.canonical('b5a1c3'), 'b5a1c3');
    });

    test('lowercases the felectronic_x509 spelling', () {
      expect(CertificateSerial.canonical('B5A1C3'), 'b5a1c3');
    });

    test('all three platform spellings converge', () {
      const ios = '00b5a1c3';
      const android = 'b5a1c3';
      const dartX509 = 'B5A1C3';

      final canonical = {
        CertificateSerial.canonical(ios),
        CertificateSerial.canonical(android),
        CertificateSerial.canonical(dartX509),
      };

      expect(canonical, hasLength(1), reason: 'spellings must converge');
      expect(canonical.single, 'b5a1c3');
    });

    test('strips separators and 0x prefixes', () {
      expect(CertificateSerial.canonical('B5:A1:C3'), 'b5a1c3');
      expect(CertificateSerial.canonical('b5 a1 c3'), 'b5a1c3');
      expect(CertificateSerial.canonical('0xB5A1C3'), 'b5a1c3');
    });

    test('strips the sign BigInteger.toString(16) emits for a negative '
        'serial', () {
      expect(CertificateSerial.canonical('-b5a1c3'), 'b5a1c3');
    });

    test('a zero serial stays distinguishable from an absent one', () {
      expect(CertificateSerial.canonical('00'), '0');
      expect(CertificateSerial.canonical('0'), '0');
      expect(CertificateSerial.canonical(''), '');
    });

    test('strips multiple leading zero bytes', () {
      expect(CertificateSerial.canonical('0000000b5a1c3'), 'b5a1c3');
    });

    test('is idempotent', () {
      for (final input in ['00b5a1c3', 'B5:A1:C3', '-0x00FF', '', '00']) {
        final once = CertificateSerial.canonical(input);
        expect(
          CertificateSerial.canonical(once),
          once,
          reason: 'not idempotent for "$input"',
        );
      }
    });
  });

  group('CertificateSerial.same', () {
    test('matches across platform spellings', () {
      expect(CertificateSerial.same('00b5a1c3', 'B5A1C3'), isTrue);
      expect(CertificateSerial.same('b5:a1:c3', '0xb5a1c3'), isTrue);
    });

    test('does not match genuinely different serials', () {
      expect(CertificateSerial.same('00b5a1c3', 'b5a1c4'), isFalse);
    });

    test('a zero serial does not match an absent one', () {
      expect(CertificateSerial.same('00', ''), isFalse);
    });
  });
}
