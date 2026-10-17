import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both native cancellation codes become DnieCancelledError', () {
    for (final code in ['DSCancelledException', 'DSUserCancelledException']) {
      final error = DnieError.fromPlatformException(
        PlatformException(code: code),
      );
      expect(error, isA<DnieCancelledError>(), reason: code);
      expect(error.toString(), startsWith('DnieCancelledError: '));
    }
  });
}
