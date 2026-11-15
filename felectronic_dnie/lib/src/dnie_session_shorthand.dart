part of 'dnie_session.dart';

/// Shorthand built on the core [DnieSession] operations.
extension DnieSessionShorthand on DnieSession {
  /// Signs the UTF-8 bytes of [text].
  Future<SignedData> signText(String text) => sign(utf8.encode(text));

  /// Signs [data] as CAdES through the remote three-phase service.
  ///
  /// Android only; see [dnie.signCades].
  Future<SignedData> signCades(Uint8List data) => dnie.signCades(
    data: data,
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// This session's credentials, using the [type] certificate.
  DnieSession withCertificate(DnieCertificateType type) =>
      DnieSession._(_can, _pin, type, timeout);

  /// This session's credentials, using the authentication certificate.
  DnieSession get auth => withCertificate(DnieCertificateType.auth);

  /// This session's credentials, using the signing certificate.
  DnieSession get signing => withCertificate(DnieCertificateType.sign);

  /// Reads personal data and certificate details, in two NFC reads.
  Future<DnieIdentity> readFullIdentity() => workflows.readFullIdentity(
    can: _can,
    pin: _pin,
    certificateType: certificateType,
    timeout: timeout,
  );

  /// Checks NFC, the card and the PIN in turn. Never throws a [DnieError].
  Future<DnieReadiness> checkReadiness() => workflows.checkReadiness(
    can: _can,
    pin: _pin,
    certificateType: certificateType,
    timeout: timeout,
  );

  /// Probes the card and signs [data] only if it is a DNIe.
  Future<SignedData> probeAndSign(Uint8List data) => workflows.probeAndSign(
    data: data,
    can: _can,
    pin: _pin,
    certificateType: certificateType,
    timeout: timeout,
  );
}
