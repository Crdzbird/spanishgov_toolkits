import 'dart:typed_data';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/forwarding.dart';
import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;
  final signed = SignedData(
    signedData: Uint8List(1),
    signedDataBase64: 'AA==',
    certificate: 'cert',
  );

  setUp(() => platform = installMockPlatform());

  test('sign forwards everything', () {
    return expectForwarded<SignedData>(
      (can, pin, timeout, type) => platform.sign(
        data: any(named: 'data'),
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      (can, pin, timeout, type) => sign(
        data: Uint8List(1),
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      signed,
    );
  });

  test('readCertificate forwards everything', () {
    return expectForwarded<SignedData>(
      (can, pin, timeout, type) => platform.readCertificate(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      (can, pin, timeout, type) => readCertificate(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      signed,
    );
  });

  test('verifyPin forwards everything', () {
    return expectForwarded<void>(
      (can, pin, timeout, type) => platform.verifyPin(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      (can, pin, timeout, type) => verifyPin(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: type,
      ),
      null,
    );
  });
}
