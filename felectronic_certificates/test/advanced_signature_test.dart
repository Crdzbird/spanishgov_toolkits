import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_certificates/felectronic_certificates.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Advanced signatures from an electronic certificate.
///
/// The point of these is the seam between two independently-written
/// vocabularies: `CertSignAlgorithm`, which the platform channel speaks, and
/// the service's Java spelling. Nothing else checks that they agree, and a
/// mismatch produces a signature the service accepts and a verifier later
/// rejects.
void main() {
  group('algorithm mapping', () {
    /// Every value must map, and map to the right spelling. The extension uses
    /// an exhaustive switch, so a new enum value breaks the build rather than
    /// reaching the service as something it does not recognize — this pins
    /// the values themselves.
    test('each platform algorithm maps to the service spelling', () {
      expect(
        CertSignAlgorithm.sha256rsa.triphaseAlgorithm.wireName,
        'SHA256withRSA',
      );
      expect(
        CertSignAlgorithm.sha384rsa.triphaseAlgorithm.wireName,
        'SHA384withRSA',
      );
      expect(
        CertSignAlgorithm.sha512rsa.triphaseAlgorithm.wireName,
        'SHA512withRSA',
      );
      expect(
        CertSignAlgorithm.sha256ec.triphaseAlgorithm.wireName,
        'SHA256withECDSA',
      );
      expect(
        CertSignAlgorithm.sha384ec.triphaseAlgorithm.wireName,
        'SHA384withECDSA',
      );
      expect(
        CertSignAlgorithm.sha512ec.triphaseAlgorithm.wireName,
        'SHA512withECDSA',
      );
    });

    test('every platform algorithm is covered', () {
      for (final algorithm in CertSignAlgorithm.values) {
        expect(algorithm.triphaseAlgorithm, isNotNull, reason: '$algorithm');
      }
    });

    /// An EC certificate signed with RSA parameters verifies against nothing.
    test('key type survives the mapping', () {
      expect(
        CertSignAlgorithm.sha256rsa.triphaseAlgorithm.isEllipticCurve,
        isFalse,
      );
      expect(
        CertSignAlgorithm.sha256ec.triphaseAlgorithm.isEllipticCurve,
        isTrue,
      );
    });

    /// The digest strength must not be quietly downgraded in translation.
    test('digest strength is preserved', () {
      for (final algorithm in CertSignAlgorithm.values) {
        final wire = algorithm.triphaseAlgorithm.wireName;
        final expected = switch (algorithm) {
          CertSignAlgorithm.sha256rsa || CertSignAlgorithm.sha256ec => 'SHA256',
          CertSignAlgorithm.sha384rsa || CertSignAlgorithm.sha384ec => 'SHA384',
          CertSignAlgorithm.sha512rsa || CertSignAlgorithm.sha512ec => 'SHA512',
        };
        expect(wire, startsWith(expected), reason: '$algorithm');
      }
    });
  });

  group('signWithDefaultCertificate', () {
    late _FakePlatform platform;

    setUp(() {
      platform = _FakePlatform();
      FelectronicCertificatesPlatform.instance = platform;
    });

    /// The top-level function must keep its offline behavior by default,
    /// exactly as the session method does.
    test('no format delegates straight to the platform', () async {
      var calls = 0;
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        calls++;
        return const TriphaseResponse(statusCode: 200, body: 'x');
      }

      final result = await signWithDefaultCertificate(
        Uint8List.fromList([1, 2, 3]),
        transport: transport,
      );

      expect(result, _FakePlatform.signature);
      expect(calls, 0);
    });

    test('a format runs the exchange', () async {
      final bodies = <String>[];
      final envelope = base64Url
          .encode(utf8.encode('top-level'))
          .replaceAll('=', '');
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        bodies.add(request.body);
        final payload = base64.encode(utf8.encode('p'));
        final body = bodies.length == 1
            ? '<xml><firma><param n="PRE">$payload</param></firma></xml>'
            : 'OK NEWID=$envelope';
        return TriphaseResponse(
          statusCode: 200,
          body: base64Url.encode(utf8.encode(body)).replaceAll('=', ''),
        );
      }

      final result = await signWithDefaultCertificate(
        Uint8List.fromList([1]),
        algorithm: CertSignAlgorithm.sha512rsa,
        format: SignatureFormat.cades,
        transport: transport,
      );

      expect(utf8.decode(result), 'top-level');
      expect(bodies[0], contains('algo=SHA512withRSA'));
      expect(bodies[0], contains('format=cades'));
    });

    /// Unlike the session method, this entry point has to find a certificate
    /// first. Saying so beats a null dereference or an opaque platform error.
    test('a format with no default certificate is a clear error', () async {
      platform.hasDefault = false;

      await expectLater(
        signWithDefaultCertificate(
          Uint8List.fromList([1]),
          format: SignatureFormat.pades,
          transport: (_) async =>
              const TriphaseResponse(statusCode: 200, body: 'x'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    /// Raw signing does not need one, and must not start requiring it.
    test('no format still works without a default certificate', () async {
      platform.hasDefault = false;
      expect(
        await signWithDefaultCertificate(Uint8List.fromList([1])),
        _FakePlatform.signature,
      );
    });
  });

  group('CertificateSession.sign', () {
    late _FakePlatform platform;

    setUp(() {
      platform = _FakePlatform();
      FelectronicCertificatesPlatform.instance = platform;
    });

    Future<CertificateSession> session() async =>
        (await CertificateSession.fromDefault())!;

    /// Without a format nothing is transmitted — the offline guarantee the
    /// existing API already made, which must not regress.
    test('no format signs locally and contacts nothing', () async {
      var transportCalls = 0;
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        transportCalls++;
        return const TriphaseResponse(statusCode: 200, body: 'x');
      }

      final result = await (await session()).sign(
        Uint8List.fromList([1, 2, 3]),
        transport: transport,
      );

      expect(result, _FakePlatform.signature);
      expect(transportCalls, 0, reason: 'raw signing must stay offline');
      expect(platform.signedPayloads, hasLength(1));
    });

    test('a format runs the three-phase exchange', () async {
      final bodies = <String>[];
      var call = 0;
      final envelope = base64Url
          .encode(utf8.encode('envelope'))
          .replaceAll('=', '');
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        bodies.add(request.body);
        call++;
        final payload = base64.encode(utf8.encode('payload'));
        final body = call == 1
            ? '<xml><firma><param n="PRE">$payload</param></firma></xml>'
            : 'OK NEWID=$envelope';
        return TriphaseResponse(
          statusCode: 200,
          body: base64Url.encode(utf8.encode(body)).replaceAll('=', ''),
        );
      }

      final result = await (await session()).sign(
        Uint8List.fromList([1, 2, 3]),
        format: SignatureFormat.pades,
        transport: transport,
      );

      expect(utf8.decode(result), 'envelope');
      expect(bodies, hasLength(2));
      expect(bodies[0], contains('format=pades'));
      expect(bodies[0], contains('algo=SHA256withRSA'));
    });

    /// The certificate must reach the service, or it cannot build the envelope.
    test('the certificate is sent, base64 encoded', () async {
      final bodies = <String>[];
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        bodies.add(request.body);
        final payload = base64.encode(utf8.encode('p'));
        final body = bodies.length == 1
            ? '<xml><firma><param n="PRE">$payload</param></firma></xml>'
            : 'OK NEWID='
                  '${base64Url.encode(utf8.encode('e')).replaceAll('=', '')}';
        return TriphaseResponse(
          statusCode: 200,
          body: base64Url.encode(utf8.encode(body)).replaceAll('=', ''),
        );
      }

      await (await session()).sign(
        Uint8List.fromList([1]),
        format: SignatureFormat.cades,
        transport: transport,
      );

      final encoded = base64.encode(_FakePlatform.certificateDer);
      expect(
        encoded,
        anyOf(contains('+'), contains('/')),
        reason: 'the fixture must be able to detect the rewrite',
      );
      expect(
        bodies[0],
        contains('cert=${TriphaseCodec.toUrlSafe(encoded)}'),
        reason: 'the certificate must reach the service url-safe',
      );
    });

    /// The platform signs the payload the service asked for, not the document.
    test('the key signs the service payload, not the document', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async {
        final payload = base64.encode(utf8.encode('what the service wants'));
        final body = platform.signedPayloads.isEmpty
            ? '<xml><firma><param n="PRE">$payload</param></firma></xml>'
            : 'OK NEWID='
                  '${base64Url.encode(utf8.encode('e')).replaceAll('=', '')}';
        return TriphaseResponse(
          statusCode: 200,
          body: base64Url.encode(utf8.encode(body)).replaceAll('=', ''),
        );
      }

      await (await session()).sign(
        Uint8List.fromList([9, 9, 9]),
        format: SignatureFormat.xades,
        transport: transport,
      );

      expect(platform.signedPayloads, hasLength(1));
      expect(
        utf8.decode(platform.signedPayloads.single),
        'what the service wants',
        reason: 'signing the document instead would produce a bad envelope',
      );
    });

    /// This package performs no network I/O of its own, so asking for a format
    /// without a transport is a programming error, caught immediately.
    test('a format without a transport is rejected', () async {
      final active = await session();
      expect(
        () => active.sign(
          Uint8List.fromList([1]),
          format: SignatureFormat.pades,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a service failure surfaces as a typed exception', () async {
      Future<TriphaseResponse> transport(TriphaseRequest request) async =>
          const TriphaseResponse(statusCode: 503, body: 'unavailable');

      await expectLater(
        (await session()).sign(
          Uint8List.fromList([1]),
          format: SignatureFormat.pades,
          transport: transport,
        ),
        throwsA(isA<TriphaseServiceException>()),
      );
    });
  });
}

/// Stands in for the device. Only the two entry points the signing path uses
/// are meaningful; the rest satisfy the interface.
class _FakePlatform extends FelectronicCertificatesPlatform
    with MockPlatformInterfaceMixin {
  static final signature = Uint8List.fromList([0xAA, 0xBB, 0xCC]);

  /// Chosen so its base64 contains both '+' and '/', which must be rewritten
  /// before reaching the request body.
  static final certificateDer = Uint8List.fromList([
    0x30,
    0x82,
    0xFB,
    0xFF,
    0xBF,
  ]);

  /// Everything handed to the private key, in order.
  final List<Uint8List> signedPayloads = [];

  /// Whether a default certificate is selected on the device.
  bool hasDefault = true;

  static final _certificate = DeviceCertificate(
    serialNumber: '0a1b',
    holderName: 'Test Holder',
    issuerName: 'Test CA',
    expirationDate: DateTime.utc(2030),
    usages: const [],
    encoded: certificateDer,
  );

  @override
  Future<DeviceCertificate?> getDefaultCertificate() async =>
      hasDefault ? _certificate : null;

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) async {
    signedPayloads.add(data);
    return signature;
  }

  @override
  Future<List<DeviceCertificate>> getAllCertificates() async => [_certificate];

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() async => _certificate;

  @override
  Future<void> setDefaultCertificateBySerialNumber(String serialNumber) async {}

  @override
  Future<void> clearDefaultCertificate() async {}

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) async {}

  @override
  Future<void> deleteDefaultCertificate() async {}

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {}
}
