import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// {@template dnie_identity}
/// Combined personal data and certificate details from a DNIe.
/// {@endtemplate}
@immutable
final class DnieIdentity {
  /// {@macro dnie_identity}
  const factory DnieIdentity({
    required PersonalData personalData,
    required CertificateInfo certificateInfo,
  }) = DnieIdentity._;

  const DnieIdentity._({
    required this.personalData,
    required this.certificateInfo,
  });

  /// Personal data extracted from the certificate subject.
  final PersonalData personalData;

  /// Parsed X.509 certificate details.
  final CertificateInfo certificateInfo;

  /// Full name from [personalData].
  String get fullName => personalData.fullName;

  /// NIF from [personalData].
  String get nif => personalData.nif;

  /// Whether the certificate is currently valid.
  bool get isValid => certificateInfo.isCurrentlyValid;

  @override
  String toString() => 'DnieIdentity(name: $fullName, nif: $nif)';
}
