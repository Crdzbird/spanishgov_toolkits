import 'package:felectronic_dnie/felectronic_dnie.dart' as dnie;
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// {@template dnie_identity}
/// Combined personal data and certificate details from a single
/// DNIe card read operation.
/// {@endtemplate}
@immutable
class DnieIdentity {
  /// {@macro dnie_identity}
  const DnieIdentity({
    required this.personalData,
    required this.certificateInfo,
  });

  /// Personal data extracted from the certificate subject.
  final PersonalData personalData;

  /// Parsed X.509 certificate details.
  final CertificateInfo certificateInfo;

  /// Shorthand: full name from personal data.
  String get fullName => personalData.fullName;

  /// Shorthand: NIF from personal data.
  String get nif => personalData.nif;

  /// Shorthand: whether the certificate is currently valid.
  bool get isValid => certificateInfo.isCurrentlyValid;

  @override
  String toString() => 'DnieIdentity(name: $fullName, nif: $nif)';
}

/// {@template dnie_readiness}
/// Result of a full readiness check: NFC status, card validity,
/// and PIN verification.
/// {@endtemplate}
@immutable
class DnieReadiness {
  /// {@macro dnie_readiness}
  const DnieReadiness({
    required this.nfcStatus,
    required this.isValidDnie,
    required this.isPinCorrect,
    this.atrHex,
    this.tagId,
    this.error,
  });

  /// NFC hardware status.
  final NfcStatus nfcStatus;

  /// Whether the detected card is a valid DNIe.
  final bool isValidDnie;

  /// Whether the CAN + PIN combination is correct.
  final bool isPinCorrect;

  /// ATR hex from the probe (if card detected).
  final String? atrHex;

  /// Tag ID from the probe (if card detected).
  final String? tagId;

  /// The error that stopped the check, if any.
  final DnieError? error;

  /// Whether everything passed and the card is ready for operations.
  bool get isReady =>
      nfcStatus.isAvailable &&
      nfcStatus.isEnabled &&
      isValidDnie &&
      isPinCorrect;

  @override
  String toString() => 'DnieReadiness(ready: $isReady)';
}

// ---------------------------------------------------------------------------
// Workflow Functions
// ---------------------------------------------------------------------------

/// Probes the card, then signs if valid.
///
/// Returns `null` if the card is not a valid DNIe.
/// Combines [dnie.probeCard] and [dnie.sign] into one call.
Future<SignedData?> probeAndSign({
  required Uint8List data,
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  int timeout = 30,
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
/// Note: this requires **two** NFC taps (two separate operations).
Future<DnieIdentity> readFullIdentity({
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  int timeout = 30,
}) async {
  final pd = await dnie.readPersonalData(
    can: can,
    pin: pin,
    timeout: timeout,
    certificateType: certificateType,
  );
  final ci = await dnie.readCertificateDetails(
    can: can,
    pin: pin,
    timeout: timeout,
    certificateType: certificateType,
  );
  return DnieIdentity(personalData: pd, certificateInfo: ci);
}

/// Performs a full readiness check: NFC → probe → verify PIN.
///
/// Never throws — captures errors into [DnieReadiness.error].
Future<DnieReadiness> checkReadiness({
  required String can,
  required String pin,
  DnieCertificateType certificateType = DnieCertificateType.sign,
  int timeout = 30,
}) async {
  // Step 1: NFC check
  NfcStatus nfc;
  try {
    nfc = await dnie.checkNfcAvailability();
  } on DnieError catch (e) {
    return DnieReadiness(
      nfcStatus: const NfcStatus(isAvailable: false, isEnabled: false),
      isValidDnie: false,
      isPinCorrect: false,
      error: e,
    );
  }

  if (!nfc.isAvailable || !nfc.isEnabled) {
    return DnieReadiness(
      nfcStatus: nfc,
      isValidDnie: false,
      isPinCorrect: false,
    );
  }

  // Step 2: Probe card
  CardProbeResult probe;
  try {
    probe = await dnie.probeCard(timeout: timeout);
  } on DnieError catch (e) {
    return DnieReadiness(
      nfcStatus: nfc,
      isValidDnie: false,
      isPinCorrect: false,
      error: e,
    );
  }

  if (!probe.isValidDnie) {
    return DnieReadiness(
      nfcStatus: nfc,
      isValidDnie: false,
      isPinCorrect: false,
      atrHex: probe.atrHex,
      tagId: probe.tagId,
    );
  }

  // Step 3: Verify PIN
  try {
    await dnie.verifyPin(
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );
    return DnieReadiness(
      nfcStatus: nfc,
      isValidDnie: true,
      isPinCorrect: true,
      atrHex: probe.atrHex,
      tagId: probe.tagId,
    );
  } on DnieError catch (e) {
    return DnieReadiness(
      nfcStatus: nfc,
      isValidDnie: true,
      isPinCorrect: false,
      atrHex: probe.atrHex,
      tagId: probe.tagId,
      error: e,
    );
  }
}
