import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/dnie_error_mapping.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/signed_data_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/models/signed_data.dart';

/// Converts a pending [DnieSignedDataMessage] reply into a [SignedData].
extension DnieSignedDataFutureMapper on Future<DnieSignedDataMessage> {
  /// The [SignedData] this reply carries, failing with a `DnieError` where
  /// the native call failed.
  Future<SignedData> toSignedData() => then((m) => m.toModel()).mapDnieErrors();
}
