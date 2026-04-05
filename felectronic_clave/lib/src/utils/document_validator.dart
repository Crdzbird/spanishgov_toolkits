/// Utility class for validating Spanish identity documents (DNI and NIE).
abstract final class DocumentValidator {
  static const _validLetters = [
    'T', 'R', 'W', 'A', 'G', 'M', 'Y', 'F', 'P', 'D', 'X', 'B', //
    'N', 'J', 'Z', 'S', 'Q', 'V', 'H', 'L', 'C', 'K', 'E',
  ];

  static final _dniPattern = RegExp(r'^\d{8}[A-Z]$');
  static final _niePattern = RegExp(r'^[XYZ]\d{7}[A-Z]$');
  static final _supportNumberPattern = RegExp(r'^[CE]\d{8}$');

  /// Returns `true` if [document] matches the DNI format (8 digits + letter).
  static bool isDni(String document) => _dniPattern.hasMatch(document);

  /// Returns `true` if [document] matches the NIE format (X/Y/Z + 7 digits + letter).
  static bool isNie(String document) => _niePattern.hasMatch(document);

  /// Validates a DNI using the modulo-23 letter check.
  static bool isValidDni(String dni) {
    if (!isDni(dni)) return false;
    final number = int.parse(dni.substring(0, 8));
    final letter = dni[8];
    return _validLetters[number % 23] == letter;
  }

  /// Validates a NIE using the modulo-23 letter check.
  ///
  /// The leading letter is mapped: X→0, Y→1, Z→2.
  static bool isValidNie(String nie) {
    if (!isNie(nie)) return false;
    final prefix = switch (nie[0]) {
      'X' => '0',
      'Y' => '1',
      'Z' => '2',
      _ => '',
    };
    if (prefix.isEmpty) return false;
    final number = int.parse('$prefix${nie.substring(1, 8)}');
    final letter = nie[8];
    return _validLetters[number % 23] == letter;
  }

  /// Validates either a DNI or NIE.
  static bool isValid(String document) =>
      isValidDni(document) || isValidNie(document);

  /// Validates a NIE support number (C or E + 8 digits).
  static bool isValidSupportNumber(String supportNumber) =>
      _supportNumberPattern.hasMatch(supportNumber);

  static final _contrastDatePattern =
      RegExp(r'^\d{2}-\d{2}-\d{4}$');

  /// Validates a contrast date string in `dd-MM-yyyy` format.
  static bool isValidContrastDate(String date) {
    if (!_contrastDatePattern.hasMatch(date)) return false;
    final parts = date.split('-');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    if (year < 1900 || year > 2100) return false;
    return true;
  }

  /// Returns the expected contrast type for a document.
  /// `'date'` for DNI (validity date), `'support'` for NIE (support number).
  static String? contrastTypeFor(String document) {
    if (isDni(document)) return 'date';
    if (isNie(document)) return 'support';
    return null;
  }
}
