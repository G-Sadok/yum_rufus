#!/usr/bin/env bash
#
# boucle-terminer.sh
# Verifie, commite, pousse, ouvre une pull request, la fusionne,
# marque la fonctionnalite comme terminee et enchaine sur la suivante.
#
# Usage :
#   ./scripts/boucle-terminer.sh                     fusion automatique
#   ./scripts/boucle-terminer.sh --sans-fusion       laisse la pull request ouverte
#   ./scripts/boucle-terminer.sh --sans-enchainer    ne demarre pas la suivante

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$RACINE/loop/backlog.json"
BRANCHE_PRINCIPALE="$(jq -r '.meta.branche_principale' "$BACKLOG")"

FUSIONNER=1
ENCHAINER=1
for ARG in "$@"; do
  case "$ARG" in
    --sans-fusion)    FUSIONNER=0 ;;
    --sans-enchainer) ENCHAINER=0 ;;
  esac
done

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
bleu()  { printf '\033[36m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# Retrouver la fonctionnalite en cours
# ---------------------------------------------------------------------------
ID="$(jq -r 'first(.features[] | select(.statut == "en_cours")) | .id // empty' "$BACKLOG")"
if [ -z "$ID" ]; then
  rouge "Aucune fonctionnalite en cours."
  jaune "Demarre en avec ./scripts/boucle-demarrer.sh"
  exit 1
fi

FICHE="$(jq -r --arg id "$ID" '.features[] | select(.id == $id)' "$BACKLOG")"
SLUG="$(echo "$FICHE" | jq -r '.slug')"
TITRE="$(echo "$FICHE" | jq -r '.titre')"
ETAPE="$(echo "$FICHE" | jq -r '.etape')"
BRANCHE="$(git rev-parse --abbrev-ref HEAD)"

bleu "Cloture de $ID sur la branche $BRANCHE"

# ---------------------------------------------------------------------------
# Verifications bloquantes
# ---------------------------------------------------------------------------
bleu "Lancement des verifications"
if ! "$RACINE/scripts/verifications.sh"; then
  rouge "Les verifications ont echoue. La fonctionnalite reste en cours."
  jaune "Corrige, puis relance ./scripts/boucle-terminer.sh"
  exit 1
fi
vert "Verifications passees"

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------
if [ -z "$(git status --porcelain)" ]; then
  jaune "Aucun changement a commiter. La fonctionnalite est peut etre deja commitee."
else
  git add -A

  MESSAGE_TMP="$(mktemp)"
  {
    echo "feat($ID): $TITRE"
    echo ""
    echo "$(echo "$FICHE" | jq -r '.description')"
    echo ""
    echo "Criteres d acceptation valides :"
    echo "$FICHE" | jq -r '.criteres[] | "  - " + .'
    echo ""
    echo "Etape $ETAPE du plan de livraison."
  } > "$MESSAGE_TMP"

  git commit --quiet --file "$MESSAGE_TMP"
  rm -f "$MESSAGE_TMP"
  vert "Commit cree"
fi

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
bleu "Envoi vers origin"
git push --quiet -u origin "$BRANCHE"
vert "Branche poussee"

# ---------------------------------------------------------------------------
# Pull request
# ---------------------------------------------------------------------------
CORPS_TMP="$(mktemp)"
{
  echo "## $TITRE"
  echo ""
  echo "$(echo "$FICHE" | jq -r '.description')"
  echo ""
  echo "### Criteres d acceptation"
  echo "$FICHE" | jq -r '.criteres[] | "- [x] " + .'
  echo ""
  echo "### Competences mobilisees"
  echo "$FICHE" | jq -r '.skills[] | "- " + .'
  echo ""
  echo "### Controles automatiques"
  echo "- [x] Compilation sans avertissement"
  echo "- [x] Tests unitaires et d integration"
  echo "- [x] Analyse statique"
  echo "- [x] Absence de tiret cadratin"
  echo "- [x] Absence de valeur visuelle en dur"
  echo "- [x] Absence de chaine en dur dans les vues"
  echo ""
  echo "Identifiant backlog : $ID, etape $ETAPE."
} > "$CORPS_TMP"

if gh pr view "$BRANCHE" >/dev/null 2>&1; then
  jaune "Une pull request existe deja pour cette branche."
else
  gh pr create \
    --base "$BRANCHE_PRINCIPALE" \
    --head "$BRANCHE" \
    --title "feat($ID): $TITRE" \
    --body-file "$CORPS_TMP"
  vert "Pull request creee"
fi
rm -f "$CORPS_TMP"

# ---------------------------------------------------------------------------
# Fusion
# ---------------------------------------------------------------------------
if [ "$FUSIONNER" -eq 1 ]; then
  bleu "Attente des controles d integration continue"
  if ! gh pr checks "$BRANCHE" --watch --fail-fast; then
    rouge "Les controles distants ont echoue. La pull request reste ouverte."
    exit 1
  fi

  gh pr merge "$BRANCHE" --squash --delete-branch
  vert "Pull request fusionnee et branche supprimee"

  git checkout "$BRANCHE_PRINCIPALE" --quiet
  git pull --ff-only origin "$BRANCHE_PRINCIPALE" --quiet
else
  jaune "Fusion non demandee, la pull request reste ouverte."
fi

# ---------------------------------------------------------------------------
# Marquer terminee
# ---------------------------------------------------------------------------
TMP="$(mktemp)"
jq --arg id "$ID" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '(.features[] | select(.id == $id) | .statut) = "termine"
   | (.features[] | select(.id == $id) | .termine_le) = $date' \
  "$BACKLOG" > "$TMP"
mv "$TMP" "$BACKLOG"

if [ "$FUSIONNER" -eq 1 ]; then
  git add "$BACKLOG"
  git commit --quiet -m "chore($ID): marquer la fonctionnalite comme terminee"
  git push --quiet origin "$BRANCHE_PRINCIPALE"
fi

TOTAL="$(jq -r '.features | length' "$BACKLOG")"
FAITS="$(jq -r '[.features[] | select(.statut == "termine")] | length' "$BACKLOG")"
vert "$ID termine. Avancement : $FAITS sur $TOTAL."

# ---------------------------------------------------------------------------
# Enchainer
# ---------------------------------------------------------------------------
RESTANT="$(jq -r '[.features[] | select(.statut == "a_faire")] | length' "$BACKLOG")"

if [ "$RESTANT" -eq 0 ]; then
  cat <<'FIN'

===========================================================================
BACKLOG TERMINE
===========================================================================
Toutes les fonctionnalites sont livrees.

Publication de la version :
  1. ./scripts/build-dmg.sh                 verification locale du DMG
  2. git tag -a v1.0.0 -m "Version 1.0.0"
  3. git push origin v1.0.0

L etiquette declenche la chaine de publication GitHub qui produit
le DMG signe, sa somme de controle et les notes de version.
===========================================================================

FIN
  exit 0
fi

if [ "$ENCHAINER" -eq 1 ]; then
  bleu "Enchainement sur la fonctionnalite suivante"
  exec "$RACINE/scripts/boucle-demarrer.sh"
else
  jaune "Enchainement non demande. Lance ./scripts/boucle-demarrer.sh quand tu veux."
fi
