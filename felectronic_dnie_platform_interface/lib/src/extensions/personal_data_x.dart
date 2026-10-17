import 'package:felectronic_dnie_platform_interface/src/models/personal_data.dart';

/// Convenience extensions on [PersonalData].
extension PersonalDataX on PersonalData {
  /// Initials from the given name and surnames (e.g. "J.G.").
  String get initials {
    final parts = <String>[];
    if (givenName.isNotEmpty) parts.add(givenName[0]);
    if (surnames.isNotEmpty) parts.add(surnames[0]);
    return parts.map((c) => '$c.').join();
  }

  /// Whether this is a signing (FIRMA) certificate.
  bool get isSigningCert => certificateType.toUpperCase() == 'FIRMA';

  /// Whether this is an authentication certificate.
  bool get isAuthCert => certificateType.toUpperCase() == 'AUTENTICACION';
}
