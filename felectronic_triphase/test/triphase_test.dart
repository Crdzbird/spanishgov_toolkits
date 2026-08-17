import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_triphase/felectronic_triphase.dart';
import 'package:test/test.dart';

/// The three-phase protocol, driven end to end through a fake service.
///
/// **What these prove:** the request bodies have the shape the service
/// expects, the session round-trips with the signature spliced into the right
/// place, and every failure the original Swift reported as an empty string is
/// now a distinct, catchable error.
///
/// **What they do not prove:** that the real @firma service accepts any of it.
/// The fake below answers the way the protocol is documented to; a misreading
/// would be mirrored in both and every test would still pass.
void main() {
  /// A session document shaped like the service's.
  String sessionXml(String preBase64) => <String>[
        '<xml>',
        '<firmas>',
        '<firma>',
        '<param n="NEED_PRE">true</param>',
        '<param n="PRE">$preBase64</param>',
        '</firma>',
        '</firmas>',
        '</xml>',
      ].join();

  /// The service answers base64url without padding.
  String encodeResponse(String text) =>
      base64Url.encode(utf8.encode(text)).replaceAll('=', '');

  final document = Uint8List.fromList(utf8.encode('the document to sign'));
  const certificate = 'Q2VydA'; // base64url of 'Cert'

  group('codec', () {
    test('decodes base64url without padding', () {
      final encoded = base64Url.encode([1, 2, 3, 4, 5]).replaceAll('=', '');
      expect(TriphaseCodec.decode(encoded), [1, 2, 3, 4, 5]);
    });

    test('accepts standard base64 too', () {
      expect(TriphaseCodec.decode(base64.encode([9, 9, 9])), [9, 9, 9]);
    });

    test('rejects an impossible length rather than guessing', () {
      expect(
        () => TriphaseCodec.decode('A'),
        throwsA(isA<TriphaseProtocolException>()),
      );
    });

    test('url-safe output rewrites the alphabet', () {
      // 0xFB 0xFF 0xBF encodes to "+/+/" in standard base64; both characters
      // would be misread in a request body.
      final urlSafe = TriphaseCodec.urlSafe([0xFB, 0xFF, 0xBF]);
      expect(urlSafe, isNot(contains('+')));
      expect(urlSafe, isNot(contains('/')));
    });

    /// The Android implementation — the only one that has run against the
    /// real service — keeps base64 padding. An earlier revision here stripped
    /// it, copying the never-executed Swift; a strict Java decoder would
    /// reject that. The input below is chosen to need padding.
    test('padding is retained, matching the Android encoder', () {
      expect(TriphaseCodec.urlSafe([0x01]), endsWith('=='));
      expect(TriphaseCodec.urlSafe([0x01, 0x02]), endsWith('='));
      expect(TriphaseCodec.urlSafe([0x01, 0x02, 0x03]), isNot(endsWith('=')));
    });

    test('an encoded string can be rewritten without touching padding', () {
      expect(TriphaseCodec.toUrlSafe('ab+/cd=='), 'ab-_cd==');
      expect(TriphaseCodec.toUrlSafe('plain'), 'plain');
    });
  });

  group('request bodies', () {
    test('pre-sign carries the operation, format and algorithm', () {
      final body = TriphaseRequests.preSign(
        certificateBase64: certificate,
        document: document,
        format: SignatureFormat.pades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        extraParams: '',
      );
      expect(body, startsWith('op=pre&cop=sign'));
      expect(body, contains('format=PAdES'));
      expect(body, contains('algo=SHA256withRSA'));
      expect(body, contains('cert=$certificate'));
    });

    /// A certificate is usually held as standard base64, whose `+` and `/`
    /// would be misread in the body. The Android implementation rewrites it;
    /// an earlier revision here passed it through untouched.
    test('the certificate is rewritten to the url-safe alphabet', () {
      final body = TriphaseRequests.preSign(
        certificateBase64: 'MIIB+aa/bb==',
        document: document,
        format: SignatureFormat.cades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        extraParams: '',
      );
      expect(body, contains('cert=MIIB-aa_bb=='));
      expect(body, isNot(contains('+')));
    });

    /// Android appends the field only when there is something to send.
    test('params is omitted when empty and present when not', () {
      String bodyWith(String extra) => TriphaseRequests.preSign(
            certificateBase64: certificate,
            document: document,
            format: SignatureFormat.cades,
            algorithm: SignatureAlgorithm.sha256withRsa,
            extraParams: extra,
          );

      expect(bodyWith(''), isNot(contains('params=')));
      expect(
        bodyWith('mode=implicit'),
        contains('params=${base64.encode(utf8.encode('mode=implicit'))}'),
      );
    });

    /// params keeps the standard alphabet while cert and doc do not — a
    /// genuine asymmetry in the Android implementation, reproduced here.
    test('params stays standard base64 while cert and doc are rewritten', () {
      final body = TriphaseRequests.preSign(
        certificateBase64: 'a+b/c',
        document: Uint8List.fromList([0xFB, 0xFF, 0xBF]),
        format: SignatureFormat.cades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        // Encodes to a value containing '+' and '/'.
        extraParams: String.fromCharCodes([0xFB, 0xFF, 0xBF]),
      );
      final params = body.split('params=').last;
      expect(params, isNot(contains('-')));
      expect(body.split('&doc=').last.split('&').first, isNot(contains('+')));
    });

    test('post-sign differs from pre-sign by op and the session', () {
      final body = TriphaseRequests.postSign(
        certificateBase64: certificate,
        document: document,
        session: '<xml/>',
        format: SignatureFormat.xades,
        algorithm: SignatureAlgorithm.sha512withRsa,
        extraParams: '',
      );
      expect(body, startsWith('op=post&cop=sign'));
      expect(body, contains('format=XAdES'));
      expect(body, contains('algo=SHA512withRSA'));
      expect(body, contains('&session='));
    });

    /// The wire names are Java's and the service matches on them exactly.
    test('format and algorithm wire names are the Java spellings', () {
      expect(SignatureFormat.cades.wireName, 'CAdES');
      expect(SignatureFormat.pades.wireName, 'PAdES');
      expect(SignatureFormat.xades.wireName, 'XAdES');
      expect(SignatureAlgorithm.sha256withRsa.wireName, 'SHA256withRSA');
      expect(SignatureAlgorithm.sha512withRsa.wireName, 'SHA512withRSA');
    });

    test('strips the success prefix the service prepends', () {
      expect(TriphaseRequests.stripPostSignPrefix('OK NEWID=abc'), 'abc');
      expect(TriphaseRequests.stripPostSignPrefix('abc'), 'abc');
    });
  });

  group('session', () {
    test('decodes the payload rather than handing back its base64', () {
      final payload = utf8.encode('sign me');
      final session = TriphaseSession.parse(
        sessionXml(base64.encode(payload)),
      );
      expect(session.payloadToSign, payload);
    });

    test('attaches the signature beside PRE, not at the document root', () {
      final session = TriphaseSession.parse(
        sessionXml(base64.encode(utf8.encode('sign me'))),
      )..attachSignature(Uint8List.fromList([1, 2, 3]));

      final xml = session.toXmlString();
      expect(
        xml,
        contains('<param n="PK1">${base64.encode([1, 2, 3])}</param>'),
      );
      // It lands inside <firma>, alongside PRE.
      expect(
        RegExp('<firma>.*PK1.*</firma>', dotAll: true).hasMatch(xml),
        isTrue,
        reason: 'PK1 must sit beside PRE for the service to pair them',
      );
    });

    test('carries the service state through untouched', () {
      final session = TriphaseSession.parse(
        sessionXml(base64.encode(utf8.encode('x'))),
      )..attachSignature(Uint8List.fromList([7]));
      expect(
        session.toXmlString(),
        contains('<param n="NEED_PRE">true</param>'),
      );
    });

    test('refuses to sign twice', () {
      final session = TriphaseSession.parse(
        sessionXml(base64.encode(utf8.encode('x'))),
      )..attachSignature(Uint8List.fromList([1]));
      expect(
        () => session.attachSignature(Uint8List.fromList([2])),
        throwsA(isA<TriphaseProtocolException>()),
      );
    });

    test('a session with no PRE is an error, not an empty payload', () {
      final session = TriphaseSession.parse('<xml><firmas/></xml>');
      expect(
        () => session.payloadToSign,
        throwsA(isA<TriphaseProtocolException>()),
      );
    });

    test('malformed XML is reported as such', () {
      expect(
        () => TriphaseSession.parse('<xml><unclosed>'),
        throwsA(isA<TriphaseProtocolException>()),
      );
      expect(
        () => TriphaseSession.parse('   '),
        throwsA(isA<TriphaseProtocolException>()),
      );
    });
  });

  group('client', () {
    /// A service that answers pre-sign then post-sign, recording both bodies.
    ({TriphaseTransport transport, List<String> bodies}) fakeService({
      required String preResponse,
      String postResponse = 'OK NEWID=',
      int status = 200,
    }) {
      final bodies = <String>[];
      var call = 0;
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        bodies.add(request.body);
        call++;
        return TriphaseResponse(
          statusCode: status,
          body: call == 1
              ? encodeResponse(preResponse)
              : encodeResponse(postResponse),
        );
      }

      return (transport: transport, bodies: bodies);
    }

    test('runs all three phases and returns the assembled signature', () async {
      final payload = utf8.encode('what the service wants signed');
      final expected = utf8.encode('the finished envelope');
      final fake = fakeService(
        preResponse: sessionXml(base64.encode(payload)),
        postResponse:
            'OK NEWID=${base64Url.encode(expected).replaceAll('=', '')}',
      );

      var signedPayload = <int>[];
      final result = await TriphaseClient(transport: fake.transport).sign(
        document: document,
        certificateBase64: certificate,
        format: SignatureFormat.cades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        signPkcs1: (bytes) async {
          signedPayload = bytes;
          return Uint8List.fromList([0xAA, 0xBB]);
        },
      );

      expect(
        signedPayload,
        payload,
        reason: 'signs what the service asked for',
      );
      expect(result, expected);
      expect(fake.bodies, hasLength(2));
      expect(fake.bodies[0], startsWith('op=pre'));
      expect(fake.bodies[1], startsWith('op=post'));
    });

    test('the signature reaches the service in the session', () async {
      final fake = fakeService(
        preResponse: sessionXml(base64.encode(utf8.encode('x'))),
        postResponse: 'OK NEWID='
            '${base64Url.encode(utf8.encode('done')).replaceAll('=', '')}',
      );

      await TriphaseClient(transport: fake.transport).sign(
        document: document,
        certificateBase64: certificate,
        format: SignatureFormat.pades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        signPkcs1: (_) async => Uint8List.fromList([0x11, 0x22]),
      );

      final sessionParam = Uri.splitQueryString(fake.bodies[1])['session']!;
      final sessionXmlSent = utf8.decode(TriphaseCodec.decode(sessionParam));
      expect(sessionXmlSent, contains(base64.encode([0x11, 0x22])));
    });

    test('the private key is used exactly once', () async {
      final fake = fakeService(
        preResponse: sessionXml(base64.encode(utf8.encode('x'))),
        postResponse: 'OK NEWID='
            '${base64Url.encode(utf8.encode('d')).replaceAll('=', '')}',
      );
      var calls = 0;
      await TriphaseClient(transport: fake.transport).sign(
        document: document,
        certificateBase64: certificate,
        format: SignatureFormat.cades,
        algorithm: SignatureAlgorithm.sha256withRsa,
        signPkcs1: (_) async {
          calls++;
          return Uint8List.fromList([1]);
        },
      );
      expect(calls, 1);
    });

    // --- Failures. Each of these was an empty string in the Swift original.

    test('an HTTP failure is distinguishable, with the body kept', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async =>
          const TriphaseResponse(statusCode: 500, body: 'boom');

      await expectLater(
        TriphaseClient(transport: transport).preSign(
          document: document,
          certificateBase64: certificate,
          format: SignatureFormat.cades,
          algorithm: SignatureAlgorithm.sha256withRsa,
        ),
        throwsA(
          isA<TriphaseServiceException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.body, 'body', 'boom'),
        ),
      );
    });

    /// The service reports its own errors with a 200 and an ERR- body, which
    /// a status check alone would let through as success.
    test('an ERR- body is a failure even with HTTP 200', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async =>
          const TriphaseResponse(statusCode: 200, body: 'ERR-06: bad document');

      await expectLater(
        TriphaseClient(transport: transport).preSign(
          document: document,
          certificateBase64: certificate,
          format: SignatureFormat.cades,
          algorithm: SignatureAlgorithm.sha256withRsa,
        ),
        throwsA(isA<TriphaseServiceException>()),
      );
    });

    test('a transport error is reported as one', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async =>
          throw const SocketExceptionStub();

      await expectLater(
        TriphaseClient(transport: transport).preSign(
          document: document,
          certificateBase64: certificate,
          format: SignatureFormat.cades,
          algorithm: SignatureAlgorithm.sha256withRsa,
        ),
        throwsA(isA<TriphaseTransportException>()),
      );
    });

    test('an empty body is a failure, not an empty signature', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async =>
          const TriphaseResponse(statusCode: 200, body: '');

      await expectLater(
        TriphaseClient(transport: transport).preSign(
          document: document,
          certificateBase64: certificate,
          format: SignatureFormat.cades,
          algorithm: SignatureAlgorithm.sha256withRsa,
        ),
        throwsA(isA<TriphaseProtocolException>()),
      );
    });

    test('post-sign refuses a session that was never signed', () async {
      final fake = fakeService(preResponse: sessionXml(base64.encode([1])));
      final client = TriphaseClient(transport: fake.transport);
      final session = await client.preSign(
        document: document,
        certificateBase64: certificate,
        format: SignatureFormat.cades,
        algorithm: SignatureAlgorithm.sha256withRsa,
      );

      await expectLater(
        client.postSign(
          document: document,
          certificateBase64: certificate,
          session: session,
          format: SignatureFormat.cades,
          algorithm: SignatureAlgorithm.sha256withRsa,
        ),
        throwsA(isA<TriphaseProtocolException>()),
      );
    });
  });
}

/// Stands in for a network failure without importing dart:io.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
