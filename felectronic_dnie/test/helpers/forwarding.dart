import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

typedef Call<T> =
    Future<T> Function(
      String can,
      String pin,
      Duration timeout,
      DnieCertificateType type,
    );

const _timeout = Duration(seconds: 12);

/// Checks that [op] hands the CAN, PIN, timeout and certificate type to
/// [onPlatform] unchanged, and returns what the platform returned.
Future<void> expectForwarded<T>(
  Call<T> onPlatform,
  Call<T> op,
  T result,
) async {
  when(
    () => onPlatform(
      any(named: 'can'),
      any(named: 'pin'),
      any(named: 'timeout'),
      any(named: 'certificateType'),
    ),
  ).thenAnswer((_) async => result);
  expect(
    await op('123456', 'password1', _timeout, DnieCertificateType.auth),
    result,
  );
  verify(
    () => onPlatform('123456', 'password1', _timeout, DnieCertificateType.auth),
  ).called(1);
}
