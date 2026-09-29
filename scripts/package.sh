#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/build-app.sh
VERSION="${VLAD_VERSION:-1.0.0}"
NAME="Proiectul-de-fizica-al-lui-Vlad-${VERSION}-macOS-arm64"
APP="$ROOT/dist/Proiectul de fizica al lui Vlad.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$NAME.zip"
STAGE="$(mktemp -d "$ROOT/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Proiectul de fizica al lui Vlad.app"
ln -s /Applications "$STAGE/Applications"
cp docs/INSTALARE.html "$STAGE/Citeste-ma.html"
hdiutil create -volname "Fizica lui Vlad" -srcfolder "$STAGE" -ov -format UDZO "$ROOT/dist/$NAME.dmg"
shasum -a 256 "$ROOT/dist/$NAME.zip" "$ROOT/dist/$NAME.dmg" | sed "s|$ROOT/dist/||" > "$ROOT/dist/SHA256SUMS.txt"
printf 'Pachete pregătite în %s/dist\n' "$ROOT"
