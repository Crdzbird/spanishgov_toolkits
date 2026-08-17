// swift-tools-version: 5.9
import PackageDescription

/// Stage 1 of replacing the j2objc-transpiled jmulticard library with Swift.
///
/// This target is deliberately platform-agnostic and dependency-free: it is
/// pure data transformation (APDU encoding, BER-TLV decoding), so it builds
/// and tests on macOS in seconds without a simulator, a device, or a card.
///
/// The behaviour is ported from the transpiled Java in
/// `felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/`, and
/// the tests assert the exact byte layouts that implementation produces —
/// the Android build of that same library is known to work against real
/// cards, so matching it byte-for-byte is the correctness criterion.
let package = Package(
  name: "DnieProtocol",
  platforms: [.iOS(.v15), .macOS(.v12)],
  products: [
    .library(name: "DnieProtocol", targets: ["DnieProtocol"]),
  ],
  targets: [
    .target(name: "DnieProtocol"),
    .testTarget(name: "DnieProtocolTests", dependencies: ["DnieProtocol"]),
  ]
)
