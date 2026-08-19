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

  # ---------------------------------------------------------------------
  # DnieProtocol — the native Swift protocol layer replacing jmulticard.
  # ---------------------------------------------------------------------
  #
  # These sources are ALSO a standalone SwiftPM package (see DnieProtocol/),
  # which is how they are tested: `swift test` in that directory runs the whole
  # suite on macOS in under a second, with no simulator, no device and no card.
  # CocoaPods compiles the same files into this framework. Keep both working —
  # the package is the only place this code is currently exercised.
  #
  # Note what this does NOT depend on: nothing under jmulticard-objc, and no
  # j2objc runtime. It uses only CryptoKit, CommonCrypto and Security. So this
  # half of the pod links today, and is unaffected by the libjre_emul.a
  # blocker documented below. As DnieProtocol grows to cover what jmulticard
  # does, the transpiled tree shrinks and eventually goes away — at which point
  # the blocker becomes irrelevant rather than solved.
  dnie_protocol_sources = 'DnieProtocol/Sources/DnieProtocol/**/*.swift'

  s.source_files = [
    'felectronic_dnie_ios/Sources/**/*.{swift,m}',
    dnie_protocol_sources,
  ] + swift_facing_headers

  # The package's tests are for `swift test`, not for the framework build.
  s.exclude_files = 'DnieProtocol/Tests/**/*'

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
  # j2objc JRE runtime
  # ---------------------------------------------------------------------
  #
  # The 1,305 transpiled sources under jmulticard-objc/ are j2objc output, and
  # j2objc emits code against a runtime it does not generate: IOSClass_*,
  # IOSArray_*, and the whole emulated JRE (JavaMathBigInteger, JavaUtilHashtable,
  # JavaSecuritySecureRandom and ~195 more). Without it the pod compiles and
  # then fails to link.
  #
  # JRE.xcframework is that runtime, built from j2objc at tag 3.0.0. The version
  # is not a guess: diffing the vendored J2ObjC_common.h against upstream tags
  # gives 30 changed lines for 3.0.0 versus 52-75 for 2.6-3.1, and all 30 are
  # cosmetic (macro formatting, `(void)` vs `()`). Same macros, same symbols.
  #
  # It carries ios-arm64 and ios-arm64_x86_64-simulator only. Intel simulators are not
  # covered; add `simulator` to ENV_J2OBJC_ARCHS and rebuild if that is needed.
  #
  # To rebuild (see Tools/build_jre_emul.sh for the script):
  #   JDK 11 exactly. The translator crashes on 17 with a NullPointerException
  #   from javac internals it was not written against, and JAVA_HOME must be the
  #   real JDK home -- Homebrew's opt/openjdk@11 symlink lacks lib/jrt-fs.jar.
  #
  s.vendored_frameworks = 'Frameworks/JRE.xcframework'
  #
  # 'jre_emul' is listed here as well as coming from the xcframework. CocoaPods
  # adds -ljre_emul to this pod's own link flags, but does not propagate it to
  # the app target, which is where the transpiled code's symbols finally have to
  # resolve -- the pod builds static, so its undefined externals are the app's
  # problem. Listing it in s.libraries puts the flag in both, and both already
  # get the xcframework's directory on LIBRARY_SEARCH_PATHS. Without it the app
  # link fails with ~100 undefined JavaLang/JavaIo/JavaNet symbols while the
  # pod itself links cleanly.
  # iconv: the emulated JRE's charset conversion calls iconv_open/iconvctl.
  # z and icucore are j2objc's other documented system dependencies.
  s.libraries           = 'z', 'icucore', 'iconv'

  # The runtime is force-loaded rather than linked with -l.
  #
  # A static archive only yields the members needed at the point it appears on
  # the link line. CocoaPods sorts -l flags alphabetically, so -ljre_emul lands
  # before -framework felectronic_dnie_ios -- nothing references the runtime
  # yet, the linker keeps nothing, and the app fails with ~100 undefined
  # JavaLang/JavaIo/JavaNet symbols even though the archive is present, on the
  # search path, and demonstrably defines every one of them.
  #
  # The path is PODS_XCFRAMEWORKS_BUILD_DIR, which CocoaPods defines for the app
  # target as well as this pod, and which its own copy phase fills with the
  # slice matching the SDK being built. That avoids naming ios-arm64 versus
  # ios-arm64_x86_64-simulator here -- both are arm64 and cannot be lipo'd together,
  # which is what the xcframework exists to solve.
  #
  # Do not use PODS_TARGET_SRCROOT: it is pod-scoped, expands to nothing in the
  # app target, and the resulting force_load path silently fails to resolve.
  # Loaded from the source tree, NOT from PODS_XCFRAMEWORKS_BUILD_DIR.
  #
  # CocoaPods' [CP] Copy XCFrameworks phase populates that directory, but it
  # does not reliably run before the app links: a build immediately after
  # `pod install` fails with ~100 undefined symbols, and the slice appears in
  # the intermediates only afterwards. Pointing at the vendored xcframework
  # directly removes the ordering dependency entirely.
  #
  # PODS_ROOT is defined for the app target; PODS_TARGET_SRCROOT is not. The
  # slice is chosen by SDK because device and simulator are both arm64 and
  # cannot be merged with lipo.
  s.user_target_xcconfig = {
    # Same reason as the header paths: the umbrella pulls in transpiled
    # headers that are not themselves module members, and the app builds this
    # module when it imports the plugin. The pod already sets this for its own
    # compilation; the app needs it too or the module fails to build with
    # "Include of non-modular header inside framework module".
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    # The app compiles this framework's module when it imports the plugin, and
    # the umbrella exposes CustomApduConnection.h, which #includes headers from
    # the transpiled tree by their source-relative path. Those headers are
    # deliberately not copied into the framework (see the note at the top), so
    # the app needs the same roots the pod uses -- expressed with PODS_ROOT,
    # because PODS_TARGET_SRCROOT is pod-scoped and expands to nothing here.
    #
    # Without these the link now succeeds and the build then fails with
    # "'es/gob/jmulticard/connection/AbstractApduConnectionIso7816.h' file not
    # found" followed by "Could not build module 'felectronic_dnie_ios'".
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios"',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/j2objc"',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc"',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/jmulticard-objc/afirma"',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/DNIe"',
      '"$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/XMLKit"',
    ].join(' '),
    'OTHER_LDFLAGS[sdk=iphoneos*]' =>
      '$(inherited) -force_load "$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/Frameworks/JRE.xcframework/ios-arm64/libjre_emul.a"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' =>
      '$(inherited) -force_load "$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/Frameworks/JRE.xcframework/ios-arm64_x86_64-simulator/libjre_emul.a"',
  }

s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  s.pod_target_xcconfig = {
    # The pod links before the app and needs the runtime too: with
    # use_frameworks! this pod is its own framework, and the undefined
    # symbols reported against Pods.xcodeproj are its link, not Runner's.
    # -ljre_emul from the vendored xcframework resolves through
    # PODS_XCFRAMEWORKS_BUILD_DIR, which the copy phase has not
    # necessarily filled yet; force-loading from the source tree removes
    # that ordering dependency.
    'OTHER_LDFLAGS[sdk=iphoneos*]' =>
      '$(inherited) -force_load "$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/Frameworks/JRE.xcframework/ios-arm64/libjre_emul.a"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' =>
      '$(inherited) -force_load "$(PODS_ROOT)/../.symlinks/plugins/felectronic_dnie_ios/ios/Frameworks/JRE.xcframework/ios-arm64_x86_64-simulator/libjre_emul.a"',
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
