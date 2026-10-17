import 'package:flutter/foundation.dart';

/// {@template card_probe_result}
/// Result of probing an NFC card to determine if it is a valid DNIe.
///
/// This operation does not require CAN or PIN authentication.
/// {@endtemplate}
@immutable
final class CardProbeResult {
  /// {@macro card_probe_result}
  const factory CardProbeResult({
    required bool isValidDnie,
    required String atrHex,
    required String tagId,
  }) = CardProbeResult._;

  const CardProbeResult._({
    required this.isValidDnie,
    required this.atrHex,
    required this.tagId,
  });

  /// Whether the detected card is a valid Spanish DNIe.
  final bool isValidDnie;

  /// The card's answer-to-select bytes as a hex string.
  ///
  /// For a DNIe this is the ISO 14443 Type B application data, which
  /// contains the marker `E1F35E11`.
  final String atrHex;

  /// Tag UID as a hex string.
  ///
  /// A DNIe answers with a random UID, so this changes on every read.
  final String tagId;

  (bool, String, String) get _fields => (isValidDnie, atrHex, tagId);

  @override
  bool operator ==(Object other) =>
      other is CardProbeResult && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'CardProbeResult(isValidDnie: $isValidDnie, '
      'atrHex: $atrHex, tagId: $tagId)';
}
