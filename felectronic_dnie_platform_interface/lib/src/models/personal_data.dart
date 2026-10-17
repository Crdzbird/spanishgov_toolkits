import 'package:flutter/foundation.dart';

/// {@template personal_data}
/// Personal data extracted from the DNIe certificate subject DN.
/// {@endtemplate}
@immutable
final class PersonalData {
  /// {@macro personal_data}
  const factory PersonalData({
    required String fullName,
    required String givenName,
    required String surnames,
    required String nif,
    required String country,
    required String certificateType,
  }) = PersonalData._;

  const PersonalData._({
    required this.fullName,
    required this.givenName,
    required this.surnames,
    required this.nif,
    required this.country,
    required this.certificateType,
  });

  /// Full name (given name and surnames), as printed in the certificate.
  final String fullName;

  /// Given name / first name.
  final String givenName;

  /// Surnames (first and second).
  final String surnames;

  /// NIF (Numero de Identificacion Fiscal).
  final String nif;

  /// Country code (e.g. "ES").
  final String country;

  /// Certificate type (e.g. "FIRMA", "AUTENTICACION").
  final String certificateType;

  (String, String, String, String, String, String) get _fields =>
      (fullName, givenName, surnames, nif, country, certificateType);

  @override
  bool operator ==(Object other) =>
      other is PersonalData && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'PersonalData(name: $fullName, nif: $nif, type: $certificateType)';
}
