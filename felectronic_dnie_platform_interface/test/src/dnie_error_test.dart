import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

DnieError map(String code, [String? message]) =>
    DnieError.fromPlatformException(
      PlatformException(code: code, message: message),
    );

void main() {
  group('DnieError.fromPlatformException', () {
    test('reads the retry count from the native message', () {
      final error = map(
        'DSDNIeWrongPINException',
        'DNIe wrong PIN. Retries remaining: 2',
      );
      expect(error, isA<DnieWrongPinError>());
      expect((error as DnieWrongPinError).remainingRetries, 2);
    });

    test('leaves the retry count null when the card did not say', () {
      final error = map('DSDNIeWrongPINException') as DnieWrongPinError;
      expect(error.remainingRetries, isNull);
      expect(error.toString(), contains('unknown retries'));
    });

    test('maps known codes to their type', () {
      expect(map('DSTimeoutException'), isA<DnieTimeoutError>());
      expect(map('DSNotDNIeException'), isA<DnieNotDnieError>());
    });

    test('keeps the message of an unknown code', () {
      final error = map('Weird', 'something odd');
      expect(error, isA<DnieUnknownError>());
      expect(error.message, 'something odd');
      expect(error.toString(), 'DnieUnknownError: something odd');
    });
  });
}
