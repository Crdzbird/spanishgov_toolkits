import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_triphase/src/triphase_protocol.dart';
import 'package:felectronic_triphase/src/triphase_session.dart';

/// Signs [payload] with the private key, under the agreed algorithm.
///
/// **This is a full signature, not a modular exponentiation.** The service
/// hands back the bytes to be signed and expects the algorithm named in the
/// request to be applied whole — the payload is hashed, then signed. On iOS
/// `SecKeyCreateSignature` with a `rsaSignatureMessagePKCS1v15SHA*` algorithm
/// does exactly this; a DNIe reaches the same result by hashing on the device
/// and letting the card apply PKCS#1 to the resulting DigestInfo.
///
/// Implementing this as raw RSA over the payload produces a signature that
/// verifies against nothing, and the service will accept the post-sign
/// request regardless — the failure surfaces much later, in a verifier.
///
/// This is the only step that needs a private key, and the only step that
/// differs between an electronic certificate and a DNIe. Everything else in
/// the protocol is identical for both, which is why it is a callback rather
/// than something this package implements.
typedef Pkcs1Signer = Future<Uint8List> Function(Uint8List payload);

/// The @firma three-phase signing protocol.
///
/// Producing a CAdES, PAdES or XAdES signature needs the whole document and a
/// good deal of format-specific machinery. Rather than do that on the device,
/// the service does it in three phases:
///
/// 1. **Pre-sign** — the client sends the document and its certificate; the
///    service returns a session document containing the bytes to sign.
/// 2. **Sign** — the client signs those bytes with its private key. This is
///    the only phase that touches the key, and the only phase where an
///    electronic certificate and a DNIe differ.
/// 3. **Post-sign** — the client returns the session with the signature
///    attached; the service assembles the final envelope.
///
/// The private key never leaves the device, and the service never sees it.
/// The document, however, *is* sent to the service — that is inherent to the
/// design, not an implementation choice, and callers should know it.
class TriphaseClient {
  TriphaseClient({required TriphaseTransport transport, Uri? serviceUrl})
      : _transport = transport,
        serviceUrl = serviceUrl ?? defaultServiceUrl;

  /// The Spanish government's mobile signing service.
  static final Uri defaultServiceUrl = Uri.parse(
    'https://firmamovil-appfactory.redsara.es'
    '/afirma-server-triphase-signer/SignatureService',
  );

  final TriphaseTransport _transport;
  final Uri serviceUrl;

  /// Runs all three phases and returns the assembled signature.
  ///
  /// [certificateBase64] is the signing certificate, base64-encoded, as the
  /// service expects it. [signPkcs1] is called exactly once, with the payload
  /// the service asked for.
  Future<Uint8List> sign({
    required Uint8List document,
    required String certificateBase64,
    required SignatureFormat format,
    required SignatureAlgorithm algorithm,
    required Pkcs1Signer signPkcs1,
    String extraParams = '',
  }) async {
    final session = await preSign(
      document: document,
      certificateBase64: certificateBase64,
      format: format,
      algorithm: algorithm,
      extraParams: extraParams,
    );

    session.attachSignature(await signPkcs1(session.payloadToSign));

    return postSign(
      document: document,
      certificateBase64: certificateBase64,
      session: session,
      format: format,
      algorithm: algorithm,
      extraParams: extraParams,
    );
  }

  /// Phase one: ask the service what to sign.
  Future<TriphaseSession> preSign({
    required Uint8List document,
    required String certificateBase64,
    required SignatureFormat format,
    required SignatureAlgorithm algorithm,
    String extraParams = '',
  }) async {
    final body = await _send(
      TriphaseRequests.preSign(
        certificateBase64: certificateBase64,
        document: document,
        format: format,
        algorithm: algorithm,
        extraParams: extraParams,
      ),
      phase: 'pre-sign',
    );
    return TriphaseSession.parse(utf8.decode(TriphaseCodec.decode(body)));
  }

  /// Phase three: return the signed session and collect the result.
  Future<Uint8List> postSign({
    required Uint8List document,
    required String certificateBase64,
    required TriphaseSession session,
    required SignatureFormat format,
    required SignatureAlgorithm algorithm,
    String extraParams = '',
  }) async {
    if (!session.hasSignature) {
      throw const TriphaseProtocolException(
        'the session has no signature attached; sign the payload first',
      );
    }
    final body = await _send(
      TriphaseRequests.postSign(
        certificateBase64: certificateBase64,
        document: document,
        session: session.toXmlString(),
        format: format,
        algorithm: algorithm,
        extraParams: extraParams,
      ),
      phase: 'post-sign',
    );
    return TriphaseCodec.decode(
      TriphaseRequests.stripPostSignPrefix(
        utf8.decode(TriphaseCodec.decode(body), allowMalformed: true),
      ),
    );
  }

  Future<String> _send(String body, {required String phase}) async {
    final TriphaseResponse response;
    try {
      response = await _transport(
        TriphaseRequest(url: serviceUrl, body: body),
      );
    } on TriphaseException {
      rethrow;
    } catch (error) {
      throw TriphaseTransportException(
        '$phase could not reach the service: $error',
      );
    }

    if (!response.isSuccess) {
      throw TriphaseServiceException(
        '$phase was rejected with HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.body.trim().isEmpty) {
      throw TriphaseProtocolException('$phase returned an empty body');
    }
    // The service reports its own failures in the body with a 200.
    if (response.body.startsWith('ERR-')) {
      throw TriphaseServiceException(
        '$phase failed: ${response.body}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return response.body;
  }
}
