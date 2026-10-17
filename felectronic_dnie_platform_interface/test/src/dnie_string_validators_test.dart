import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateCan', () {
    test('accepts six digits, ignoring surrounding whitespace', () {
      expect(' 070526 '.validateCan(), isNull);
      expect(' 070526 '.isValidCan, isTrue);
    });

    test('names the first problem it finds', () {
      expect(''.validateCan(), DnieValidationError.canRequired);
      expect('12345'.validateCan(), DnieValidationError.canLength);
      expect('12a456'.validateCan(), DnieValidationError.canFormat);
      expect('12a456'.isValidCan, isFalse);
    });
  });

  group('validatePin', () {
    test('accepts 8 to 16 characters', () {
      expect('abcd1234'.isValidPin, isTrue);
      expect('abcd1234abcd1234'.isValidPin, isTrue);
    });

    test('names the first problem it finds', () {
      expect('   '.validatePin(), DnieValidationError.pinRequired);
      expect('short'.validatePin(), DnieValidationError.pinTooShort);
      expect(('a' * 17).isValidPin, isFalse);
      expect(('a' * 17).validatePin(), DnieValidationError.pinTooLong);
    });
  });

  group('isValidNif', () {
    test('accepts a NIF and NIEs whose control letter matches', () {
      expect('12345678Z'.isValidNif, isTrue);
      expect('x1234567l'.isValidNif, isTrue);
      expect(' Y1234567X '.isValidNif, isTrue);
      expect('Z7654321H'.isValidNif, isTrue);
    });

    test('rejects a wrong letter or a malformed number', () {
      expect('12345678A'.isValidNif, isFalse);
      expect('X12345678L'.isValidNif, isFalse);
      expect('1234567Z'.isValidNif, isFalse);
      expect(''.isValidNif, isFalse);
    });
  });
}
