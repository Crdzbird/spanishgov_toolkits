import 'dart:convert';

import 'package:flutter/foundation.dart';

/// {@template signed_data}
/// Result of a successful DNIe signing operation.
///
/// Contains the raw signed bytes, their Base64 representation,
/// and the signing certificate.
/// {@endtemplate}
@immutable
class SignedData {
  /// {@macro signed_data}
  const SignedData({
    required this.signedData,
    required this.signedDataBase64,
    required this.certificate,
  });

  /// Creates a [SignedData] from a map returned by the native platform.
  ///
  /// Expected keys: `signedData` (List of int), `base64signedData` (String),
  /// `base64certificate` (String).
  factory SignedData.fromMap(Map<String, dynamic> map) {
    final rawBytes = map['signedData'];
    final Uint8List bytes;

    if (rawBytes is Uint8List) {
      bytes = rawBytes;
    } else if (rawBytes is List) {
      bytes = Uint8List.fromList(rawBytes.cast<int>());
    } else {
      bytes = Uint8List(0);
    }

    return SignedData(
      signedData: bytes,
      signedDataBase64: map['base64signedData'] as String? ?? '',
      certificate: map['base64certificate'] as String? ?? '',
    );
  }

  /// Creates a [SignedData] from a JSON string.
  factory SignedData.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SignedData.fromMap(map);
  }

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
