import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

/// Signs [data] as CAdES through the three-phase protocol, which sends [data]
/// and the certificate chain to the remote signing service.
///
/// Android only: iOS throws [DnieUnsupportedError]. For a signature made on
/// the device, with nothing sent anywhere, use `sign`. Whitespace around
/// [can] and [pin] is ignored.
Future<SignedData> signCades({
  required Uint8List data,
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => FelectronicDniePlatform.instance.signCades(
  data: data,
  can: can.trim(),
  pin: pin.trim(),
  timeout: timeout,
  certificateType: certificateType,
);
