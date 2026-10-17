import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/models/personal_data.dart';

/// Converts the Pigeon [DniePersonalDataMessage] into a [PersonalData].
extension DniePersonalDataMessageMapper on DniePersonalDataMessage {
  /// The [PersonalData] this message carries.
  PersonalData toModel() => PersonalData(
    fullName: fullName,
    givenName: givenName,
    surnames: surnames,
    nif: nif,
    country: country,
    certificateType: certificateType,
  );
}
