import 'package:flutter/foundation.dart';

/// {@template signed_data}
/// Result of a successful DNIe signing operation.
///
/// Contains the raw signed bytes, their Base64 representation,
/// and the signing certificate.
/// {@endtemplate}
@immutable
final class SignedData {
  /// {@macro signed_data}
  const factory SignedData({
    required Uint8List signedData,
    required String signedDataBase64,
    required String certificate,
  }) = SignedData._;

  const SignedData._({
    required this.signedData,
    required this.signedDataBase64,
    required this.certificate,
  });

  /// The raw signed bytes.
  final Uint8List signedData;

  /// Base64-encoded representation of [signedData].
  final String signedDataBase64;

  /// Base64-encoded signing certificate.
  final String certificate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignedData &&
          other.signedDataBase64 == signedDataBase64 &&
          other.certificate == certificate &&
          listEquals(other.signedData, signedData);

  @override
  int get hashCode => Object.hash(
    signedDataBase64,
    certificate,
    Object.hashAll(signedData),
  );

  @override
  String toString() {
    final certPreview = certificate.length > 20
        ? '${certificate.substring(0, 20)}...'
        : certificate;
    return 'SignedData('
        'signedDataLength: ${signedData.length}, '
        'certificate: $certPreview'
        ')';
  }
}
