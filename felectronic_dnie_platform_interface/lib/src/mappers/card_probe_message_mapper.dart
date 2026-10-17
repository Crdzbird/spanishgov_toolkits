import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/models/card_probe_result.dart';

/// Converts the Pigeon [DnieCardProbeMessage] into a [CardProbeResult].
extension DnieCardProbeMessageMapper on DnieCardProbeMessage {
  /// The [CardProbeResult] this message carries.
  CardProbeResult toModel() => CardProbeResult(
    isValidDnie: isValidDnie,
    atrHex: atrHex,
    tagId: tagId,
  );
}
