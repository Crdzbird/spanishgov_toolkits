import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/describe_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a wrong PIN warns before the attempt that locks the card', () {
    final status = describeError(const DnieWrongPinError(remainingRetries: 1));
    expect(status.isError, isTrue);
    expect(status.detail, contains('1 tries left'));
    expect(status.detail, contains('locks the card'));
  });

  test('a retryable DNIe error says how to retry', () {
    final status = describeError(const DnieTimeoutError());
    expect(status.detail, contains('try again'));
  });

  test('anything unexpected is still shown', () {
    expect(describeError(StateError('boom')).detail, contains('boom'));
  });
}
