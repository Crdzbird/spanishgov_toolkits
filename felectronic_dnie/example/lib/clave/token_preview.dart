/// Tokens are long and mostly noise: this shows enough to tell two apart.
extension TokenPreview on String {
  String get tokenPreview =>
      length <= 24 ? this : '${substring(0, 24)}... ($length characters)';
}
