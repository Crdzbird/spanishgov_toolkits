#!/usr/bin/env bash
#
# Regenerates the DER fixtures embedded in `certificate_fixtures.dart`.
#
# The fixtures are real X.509 certificates, not hand-written byte arrays, so
# the derivation path in `MethodChannelFelectronicCertificates._toCertificate`
# is exercised against encodings a real CA actually emits.
#
# Validity windows are pinned (not relative to "now") so assertions stay
# deterministic and the suite does not start failing on a future date.
#
# Usage:  ./generate_fixtures.sh [output_dir]
#
# Requires OpenSSL 3.x for the `-not_before` / `-not_after` flags.
set -euo pipefail

OUT="${1:-$(mktemp -d)}"
cd "$OUT"

echo "Generating into $OUT"

# Issuer for every leaf, so subject CN and issuer CN are always distinguishable.
openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.pem -days 3650 -nodes \
  -subj "/C=ES/O=FNMT-RCM/OU=AC FNMT Usuarios/CN=AC FNMT Usuarios" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

gen() {
  local name="$1" subj="$2" ku="$3" nb="$4" na="$5"
  openssl req -newkey rsa:2048 -keyout "$name.key" -out "$name.csr" -nodes \
    -subj "$subj" 2>/dev/null
  if [ -n "$ku" ]; then
    printf "keyUsage=critical,%s\n" "$ku" > "$name.ext"
  else
    : > "$name.ext"   # deliberately no keyUsage extension
  fi
  openssl x509 -req -in "$name.csr" -CA ca.pem -CAkey ca.key -CAcreateserial \
    -out "$name.pem" -extfile "$name.ext" \
    -not_before "$nb" -not_after "$na" 2>/dev/null
  openssl x509 -in "$name.pem" -outform DER -out "$name.der"
  printf "  %-10s %s\n" "$name" \
    "$(openssl x509 -in "$name.pem" -noout -ext keyUsage 2>/dev/null \
       | tail -1 | sed 's/^ *//')"
}

# CN contains a comma — a DN-parsing stress case.
gen signing   "/C=ES/CN=GARCIA GARCIA, JUAN - 12345678Z/serialNumber=IDCES-12345678Z" \
              "nonRepudiation"                   20260101000000Z 20280101000000Z
gen auth      "/C=ES/CN=AUTENTICACION - GARCIA GARCIA, JUAN" \
              "digitalSignature"                 20260101000000Z 20280101000000Z
gen enc       "/C=ES/CN=CIFRADO - GARCIA GARCIA, JUAN" \
              "keyEncipherment,dataEncipherment" 20260101000000Z 20280101000000Z
# No keyUsage extension at all — must NOT be assumed signing-capable.
gen nousage   "/C=ES/CN=SIN USO DEFINIDO" \
              ""                                 20260101000000Z 20280101000000Z
gen expired   "/C=ES/CN=CADUCADO - GARCIA GARCIA, JUAN" \
              "nonRepudiation,digitalSignature"  20200101000000Z 20210101000000Z
# notAfter >= 2050 must be encoded as GeneralizedTime while notBefore stays
# UTCTime (RFC 5280 4.1.2.5) — a mixed-encoding certificate.
gen farfuture "/C=ES/CN=GENERALIZED TIME - GARCIA" \
              "nonRepudiation"                   20260101000000Z 20600101000000Z

echo
echo "Base64 DER for certificate_fixtures.dart:"
for f in signing auth enc nousage expired farfuture; do
  echo "--- $f ---"
  base64 < "$f.der" | tr -d '\n' | fold -w 68
  echo
done
