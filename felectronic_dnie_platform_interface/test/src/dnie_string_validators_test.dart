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
}
