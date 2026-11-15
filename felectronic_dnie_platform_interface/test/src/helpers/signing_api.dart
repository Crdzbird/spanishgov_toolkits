import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/services.dart';

final _raw = DnieSignedDataMessage(
  signedData: Uint8List.fromList([1, 2, 3]),
  signedDataBase64: 'AQID',
  certificate: 'Y2VydA==',
);

final _cades = DnieSignedDataMessage(
  signedData: Uint8List.fromList([48, 128]),
  signedDataBase64: 'MIA=',
  certificate: 'Y2VydA==',
);

/// A host API that records sign and signCades calls.
final class SigningApi extends FelectronicDnieHostApi {
  final calls = <String>[];
  PlatformException? error;

  @override
  Future<DnieSignedDataMessage> sign(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    calls.add('sign $can $pin $timeout $certificateType ${data.length}');
    return _raw;
  }

  @override
  Future<DnieSignedDataMessage> signCades(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    calls.add('signCades $can $pin $timeout $certificateType ${data.length}');
    if (error case final error?) throw error;
    return _cades;
  }
}
