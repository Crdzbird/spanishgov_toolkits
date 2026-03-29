import 'package:flutter/foundation.dart';

/// {@template card_probe_result}
/// Result of probing an NFC card to determine if it is a valid DNIe.
///
/// This operation does not require CAN or PIN authentication.
/// {@endtemplate}
@immutable
class CardProbeResult {
  /// {@macro card_probe_result}
  const CardProbeResult({
    required this.isValidDnie,
    required this.atrHex,
    required this.tagId,
  });

  /// Whether the detected card is a valid Spanish DNIe.
  final bool isValidDnie;

  /// Historical bytes (ATR) from the card as a hex string.
  final String atrHex;

  /// Tag UID / identifier as a hex string.
  final String tagId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardProbeResult &&
          other.isValidDnie == isValidDnie &&
          other.atrHex == atrHex &&
          other.tagId == tagId;

  @override
  int get hashCode => Object.hash(isValidDnie, atrHex, tagId);

  @override
  String toString() => 'CardProbeResult('
      'isValidDnie: $isValidDnie, '
      'atrHex: $atrHex, '
      'tagId: $tagId'
      ')';
}
