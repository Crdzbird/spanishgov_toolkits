import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_certificates_platform_interface/src/models/cert_key_usage.dart';
import 'package:felectronic_x509/felectronic_x509.dart';
import 'package:flutter/foundation.dart' show immutable;

/// {@template device_certificate}
/// Represents a certificate stored on the device (keychain / keystore).
/// {@endtemplate}
@immutable
class DeviceCertificate {
  /// {@macro device_certificate}
  const DeviceCertificate({
    required this.serialNumber,
    required this.holderName,
    required this.issuerName,
    required this.expirationDate,
    required this.usages,
    required this.encoded,
    this.alias,
    this.chain = const [],
  });

  /// Builds a certificate from a platform message.
  ///
  /// The message carries only what the keystore alone knows — the serial and
  /// the alias. Subject CN, issuer CN, validity and key usage are decoded
  /// here from [DeviceCertificateMessage.encoded] with `felectronic_x509`.
  ///
  /// This is the single implementation of that conversion. Both federated
  /// implementations and the default method-channel platform call it, so
  /// Android and iOS cannot report different values for the same
  /// certificate.
  ///
  /// A certificate whose DER will not decode yields empty names, no usages
  /// and a `null` [expirationDate] rather than plausible-looking
  /// substitutes, and never throws — one unreadable certificate must not
  /// fail a whole listing.
  factory DeviceCertificate.fromMessage(DeviceCertificateMessage message) {
    X509Certificate? parsed;
    if (message.encoded.isNotEmpty) {
      try {
        parsed = X509Parser.fromDer(message.encoded);
      } on FormatException {
        parsed = null;
      }
    }

    return DeviceCertificate(
      serialNumber: message.serialNumber,
      alias: message.alias,
      holderName: parsed?.subject.commonName ?? '',
      issuerName: parsed?.issuer.commonName ?? '',
      expirationDate: parsed?.notValidAfter,
      usages: parsed == null
          ? const []
          : CertKeyUsage.fromX509Flags(parsed.keyUsage),
      encoded: message.encoded,
      chain: message.chain ?? const [],
    );
  }

  /// Certificate serial number (hex string).
  final String serialNumber;

  /// Optional alias / label.
  final String? alias;

  /// Holder (subject) common name.
  final String holderName;

  /// Issuer common name.
  final String issuerName;

  /// Certificate expiration date (`notAfter`), as a UTC instant.
  ///
  /// `null` when the certificate could not be decoded, which is genuinely
  /// different from "expired". Earlier versions substituted the epoch here,
  /// so an undecodable certificate silently reported itself as long expired.
  final DateTime? expirationDate;

  /// Key usage flags for this certificate.
  final List<CertKeyUsage> usages;

  /// DER-encoded certificate bytes.
  final Uint8List encoded;

  /// The certificate chain, leaf first, DER-encoded.
  ///
  /// Empty when the platform could not build one — not a claim that the
  /// certificate is self-signed. [signingChain] is the accessor to use; it
  /// falls back to [encoded] so callers never have to handle the empty case.
  final List<Uint8List> chain;

  /// The chain to present when signing, always at least the leaf.
  ///
  /// The @firma service needs the intermediates to validate a certificate
  /// whose issuer it does not already hold. Falling back to the leaf keeps a
  /// platform that cannot build a chain working wherever the issuer is
  /// already trusted, rather than failing outright.
  List<Uint8List> get signingChain => chain.isEmpty ? [encoded] : chain;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceCertificate &&
          runtimeType == other.runtimeType &&
          serialNumber == other.serialNumber;

  @override
  int get hashCode => serialNumber.hashCode;

  @override
  String toString() =>
      'DeviceCertificate(serialNumber: $serialNumber, '
      'holder: $holderName, issuer: $issuerName, '
      'expires: $expirationDate, usages: $usages)';
}
