#!/usr/bin/env bash
#
# build-dmg.sh
# Compile, archive, exporte, signe, notarise, agrafe et empaquete l application
# en DMG, puis verifie le resultat avant de le declarer publiable.
#
# Usage :
#   ./scripts/build-dmg.sh                       version deduite du projet
#   ./scripts/build-dmg.sh 1.2.0                 version imposee
#   SANS_NOTARISATION=1 ./scripts/build-dmg.sh   iteration rapide, signe sans notariser
#   SANS_SIGNATURE=1 ./scripts/build-dmg.sh      construction de travail, non publiable
#   ./scripts/build-dmg.sh --tests               tests d empaquetage, sans Xcode ni certificat
#   ./scripts/build-dmg.sh --tests-publication   tests de la chaine de publication, sans reseau
#   ./scripts/build-dmg.sh --notes v1.0.0        relit les notes avant de poser l etiquette
#   ./scripts/build-dmg.sh --fond                refabrique le fond depuis les jetons
#
# Variables d environnement attendues pour la chaine complete :
#   IDENTITE_SIGNATURE    par exemple "Developer ID Application: Nom (TEAMID)"
#   EQUIPE_APPLE          identifiant d equipe Apple
#   PROFIL_NOTARISATION   nom du profil stocke dans le trousseau
#
# Pour creer le profil de notarisation une fois pour toutes :
#   xcrun notarytool store-credentials "yum-notarisation" \
#     --apple-id "adresse@exemple.fr" \
#     --team-id "TEAMID" \
#     --password "mot-de-passe-application"
#
# L ordre des douze etapes ci dessous n est pas negociable. L application se
# notarise et s agrafe avant d entrer dans le DMG, et le DMG se notarise et
# s agrafe a son tour. Inverser les deux, ou n en faire qu un des deux, produit
# une image qui passe la verification du poste de construction, ou le ticket est
# encore en cache, et qui declenche Gatekeeper chez l utilisateur. C est la
# panne la plus couteuse de cette etape, parce qu elle ne se voit pas avant la
# publication. tests-empaquetage.sh verifie cet ordre a chaque integration.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

# shellcheck source=/dev/null
. "$RACINE/scripts/lib-dmg.sh"

if [ "${1:-}" = "--tests" ]; then
  exec bash "$RACINE/scripts/tests-empaquetage.sh"
fi

if [ "${1:-}" = "--tests-publication" ]; then
  exec bash "$RACINE/scripts/tests-publication.sh"
fi

# Relire les notes avant de poser l etiquette est un point de la liste de
# controle de la competence release-dmg. Les decouvrir sur la page de la release
# est trop tard : l etiquette est posee et la chaine a deja tourne.
if [ "${1:-}" = "--notes" ]; then
  shift
  exec bash "$RACINE/scripts/notes-de-version.sh" "$@"
fi

if [ "${1:-}" = "--fond" ]; then
  exec python3 "$RACINE/scripts/fabriquer-fond-dmg.py" "$RACINE/Ressources/fond-dmg.png"
fi

SCHEMA="${SCHEMA_XCODE:-Yum}"
NOM_APP="${NOM_APP:-Yum}"
VERSION="${1:-}"
SORTIE="$RACINE/build"
ARCHIVE="$SORTIE/$NOM_APP.xcarchive"
EXPORT="$SORTIE/export"
STAGING="$SORTIE/staging"
FOND="$RACINE/Ressources/fond-dmg.png"

rouge() { printf '\033[31m%s\033[0m\n' "$1" >&2; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
etape() { printf '\n\033[36m>> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
etape "Preparation"
# ---------------------------------------------------------------------------
command -v xcodebuild >/dev/null 2>&1 || { rouge "xcodebuild est requis, installe Xcode."; exit 1; }

# Une construction non signee ne se refuse pas en silence et ne se produit pas
# non plus par accident. L ancienne version se contentait d un avertissement
# jaune au milieu de deux cents lignes de sortie, et rien ne distinguait le DMG
# publiable de celui qui ne l etait pas une fois les deux dans build/.
if [ -z "${IDENTITE_SIGNATURE:-}" ] && [ "${SANS_SIGNATURE:-0}" != "1" ]; then
  rouge "IDENTITE_SIGNATURE est absente."
  rouge "Un DMG non signe declenche Gatekeeper sur toute machine tierce."
  rouge "Pour une construction de travail, assumee non publiable :"
  rouge "  SANS_SIGNATURE=1 ./scripts/build-dmg.sh"
  exit 1
fi

SIGNE=0
[ -n "${IDENTITE_SIGNATURE:-}" ] && SIGNE=1

NOTARISE=0
if [ "$SIGNE" -eq 1 ] && [ "${SANS_NOTARISATION:-0}" != "1" ] && [ -n "${PROFIL_NOTARISATION:-}" ]; then
  NOTARISE=1
fi

rm -rf "$SORTIE"
mkdir -p "$SORTIE" "$STAGING"

if [ -z "$VERSION" ]; then
  VERSION="$(xcodebuild -scheme "$SCHEMA" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}' | tr -d ' ')"
  VERSION="${VERSION:-0.0.0}"
fi

# La version se retrouve dans l etiquette git, dans le nom du DMG et dans les
# notes de version. Une version a deux segments passait ici sans bruit et ne
# correspondait plus a l etiquette v1.0.0 attendue par la chaine de publication.
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  rouge "Version $VERSION non conforme au versionnage semantique, attendu MAJEUR.MINEUR.CORRECTIF"
  exit 1
fi
vert "Version : $VERSION"

DMG="$SORTIE/$NOM_APP-$VERSION.dmg"

# Le fond est un artefact derive des jetons du systeme de design. Il se
# refabrique s il manque plutot que de laisser une fenetre grise.
if [ ! -f "$FOND" ]; then
  jaune "Fond du DMG absent, fabrication depuis les jetons"
  python3 "$RACINE/scripts/fabriquer-fond-dmg.py" "$FOND"
fi

# ---------------------------------------------------------------------------
etape "1. Archivage"
# ---------------------------------------------------------------------------
REGLAGES_SIGNATURE=()
if [ "$SIGNE" -eq 1 ]; then
  # Le durcissement du moteur d execution et l horodatage sont exiges par la
  # notarisation. Le projet les porte deja, on les repose ici pour qu une
  # construction reste correcte meme si le reglage bouge cote projet.
  REGLAGES_SIGNATURE=(
    ENABLE_HARDENED_RUNTIME=YES
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
fi

xcodebuild archive \
  -scheme "$SCHEMA" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  "${REGLAGES_SIGNATURE[@]+"${REGLAGES_SIGNATURE[@]}"}" \
  -quiet
vert "Archive produite"

# ---------------------------------------------------------------------------
etape "2. Export"
# ---------------------------------------------------------------------------
PLIST_EXPORT="$SORTIE/ExportOptions.plist"

if [ "$SIGNE" -eq 1 ]; then
  METHODE="developer-id"
  CERTIFICAT="  <key>signingCertificate</key>
  <string>Developer ID Application</string>"
else
  jaune "Construction non signee assumee, ce DMG n est pas publiable."
  METHODE="mac-application"
  CERTIFICAT=""
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
$CERTIFICAT
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
etape "3. Verification de la signature de l application"
# ---------------------------------------------------------------------------
if [ "$SIGNE" -eq 1 ]; then
  codesign --verify --deep --strict --verbose=2 "$APP"

  # Le durcissement se lit dans les indicateurs de la signature. Une
  # application signee sans lui passe codesign et se fait refuser par la
  # notarisation dix minutes plus tard.
  if codesign --display --verbose=2 "$APP" 2>&1 | grep -q "flags=.*runtime"; then
    vert "Signature valide, moteur d execution durci"
  else
    rouge "Moteur d execution non durci, la notarisation refusera l application"
    exit 1
  fi
else
  jaune "Verification ignoree, application non signee"
fi

# Soumet un fichier a la notarisation et remonte le journal Apple en cas de
# refus. Sans ce journal, un refus se resume a un identifiant de soumission et
# la cause reste a deviner.
notariser() {
  local fichier="$1"
  local trace
  trace="$(mktemp)"

  if xcrun notarytool submit "$fichier" \
      --keychain-profile "$PROFIL_NOTARISATION" \
      --wait 2>&1 | tee "$trace"; then
    if grep -q "status: Accepted" "$trace"; then
      rm -f "$trace"
      return 0
    fi
  fi

  local identifiant
  identifiant="$(awk '/id: /{print $2; exit}' "$trace")"
  rouge "Notarisation refusee pour $(basename "$fichier")"
  if [ -n "$identifiant" ]; then
    xcrun notarytool log "$identifiant" --keychain-profile "$PROFIL_NOTARISATION" || true
  fi
  rm -f "$trace"
  return 1
}

# ---------------------------------------------------------------------------
etape "4. Notarisation de l application"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  ZIP_NOTAIRE="$SORTIE/$NOM_APP-notarisation.zip"
  ditto -c -k --keepParent "$APP" "$ZIP_NOTAIRE"
  notariser "$ZIP_NOTAIRE"
  rm -f "$ZIP_NOTAIRE"
  vert "Application notarisee"
else
  jaune "Notarisation de l application ignoree"
fi

# ---------------------------------------------------------------------------
etape "5. Agrafage de l application"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  vert "Ticket agrafe a l application"
else
  jaune "Agrafage de l application ignore"
fi

# ---------------------------------------------------------------------------
etape "6. Verdict de Gatekeeper sur l application"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  if spctl --assess --type execute --verbose=4 "$APP" 2>&1 | grep -q "accepted"; then
    vert "spctl accepte l application"
  else
    rouge "spctl refuse l application. Verifie la signature, le durcissement et l agrafage."
    spctl --assess --type execute --verbose=4 "$APP" || true
    exit 1
  fi
else
  jaune "Verdict spctl sur l application ignore, chaine incomplete"
fi

# ---------------------------------------------------------------------------
etape "7. Construction du DMG"
# ---------------------------------------------------------------------------
dmg_preparer_staging "$APP" "$STAGING" "$FOND"
dmg_fabriquer "$STAGING" "$NOM_APP" "$DMG" "$NOM_APP.app"
vert "DMG cree : $DMG"

# ---------------------------------------------------------------------------
etape "8. Signature du DMG"
# ---------------------------------------------------------------------------
if [ "$SIGNE" -eq 1 ]; then
  codesign --sign "$IDENTITE_SIGNATURE" --timestamp "$DMG"
  codesign --verify --strict --verbose=2 "$DMG"
  vert "DMG signe"
else
  jaune "Signature du DMG ignoree"
fi

# ---------------------------------------------------------------------------
etape "9. Notarisation du DMG"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  notariser "$DMG"
  vert "DMG notarise"
else
  jaune "Notarisation du DMG ignoree"
fi

# ---------------------------------------------------------------------------
etape "10. Agrafage du DMG"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  xcrun stapler staple "$DMG"
  vert "Ticket agrafe au DMG"
fi

# ---------------------------------------------------------------------------
etape "11. Verdict de Gatekeeper sur le DMG"
# ---------------------------------------------------------------------------
if [ "$NOTARISE" -eq 1 ]; then
  # L agrafe se verifie avant le verdict. spctl sait consulter Apple en ligne,
  # et une image non agrafee peut donc etre acceptee ici tout en etant refusee
  # chez un utilisateur hors ligne. Le controle du ticket local est le seul qui
  # dise quelque chose de la machine tierce.
  xcrun stapler validate "$DMG"
  vert "Ticket present dans le DMG, verifiable hors ligne"

  if spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" 2>&1 | grep -q "accepted"; then
    vert "Gatekeeper accepte le DMG"
  else
    rouge "Gatekeeper refuse le DMG. Verifie la signature et la notarisation."
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" || true
    exit 1
  fi
else
  jaune "Verdict spctl sur le DMG ignore, chaine incomplete"
fi

# ---------------------------------------------------------------------------
etape "12. Verification du contenu du DMG"
# ---------------------------------------------------------------------------
dmg_verifier "$DMG" "$NOM_APP.app" || {
  rouge "Le contenu du DMG est incomplet."
  exit 1
}

# ---------------------------------------------------------------------------
etape "Somme de controle"
# ---------------------------------------------------------------------------
# La somme se calcule depuis le dossier de sortie pour que le fichier ne porte
# que le nom du DMG, sans chemin absolu, et reste verifiable par
# `shasum -a 256 -c Yum-VERSION.dmg.sha256` a cote du fichier telecharge.
#
# L ancienne version passait le nom du fichier dans le programme awk lui meme.
# Les points de la version y devenaient des operateurs, awk sortait en erreur
# de syntaxe, et le fichier de somme etait ecrit vide sans que rien n echoue.
# Une release publiait alors une somme absente en la presentant comme faite.
(
  cd "$SORTIE"
  shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)
[ -s "$DMG.sha256" ] || { rouge "La somme SHA 256 est vide"; exit 1; }
vert "Somme SHA 256 ecrite dans $DMG.sha256"

TAILLE="$(du -h "$DMG" | cut -f1)"

if [ "$NOTARISE" -eq 1 ]; then
  ETAT="signe, notarise, agrafe, publiable"
elif [ "$SIGNE" -eq 1 ]; then
  ETAT="signe mais non notarise, NON publiable"
else
  ETAT="non signe, NON publiable"
fi

cat <<FIN

===========================================================================
DMG PRET
===========================================================================
  Fichier  : $DMG
  Taille   : $TAILLE
  Version  : $VERSION
  Etat     : $ETAT
  Somme    : $(cut -d' ' -f1 < "$DMG.sha256")

Pour publier :
  git tag -a v$VERSION -m "Version $VERSION"
  git push origin v$VERSION
===========================================================================

FIN
