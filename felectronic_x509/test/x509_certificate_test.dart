import 'dart:typed_data';

import 'package:felectronic_x509/felectronic_x509.dart';
import 'package:test/test.dart';

void main() {
  group('X509Name', () {
    test('distinguishedName formats correctly', () {
      const name = X509Name({
        '2.5.4.3': 'John Doe',
        '2.5.4.10': 'Acme Corp',
        '2.5.4.6': 'ES',
      });
      final dn = name.distinguishedName;
      expect(dn, contains('CN=John Doe'));
      expect(dn, contains('O=Acme Corp'));
      expect(dn, contains('C=ES'));
    });

    test('commonName getter works', () {
      const name = X509Name({'2.5.4.3': 'My CN'});
      expect(name.commonName, 'My CN');
    });

    test('organization getter works', () {
      const name = X509Name({'2.5.4.10': 'My Org'});
      expect(name.organization, 'My Org');
    });

    test('country getter works', () {
      const name = X509Name({'2.5.4.6': 'US'});
      expect(name.country, 'US');
    });

    test('serialNumber getter works', () {
      const name = X509Name({'2.5.4.5': 'ABC123'});
      expect(name.serialNumber, 'ABC123');
    });

    test('email getter works', () {
      const name = X509Name({'1.2.840.113549.1.9.1': 'a@b.com'});
      expect(name.email, 'a@b.com');
    });

    test('missing attributes return empty string', () {
      const name = X509Name(<String, String>{});
      expect(name.commonName, '');
      expect(name.organization, '');
      expect(name.country, '');
      expect(name.serialNumber, '');
      expect(name.email, '');
      expect(name.state, '');
      expect(name.locality, '');
      expect(name.organizationalUnit, '');
    });

    test('equality by attributes', () {
      const a = X509Name({'2.5.4.3': 'X', '2.5.4.6': 'Y'});
      const b = X509Name({'2.5.4.3': 'X', '2.5.4.6': 'Y'});
      const c = X509Name({'2.5.4.3': 'X', '2.5.4.6': 'Z'});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('toString returns distinguishedName', () {
      const name = X509Name({'2.5.4.3': 'Test'});
      expect(name.toString(), contains('CN=Test'));
    });
  });

  group('X509Extension', () {
    test('name maps known OIDs', () {
      final ext = X509Extension(
        oid: '2.5.29.15',
        isCritical: true,
        value: Uint8List(0),
      );
      expect(ext.name, 'keyUsage');
    });

    test('name returns raw OID for unknown', () {
      final ext = X509Extension(
        oid: '1.2.3.4.5',
        isCritical: false,
        value: Uint8List(0),
      );
      expect(ext.name, '1.2.3.4.5');
    });

    test('toString includes name and critical', () {
      final ext = X509Extension(
        oid: '2.5.29.19',
        isCritical: false,
        value: Uint8List(0),
      );
      expect(ext.toString(), contains('basicConstraints'));
      expect(ext.toString(), contains('critical=false'));
    });
  });

  group('X509PublicKeyUtil', () {
    test('algorithmName maps RSA', () {
      expect(
        X509PublicKeyUtil.algorithmName('1.2.840.113549.1.1.1'),
        'RSA',
      );
    });

    test('algorithmName maps EC', () {
      expect(
        X509PublicKeyUtil.algorithmName('1.2.840.10045.2.1'),
        'EC',
      );
    });

    test('algorithmName returns OID for unknown', () {
      expect(
        X509PublicKeyUtil.algorithmName('9.9.9'),
        '9.9.9',
      );
    });
  });
}
