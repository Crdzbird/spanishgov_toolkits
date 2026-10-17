import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/models/signed_data.dart';

/// Converts the Pigeon [DnieSignedDataMessage] into a [SignedData].
extension DnieSignedDataMessageMapper on DnieSignedDataMessage {
  /// The [SignedData] this message carries.
  SignedData toModel() => SignedData(
    signedData: signedData,
    signedDataBase64: signedDataBase64,
    certificate: certificate,
  );
}
