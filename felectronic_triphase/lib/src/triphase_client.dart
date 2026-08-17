import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_triphase/src/triphase_protocol.dart';
import 'package:felectronic_triphase/src/triphase_session.dart';

/// Produces a raw PKCS#1 signature over [payload].
///
/// This is the only step that needs a private key, and the only step that
/// differs between an electronic certificate in the keystore and a DNIe card.
/// Everything else in the three-phase protocol is the same for both, which is
/// why this is a function the caller supplies rather than something this
/// package knows about.
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
