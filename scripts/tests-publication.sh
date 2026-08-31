#!/usr/bin/env bash
#
# tests-publication.sh
# Tests de la chaine de publication, sans reseau, sans jeton GitHub et sans
# certificat Developer ID.
#
# Ce que ces tests couvrent vraiment :
#   1. le flux de travail se declenche sur une etiquette de la forme v1.0.0
#   2. la release emporte le DMG et son fichier de somme SHA 256
#   3. la release est creee en brouillon
#   4. les notes de version sortent des messages de commit, sur un vrai depot
#      git fabrique pour l occasion
#   5. les sections sans contenu le disent, au lieu de sortir vides
#   6. la premiere version, celle qui n a pas d etiquette precedente, liste
#      quand meme ses nouveautes
#   7. la somme SHA 256 publiee est celle du DMG construit
#   8. un tiret cadratin venu d un message de commit bloque la redaction
#   9. le flux de travail appelle bien le script teste ici, et pas une copie
#
# Ce qu ils ne couvrent pas : l execution reelle de GitHub Actions, la creation
# reelle d une release et le verdict de Gatekeeper. Le point 9 est ce qui rend
# les huit autres utiles, sans lui on testerait du code que la chaine n appelle
# jamais.
#
# Usage :
#   ./scripts/tests-publication.sh
#   ./scripts/build-dmg.sh --tests-publication

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

FLUX="$RACINE/.github/workflows/release.yml"
NOTES="$RACINE/scripts/notes-de-version.sh"

ECHECS=0
BAC="$(mktemp -d)"
trap 'rm -rf "$BAC"' EXIT

reussi() { printf '\033[32m  OK      %s\033[0m\n' "$1"; }
echoue() { printf '\033[31m  ECHEC   %s\033[0m\n' "$1" >&2; ECHECS=$((ECHECS + 1)); }
titre()  { printf '\n\033[36m%s\033[0m\n' "$1"; }

# Fabrique un depot git jetable, isole de la configuration de la machine.
# core.hooksPath est neutralise : le depot du projet installe des crochets qui
# refusent le tiret cadratin et protegent la branche principale, et ces tests
# ont justement besoin de commiter des messages fautifs sur une branche neuve.
depot_jetable() {
  local chemin="$1"
  mkdir -p "$chemin"
  git -C "$chemin" init -q -b publication
  git -C "$chemin" config core.hooksPath /dev/null
  git -C "$chemin" config user.name "Test"
  git -C "$chemin" config user.email "test@exemple.fr"
  git -C "$chemin" config commit.gpgsign false
}

commiter() {
  local chemin="$1"
  local message="$2"
  printf '%s\n' "$message" >> "$chemin/journal.txt"
  git -C "$chemin" add -A
  git -C "$chemin" commit -q -m "$message"
}

etiqueter() {
  git -C "$1" tag -a "$2" -m "Version ${2#v}"
}

# Le bit d execution ne survit ni a tous les clones ni a tous les postes, et la
# chaine le repose elle meme avant d appeler quoi que ce soit. On invoque donc
# par bash : sans cela, un fichier sans droit d execution ferait passer au vert
# tous les tests de refus, qui refuseraient pour la mauvaise raison.
rediger() {
  local depot="$1"
  shift
  (cd "$depot" && bash "$NOTES" "$@")
}

# ---------------------------------------------------------------------------
titre "1. Declencheur du flux de travail"
# ---------------------------------------------------------------------------
if [ -f "$FLUX" ]; then
  reussi "Le flux de publication existe"
else
  echoue "Le flux .github/workflows/release.yml est absent"
fi

# La section on.push.tags. On lit la ligne du motif plutot que le fichier
# entier, sinon un motif present dans un commentaire suffirait a rendre vert.
if grep -Eq "^ +- 'v\*\.\*\.\*'$" "$FLUX"; then
  reussi "Une etiquette v1.0.0 declenche le flux"
else
  echoue "Le flux ne se declenche pas sur les etiquettes v*.*.*"
fi

if grep -q "^  push:" "$FLUX" && grep -q "^    tags:" "$FLUX"; then
  reussi "Le declencheur est bien un push d etiquette"
else
  echoue "Le declencheur n est pas un push d etiquette"
fi

if grep -q "contents: write" "$FLUX"; then
  reussi "Le jeton a le droit d ecrire, sans quoi la release ne se cree pas"
else
  echoue "Le flux ne demande pas la permission contents: write"
fi

# ---------------------------------------------------------------------------
titre "2. Contenu et etat de la release"
# ---------------------------------------------------------------------------
# On isole l invocation de gh release create pour lire ses arguments, plutot
# que de chercher les mots au hasard dans tout le fichier.
INVOCATION="$BAC/invocation.txt"
awk '/gh release create/{lecture=1} lecture{print} lecture && /^$/{exit}' "$FLUX" > "$INVOCATION"

if [ -s "$INVOCATION" ]; then
  reussi "Le flux appelle gh release create"
else
  echoue "Le flux n appelle pas gh release create"
fi

if grep -q -- "--draft" "$INVOCATION"; then
  reussi "La release est creee en brouillon"
else
  echoue "La release n est pas creee en brouillon"
fi

if grep -q '\.dmg"' "$INVOCATION"; then
  reussi "Le DMG est joint a la release"
else
  echoue "Le DMG n est pas joint a la release"
fi

if grep -q '\.dmg\.sha256"' "$INVOCATION"; then
  reussi "Le fichier de somme SHA 256 est joint a la release"
else
  echoue "Le fichier de somme SHA 256 n est pas joint a la release"
fi

if grep -q -- "--notes-file" "$INVOCATION"; then
  reussi "Les notes de version sont attachees a la release"
else
  echoue "La release ne porte pas de notes de version"
fi

# Une release publiee directement ne se depublie pas proprement : les miroirs
# et les flux ont deja vu passer le DMG. Le brouillon est le seul etat qui
# laisse une marche arriere.
if grep -Eq -- "--(latest|prerelease=false)" "$INVOCATION"; then
  echoue "Le flux force un etat publie, le brouillon ne tient plus"
else
  reussi "Rien ne contredit l etat brouillon"
fi

# ---------------------------------------------------------------------------
titre "3. Le flux appelle le script de notes teste ici"
# ---------------------------------------------------------------------------
if grep -q "scripts/notes-de-version.sh" "$FLUX"; then
  reussi "Le flux delegue la redaction a scripts/notes-de-version.sh"
else
  echoue "Le flux redige les notes sur place, ces tests ne couvrent alors rien"
fi

if grep -q "scripts/tests-publication.sh" "$FLUX" \
  || grep -q -- "--tests-publication" "$FLUX"; then
  reussi "Le flux passe ces tests avant de construire quoi que ce soit"
else
  echoue "Le flux ne lance pas les tests de publication avant de construire"
fi

if [ -f "$NOTES" ] && head -1 "$NOTES" | grep -q '^#!.*bash'; then
  reussi "Le script de notes existe et s execute en bash"
else
  echoue "Le script de notes est absent ou sans interprete declare"
fi

# Le bit d execution ne survit pas a tous les postes ni a tous les clones. Le
# flux le repose avant d appeler quoi que ce soit, et c est cela qu on verifie,
# pas l etat du fichier sur la machine qui lance ces tests.
if grep -q "chmod +x scripts/\*\.sh" "$FLUX"; then
  reussi "Le flux repose le bit d execution avant d appeler les scripts"
else
  echoue "Le flux appelle des scripts sans garantir leur bit d execution"
fi

# ---------------------------------------------------------------------------
titre "4. Notes redigees depuis les messages de commit"
# ---------------------------------------------------------------------------
DEPOT="$BAC/depot"
depot_jetable "$DEPOT"

commiter "$DEPOT" "feat(F001): Socle du depot et outillage"
etiqueter "$DEPOT" "v0.9.0"
commiter "$DEPOT" "feat(F002): Lecture des archives ZIP"
commiter "$DEPOT" "fix(F002): Corrige le tri naturel des pages"
commiter "$DEPOT" "chore: mise a jour des statuts du backlog"
commiter "$DEPOT" "docs: completer le guide d utilisation"
commiter "$DEPOT" "feat: Mode sombre"
etiqueter "$DEPOT" "v1.0.0"

SORTIE="$BAC/notes-v1.md"
if rediger "$DEPOT" v1.0.0 > "$SORTIE" 2>"$BAC/erreur-v1.txt"; then
  reussi "Les notes se redigent sans erreur"
else
  echoue "La redaction des notes a echoue"
  cat "$BAC/erreur-v1.txt" >&2
fi

if grep -q "^## Version 1.0.0$" "$SORTIE"; then
  reussi "Les notes portent le numero de version de l etiquette"
else
  echoue "Les notes ne portent pas le numero de version"
fi

if grep -q "^- Lecture des archives ZIP (F002)$" "$SORTIE"; then
  reussi "Une nouveaute vient du message de commit, identifiant compris"
else
  echoue "La nouveaute F002 est absente ou mal formee"
fi

if grep -q "^- Mode sombre$" "$SORTIE"; then
  reussi "Un commit sans portee est mis en forme au lieu d etre recopie brut"
else
  echoue "Le commit feat sans portee n est pas mis en forme"
fi

if grep -q "^- Corrige le tri naturel des pages (F002)$" "$SORTIE"; then
  reussi "Une correction vient du message de commit"
else
  echoue "La correction F002 est absente ou mal formee"
fi

# Le contenu d avant l etiquette precedente n a rien a faire dans ces notes.
if grep -q "Socle du depot" "$SORTIE"; then
  echoue "Les notes remontent avant l etiquette precedente"
else
  reussi "Les notes s arretent a l etiquette precedente"
fi

if grep -qE "^- (Mise a jour des statuts|Completer le guide)" "$SORTIE"; then
  echoue "Les commits chore et docs se retrouvent dans les notes"
else
  reussi "Les commits chore et docs restent hors des notes"
fi

if grep -q "^feat" "$SORTIE" || grep -q "^fix" "$SORTIE"; then
  echoue "Un prefixe de commit brut subsiste dans les notes"
else
  reussi "Aucun prefixe de commit brut ne subsiste"
fi

TIRET_CADRATIN="$(printf '\342\200\224')"
if grep -q -e "$TIRET_CADRATIN" "$SORTIE"; then
  echoue "Tiret cadratin dans les notes produites"
else
  reussi "Aucun tiret cadratin dans les notes produites"
fi

# ---------------------------------------------------------------------------
titre "5. Sections sans contenu"
# ---------------------------------------------------------------------------
# Regression du repli `git log | grep | sed || echo`, qui ne se declenchait
# jamais parce que bash rend le code de sortie du dernier maillon du tube.
DEPOT_SANS_FIX="$BAC/depot-sans-fix"
depot_jetable "$DEPOT_SANS_FIX"
commiter "$DEPOT_SANS_FIX" "feat(F001): Socle du depot"
etiqueter "$DEPOT_SANS_FIX" "v1.0.0"
commiter "$DEPOT_SANS_FIX" "feat(F002): Bibliotheque"
etiqueter "$DEPOT_SANS_FIX" "v1.1.0"

SORTIE_SANS_FIX="$BAC/notes-sans-fix.md"
rediger "$DEPOT_SANS_FIX" v1.1.0 > "$SORTIE_SANS_FIX" 2>&1

if grep -q "Aucune correction dans cette version." "$SORTIE_SANS_FIX"; then
  reussi "Une section Corrections vide le dit explicitement"
else
  echoue "La section Corrections sort vide au lieu de le dire"
fi

DEPOT_SANS_FEAT="$BAC/depot-sans-feat"
depot_jetable "$DEPOT_SANS_FEAT"
commiter "$DEPOT_SANS_FEAT" "feat(F001): Socle du depot"
etiqueter "$DEPOT_SANS_FEAT" "v1.0.0"
commiter "$DEPOT_SANS_FEAT" "fix(F001): Corrige un chemin relatif"
etiqueter "$DEPOT_SANS_FEAT" "v1.0.1"

SORTIE_SANS_FEAT="$BAC/notes-sans-feat.md"
rediger "$DEPOT_SANS_FEAT" v1.0.1 > "$SORTIE_SANS_FEAT" 2>&1

if grep -q "Aucune nouvelle fonctionnalite dans cette version." "$SORTIE_SANS_FEAT"; then
  reussi "Une section Nouveautes vide le dit explicitement"
else
  echoue "La section Nouveautes sort vide au lieu de le dire"
fi

if grep -q "^- Corrige un chemin relatif (F001)$" "$SORTIE_SANS_FEAT"; then
  reussi "Un correctif seul remplit bien sa section"
else
  echoue "Le correctif est absent de ses propres notes"
fi

# ---------------------------------------------------------------------------
titre "6. Premiere version"
# ---------------------------------------------------------------------------
# La version 1.0.0 d un projet n a pas d etiquette precedente. C est aussi celle
# qui a le plus de choses a annoncer, elle ne peut pas sortir vide.
DEPOT_PREMIER="$BAC/depot-premier"
depot_jetable "$DEPOT_PREMIER"
commiter "$DEPOT_PREMIER" "feat(F001): Socle du depot"
commiter "$DEPOT_PREMIER" "feat(F067): Publication de la version sur GitHub"
etiqueter "$DEPOT_PREMIER" "v1.0.0"

SORTIE_PREMIER="$BAC/notes-premier.md"
rediger "$DEPOT_PREMIER" v1.0.0 > "$SORTIE_PREMIER" 2>&1

if grep -q "Premiere version publiee." "$SORTIE_PREMIER"; then
  reussi "La premiere version est annoncee comme telle"
else
  echoue "La premiere version n est pas annoncee"
fi

if grep -q "^- Socle du depot (F001)$" "$SORTIE_PREMIER" \
  && grep -q "^- Publication de la version sur GitHub (F067)$" "$SORTIE_PREMIER"; then
  reussi "La premiere version liste quand meme toutes ses nouveautes"
else
  echoue "La premiere version ne liste pas ses nouveautes"
  cat "$SORTIE_PREMIER" >&2
fi

# ---------------------------------------------------------------------------
titre "7. Somme SHA 256 dans les notes"
# ---------------------------------------------------------------------------
FAUX_DMG="$BAC/Yum-1.0.0.dmg"
printf 'contenu de test\n' > "$FAUX_DMG"
(cd "$BAC" && shasum -a 256 "Yum-1.0.0.dmg" > "Yum-1.0.0.dmg.sha256")
SOMME_ATTENDUE="$(cut -d' ' -f1 < "$BAC/Yum-1.0.0.dmg.sha256")"

SORTIE_SOMME="$BAC/notes-somme.md"
rediger "$DEPOT" v1.0.0 "$BAC/Yum-1.0.0.dmg.sha256" > "$SORTIE_SOMME" 2>&1

if grep -q "^$SOMME_ATTENDUE$" "$SORTIE_SOMME"; then
  reussi "Les notes publient la somme du DMG construit"
else
  echoue "Les notes ne publient pas la somme du DMG"
fi

if grep -q "shasum -a 256 -c Yum-1.0.0.dmg.sha256" "$SORTIE_SOMME"; then
  reussi "Les notes donnent la commande de verification"
else
  echoue "Les notes ne disent pas comment verifier la somme"
fi

# Une somme absente doit arreter la redaction. Sans ce refus, la chaine
# publierait des notes qui annoncent une verification impossible.
REFUS_SOMME="$BAC/refus-somme.txt"
if rediger "$DEPOT" v1.0.0 "$BAC/somme-inexistante.sha256" >/dev/null 2>"$REFUS_SOMME"; then
  echoue "Le script accepte un fichier de somme inexistant"
elif grep -q "Somme de controle absente ou vide" "$REFUS_SOMME"; then
  reussi "Le script refuse un fichier de somme inexistant, et le dit"
else
  echoue "Le script echoue sur la somme manquante sans dire pourquoi"
fi

# ---------------------------------------------------------------------------
titre "8. Refus des entrees fautives"
# ---------------------------------------------------------------------------
REFUS="$BAC/refus-etiquette.txt"
for MAUVAISE in "1.0.0" "v1.0" "v1.0.0-beta" "" "v1.0.0; rm -rf /"; do
  if rediger "$DEPOT" "$MAUVAISE" >/dev/null 2>"$REFUS"; then
    echoue "Le script accepte l etiquette fautive [$MAUVAISE]"
  elif grep -qE "(non conforme|Usage)" "$REFUS"; then
    reussi "Le script refuse l etiquette fautive [${MAUVAISE:-vide}], et le dit"
  else
    echoue "Le script echoue sur [${MAUVAISE:-vide}] sans dire pourquoi"
  fi
done

DEPOT_TIRET="$BAC/depot-tiret"
depot_jetable "$DEPOT_TIRET"
commiter "$DEPOT_TIRET" "feat(F001): Socle"
etiqueter "$DEPOT_TIRET" "v1.0.0"
# Le message fautif se construit en octal, comme partout ailleurs dans le
# projet, pour que ce fichier ne contienne pas lui meme le caractere interdit.
commiter "$DEPOT_TIRET" "feat(F002): Lecteur $(printf '\342\200\224') mode webtoon"
etiqueter "$DEPOT_TIRET" "v1.1.0"

REFUS_TIRET="$BAC/refus-tiret.txt"
if rediger "$DEPOT_TIRET" v1.1.0 >/dev/null 2>"$REFUS_TIRET"; then
  echoue "Un tiret cadratin venu d un commit passe dans les notes"
elif grep -q "Tiret cadratin dans les notes" "$REFUS_TIRET"; then
  reussi "Un tiret cadratin venu d un commit bloque la redaction, et le dit"
else
  echoue "La redaction echoue sur le tiret cadratin sans dire pourquoi"
fi

# ---------------------------------------------------------------------------
titre "9. Coherence entre l etiquette et la version construite"
# ---------------------------------------------------------------------------
# build-dmg.sh impose MARKETING_VERSION a l archivage depuis la version qu on
# lui passe, et la chaine lui passe la version de l etiquette. La coherence est
# donc structurelle, a condition que ce passage existe vraiment.
if grep -q 'MARKETING_VERSION="\$VERSION"' "$RACINE/scripts/build-dmg.sh"; then
  reussi "La version de l etiquette est imposee a l archivage"
else
  echoue "L archivage n impose pas la version, l application peut mentir sur son numero"
fi

if grep -Eq '\^\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$' "$FLUX"; then
  reussi "Le flux valide la version avant de s en servir"
else
  echoue "Le flux ne valide pas la version recue"
fi

# ---------------------------------------------------------------------------
titre "Resultat"
# ---------------------------------------------------------------------------
if [ "$ECHECS" -gt 0 ]; then
  printf '\033[31m%d test(s) de publication en echec.\033[0m\n\n' "$ECHECS"
  exit 1
fi

printf '\033[32mTous les tests de publication sont passes.\033[0m\n\n'
exit 0
