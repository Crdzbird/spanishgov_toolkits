import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:felectronic_triphase/felectronic_triphase.dart';

/// Maps this package's algorithm vocabulary onto the signing service's.
///
/// The two vocabularies exist independently — `CertSignAlgorithm` is what the
/// platform channel speaks, `SignatureAlgorithm` is Java's JCA spelling that
/// the @firma service matches on — so they are related here, once, and
/// exhaustively. A `switch` without a default means adding a value to either
/// enum is a compile error rather than a signature the service silently
/// rejects.
extension CertSignAlgorithmTriphase on CertSignAlgorithm {
  /// The name the signing service expects.
  SignatureAlgorithm get triphaseAlgorithm => switch (this) {
    CertSignAlgorithm.sha256rsa => SignatureAlgorithm.sha256withRsa,
    CertSignAlgorithm.sha384rsa => SignatureAlgorithm.sha384withRsa,
    CertSignAlgorithm.sha512rsa => SignatureAlgorithm.sha512withRsa,
    CertSignAlgorithm.sha256ec => SignatureAlgorithm.sha256withEcdsa,
    CertSignAlgorithm.sha384ec => SignatureAlgorithm.sha384withEcdsa,
    CertSignAlgorithm.sha512ec => SignatureAlgorithm.sha512withEcdsa,
  };
}
