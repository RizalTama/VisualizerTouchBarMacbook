#!/bin/bash
# Membuat & mempercayai sertifikat code-signing self-signed LOKAL bernama
# "VisualizerTouchBar Dev" di login keychain, supaya `codesign` tidak perlu
# pakai ad-hoc ("-") lagi.
#
# KENAPA INI PERLU — lihat README.md bagian "Code signing & izin privacy":
# ad-hoc signing (`codesign --sign -`) menghasilkan CDHash (hash biner) baru
# di SETIAP build, dan di macOS 26 ini izin Screen Recording (ScreenCaptureKit)
# terikat ketat ke CDHash — jadi tiap rebuild, izin yang sudah di-grant balik
# ke "declined" lagi. Sertifikat self-signed TIDAK sepenuhnya menghilangkan
# masalah itu (CDHash tetap berubah tiap build apa pun metode signing-nya),
# TAPI tetap dipakai supaya identitas app konsisten untuk hal lain (Microphone
# biasanya lebih toleran, dan ini praktik standar buat app non-notarized).
#
# Jalankan skrip ini SEKALI SAJA (kalau sertifikat sudah ada di keychain,
# cukup pakai `codesign --sign "VisualizerTouchBar Dev"` seperti biasa).
# Perlu dijalankan ulang kalau: ganti mesin, keychain di-reset, atau
# sertifikatnya kehapus/kadaluarsa.
set -euo pipefail

NAMA_SERTIFIKAT="VisualizerTouchBar Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
DIR_SEMENTARA="$(mktemp -d)"
trap 'rm -rf "$DIR_SEMENTARA"' EXIT

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$NAMA_SERTIFIKAT"; then
  echo "Sertifikat '$NAMA_SERTIFIKAT' sudah ada di keychain, tidak perlu dibuat ulang."
  exit 0
fi

echo "==> Membuat key pair + sertifikat self-signed..."
cat > "$DIR_SEMENTARA/codesign.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_req
prompt = no

[dn]
CN = $NAMA_SERTIFIKAT

[v3_req]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 \
  -keyout "$DIR_SEMENTARA/key.pem" -out "$DIR_SEMENTARA/cert.pem" \
  -days 3650 -nodes -config "$DIR_SEMENTARA/codesign.cnf"

echo "==> Export ke PKCS12 (pakai -legacy, format baru OpenSSL 3.x tidak dikenali 'security')..."
PASSWORD_SEMENTARA="$(openssl rand -hex 16)"
openssl pkcs12 -export -legacy \
  -out "$DIR_SEMENTARA/cert.p12" \
  -inkey "$DIR_SEMENTARA/key.pem" -in "$DIR_SEMENTARA/cert.pem" \
  -passout "pass:$PASSWORD_SEMENTARA"

echo "==> Import ke login keychain..."
security import "$DIR_SEMENTARA/cert.p12" -k "$KEYCHAIN" \
  -P "$PASSWORD_SEMENTARA" -T /usr/bin/codesign -T /usr/bin/security

echo "==> Percayakan sertifikat untuk code signing..."
security add-trusted-cert -d -r trustRoot -p codeSign -k "$KEYCHAIN" "$DIR_SEMENTARA/cert.pem"

echo "==> Selesai. Verifikasi:"
security find-identity -v -p codesigning | grep "$NAMA_SERTIFIKAT"
