import 'dart:typed_data';

import 'package:felectronic_dnie/src/dnie_operations.dart' as dnie;
import 'package:felectronic_dnie/src/workflows/dnie_identity.dart';
import 'package:felectronic_dnie/src/workflows/dnie_readiness.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

/// Probes the card, then signs if valid.
///
/// Returns `null` if the card is not a valid DNIe.
Future<SignedData?> probeAndSign({
  required Uint8List data,
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  Duration timeout = dnieDefaultTimeout,
}) async {
  final probe = await dnie.probeCard(timeout: timeout);
  if (!probe.isValidDnie) return null;
  return dnie.sign(
    data: data,
    can: can,
    pin: pin,
    timeout: timeout,
    certificateType: certificateType,
  );
}

/// Reads both personal data and certificate details.
///
/// This takes two NFC reads, one per operation.
Future<DnieIdentity> readFullIdentity({
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  Duration timeout = dnieDefaultTimeout,
}) async => DnieIdentity(
  personalData: await dnie.readPersonalData(
    can: can,
    pin: pin,
    timeout: timeout,
    certificateType: certificateType,
  ),
  certificateInfo: await dnie.readCertificateDetails(
    can: can,
    pin: pin,
    timeout: timeout,
    certificateType: certificateType,
  ),
);

/// Checks NFC, then probes the card, then verifies the PIN, stopping at the
/// first step that fails.
///
/// Never throws a [DnieError]: it is captured in [DnieReadiness.error].
Future<DnieReadiness> checkReadiness({
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  Duration timeout = dnieDefaultTimeout,
}) async {
  var nfc = const NfcStatus(isAvailable: false, isEnabled: false);
  CardProbeResult? probe;
  var isPinCorrect = false;
  DnieError? error;
  try {
    nfc = await dnie.checkNfcAvailability();
    if (nfc.isReady) probe = await dnie.probeCard(timeout: timeout);
    if (probe?.isValidDnie ?? false) {
      await dnie.verifyPin(
        can: can,
        pin: pin,
        timeout: timeout,
        certificateType: certificateType,
      );
      isPinCorrect = true;
    }
  } on DnieError catch (e) {
    error = e;
  }
  return DnieReadiness(
    nfcStatus: nfc,
    isValidDnie: probe?.isValidDnie ?? false,
    isPinCorrect: isPinCorrect,
    atrHex: probe?.atrHex,
    tagId: probe?.tagId,
    error: error,
  );
}
