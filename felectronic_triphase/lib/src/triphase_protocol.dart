import 'dart:convert';
import 'dart:typed_data';

/// The advanced-signature envelope to produce.
///
/// The @firma service builds these; the client only ever contributes a raw
/// PKCS#1 signature over a payload the server hands back.
enum SignatureFormat {
  /// Binary documents.
  cades('CAdES'),

  /// PDF.
  pades('PAdES'),

  /// XML.
  xades('XAdES');

  const SignatureFormat(this.wireName);

  /// The value the service expects in `format=`.
  final String wireName;
}

/// Digest and signature algorithm pair, named as the service expects.
///
/// The wire names are Java's, because the service is a Java implementation —
/// they are not Dart or Apple spellings and must not be "tidied".
enum SignatureAlgorithm {
  sha256withRsa('SHA256withRSA'),
  sha384withRsa('SHA384withRSA'),
  sha512withRsa('SHA512withRSA'),
  sha256withEcdsa('SHA256withECDSA'),
  sha384withEcdsa('SHA384withECDSA'),
  sha512withEcdsa('SHA512withECDSA');

  const SignatureAlgorithm(this.wireName);

  /// The name the service matches on, in Java's JCA spelling.
  final String wireName;

  /// Whether this names an elliptic-curve key rather than an RSA one.
  ///
  /// A DNIe is always RSA; an electronic certificate in the keystore may not
  /// be, and signing EC data with RSA parameters produces a signature that
  /// verifies against nothing.
  bool get isEllipticCurve => wireName.endsWith('withECDSA');
}

/// What went wrong during a three-phase signature.
///
/// The Swift implementation this was ported from reported every failure as an
/// empty string — a network error, an HTTP 500 and a genuinely empty response
/// were indistinguishable to the caller. Each failure is now its own case, so
/// a caller can tell a retryable network problem from a rejected document.
sealed class TriphaseException implements Exception {
  const TriphaseException(this.message);

  final String message;

  /// A stable label for this failure, used in [toString].
  ///
  /// Spelled out rather than taken from `runtimeType`, which is not
  /// dependable once the code is minified.
  String get label;

  @override
  String toString() => '$label: $message';
}

/// The service could not be reached, or the request failed at the transport.
final class TriphaseTransportException extends TriphaseException {
  const TriphaseTransportException(super.message);

  @override
  String get label => 'TriphaseTransportException';
}

/// The service answered, but not with success.
final class TriphaseServiceException extends TriphaseException {
  const TriphaseServiceException(super.message, {this.statusCode, this.body});

  /// HTTP status, when the transport reported one.
  final int? statusCode;

  /// The response body, truncated for the message but kept whole here.
  final String? body;

  @override
  String get label => 'TriphaseServiceException';
}

/// The service's answer did not have the shape the protocol requires.
final class TriphaseProtocolException extends TriphaseException {
  const TriphaseProtocolException(super.message);

  @override
  String get label => 'TriphaseProtocolException';
}

/// A single request to the signing service.
///
/// Kept as data rather than performed here so the protocol can be tested
/// without a network, and so the caller chooses the HTTP stack.
class TriphaseRequest {
  const TriphaseRequest({required this.url, required this.body});

  final Uri url;

  /// The request body. Sent as `text/plain`, which is what the service
  /// expects despite the content being form-shaped.
  final String body;

  /// The content type the service requires.
  static const contentType = 'text/plain';
}

/// The transport a caller supplies: perform the request, return the response.
///
/// Implementations should return the body for any HTTP status rather than
/// throwing on non-2xx, and throw only when the request could not be made at
/// all. The client turns a non-2xx into a [TriphaseServiceException] with the
/// body attached, which is more useful to a caller than a bare status code.
typedef TriphaseTransport = Future<TriphaseResponse> Function(
  TriphaseRequest request,
);

/// What the transport got back.
class TriphaseResponse {
  const TriphaseResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Base64 in the two variants this protocol mixes.
///
/// The service's own Java `Base64` class takes a boolean for URL-safe output,
/// and the original client passed `true` for the document and certificate but
/// used standard base64 for the extra parameters. That inconsistency is
/// preserved here rather than harmonized — the request body is not
/// form-encoded, so changing which characters appear in a value could change
/// how the service parses it, and there is no way to verify that without the
/// live service.
///
/// See [TriphaseCodec.urlSafe] and [TriphaseCodec.standard].
abstract final class TriphaseCodec {
  /// URL-safe base64, unpadded — `-` and `_` for `+` and `/`.
  static String urlSafe(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Standard base64, padded.
  static String standard(List<int> bytes) => base64.encode(bytes);

  /// Accepts either variant, restoring padding as needed.
  ///
  /// The service answers in URL-safe base64 without padding; `base64.decode`
  /// requires a length that is a multiple of four, so the padding is restored
  /// before decoding.
  static Uint8List decode(String value) {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/').trim();
    switch (normalized.length % 4) {
      case 2:
        normalized += '==';
      case 3:
        normalized += '=';
      case 1:
        throw const TriphaseProtocolException(
          'base64 payload has an impossible length',
        );
    }
    try {
      return base64.decode(normalized);
    } on FormatException catch (error) {
      throw TriphaseProtocolException(
        'could not decode base64: ${error.message}',
      );
    }
  }
}

/// Builds the request bodies the service expects.
///
/// The parameter order matches the original client's. The service is not known
/// to care, but there is no reason to differ from a request shape that the
/// Android build exercises.
abstract final class TriphaseRequests {
  /// The pre-sign body: asks the service what to sign.
  static String preSign({
    required String certificateBase64,
    required Uint8List document,
    required SignatureFormat format,
    required SignatureAlgorithm algorithm,
    required String extraParams,
  }) =>
      'op=pre&cop=sign&format=${format.wireName}'
      '&algo=${algorithm.wireName}'
      '&cert=$certificateBase64'
      '&doc=${TriphaseCodec.urlSafe(document)}'
      '&params=${TriphaseCodec.standard(utf8.encode(extraParams))}';

  /// The post-sign body: hands back the session with the signature spliced in.
  static String postSign({
    required String certificateBase64,
    required Uint8List document,
    required String session,
    required SignatureFormat format,
    required SignatureAlgorithm algorithm,
    required String extraParams,
  }) =>
      'op=post&cop=sign&format=${format.wireName}'
      '&algo=${algorithm.wireName}'
      '&cert=$certificateBase64'
      '&doc=${TriphaseCodec.urlSafe(document)}'
      '&session=${TriphaseCodec.urlSafe(utf8.encode(session))}'
      '&params=${TriphaseCodec.standard(utf8.encode(extraParams))}';

  /// Strips the `OK NEWID=` prefix the service puts on a successful post-sign.
  static String stripPostSignPrefix(String decoded) =>
      decoded.replaceFirst('OK NEWID=', '');
}
