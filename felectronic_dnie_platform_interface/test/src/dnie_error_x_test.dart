import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transient NFC failures are retryable, credentials are not', () {
    expect(const DnieTimeoutError().isRetryable, isTrue);
    expect(const DnieConnectionError().isRetryable, isTrue);
    expect(const DnieWrongCanError().isRetryable, isFalse);
    expect(const DnieCancelledError().isRetryable, isFalse);
  });

  test('CAN and PIN problems are credential errors', () {
    expect(const DnieWrongPinError().isCredentialError, isTrue);
    expect(const DnieWrongCanError().isCredentialError, isTrue);
    expect(const DnieLockedPinError().isCredentialError, isTrue);
    expect(const DnieTimeoutError().isCredentialError, isFalse);
  });

  test('isLastAttempt is true only with one try left', () {
    expect(const DnieWrongPinError(remainingRetries: 1).isLastAttempt, isTrue);
    expect(const DnieWrongPinError(remainingRetries: 2).isLastAttempt, isFalse);
    expect(const DnieWrongPinError().isLastAttempt, isFalse);
  });
}
