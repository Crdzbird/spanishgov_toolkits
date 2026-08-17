Pod::Spec.new do |s|
  s.name             = 'felectronic_dnie_ios'
  s.version          = '1.0.0'
  s.summary          = 'iOS implementation of the felectronic_dnie plugin.'
  s.description      = <<-DESC
iOS implementation for reading and signing with Spanish electronic DNIe
(Documento Nacional de Identidad electrónico) via NFC.
                       DESC
  s.homepage         = 'https://github.com/Crdzbird/spanishgov_toolkits'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'crdzbird' => 'luisalfonsocb83@gmail.com' }
  s.source           = { :path => '.' }

  # Only compiled units are listed. The 2,882 headers in the j2objc/jmulticard
  # tree are deliberately NOT in `source_files`.
  #
  # Background: the Podfile uses `use_frameworks!`, so every header in
  # `source_files` is copied into the framework bundle. Copying them flat made
  # 82 basenames collide across directories (java/security/cert/
  # X509Certificate.h vs javax/security/cert/X509Certificate.h, five different
  # Utils.h, ...) and the build failed with "Multiple commands produce
  # .../Headers/<name>.h". Setting `header_mappings_dir` fixed the collision by
  # preserving the directory structure, but it also turned the copy into ~2,882
  # individually-tracked build tasks, and the build then deadlocked inside
  # llbuild's scheduler: the build engine parked on a condition variable while
  # all 14 execution lanes sat idle.
  #
  # Not copying them at all avoids both problems. These headers are internal
  # implementation detail of the transpiled Java code — nothing outside this
  # pod imports them, and the framework's public surface is the Swift API plus
  # its generated `-Swift.h`. The compiler still finds them through
  # HEADER_SEARCH_PATHS below, which point into the source tree.
  # Transitive closure of every Objective-C type Swift touches: the types in
  # the called signatures, plus their complete superclass chains and protocol
  # conformances up to NSObject. Swift silently DROPS any method whose
  # parameter or return type it cannot fully model, which surfaces as
  # "has no member ..." at the call site rather than a missing-type error --
  # so a gap anywhere in this closure looks like a nonexistent method.
  #
  # Computed mechanically from @interface/@protocol declarations, not by
  # hand. 49 headers, against the 1,176 that DNIeManagerImports.h pulled in.
  swift_facing_headers = [
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/DNIe/DNIeExceptionCatcher.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/XMLKit/XMLKit.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/lang/Byte.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/IOSArray.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/IOSPrimitiveArray.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/JavaObject.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/NSCopying+JavaCloneable.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/io/IOException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/io/Serializable.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/lang/Comparable.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/lang/Enum.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/lang/Exception.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/lang/Throwable.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/Key.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/PublicKey.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/cert/Certificate.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/cert/X509Certificate.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/cert/X509Extension.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/interfaces/RSAKey.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/java/security/interfaces/RSAPublicKey.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/javax/security/auth/callback/Callback.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/javax/security/auth/callback/CallbackHandler.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc/javax/security/auth/callback/PasswordCallback.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/CustomApduConnection.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/DNIeSwiftBridge.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/CustomDnieCallbackHandler.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/afirma/es/gob/afirma/core/misc/Base64.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/CryptoHelper.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/AbstractSmartCard.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/AuthenticationModeLockedException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/BadPinException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/Card.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/CardException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/CryptoCard.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/InvalidCardException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/PinException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/PrivateKeyReference.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/cwa14890/Cwa14890Card.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/BurnedDnieCardException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/Dni.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/Dnie.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/Dnie3.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/DnieFactory.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/dnie/DnieNfc.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/icao/IcaoException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/icao/InvalidCanOrMrzException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/icao/MrtdLds1.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/iso7816eight/AbstractIso7816EightCard.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/iso7816four/AbstractIso7816FourCard.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/card/iso7816four/Iso7816FourCardException.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/connection/AbstractApduConnectionIso7816.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/connection/ApduConnection.h',
    'felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/es/gob/jmulticard/crypto/BcCryptoHelper.h',
  ]

  s.source_files = ['felectronic_dnie_ios/Sources/**/*.{swift,m}'] + swift_facing_headers

  # Only these reach the framework's umbrella header. The remaining ~2,870
  # headers stay out of every build phase and resolve through
  # HEADER_SEARCH_PATHS below.
  s.public_header_files = swift_facing_headers

  # Keep the rest available on disk for the search paths, without adding them
  # to any build phase.
  s.preserve_paths   = 'felectronic_dnie_ios/Sources/**/*.h'

  # The whole Objective-C surface of this pod is non-ARC:
  #   * the 1,305 j2objc-transpiled files use manual retain/release and
  #     explicitly guard against ARC ("must not be compiled with -fobjc-arc"),
  #   * and the hand-written bridges (CustomApduConnection,
  #     CustomDnieCallbackHandler) call `[super dealloc]`, which ARC forbids.
  #
  # This flag was never set because the pod had never compiled far enough to
  # reach Objective-C compilation.
  s.compiler_flags = '-fno-objc-arc'

  # ---------------------------------------------------------------------
  # j2objc JRE runtime — REQUIRED for this pod to link. Currently missing.
  # ---------------------------------------------------------------------
  #
  # Every source file in this pod compiles (1,769 of them), but linking fails
  # with ~460 undefined symbols: IOSClass_*, IOSArray_*, JavaLang*, JavaUtil*,
  # JavaIo*, JavaMath*, JavaNet*.
  #
  # Those are j2objc's JRE emulation. This repository ships the transpiled
  # APPLICATION code (1,305 .m files under jmulticard-objc/) and 1,040 JRE
  # HEADERS under j2objc/ — but no JRE implementations, because j2objc ships
  # them as a prebuilt static library instead. Android does the equivalent
  # correctly: felectronic_dnie_android/android/libs/jmulticard-3.0.0.jar is
  # vendored, which is why Android links and builds.
  #
  # To finish: drop libjre_emul.a into felectronic_dnie_ios/Libraries/ and
  # uncomment the two lines below.
  #
  #   s.vendored_libraries = 'felectronic_dnie_ios/Libraries/libjre_emul.a'
  #   s.libraries          = 'z', 'icucore'
  #
  # Sourcing it:
  #   * Prefer the exact build that produced this tree — the upstream
  #     DNIe/Portafirmas iOS project. The generated code is ABI-coupled to the
  #     j2objc version that emitted it, and these headers carry no version
  #     marker (jmulticard-3.0.0 is the Java library's version, not j2objc's).
  #     A mismatched runtime can fail to link, or link and misbehave at run
  #     time inside signing code.
  #   * Google no longer publishes prebuilt archives: the release assets for
  #     tags 3.1 / 3.0.0 / 2.8 / 2.7 / 2.6 are gone (404). Building j2objc from
  #     source is possible but yields an unverified version match.
  #
  # The library must include the simulator slice (or be an .xcframework) for
  # simulator builds; use s.vendored_frameworks instead of s.vendored_libraries
  # if it arrives as an .xcframework.
  #
  # Once linking succeeds, restore the ios end-to-end job removed from
  # .github/workflows/felectronic_dnie.yaml.

  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # No SWIFT_OBJC_BRIDGING_HEADER: bridging headers are unsupported in
    # framework targets. Swift sees the Objective-C API through the module's
    # umbrella header instead (see `public_header_files` above), which is the
    # supported mechanism for a mixed-language framework.
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',

    # Explicit Swift modules (default since Xcode 16) deadlock on this target.
    # A `sample` of a hung build shows the build service parked in:
    #
    #   swift::ModuleDependencyScanner::resolveAllClangModuleDependencies
    #     -> resolveImportedModuleDependencies
    #       -> performDependencyScan  ->  std::condition_variable::wait
    #
    # at 0% CPU, with no swift-frontend ever spawned and zero objects
    # produced. The scanner has to resolve the Clang module graph reachable
    # from this target's umbrella, which transitively pulls ~2,870 transpiled
    # j2objc headers spread over 266 directories, found through the recursive
    # HEADER_SEARCH_PATHS below. Disabling explicit modules skips that
    # scanning phase and uses implicit module builds instead.
    #
    # Scoped to this pod only; every other target keeps the default.
    'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) J2OBJC=1',
    # Include roots only — NEVER recursive (`/**`).
    #
    # The transpiled sources include path-style against these roots
    # (`#include "java/lang/Boolean.h"`, `#include "es/gob/jmulticard/..."`).
    #
    # A recursive search path is actively dangerous here. It puts
    # `j2objc/java/lang/` on the include path, and that directory contains
    # Math.h, Time.h, Error.h, Character.h, System.h and Thread.h. macOS has a
    # case-insensitive filesystem, so the SDK's own `#include <math.h>` (from
    # tgmath.h) resolved to Java's Math.h and every system module —
    # Darwin, CoreFoundation, Foundation, UIKit — failed to build.
    #
    # Rooted non-recursively there is no shadowing: Java's Math.h is only
    # reachable as "java/lang/Math.h", never as "math.h".
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios"',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc"',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc"',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/afirma"',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/DNIe"',
      '"$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/XMLKit"',
    ].join(' '),
  }
  s.swift_version    = '5.0'
end
