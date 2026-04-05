import 'package:flutter/foundation.dart';

/// {@template personal_data}
/// Personal data extracted from the DNIe certificate subject DN.
/// {@endtemplate}
@immutable
class PersonalData {
  /// {@macro personal_data}
  const PersonalData({
    required this.fullName,
    required this.givenName,
    required this.surnames,
    required this.nif,
    required this.country,
    required this.certificateType,
  });

  /// Full name (given name + surnames).
  final String fullName;

  /// Given name / first name.
  final String givenName;

  /// Surnames (first + second).
  final String surnames;

  /// NIF (Numero de Identificacion Fiscal).
  final String nif;

  /// Country code (e.g. "ES").
  final String country;

  /// Certificate type (e.g. "FIRMA", "AUTENTICACION").
  final String certificateType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalData &&
          other.fullName == fullName &&
          other.givenName == givenName &&
          other.surnames == surnames &&
          other.nif == nif &&
          other.country == country &&
          other.certificateType == certificateType;

  @override
  int get hashCode => Object.hash(
        fullName,
        givenName,
        surnames,
        nif,
        country,
        certificateType,
      );

  @override
  String toString() => 'PersonalData('
      'name: $fullName, '
      'nif: $nif, '
      'type: $certificateType'
      ')';
}
