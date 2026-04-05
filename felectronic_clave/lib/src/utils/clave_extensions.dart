import 'package:felectronic_clave/src/config/clave_config.dart';
import 'package:felectronic_clave/src/models/clave_auth_result.dart';
import 'package:felectronic_clave/src/models/clave_mobile_session.dart';
import 'package:felectronic_clave/src/utils/document_validator.dart';

/// String extensions for document and contrast validation.
extension ClaveStringValidators on String {
  /// Whether this string is a valid DNI.
  bool get isValidDni => DocumentValidator.isValidDni(this);

  /// Whether this string is a valid NIE.
  bool get isValidNie => DocumentValidator.isValidNie(this);

  /// Whether this string is a valid DNI or NIE.
  bool get isValidDocument => DocumentValidator.isValid(this);

  /// Returns `'DNI'`, `'NIE'`, or `null` if neither.
  String? get documentType {
    if (DocumentValidator.isDni(this)) return 'DNI';
    if (DocumentValidator.isNie(this)) return 'NIE';
    return null;
  }

  /// Whether this string is a valid support number (C/E + 8 digits).
  bool get isValidSupportNumber =>
      DocumentValidator.isValidSupportNumber(this);

  /// Whether this string is a valid contrast date (dd-MM-yyyy).
  bool get isValidContrastDate =>
      DocumentValidator.isValidContrastDate(this);

  /// Returns an error message if this is not a valid document, or `null`.
  String? validateDocument() {
    final trimmed = trim();
    if (trimmed.isEmpty) return 'Document number is required.';
    if (!DocumentValidator.isValid(trimmed)) {
      // isValid already checks isDni/isNie format + check letter.
      final hasFormat =
          DocumentValidator.isDni(trimmed) || DocumentValidator.isNie(trimmed);
      return hasFormat
          ? 'Check letter is incorrect.'
          : 'Enter a valid DNI or NIE.';
    }
    return null;
  }

  /// Returns an error message for contrast, or `null`.
  /// [isDni] determines whether to validate as date or support number.
  String? validateContrast({required bool isDni}) {
    final trimmed = trim();
    if (trimmed.isEmpty) {
      return isDni ? 'Validity date is required.' : 'Support number '
          'is required.';
    }
    if (isDni && !DocumentValidator.isValidContrastDate(trimmed)) {
      return 'Enter a valid date (dd-MM-yyyy).';
    }
    if (!isDni && !DocumentValidator.isValidSupportNumber(trimmed)) {
      return 'Enter a valid support number (C/E + 8 digits).';
    }
    return null;
  }
}

/// Convenience extensions on [ClaveAuthResult].
extension ClaveAuthResultX on ClaveAuthResult {
  /// Whether a refresh token is available.
  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.isNotEmpty;

  /// Computed expiry time, or `null` if [expiresIn] is not set.
  DateTime? get expiresAt => expiresIn != null
      ? DateTime.now().add(Duration(seconds: expiresIn!))
      : null;

  /// Whether the token has expired based on [expiresIn].
  bool get isTokenExpired => expiresIn != null && expiresIn! <= 0;
}

/// Convenience extensions on [ClaveMobileSession].
extension ClaveMobileSessionX on ClaveMobileSession {
  /// Whether this session has an active token for polling.
  bool get isActive => token.isNotEmpty;

  /// The verification code zero-padded to 6 digits for display.
  String get displayCode => verificationCode.padLeft(6, '0');
}

/// Convenience extensions on [ClaveConfig].
extension ClaveConfigX on ClaveConfig {
  /// Whether Cl@ve Movil endpoints are configured.
  bool get hasClaveMobileUrls =>
      claveMobileCreateUrl != null &&
      claveMobileCreateUrl!.isNotEmpty &&
      claveMobileValidateUrl != null &&
      claveMobileValidateUrl!.isNotEmpty;

  /// Whether all required fields are non-empty.
  bool get isValid =>
      discoveryUrl.isNotEmpty &&
      clientId.isNotEmpty &&
      redirectUri.isNotEmpty &&
      clientSecret.isNotEmpty &&
      userInfoUrl.isNotEmpty &&
      logoutUrl.isNotEmpty;
}
