import 'package:felectronic_dnie_platform_interface/src/models/dnie_certificate_type.dart';
import 'package:felectronic_dnie_platform_interface/src/models/personal_data.dart';

/// Convenience extensions on [PersonalData].
extension PersonalDataX on PersonalData {
  static const _particles = {'de', 'del', 'la', 'las', 'los', 'y'};

  /// Initials from the given name and surnames (e.g. "J.G.").
  String get initials => [
    givenName,
    surnames,
  ].where((part) => part.isNotEmpty).map((part) => '${part[0]}.').join();

  /// Which DNIe certificate this data was read from, or `null` if the
  /// certificate names neither.
  ///
  /// Matches with or without the accent, since a real DNIe writes
  /// "AUTENTICACIÓN".
  DnieCertificateType? get certificateKind {
    final type = certificateType.toUpperCase();
    if (type.startsWith('FIRMA')) return DnieCertificateType.sign;
    if (type.startsWith('AUTENTICACI')) return DnieCertificateType.auth;
    return null;
  }

  /// Whether this is a signing (FIRMA) certificate.
  bool get isSigningCert => certificateKind == DnieCertificateType.sign;

  /// Whether this is an authentication certificate.
  bool get isAuthCert => certificateKind == DnieCertificateType.auth;

  /// The name in reading order and title case, e.g. "Maria de la Cruz
  /// Garcia" for given name "MARIA" and surnames "DE LA CRUZ GARCIA".
  String get displayName {
    final words = '$givenName $surnames'.toLowerCase().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .indexed
        .map(
          (entry) => entry.$1 > 0 && _particles.contains(entry.$2)
              ? entry.$2
              : '${entry.$2[0].toUpperCase()}${entry.$2.substring(1)}',
        )
        .join(' ');
  }
}
