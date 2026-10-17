# felectronic_dnie_ios

[![pub package](https://img.shields.io/pub/v/felectronic_dnie_ios.svg)](https://pub.dev/packages/felectronic_dnie_ios)

The iOS implementation of [`felectronic_dnie`](https://github.com/Crdzbird/spanishgov_toolkits/tree/master/felectronic_dnie).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin) and
will be automatically included when you depend on `felectronic_dnie`.

## The j2objc runtime

The pod links against the j2objc runtime, `JRE.xcframework`. At about 270 MB
it is far too large for pub.dev, so it is published as an asset of the GitHub
release
[`j2objc-jre-3.0.0`](https://github.com/Crdzbird/spanishgov_toolkits/releases/tag/j2objc-jre-3.0.0)
and the podspec downloads it the first time `pod install` reads it, into
`ios/Frameworks/`. Later installs reuse it.

The archive is checked against a SHA-256 pinned in the podspec before anything
is extracted, and a mismatch stops `pod install` rather than linking an
unverified binary into your app. The first `pod install` therefore needs
network access; to use a mirror, set `FELECTRONIC_JRE_URL` to a copy of the
same archive.

j2objc is Apache 2.0; its licence is extracted next to the framework as
`J2OBJC_LICENSE`.

### Publishing a new runtime (maintainers)

1. `Tools/build_jre_emul.sh` builds `ios/Frameworks/JRE.xcframework`.
2. `Tools/package_jre.sh` zips it with the licence and prints its SHA-256.
3. Upload the zip to a release tagged `j2objc-jre-<version>`, then update
   `jre_version` and `jre_sha256` in the podspec.

### Why it is needed

The card protocol comes from jmulticard, a Java library, transpiled to
Objective-C with [j2objc](https://github.com/google/j2objc). The 1,305
transpiled sources under `jmulticard-objc/` reference a runtime that j2objc
does **not** generate: `IOSClass_*`, `IOSArray_*`, and an emulated JRE
(`JavaMathBigInteger`, `JavaUtilHashtable`, `JavaSecuritySecureRandom`, and
about 195 more types). Without it the pod compiles and then fails to link with
roughly 460 undefined symbols.

Google no longer publishes prebuilt distributions: the only GitHub release is
3.1 with zero assets, and there is no Homebrew formula. So it has to be built
from source.

### Which version, and how it was determined

**j2objc 3.0.0.** Not a guess: diffing the vendored `J2ObjC_common.h` against
upstream tags gives 30 changed lines for 3.0.0 versus 52–75 for 2.6–3.1, and
all 30 are cosmetic (macro formatting, `(void)` versus `()`). Same macros, same
symbols.

### Things the script exists to get right

Each of these cost real time to find, and each is a comment in the script:

* **JDK 11 exactly.** On 17 the translator dies with a `NullPointerException`
  from javac internals it was never written against.
* **`JAVA_HOME` must be the real JDK home.** Homebrew's
  `opt/openjdk@11` symlink has no `lib/jrt-fs.jar`. Do not rely on
  `/usr/libexec/java_home -v 11` either: on a machine with a newer JDK it
  answers with that one.
* **The module image needs `jrt-fs.jar` copied in by hand.** The Makefile rule
  intends to and does not; `javac` then rejects the image with
  `illegal argument for --system`. The script runs the build, repairs the
  image, and runs it again.
* **`-Werror` is removed.** j2objc 3.0.0 is from 2023 and Xcode 26's clang
  raises warnings that did not exist then.
* **All three architectures are required:** `iphone64_simulator_simulator64`.
  j2objc's names are counter-intuitive: `simulator` is **x86_64** and
  `simulator64` is **arm64**. Omitting `simulator` yields an arm64-only
  simulator slice, and a wrong-architecture static archive is *silently
  ignored* by the linker: no error, no warning, just undefined symbols that
  look exactly like a missing library.

### If a slice name changes

The podspec hardcodes the slice paths for `-force_load` in four places. The
simulator slice is named after the architectures it holds
(`ios-arm64_x86_64-simulator` when fat). The script prints the slices it
produced.
