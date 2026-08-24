#!/usr/bin/env bash
#
# boucle-terminer.sh
# Verifie, commite, pousse la branche de fonctionnalite, puis bascule sur la
# branche principale et l y integre par un pull, sans passer par une pull request.
#
# Usage :
#   ./scripts/boucle-terminer.sh                    cycle complet
#   ./scripts/boucle-terminer.sh --sans-fusion      pousse seulement, n integre pas
#   ./scripts/boucle-terminer.sh --sans-enchainer   n ouvre pas la fonctionnalite suivante
#   ./scripts/boucle-terminer.sh --garder-branche   ne supprime pas la branche apres fusion
#
# Reglages :
#   STRATEGIE_FUSION=no-ff   no-ff pour un commit de fusion par fonctionnalite,
#                            ff pour une avance rapide quand elle est possible

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$RACINE/loop/backlog.json"
BRANCHE_PRINCIPALE="$(jq -r '.meta.branche_principale' "$BACKLOG")"
STRATEGIE_FUSION="${STRATEGIE_FUSION:-no-ff}"

# Un editeur qui s ouvre bloquerait une boucle sans surveillance
export GIT_MERGE_AUTOEDIT=no
export GIT_EDITOR=true

FUSIONNER=1
ENCHAINER=1
GARDER_BRANCHE=0
for ARG in "$@"; do
  case "$ARG" in
    --sans-fusion)    FUSIONNER=0 ;;
    --sans-enchainer) ENCHAINER=0 ;;
    --garder-branche) GARDER_BRANCHE=1 ;;
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
  jaune "Demarre en une avec ./scripts/boucle-demarrer.sh"
  exit 1
fi

FICHE="$(jq -r --arg id "$ID" '.features[] | select(.id == $id)' "$BACKLOG")"
TITRE="$(echo "$FICHE" | jq -r '.titre')"
ETAPE="$(echo "$FICHE" | jq -r '.etape')"
BRANCHE="$(git rev-parse --abbrev-ref HEAD)"

if [ "$BRANCHE" = "$BRANCHE_PRINCIPALE" ]; then
  rouge "Tu es sur $BRANCHE_PRINCIPALE, pas sur une branche de fonctionnalite."
  jaune "La cloture doit partir de la branche de travail."
  exit 1
fi

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
  jaune "Aucun changement a commiter, la fonctionnalite est peut etre deja commitee."
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
# Push de la branche de fonctionnalite
# ---------------------------------------------------------------------------
bleu "Envoi de $BRANCHE vers origin"
if git push --quiet -u origin "$BRANCHE"; then
  vert "Branche poussee"
else
  rouge "Le push a echoue. La fonctionnalite reste en cours."
  exit 1
fi

if [ "$FUSIONNER" -eq 0 ]; then
  jaune "Fusion non demandee, la branche reste isolee."
  jaune "Integre la plus tard avec :"
  jaune "  git checkout $BRANCHE_PRINCIPALE && git pull origin $BRANCHE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Integration sur la branche principale
# ---------------------------------------------------------------------------
bleu "Bascule sur $BRANCHE_PRINCIPALE"
if ! git checkout "$BRANCHE_PRINCIPALE" --quiet; then
  rouge "Impossible de basculer sur $BRANCHE_PRINCIPALE."
  exit 1
fi

# Se mettre a jour avant de fusionner, sinon le push sera refuse
bleu "Mise a jour depuis origin/$BRANCHE_PRINCIPALE"
if ! git pull --ff-only --quiet origin "$BRANCHE_PRINCIPALE" 2>/dev/null; then
  jaune "Impossible d avancer en ff depuis origin, $BRANCHE_PRINCIPALE a peut etre diverge."
  jaune "Resous la divergence a la main, puis relance la cloture."
  git checkout "$BRANCHE" --quiet
  exit 1
fi

# Recuperation de la branche de fonctionnalite
bleu "Recuperation de $BRANCHE dans $BRANCHE_PRINCIPALE"

if [ "$STRATEGIE_FUSION" = "ff" ]; then
  OPTIONS_FUSION="--no-edit"
else
  OPTIONS_FUSION="--no-ff --no-edit"
fi

# shellcheck disable=SC2086
if git pull $OPTIONS_FUSION origin "$BRANCHE"; then
  vert "$BRANCHE integree dans $BRANCHE_PRINCIPALE"
else
  rouge "Conflit lors de la recuperation de $BRANCHE."

  if [ -d "$(git rev-parse --git-dir)/MERGE_HEAD" ] || git rev-parse -q --verify MERGE_HEAD >/dev/null; then
    jaune "Fichiers en conflit :"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    git merge --abort 2>/dev/null || true
    vert "Fusion annulee, $BRANCHE_PRINCIPALE est revenue a son etat anterieur."
  fi

  git checkout "$BRANCHE" --quiet 2>/dev/null || true
  jaune "Resous le conflit a la main :"
  jaune "  git checkout $BRANCHE_PRINCIPALE"
  jaune "  git pull origin $BRANCHE"
  jaune "  ... resoudre, puis git commit et git push"
  exit 1
fi

# ---------------------------------------------------------------------------
# Marquer terminee, avant le push pour que le statut parte avec
# ---------------------------------------------------------------------------
TMP="$(mktemp)"
jq --arg id "$ID" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '(.features[] | select(.id == $id) | .statut) = "termine"
   | (.features[] | select(.id == $id) | .termine_le) = $date' \
  "$BACKLOG" > "$TMP"
mv "$TMP" "$BACKLOG"

if [ -n "$(git status --porcelain -- "$BACKLOG")" ]; then
  git add "$BACKLOG"
  git commit --quiet -m "chore($ID): marquer la fonctionnalite comme terminee"
fi

# ---------------------------------------------------------------------------
# Push de la branche principale
# ---------------------------------------------------------------------------
bleu "Envoi de $BRANCHE_PRINCIPALE vers origin"
if git push --quiet origin "$BRANCHE_PRINCIPALE"; then
  vert "$BRANCHE_PRINCIPALE poussee"
else
  rouge "Le push de $BRANCHE_PRINCIPALE a echoue."
  jaune "Cause frequente : la branche est protegee sur GitHub et refuse les"
  jaune "pushs directs. Retire la protection dans Settings, Branches."
  jaune "La fusion locale est faite, seul le push manque."
  exit 1
fi

# ---------------------------------------------------------------------------
# Nettoyage de la branche de fonctionnalite
# ---------------------------------------------------------------------------
if [ "$GARDER_BRANCHE" -eq 0 ]; then
  git branch -d "$BRANCHE" --quiet 2>/dev/null \
    && vert "Branche locale $BRANCHE supprimee" \
    || jaune "Branche locale $BRANCHE conservee, elle n etait pas totalement fusionnee"

  git push --quiet origin --delete "$BRANCHE" 2>/dev/null \
    && vert "Branche distante $BRANCHE supprimee" \
    || jaune "Branche distante $BRANCHE conservee"
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
