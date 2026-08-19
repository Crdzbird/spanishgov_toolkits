import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:felectronic_certificates/src/certificate_session.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';

/// Certificate handling that only applies to Apple platforms.
///
/// ## Why this is separate
///
/// Android and Apple acquire credentials in fundamentally different ways, and
/// a single cross-platform API hides that difference until it bites.
///
/// On Android, `KeyChain` can hand an app a credential the *system* holds,
/// once the user consents. On iOS and macOS there is no equivalent: an app
/// can only see identities in its own keychain access groups.
/// `SecItemCopyMatching` never searches the system keychain.
///
/// The practical consequence catches people out. A certificate installed as a
/// **configuration profile** — Settings › General › VPN & Device Management —
/// is genuinely installed, is visible in Settings, and works for Safari, Mail
/// and VPN. It is still completely invisible to this plugin, because iOS does
/// not expose profile-installed private keys to third-party apps. The generic
/// `getAllCertificates()` correctly returns an empty list, which reads like a
/// bug and is not one.
///
/// So on Apple platforms a certificate has to be imported into the app itself.
/// [AppleCertificates.importAndSelect] is that step, in one call.
abstract final class AppleCertificates {
  /// Whether the current platform is one this class applies to.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  /// Imports a PKCS#12 and makes it the default, in one step.
  ///
  /// This is the Apple entry point: it takes a caller from "I have a .p12" to
  /// "ready to sign" without the import → list → select dance, which is where
  /// the empty-keychain confusion tends to happen.
  ///
  /// [pkcs12] is the raw `.p12` / `.pfx` bytes. [password] may be null for an
  /// unencrypted file — note that null and `''` are different things to the
  /// Security framework, so pass null rather than an empty string. [alias] is
  /// an optional label; the file name is a reasonable choice.
  ///
  /// Returns a session on the imported certificate, ready to sign.
  ///
  /// Throws:
  /// * [UnsupportedError] when called on a non-Apple platform. Android should
  ///   use the ordinary import and selection calls, which can also reach
  ///   system-held credentials.
  /// * [CertIncorrectPasswordError] when the password does not open the file.
  /// * [CertAlreadyExistsError] when the identity is already present.
  /// * [CertNotFoundError] when the import reports success but the identity
  ///   cannot then be found — which would mean the keychain accepted it and
  ///   did not store it, and is worth investigating rather than retrying.
  static Future<CertificateSession> importAndSelect(
    Uint8List pkcs12, {
    String? password,
    String? alias,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'AppleCertificates.importAndSelect is iOS and macOS only. On Android '
        'use importCertificate and selectDefaultCertificate, which can also '
        'reach credentials the system holds.',
      );
    }

    final platform = FelectronicCertificatesPlatform.instance;
    final before = (await platform.getAllCertificates())
        .map((c) => c.serialNumber)
        .toSet();

    await platform.importCertificate(
      pkcs12,
      // An empty string is a password of zero length, which is not the same
      // as no password at all.
      password: (password?.isEmpty ?? true) ? null : password,
      alias: alias,
    );

    final after = await platform.getAllCertificates();
    if (after.isEmpty) {
      throw const CertNotFoundError();
    }

    // Prefer the identity that was not there before. A re-import of the same
    // certificate adds nothing new, so fall back to matching the alias, then
    // to the only entry.
    final imported =
        after.where((c) => !before.contains(c.serialNumber)).firstOrNull ??
        (alias == null
            ? null
            : after.where((c) => c.alias == alias).firstOrNull) ??
        (after.length == 1 ? after.first : null);

    if (imported == null) {
      throw const CertNotFoundError();
    }

    await platform.setDefaultCertificateBySerialNumber(imported.serialNumber);

    final session = await CertificateSession.fromDefault();
    if (session == null) {
      throw const CertNotFoundError();
    }
    return session;
  }

  /// Explains an empty keychain, for surfacing to a user.
  ///
  /// `getAllCertificates` returning empty is indistinguishable from a failure
  /// at the call site. On Apple platforms the overwhelmingly common cause is a
  /// certificate installed as a configuration profile, which the app cannot
  /// see, so it is worth saying so rather than leaving a blank list.
  static String get emptyKeychainExplanation =>
      "No certificates in this app's keychain.\n\n"
      'A certificate installed as a configuration profile (Settings › '
      'General › VPN & Device Management) does not count: iOS keeps it in '
      'the system keychain, and an app cannot read identities from there. '
      'That is a platform rule, not a limitation of this plugin.\n\n'
      'Import the .p12 the profile was created from.';
}
