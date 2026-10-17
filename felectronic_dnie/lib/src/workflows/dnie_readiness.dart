import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// {@template dnie_readiness}
/// Result of a full readiness check: NFC status, card validity,
/// and PIN verification.
/// {@endtemplate}
@immutable
final class DnieReadiness {
  /// {@macro dnie_readiness}
  const factory DnieReadiness({
    required NfcStatus nfcStatus,
    required bool isValidDnie,
    required bool isPinCorrect,
    String? atrHex,
    String? tagId,
    DnieError? error,
  }) = DnieReadiness._;

  const DnieReadiness._({
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

  /// Whether the CAN and PIN combination is correct.
  final bool isPinCorrect;

  /// Answer-to-select bytes from the probe, if a card was detected.
  final String? atrHex;

  /// Tag ID from the probe, if a card was detected.
  final String? tagId;

  /// The error that stopped the check, if any.
  final DnieError? error;

  /// Whether everything passed and the card is ready for operations.
  bool get isReady => nfcStatus.isReady && isValidDnie && isPinCorrect;

  @override
  String toString() => 'DnieReadiness(ready: $isReady)';
}
