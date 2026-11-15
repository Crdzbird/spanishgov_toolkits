import 'dart:typed_data';

import 'package:felectronic_dnie_android/felectronic_dnie_android.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Api extends FelectronicDnieHostApi {
  final routes = <String>[];

  DnieSignedDataMessage _answer(String route, List<int> signature) {
    routes.add(route);
    return DnieSignedDataMessage(
      signedData: Uint8List.fromList(signature),
      signedDataBase64: '',
      certificate: 'Y2VydA==',
    );
  }

  @override
  Future<DnieSignedDataMessage> sign(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async => _answer('sign $certificateType', [1]);

  @override
  Future<DnieSignedDataMessage> signCades(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async => _answer('signCades $certificateType', [48]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sign stays local and signCades is its own native call', () async {
    final api = _Api();
    final platform = FelectronicDnieAndroid()..api = api;

    final raw = await platform.sign(
      data: Uint8List(1),
      can: '123456',
      pin: 'password1',
      certificateType: DnieCertificateType.auth,
    );
    final cades = await platform.signCades(
      data: Uint8List(1),
      can: '123456',
      pin: 'password1',
    );

    expect(raw.signedData, [1]);
    expect(cades.signedData, [48]);
    expect(api.routes, ['sign AUTH', 'signCades SIGN']);
  });
}
