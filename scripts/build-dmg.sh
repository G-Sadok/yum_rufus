#!/usr/bin/env bash
#
# build-dmg.sh
# Compile, archive, exporte, signe, notarise et empaquete l application en DMG.
#
# Usage :
#   ./scripts/build-dmg.sh                    version deduite du projet
#   ./scripts/build-dmg.sh 1.2.0              version imposee
#   SANS_NOTARISATION=1 ./scripts/build-dmg.sh   ignore la notarisation
#
# Variables d environnement attendues pour la signature complete :
#   IDENTITE_SIGNATURE    par exemple "Developer ID Application: Nom (TEAMID)"
#   EQUIPE_APPLE          identifiant d equipe Apple
#   PROFIL_NOTARISATION   nom du profil stocke dans le trousseau
#
# Pour creer le profil de notarisation une fois pour toutes :
#   xcrun notarytool store-credentials "yum-notarisation" \
#     --apple-id "adresse@exemple.fr" \
#     --team-id "TEAMID" \
#     --password "mot-de-passe-application"

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

SCHEMA="${SCHEMA_XCODE:-Yum}"
NOM_APP="${NOM_APP:-Yum}"
VERSION="${1:-}"
SORTIE="$RACINE/build"
ARCHIVE="$SORTIE/$NOM_APP.xcarchive"
EXPORT="$SORTIE/export"
STAGING="$SORTIE/staging"

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
etape() { printf '\n\033[36m>> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
etape "Preparation"
# ---------------------------------------------------------------------------
command -v xcodebuild >/dev/null 2>&1 || { rouge "xcodebuild est requis, installe Xcode."; exit 1; }

rm -rf "$SORTIE"
mkdir -p "$SORTIE" "$STAGING"

if [ -z "$VERSION" ]; then
  VERSION="$(xcodebuild -scheme "$SCHEMA" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}' | tr -d ' ')"
  VERSION="${VERSION:-0.0.0}"
fi
vert "Version : $VERSION"

DMG="$SORTIE/$NOM_APP-$VERSION.dmg"

# ---------------------------------------------------------------------------
etape "Archivage"
# ---------------------------------------------------------------------------
xcodebuild archive \
  -scheme "$SCHEMA" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  -quiet
vert "Archive produite"

# ---------------------------------------------------------------------------
etape "Export"
# ---------------------------------------------------------------------------
PLIST_EXPORT="$SORTIE/ExportOptions.plist"

if [ -n "${IDENTITE_SIGNATURE:-}" ]; then
  METHODE="developer-id"
else
  jaune "IDENTITE_SIGNATURE absente, export non signe. Le DMG declenchera Gatekeeper."
  METHODE="mac-application"
fi

cat > "$PLIST_EXPORT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>$METHODE</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${EQUIPE_APPLE:-}</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$PLIST_EXPORT" \
  -quiet
vert "Application exportee"

APP="$EXPORT/$NOM_APP.app"
[ -d "$APP" ] || { rouge "Application introuvable a $APP"; exit 1; }

# ---------------------------------------------------------------------------
etape "Verification de la signature"
# ---------------------------------------------------------------------------
if [ -n "${IDENTITE_SIGNATURE:-}" ]; then
  codesign --verify --deep --strict --verbose=2 "$APP"
  vert "Signature valide"
else
  jaune "Verification ignoree, application non signee"
fi

# ---------------------------------------------------------------------------
etape "Notarisation"
# ---------------------------------------------------------------------------
if [ "${SANS_NOTARISATION:-0}" = "1" ] || [ -z "${PROFIL_NOTARISATION:-}" ]; then
  jaune "Notarisation ignoree"
else
  ZIP_NOTAIRE="$SORTIE/$NOM_APP-notarisation.zip"
  ditto -c -k --keepParent "$APP" "$ZIP_NOTAIRE"

  xcrun notarytool submit "$ZIP_NOTAIRE" \
    --keychain-profile "$PROFIL_NOTARISATION" \
    --wait

  xcrun stapler staple "$APP"
  rm -f "$ZIP_NOTAIRE"
  vert "Application notarisee et agrafee"
fi

# ---------------------------------------------------------------------------
etape "Construction du DMG"
# ---------------------------------------------------------------------------
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

if [ -f "$RACINE/Ressources/fond-dmg.png" ]; then
  mkdir -p "$STAGING/.fond"
  cp "$RACINE/Ressources/fond-dmg.png" "$STAGING/.fond/fond.png"
fi

hdiutil create \
  -volname "$NOM_APP" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG"

vert "DMG cree : $DMG"

# ---------------------------------------------------------------------------
etape "Signature et notarisation du DMG"
# ---------------------------------------------------------------------------
if [ -n "${IDENTITE_SIGNATURE:-}" ]; then
  codesign --sign "$IDENTITE_SIGNATURE" --timestamp "$DMG"
  vert "DMG signe"

  if [ "${SANS_NOTARISATION:-0}" != "1" ] && [ -n "${PROFIL_NOTARISATION:-}" ]; then
    xcrun notarytool submit "$DMG" \
      --keychain-profile "$PROFIL_NOTARISATION" \
      --wait
    xcrun stapler staple "$DMG"
    vert "DMG notarise et agrafe"
  fi
fi

# ---------------------------------------------------------------------------
etape "Somme de controle"
# ---------------------------------------------------------------------------
shasum -a 256 "$DMG" | awk '{print $1"  "'"$(basename "$DMG")"'}' > "$DMG.sha256"
vert "Somme SHA 256 ecrite dans $DMG.sha256"

# ---------------------------------------------------------------------------
etape "Verification finale"
# ---------------------------------------------------------------------------
if [ -n "${IDENTITE_SIGNATURE:-}" ] && [ "${SANS_NOTARISATION:-0}" != "1" ]; then
  if spctl --assess --type open --context context:primary-signature -v "$DMG" 2>&1 | grep -q "accepted"; then
    vert "Gatekeeper accepte le DMG"
  else
    rouge "Gatekeeper refuse le DMG. Verifie la signature et la notarisation."
    exit 1
  fi
fi

TAILLE="$(du -h "$DMG" | cut -f1)"

cat <<FIN

===========================================================================
DMG PRET
===========================================================================
  Fichier  : $DMG
  Taille   : $TAILLE
  Version  : $VERSION
  Somme    : $(cut -d' ' -f1 < "$DMG.sha256")

Pour publier :
  git tag -a v$VERSION -m "Version $VERSION"
  git push origin v$VERSION
===========================================================================

FIN
