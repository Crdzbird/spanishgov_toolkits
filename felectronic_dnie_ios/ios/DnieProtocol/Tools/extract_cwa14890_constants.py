#!/usr/bin/env python3
"""Regenerate Cwa14890Constants.swift from the transpiled jmulticard sources.

The CWA-14890 handshake needs the terminal's key pair and its card-verifiable
certificates byte for byte. Those are pure data — no test of the surrounding
logic can tell a correct transcription from a corrupted one — so they are
extracted mechanically by this script rather than copied by hand, and the
script is committed so the result can be reproduced and audited.

Two traps this script exists to avoid, both hit while writing it:

  * Anchoring on a *mention* of `ifdModulus_` finds the getter, not the
    assignment, and silently captures bytes from an unrelated array further
    down the file. Every pattern here anchors on the assignment.
  * `CHR_C_CV_IFD` ends with the same characters as `C_CV_IFD`, so a substring
    anchor matches the wrong constant depending on file order. The patterns
    below bind the full constant name.

Each extracted array is checked against the `count:` the source declares, and
each key pair is checked functionally: m^d^e mod n == m. A single flipped bit
in the modulus or the private exponent fails that.

Usage:
    python3 extract_cwa14890_constants.py > ../Sources/DnieProtocol/Cwa14890Constants.swift
"""

import glob
import os
import re
import sys

JMULTICARD = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "../../felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc",
    "es/gob/jmulticard/card/dnie",
)

# The public exponent is not stored alongside the private key: a Java
# RSAPrivateKey carries only modulus and private exponent, and the DER blob
# beside it leaves the CRT fields zero. 65537 is recovered by verifying
# m^d^e mod n == m, which fails for every other candidate tried (3, 17).
PUBLIC_EXPONENT = 65537

# Which source file backs which Swift constant set.
SETS = [
    ("dnie", "DnieCwa14890Constants.m", "the classic DNIe, and the DNIe 3.0 user channel"),
    ("dnie3Pin", "Dnie3PinCwa14890Constants.m", "the DNIe 3.0 PIN channel"),
    ("dnie3r2Pin", "Dnie3r2PinCwa14890Constants.m", "the DNIe 3.0 r2 PIN channel"),
    ("dnie3r2Usr", "Dnie3r2UsrCwa14890Constants.m", "the DNIe 3.0 r2 user channel"),
]

ARRAY_FIELDS = ["C_CV_CA", "CHR_C_CV_CA", "C_CV_IFD", "CHR_C_CV_IFD",
                "REF_C_CV_CA_PUBLIC_KEY", "REF_ICC_PRIVATE_KEY"]


def read(name):
    with open(os.path.join(JMULTICARD, name)) as handle:
        return handle.read()


def static_array(src, field):
    """A static byte-array constant, anchored on its full name."""
    pattern = (r"JreStrongAssignAndConsume\(&\w*?Constants_" + field +
               r", \[IOSByteArray newArrayWithBytes:\(jbyte\[\]\)\{(.*?)\} count:(\d+)\]")
    match = re.search(pattern, src, re.S)
    if not match:
        return None
    value = bytes(int(h, 16) for h in re.findall(r"0x([0-9A-Fa-f]{2})", match.group(1)))
    declared = int(match.group(2))
    if len(value) != declared:
        raise SystemExit(f"{field}: parsed {len(value)} bytes but source declares {declared}")
    return value


def key_field(src, field):
    """A BigInteger field inside the private-key class, anchored on assignment."""
    pattern = (r"JreStrongAssignAndConsume\(&self->" + field +
               r", new_JavaMathBigInteger_initWithInt_withByteArray_\(1, "
               r"\[IOSByteArray arrayWithBytes:\(jbyte\[\]\)\{(.*?)\} count:(\d+)\]")
    match = re.search(pattern, src, re.S)
    if not match:
        return None
    value = bytes(int(h, 16) for h in re.findall(r"0x([0-9A-Fa-f]{2})", match.group(1)))
    declared = int(match.group(2))
    if len(value) != declared:
        raise SystemExit(f"{field}: parsed {len(value)} bytes but source declares {declared}")
    return value


def collect(filename):
    src = read(filename)
    out = {f: static_array(src, f) for f in ARRAY_FIELDS}
    out["ifdModulus"] = key_field(src, "ifdModulus_")
    out["ifdPrivateExponent"] = key_field(src, "ifdPrivateExponent_")

    # Inherited constants: the r1/r2 subclasses redefine only C_CV_CA, and the
    # PIN/USR classes inherit the CA material from their parent.
    if out["C_CV_CA"] is None:
        for parent in ("Dnie3r2Cwa14890Constants.m", "DnieCwa14890Constants.m"):
            if parent.startswith(filename[:7]) or parent == "DnieCwa14890Constants.m":
                value = static_array(read(parent), "C_CV_CA")
                if value:
                    out["C_CV_CA"] = value
                    break
    for field in ARRAY_FIELDS:
        if out[field] is None:
            out[field] = static_array(read("DnieCwa14890Constants.m"), field)
    return out


def verify(name, values):
    n = int.from_bytes(values["ifdModulus"], "big")
    d = int.from_bytes(values["ifdPrivateExponent"], "big")
    probe = 0xDEADBEEF12345678
    if pow(pow(probe, d, n), PUBLIC_EXPONENT, n) != probe:
        raise SystemExit(f"{name}: the extracted key pair does not round-trip; extraction is wrong")
    if len(values["ifdModulus"]) != 128:
        raise SystemExit(f"{name}: modulus is {len(values['ifdModulus'])} bytes, expected 128")


def hex_literal(value, indent):
    text = value.hex()
    lines = [text[i:i + 64] for i in range(0, len(text), 64)]
    joined = ("\n" + " " * indent + '+ "').join(f'{line}"' for line in lines)
    return " " * 0 + '"' + joined


def main():
    print(HEADER)
    for name, filename, description in SETS:
        values = collect(filename)
        verify(name, values)
        print(f"  /// Constants for {description}.")
        print(f"  ///")
        print(f"  /// Extracted from `{filename}`.")
        print(f"  public static let {name} = Cwa14890Constants(")
        for swift, key in [("caCertificate", "C_CV_CA"), ("caCertificateReference", "CHR_C_CV_CA"),
                           ("terminalCertificate", "C_CV_IFD"),
                           ("terminalCertificateReference", "CHR_C_CV_IFD"),
                           ("caPublicKeyReference", "REF_C_CV_CA_PUBLIC_KEY"),
                           ("cardPrivateKeyReference", "REF_ICC_PRIVATE_KEY"),
                           ("terminalModulus", "ifdModulus"),
                           ("terminalPrivateExponent", "ifdPrivateExponent")]:
            print(f"    {swift}: " + hex_literal(values[key], 6) + ",")
        print("  )")
        print()
    print("}")


HEADER = '''// Generated by Tools/extract_cwa14890_constants.py — do not edit by hand.
//
// Regenerate with:
//     cd Tools && python3 extract_cwa14890_constants.py \\
//         > ../Sources/DnieProtocol/Cwa14890Constants.swift
//
// These are the Spanish DNIe terminal credentials that jmulticard publishes
// and that the working Android build in this repository already ships. They
// are not secrets in any useful sense — every DNIe client carries them — but
// they must be byte-exact, because nothing in the surrounding logic can tell
// a correct transcription from a corrupted one.
//
// The generator checks every array against the length the source declares, and
// checks each key pair functionally (m^d^e mod n == m). CwaConstantsTests
// repeats those checks here, so a bad regeneration fails the suite rather than
// failing silently against a card.

import Foundation

/// The terminal credentials for one CWA-14890 channel.
///
/// A DNIe presents different channels — the classic card, and the PIN and user
/// channels of DNIe 3.0 — and each is entered with its own terminal key pair
/// and certificate chain. Picking the wrong set fails authentication in a way
/// that looks like a broken card.
public struct Cwa14890Constants: Equatable, Sendable {
  /// The CA's card-verifiable certificate, sent with PSO VERIFY CERTIFICATE.
  public let caCertificate: [UInt8]
  /// The CA certificate's holder reference.
  public let caCertificateReference: [UInt8]
  /// The terminal's card-verifiable certificate.
  public let terminalCertificate: [UInt8]
  /// The terminal certificate's holder reference — `chrCCvIfd`, bound into the
  /// digest the card signs during internal authentication.
  public let terminalCertificateReference: [UInt8]
  /// File identifier of the CA public key on the card.
  public let caPublicKeyReference: [UInt8]
  /// Reference to the card's own private key.
  public let cardPrivateKeyReference: [UInt8]
  /// The terminal RSA modulus, big-endian.
  public let terminalModulus: [UInt8]
  /// The terminal RSA private exponent, big-endian.
  public let terminalPrivateExponent: [UInt8]

  /// The terminal's public exponent.
  ///
  /// Not stored beside the key in the Java: an `RSAPrivateKey` carries only
  /// modulus and private exponent, and the DER blob next to it leaves the CRT
  /// fields zero. 65537 is recovered by verifying that m^d^e mod n == m, which
  /// holds for 65537 and fails for the other common choices.
  public let terminalPublicExponent: [UInt8] = [0x01, 0x00, 0x01]

  init(caCertificate: String, caCertificateReference: String,
       terminalCertificate: String, terminalCertificateReference: String,
       caPublicKeyReference: String, cardPrivateKeyReference: String,
       terminalModulus: String, terminalPrivateExponent: String) {
    self.caCertificate = Cwa14890Constants.decode(caCertificate)
    self.caCertificateReference = Cwa14890Constants.decode(caCertificateReference)
    self.terminalCertificate = Cwa14890Constants.decode(terminalCertificate)
    self.terminalCertificateReference = Cwa14890Constants.decode(terminalCertificateReference)
    self.caPublicKeyReference = Cwa14890Constants.decode(caPublicKeyReference)
    self.cardPrivateKeyReference = Cwa14890Constants.decode(cardPrivateKeyReference)
    self.terminalModulus = Cwa14890Constants.decode(terminalModulus)
    self.terminalPrivateExponent = Cwa14890Constants.decode(terminalPrivateExponent)
  }

  /// Hex is used rather than byte arrays so these can be diffed directly
  /// against the Java sources they came from.
  static func decode(_ hex: String) -> [UInt8] {
    var out: [UInt8] = []
    out.reserveCapacity(hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      out.append(UInt8(hex[index..<next], radix: 16)!)
      index = next
    }
    return out
  }
'''

if __name__ == "__main__":
    main()
