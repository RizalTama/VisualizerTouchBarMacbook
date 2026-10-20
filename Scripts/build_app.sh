#!/bin/bash
# Bungkus binary hasil `swift build -c release` jadi bundel .app siap pakai.
set -euo pipefail

NAMA_APP="Visualizer Touch Bar"
EXECUTABLE_NAME="VisualizerTouchBar"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/$NAMA_APP.app"

echo "==> Membangun binary (release)..."
swift build -c release --package-path "$ROOT_DIR"

echo "==> Membungkus jadi $NAMA_APP.app..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "==> Menandatangani..."
IDENTITAS_SIGN="VisualizerTouchBar Dev"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITAS_SIGN"; then
  echo "    PERINGATAN: sertifikat '$IDENTITAS_SIGN' tidak ditemukan di keychain."
  echo "    Fallback ke ad-hoc sign (-) — izin Microphone/Screen Recording akan"
  echo "    ke-reset setiap kali rebuild kalau pakai ad-hoc. Lihat README.md"
  echo "    bagian 'Code signing & izin privacy' untuk cara membuat ulang"
  echo "    sertifikat lokal yang stabil."
  IDENTITAS_SIGN="-"
fi
codesign --force --deep --sign "$IDENTITAS_SIGN" "$APP_DIR"

echo "==> Selesai: $APP_DIR"
echo "    Install: cp -R \"$APP_DIR\" /Applications/"
