#!/usr/bin/env bash
# Packages ios/Frameworks/JRE.xcframework as the GitHub release asset that the
# podspec downloads, and prints the SHA-256 the podspec must pin.
#
#     Tools/package_jre.sh [output directory]
#
# Upload the zip to the release tagged j2objc-jre-<VERSION>. j2objc is Apache
# 2.0, so its licence travels inside the archive.
set -euo pipefail

VERSION=3.0.0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAMEWORK="$HERE/ios/Frameworks/JRE.xcframework"
OUT_DIR="$(mkdir -p "${1:-$HERE/build}" && cd "${1:-$HERE/build}" && pwd)"
OUT="$OUT_DIR/JRE.xcframework-$VERSION.zip"

[ -f "$FRAMEWORK/Info.plist" ] || { echo "No runtime at $FRAMEWORK: run Tools/build_jre_emul.sh first"; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$FRAMEWORK" "$STAGE/"
curl -fsSL "https://raw.githubusercontent.com/google/j2objc/$VERSION/LICENSE" -o "$STAGE/J2OBJC_LICENSE"

rm -f "$OUT"
(cd "$STAGE" && zip -qry -9 -X "$OUT" JRE.xcframework J2OBJC_LICENSE)
echo "$OUT"
shasum -a 256 "$OUT" | cut -d' ' -f1
