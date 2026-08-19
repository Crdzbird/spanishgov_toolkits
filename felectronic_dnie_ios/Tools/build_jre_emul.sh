#!/usr/bin/env bash
# Rebuild JRE.xcframework, the j2objc runtime this pod links against.
#
# The transpiled sources under jmulticard-objc/ are j2objc output, and j2objc
# emits code against a runtime it does not generate. Google stopped publishing
# prebuilt distributions -- their only GitHub release is 3.1 with zero assets,
# and there is no Homebrew formula -- so it has to be built.
#
# Every step below exists because of a failure. Read the comments before
# "simplifying" any of them.
set -euo pipefail

VERSION=3.0.0          # Not a guess: diffing the vendored J2ObjC_common.h
                       # against upstream tags gives 30 changed lines for
                       # 3.0.0 vs 52-75 for 2.6-3.1, and all 30 are cosmetic.
# Underscores are separators; the Makefile substitutes them for spaces.
#
# All three are REQUIRED. j2objc's names are counter-intuitive: `simulator` is
# x86_64 and `simulator64` is arm64. Omitting `simulator` produces an
# arm64-only simulator slice, and Xcode still links the simulator for x86_64 --
# a wrong-architecture static archive is silently ignored by the linker, with
# no error and no warning, so the build fails with ~100 undefined symbols that
# look exactly like a missing library. That cost several hours to find.
ARCHS="iphone64_simulator_simulator64"

# JDK 11 EXACTLY. On 17 the translator dies with a NullPointerException from
# javac internals it was never written against. And this must be the real JDK
# home: Homebrew's /opt/homebrew/opt/openjdk@11 symlink has no lib/jrt-fs.jar,
# which fails the module-image step in a way that only surfaces much later.
#
# Do not rely on /usr/libexec/java_home -- on a machine with a newer JDK
# installed it answers with that one even when asked for -v 11.
export JAVA_HOME=/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:/opt/homebrew/bin:$PATH"
export ENV_J2OBJC_ARCHS="$ARCHS"

[ -x "$JAVA_HOME/bin/javac" ] || { echo "JDK 11 not at $JAVA_HOME (brew install openjdk@11)"; exit 1; }
command -v mvn >/dev/null || { echo "maven required (brew install maven)"; exit 1; }

WORK="${1:-$(mktemp -d)}"
git clone --depth 1 --branch "$VERSION" --recurse-submodules --shallow-submodules \
  https://github.com/google/j2objc.git "$WORK/j2objc"
cd "$WORK/j2objc"

# j2objc 3.0.0 is from 2023 and builds -Werror. Xcode 26's clang raises
# warnings that did not exist then -- e.g. Hashtable's MAX_ARRAY_SIZE + 1 is an
# implicit int->float conversion that cannot be represented exactly. These are
# compiler pedantry against Google's own sources, and this is a dependency
# build, not j2objc development.
python3 - <<'PY'
p = "make/common.mk"
s = open(p).read()
s = s.replace("CC_WARNINGS = -Wall -Werror -Wshorten-64-to-32",
              "CC_WARNINGS = -Wall -Wshorten-64-to-32")
open(p, "w").write(s)
PY

make translator_dist

# The module-image rule ends with `cp $(JAVA_HOME)/lib/jrt-fs.jar
# $(EMULATION_MODULE)/lib/`, and that file does not end up there. javac accepts
# a --system image only if it holds lib/jrt-fs.jar or a root-level `modules`;
# the generated image has lib/modules, which is neither, so translation fails
# with "illegal argument for --system". Run once, repair, run again -- the rule
# will not re-run once the directory exists and is newer than the jar.
make jre_emul_dist || true
M=dist/lib/jre_emul_module
if [ -d "$M/lib" ] && [ ! -f "$M/lib/jrt-fs.jar" ]; then
  cp "$JAVA_HOME/lib/jrt-fs.jar" "$M/lib/"
fi
make jre_emul_dist

DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ios" && pwd)/Frameworks"
mkdir -p "$DEST"
rm -rf "$DEST/JRE.xcframework"
cp -R dist/frameworks/JRE.xcframework "$DEST/"
echo "Installed $DEST/JRE.xcframework"
for f in "$DEST"/JRE.xcframework/*/libjre_emul.a; do
  echo "  $(basename "$(dirname "$f")"): $(lipo -archs "$f")"
done
echo
echo "If a slice directory name changed, update the hardcoded force_load paths"
echo "in felectronic_dnie_ios.podspec -- the simulator slice is named after the"
echo "architectures it holds (ios-arm64_x86_64-simulator when fat)."
