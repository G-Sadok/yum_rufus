#!/usr/bin/env bash
#
# tests-empaquetage.sh
# Tests de la chaine d empaquetage, sans Xcode, sans certificat Developer ID et
# sans identifiants Apple.
#
# Ce que ces tests couvrent vraiment :
#   1. le DMG produit contient le lien symbolique vers /Applications
#   2. il contient le fond de fenetre et l application
#   3. la verification du contenu echoue quand le lien manque, autrement dit
#      elle ne repond pas OK a vide
#   4. les douze etapes de build-dmg.sh s enchainent dans l ordre exige par la
#      notarisation, application avant DMG, agrafage avant verdict
#   5. le script refuse de produire un DMG non signe sans consentement explicite
#   6. le script refuse une version non semantique
#   7. le fond de fenetre se fabrique depuis les jetons du systeme de design
#
# Ce qu ils ne couvrent pas, et ne peuvent pas couvrir ici : le verdict reel de
# Gatekeeper sur une machine tierce, qui demande un certificat Developer ID et
# un aller retour chez Apple. Le point 4 verifie l enchainement des appels, pas
# leur resultat. Les appels a codesign, spctl et notarytool sont remplaces par
# des doublures qui consignent ce qu on leur demande.
#
# Usage :
#   ./scripts/tests-empaquetage.sh
#   ./scripts/build-dmg.sh --tests

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

# shellcheck source=/dev/null
. "$RACINE/scripts/lib-dmg.sh"

ECHECS=0
BAC="$(mktemp -d)"
trap 'rm -rf "$BAC"' EXIT

# Finder ne repond pas sur une machine d integration continue. La borne courte
# evite d attendre quarante cinq secondes par DMG pour un confort de fenetre
# dont aucun test ne depend.
export DMG_DELAI_FINDER=15

reussi() { printf '\033[32m  OK      %s\033[0m\n' "$1"; }
echoue() { printf '\033[31m  ECHEC   %s\033[0m\n' "$1" >&2; ECHECS=$((ECHECS + 1)); }
titre()  { printf '\n\033[36m%s\033[0m\n' "$1"; }

# Fabrique une fausse application, structure minimale suffisante pour hdiutil.
fausse_application() {
  local chemin="$1"
  mkdir -p "$chemin/Contents/MacOS" "$chemin/Contents/Resources"
  cat > "$chemin/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Yum</string>
  <key>CFBundleIdentifier</key>
  <string>com.yum.lecteur</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
</dict>
</plist>
PLIST
  printf 'fausse application de test\n' > "$chemin/Contents/MacOS/Yum"
  chmod +x "$chemin/Contents/MacOS/Yum"
}

# ---------------------------------------------------------------------------
titre "1. Fabrication du fond depuis les jetons du systeme de design"
# ---------------------------------------------------------------------------
FOND="$BAC/fond.png"
if python3 "$RACINE/scripts/fabriquer-fond-dmg.py" "$FOND" >/dev/null 2>&1; then
  reussi "Le fond se fabrique sans erreur"
else
  echoue "La fabrication du fond a echoue"
fi

if [ -f "$FOND" ]; then
  SIGNATURE_PNG="$(od -An -tx1 -N8 "$FOND" | tr -d ' \n')"
  if [ "$SIGNATURE_PNG" = "89504e470d0a1a0a" ]; then
    reussi "Le fond est un PNG valide"
  else
    echoue "Le fond n est pas un PNG, entete $SIGNATURE_PNG"
  fi

  # Largeur et hauteur vivent dans le morceau IHDR, octets 16 a 23.
  DIMENSIONS="$(od -An -tu4 -j16 -N8 "$FOND" | tr -s ' ')"
  LARGEUR_LUE="$(printf '%s' "$DIMENSIONS" | awk '{print $1}')"
  HAUTEUR_LUE="$(printf '%s' "$DIMENSIONS" | awk '{print $2}')"
  # od rend les entiers en ordre machine, l intel et l apple silicon sont tous
  # deux petit boutistes alors que le PNG est gros boutiste. On compare donc
  # sur les octets, pas sur la valeur decodee.
  ENTETE_TAILLE="$(od -An -tx1 -j16 -N8 "$FOND" | tr -d ' \n')"
  if [ "$ENTETE_TAILLE" = "0000029400000190" ]; then
    reussi "Le fond fait 660 par 400 points, taille de la fenetre du DMG"
  else
    echoue "Le fond ne fait pas 660 par 400 points, entete $ENTETE_TAILLE ($LARGEUR_LUE par $HAUTEUR_LUE)"
  fi

  # Le fond suivi par git doit correspondre a ce que les jetons produisent
  # aujourd hui. Sans ce controle, un changement de jeton laisserait le DMG
  # peint avec les couleurs d avant, sans que rien ne le signale.
  if cmp -s "$FOND" "$RACINE/Ressources/fond-dmg.png"; then
    reussi "Le fond suivi par git correspond aux jetons courants"
  else
    echoue "Le fond suivi par git a derive des jetons, lance ./scripts/build-dmg.sh --fond"
  fi
else
  echoue "Aucun fond produit"
fi

# ---------------------------------------------------------------------------
titre "2. Contenu du DMG"
# ---------------------------------------------------------------------------
APPLICATION="$BAC/source/Yum.app"
mkdir -p "$BAC/source"
fausse_application "$APPLICATION"

STAGING="$BAC/staging"
DMG_COMPLET="$BAC/Yum-test.dmg"

if dmg_preparer_staging "$APPLICATION" "$STAGING" "$FOND" >/dev/null; then
  if [ -L "$STAGING/Applications" ] && [ "$(readlink "$STAGING/Applications")" = "/Applications" ]; then
    reussi "Le staging porte le lien vers /Applications"
  else
    echoue "Le staging ne porte pas le lien vers /Applications"
  fi
else
  echoue "La preparation du staging a echoue"
fi

TRACE_FABRICATION="$BAC/fabrication.txt"
if dmg_fabriquer "$STAGING" "YumTest" "$DMG_COMPLET" "Yum.app" > "$TRACE_FABRICATION" 2>&1; then
  reussi "Le DMG se fabrique"
  if dmg_verifier "$DMG_COMPLET" "Yum.app"; then
    reussi "Le DMG contient le lien Applications, l application et le fond"
  else
    echoue "Le contenu du DMG est incomplet"
  fi
else
  echoue "La fabrication du DMG a echoue"
  cat "$TRACE_FABRICATION" >&2
fi

# ---------------------------------------------------------------------------
titre "3. La verification du contenu detecte un lien manquant"
# ---------------------------------------------------------------------------
# Sans ce test, le precedent pourrait repondre OK sur une verification qui ne
# verifie rien, ce qui est exactement le genre de controle vert et faux que la
# section 14 du cahier de developpement interdit.
STAGING_SANS_LIEN="$BAC/staging-sans-lien"
DMG_SANS_LIEN="$BAC/Yum-sans-lien.dmg"

dmg_preparer_staging "$APPLICATION" "$STAGING_SANS_LIEN" "$FOND" >/dev/null
rm -f "$STAGING_SANS_LIEN/Applications"

if dmg_fabriquer "$STAGING_SANS_LIEN" "YumSansLien" "$DMG_SANS_LIEN" "Yum.app" >/dev/null 2>&1; then
  if dmg_verifier "$DMG_SANS_LIEN" "Yum.app" >/dev/null 2>&1; then
    echoue "La verification accepte un DMG sans lien vers Applications"
  else
    reussi "La verification refuse un DMG sans lien vers Applications"
  fi
else
  echoue "La fabrication du DMG temoin a echoue"
fi

# ---------------------------------------------------------------------------
titre "4. Ordre des etapes de la chaine complete"
# ---------------------------------------------------------------------------
DOUBLURES="$BAC/doublures"
mkdir -p "$DOUBLURES"
JOURNAL="$BAC/journal.txt"
: > "$JOURNAL"

cat > "$DOUBLURES/xcodebuild" <<'DOUBLURE'
#!/usr/bin/env bash
journaliser() { printf '%s\n' "$1" >> "$JOURNAL_EMPAQUETAGE"; }

for argument in "$@"; do
  case "$argument" in
    -showBuildSettings)
      echo "    MARKETING_VERSION = 1.0.0"
      exit 0
      ;;
  esac
done

destination=""
mode=""
attendu=""
for argument in "$@"; do
  case "$attendu" in
    archive) destination="$argument"; attendu="" ; continue ;;
    export)  destination="$argument"; attendu="" ; continue ;;
  esac
  case "$argument" in
    archive)        mode="archive" ;;
    -exportArchive) mode="export" ;;
    -archivePath)   [ "$mode" = "archive" ] && attendu="archive" ;;
    -exportPath)    attendu="export" ;;
  esac
done

if [ "$mode" = "archive" ]; then
  journaliser "xcodebuild archive"
  mkdir -p "$destination/Products/Applications"
  exit 0
fi

if [ "$mode" = "export" ]; then
  journaliser "xcodebuild export"
  mkdir -p "$destination/Yum.app/Contents/MacOS"
  printf 'fausse application de test\n' > "$destination/Yum.app/Contents/MacOS/Yum"
  chmod +x "$destination/Yum.app/Contents/MacOS/Yum"
  cat > "$destination/Yum.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>Yum</string></dict></plist>
PLIST
  exit 0
fi

exit 0
DOUBLURE

cat > "$DOUBLURES/codesign" <<'DOUBLURE'
#!/usr/bin/env bash
journaliser() { printf '%s\n' "$1" >> "$JOURNAL_EMPAQUETAGE"; }

cible=""
for argument in "$@"; do
  case "$argument" in
    -*) ;;
    *) cible="$argument" ;;
  esac
done
nom="$(basename "$cible")"

case "$1" in
  --verify)  journaliser "codesign verifie $nom" ;;
  --display) echo "Identifier=com.yum.lecteur" >&2
             echo "CodeDirectory v=20500 flags=0x10000(runtime) hashes=1+2" >&2 ;;
  --sign)    journaliser "codesign signe $nom" ;;
esac
exit 0
DOUBLURE

cat > "$DOUBLURES/spctl" <<'DOUBLURE'
#!/usr/bin/env bash
journaliser() { printf '%s\n' "$1" >> "$JOURNAL_EMPAQUETAGE"; }

type_evalue=""
cible=""
attendu=0
for argument in "$@"; do
  if [ "$attendu" -eq 1 ]; then type_evalue="$argument"; attendu=0; continue; fi
  case "$argument" in
    --type) attendu=1 ;;
    -*) ;;
    *) cible="$argument" ;;
  esac
done

journaliser "spctl $type_evalue $(basename "$cible")"
echo "$cible: accepted"
exit 0
DOUBLURE

cat > "$DOUBLURES/xcrun" <<'DOUBLURE'
#!/usr/bin/env bash
journaliser() { printf '%s\n' "$1" >> "$JOURNAL_EMPAQUETAGE"; }

outil="$1"
shift

case "$outil" in
  notarytool)
    action="$1"; shift
    if [ "$action" = "submit" ]; then
      journaliser "notarytool submit $(basename "$1")"
      echo "  id: 00000000-0000-0000-0000-000000000000"
      echo "  status: Accepted"
    fi
    ;;
  stapler)
    action="$1"; shift
    journaliser "stapler $action $(basename "$1")"
    ;;
esac
exit 0
DOUBLURE

chmod +x "$DOUBLURES"/*

ATTENDU="$BAC/attendu.txt"
cat > "$ATTENDU" <<'ORDRE'
xcodebuild archive
xcodebuild export
codesign verifie Yum.app
notarytool submit Yum-notarisation.zip
stapler staple Yum.app
stapler validate Yum.app
spctl execute Yum.app
codesign signe Yum-1.0.0.dmg
codesign verifie Yum-1.0.0.dmg
notarytool submit Yum-1.0.0.dmg
stapler staple Yum-1.0.0.dmg
stapler validate Yum-1.0.0.dmg
spctl open Yum-1.0.0.dmg
ORDRE

TRACE="$BAC/trace-chaine.txt"
if JOURNAL_EMPAQUETAGE="$JOURNAL" \
   PATH="$DOUBLURES:$PATH" \
   IDENTITE_SIGNATURE="Developer ID Application: Test (TEST123456)" \
   EQUIPE_APPLE="TEST123456" \
   PROFIL_NOTARISATION="profil-de-test" \
   "$RACINE/scripts/build-dmg.sh" 1.0.0 > "$TRACE" 2>&1; then
  reussi "La chaine complete se deroule jusqu au bout"
else
  echoue "La chaine complete a echoue"
  tail -25 "$TRACE" >&2
fi

if diff -u "$ATTENDU" "$JOURNAL" >/dev/null 2>&1; then
  reussi "Les douze etapes s enchainent dans l ordre exige"
else
  echoue "L ordre des etapes ne correspond pas a l ordre exige"
  diff -u "$ATTENDU" "$JOURNAL" >&2 || true
fi

SOMME="$RACINE/build/Yum-1.0.0.dmg.sha256"
if [ -s "$SOMME" ]; then
  reussi "La somme SHA 256 est produite et non vide"
  # La somme doit se verifier a cote du fichier telecharge, exactement comme
  # les notes de version le demandent a l utilisateur.
  if (cd "$RACINE/build" && shasum -a 256 -c "$(basename "$SOMME")" >/dev/null 2>&1); then
    reussi "La somme SHA 256 correspond au DMG"
  else
    echoue "La somme SHA 256 ne correspond pas au DMG"
  fi
else
  echoue "La somme SHA 256 est absente ou vide"
fi

# ---------------------------------------------------------------------------
titre "5. Refus des constructions non publiables"
# ---------------------------------------------------------------------------
SORTIE_REFUS="$BAC/refus.txt"
if PATH="$DOUBLURES:$PATH" "$RACINE/scripts/build-dmg.sh" 1.0.0 > "$SORTIE_REFUS" 2>&1; then
  echoue "Le script produit un DMG non signe sans consentement explicite"
else
  if grep -q "IDENTITE_SIGNATURE est absente" "$SORTIE_REFUS"; then
    reussi "Le script refuse de construire sans identite de signature"
  else
    echoue "Le refus ne mentionne pas l identite de signature manquante"
  fi
fi

SORTIE_VERSION="$BAC/version.txt"
if JOURNAL_EMPAQUETAGE="$JOURNAL" \
   PATH="$DOUBLURES:$PATH" \
   IDENTITE_SIGNATURE="Developer ID Application: Test (TEST123456)" \
   EQUIPE_APPLE="TEST123456" \
   "$RACINE/scripts/build-dmg.sh" 1.0 > "$SORTIE_VERSION" 2>&1; then
  echoue "Le script accepte une version non semantique"
else
  if grep -q "versionnage semantique" "$SORTIE_VERSION"; then
    reussi "Le script refuse une version non semantique"
  else
    echoue "Le refus ne mentionne pas le versionnage semantique"
  fi
fi

rm -rf "$RACINE/build"

# ---------------------------------------------------------------------------
titre "Resultat"
# ---------------------------------------------------------------------------
if [ "$ECHECS" -gt 0 ]; then
  printf '\033[31m%d test(s) d empaquetage en echec.\033[0m\n\n' "$ECHECS"
  exit 1
fi

printf '\033[32mTous les tests d empaquetage sont passes.\033[0m\n\n'
exit 0
