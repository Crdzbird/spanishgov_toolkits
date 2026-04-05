import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentValidator', () {
    group('isDni', () {
      test('returns true for valid DNI format', () {
        expect(DocumentValidator.isDni('12345678Z'), isTrue);
        expect(DocumentValidator.isDni('00000000T'), isTrue);
      });

      test('returns false for invalid format', () {
        expect(DocumentValidator.isDni('1234567Z'), isFalse); // 7 digits
        expect(DocumentValidator.isDni('123456789Z'), isFalse); // 9 digits
        expect(DocumentValidator.isDni('12345678z'), isFalse); // lowercase
        expect(DocumentValidator.isDni('X1234567L'), isFalse); // NIE
      });
    });

    group('isNie', () {
      test('returns true for valid NIE format', () {
        expect(DocumentValidator.isNie('X1234567L'), isTrue);
        expect(DocumentValidator.isNie('Y0000000Z'), isTrue);
        expect(DocumentValidator.isNie('Z0000000M'), isTrue);
      });

      test('returns false for invalid format', () {
        expect(DocumentValidator.isNie('12345678Z'), isFalse); // DNI
        expect(DocumentValidator.isNie('A1234567L'), isFalse); // bad prefix
        expect(DocumentValidator.isNie('X123456L'), isFalse); // 6 digits
      });
    });

    group('isValidDni', () {
      test('validates correct DNI letter', () {
        // 12345678 % 23 = 14 → letter Z
        expect(DocumentValidator.isValidDni('12345678Z'), isTrue);
        // 00000000 % 23 = 0 → letter T
        expect(DocumentValidator.isValidDni('00000000T'), isTrue);
      });

      test('rejects incorrect DNI letter', () {
        expect(DocumentValidator.isValidDni('12345678A'), isFalse);
        expect(DocumentValidator.isValidDni('00000000A'), isFalse);
      });
    });

    group('isValidNie', () {
      test('validates correct NIE letter', () {
        // X=0 → 1234567 % 23 = 19 → letter L
        expect(DocumentValidator.isValidNie('X1234567L'), isTrue);
      });

      test('rejects incorrect NIE letter', () {
        expect(DocumentValidator.isValidNie('X1234567A'), isFalse);
      });
    });

    group('isValid', () {
      test('accepts valid DNI or NIE', () {
        expect(DocumentValidator.isValid('12345678Z'), isTrue);
        expect(DocumentValidator.isValid('X1234567L'), isTrue);
      });

      test('rejects invalid documents', () {
        expect(DocumentValidator.isValid('INVALID'), isFalse);
        expect(DocumentValidator.isValid('12345678A'), isFalse);
      });
    });

    group('isValidSupportNumber', () {
      test('accepts valid support numbers', () {
        expect(DocumentValidator.isValidSupportNumber('C12345678'), isTrue);
        expect(DocumentValidator.isValidSupportNumber('E12345678'), isTrue);
      });

      test('rejects invalid support numbers', () {
        expect(DocumentValidator.isValidSupportNumber('A12345678'), isFalse);
        expect(DocumentValidator.isValidSupportNumber('C1234567'), isFalse);
        expect(DocumentValidator.isValidSupportNumber('C123456789'), isFalse);
      });
    });
  });
}
