/// The canonical encoding for certificate serial numbers.
///
/// A certificate serial is a DER INTEGER, and every layer used to spell it
/// differently for the same certificate:
///
/// | Source                                    | Serial `0xB5A1C3` |
/// |-------------------------------------------|-------------------|
/// | iOS `SecCertificateCopySerialNumberData`  | `00b5a1c3`        |
/// | Android `BigInteger.toString(16)`         | `b5a1c3`          |
/// | `felectronic_x509`                        | `B5A1C3`          |
///
/// The iOS spelling keeps the DER sign-padding byte (DER INTEGERs are
/// signed, so a value whose top bit is set gains a leading `0x00`), while
/// the others drop it and disagree on case. Since the serial is the keystore
/// lookup key for `deleteCertificateBySerialNumber` and
/// `setDefaultCertificateBySerialNumber`, those spellings had to be
/// reconciled or lookups would fail across platforms.
abstract final class CertificateSerial {
  /// Normalises [serial] to lowercase hex of the serial's magnitude, with no
  /// sign-padding byte and no leading zeros.
  ///
  /// Tolerates the spellings seen in the wild: uppercase, `0x` prefixes,
  /// colon- or space-separated byte groups (`B5:A1:C3`), and the leading `-`
  /// that `BigInteger.toString(16)` emits for a certificate whose serial was
  /// mis-encoded as negative.
  ///
  /// Returns `'0'` for an all-zero serial and `''` for empty input, so a
  /// genuine zero serial stays distinguishable from an absent one.
  ///
  /// Idempotent: `canonical(canonical(x)) == canonical(x)`.
  static String canonical(String serial) {
    if (serial.isEmpty) return '';

    var hex = serial.toLowerCase().replaceAll(RegExp('[ \t:_-]'), '');
    if (hex.startsWith('0x')) hex = hex.substring(2);
    if (hex.isEmpty) return '';

    final stripped = hex.replaceFirst(RegExp('^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }

  /// Whether two serials refer to the same certificate, comparing canonically.
  ///
  /// Use this instead of `==` on raw serials — a value persisted by an
  /// earlier version may still carry a platform-specific spelling.
  static bool same(String a, String b) => canonical(a) == canonical(b);
}
