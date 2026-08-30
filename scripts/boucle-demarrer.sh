#!/usr/bin/env bash
#
# boucle-demarrer.sh
# Selectionne la prochaine fonctionnalite du backlog, verifie ses dependances,
# cree la branche de travail et affiche la fiche de mission.
#
# Usage :
#   ./scripts/boucle-demarrer.sh            prend la prochaine fonctionnalite a faire
#   ./scripts/boucle-demarrer.sh F014       force une fonctionnalite precise

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$RACINE/loop/backlog.json"
BRANCHE_PRINCIPALE="$(jq -r '.meta.branche_principale' "$BACKLOG")"
PREFIXE="$(jq -r '.meta.prefixe_branche' "$BACKLOG")"

rouge()  { printf '\033[31m%s\033[0m\n' "$1"; }
vert()   { printf '\033[32m%s\033[0m\n' "$1"; }
jaune()  { printf '\033[33m%s\033[0m\n' "$1"; }
bleu()   { printf '\033[36m%s\033[0m\n' "$1"; }

command -v jq >/dev/null 2>&1 || { rouge "jq est requis. Installe le avec brew install jq"; exit 1; }
# gh ne sert plus au cycle : la fusion se fait par pull, sans pull request.
# Il reste utile pour la publication de la release.

# ---------------------------------------------------------------------------
# Verifier qu aucune fonctionnalite n est deja en cours
# ---------------------------------------------------------------------------
EN_COURS="$(jq -r '[.features[] | select(.statut == "en_cours")] | length' "$BACKLOG")"
if [ "$EN_COURS" -gt 0 ]; then
  ID_EN_COURS="$(jq -r '.features[] | select(.statut == "en_cours") | .id' "$BACKLOG")"
  rouge "La fonctionnalite $ID_EN_COURS est deja en cours."
  jaune "Termine la avec ./scripts/boucle-terminer.sh ou debloque la avec ./scripts/boucle-statut.sh --debloquer $ID_EN_COURS"
  exit 1
fi

# ---------------------------------------------------------------------------
# Selectionner la fonctionnalite
# ---------------------------------------------------------------------------
if [ $# -ge 1 ]; then
  ID="$1"
  EXISTE="$(jq -r --arg id "$ID" '[.features[] | select(.id == $id)] | length' "$BACKLOG")"
  if [ "$EXISTE" -eq 0 ]; then
    rouge "La fonctionnalite $ID n existe pas dans le backlog."
    exit 1
  fi
else
  ID="$(jq -r 'first(.features[] | select(.statut == "a_faire")) | .id // empty' "$BACKLOG")"
  if [ -z "$ID" ]; then
    vert "Toutes les fonctionnalites sont terminees."
    jaune "Lance la publication avec ./scripts/build-dmg.sh puis une etiquette de version."
    exit 0
  fi
fi

FICHE="$(jq -r --arg id "$ID" '.features[] | select(.id == $id)' "$BACKLOG")"
SLUG="$(echo "$FICHE" | jq -r '.slug')"
TITRE="$(echo "$FICHE" | jq -r '.titre')"
ETAPE="$(echo "$FICHE" | jq -r '.etape')"

# ---------------------------------------------------------------------------
# Verifier les dependances
# ---------------------------------------------------------------------------
MANQUANTES=""
for DEP in $(echo "$FICHE" | jq -r '.depend_de[]?'); do
  STATUT_DEP="$(jq -r --arg id "$DEP" '.features[] | select(.id == $id) | .statut' "$BACKLOG")"
  if [ "$STATUT_DEP" != "termine" ]; then
    MANQUANTES="$MANQUANTES $DEP"
  fi
done

if [ -n "$MANQUANTES" ]; then
  rouge "Dependances non terminees :$MANQUANTES"
  jaune "Termine les d abord, ou force avec FORCER_DEPENDANCES=1"
  if [ "${FORCER_DEPENDANCES:-0}" != "1" ]; then
    exit 1
  fi
  jaune "Dependances forcees, tu prends le risque."
fi

# ---------------------------------------------------------------------------
# Verifier que le DESIGN-SPEC existe si la fonctionnalite touche au design
# ---------------------------------------------------------------------------
BESOIN_DESIGN="$(echo "$FICHE" | jq -r '[.skills[] | select(. == "design-systeme")] | length')"
if [ "$BESOIN_DESIGN" -gt 0 ] && [ ! -f "$RACINE/DESIGN-SPEC.md" ]; then
  rouge "Cette fonctionnalite touche a l interface mais DESIGN-SPEC.md est absent."
  jaune "Fais produire le fichier par Claude Design avant de continuer. C est bloquant et c est voulu."
  exit 1
fi

# ---------------------------------------------------------------------------
# Preparer la branche
# ---------------------------------------------------------------------------
BRANCHE="${PREFIXE}${ID}-${SLUG}"

if [ -n "$(git status --porcelain)" ]; then
  rouge "L arbre de travail n est pas propre. Commite ou remise tes changements."
  git status --short
  exit 1
fi

bleu "Mise a jour de $BRANCHE_PRINCIPALE"
git checkout "$BRANCHE_PRINCIPALE" --quiet
git pull --ff-only origin "$BRANCHE_PRINCIPALE" --quiet || jaune "Impossible de recuperer depuis origin, on continue en local."

if git show-ref --verify --quiet "refs/heads/$BRANCHE"; then
  jaune "La branche $BRANCHE existe deja, on la reprend."
  git checkout "$BRANCHE" --quiet

  # Une branche laissee par un incident precedent peut avoir des dizaines de
  # commits de retard. Reprise telle quelle, la fonctionnalite se developpe sur
  # une base ou les precedentes n existent pas, et le defaut ne se voit qu a la
  # fusion, ou plus tard.
  if [ -n "$(git log --oneline "$BRANCHE".."$BRANCHE_PRINCIPALE" 2>/dev/null)" ]; then
    bleu "Elle est en retard sur $BRANCHE_PRINCIPALE, mise a jour"
    if ! git merge --no-edit "$BRANCHE_PRINCIPALE" --quiet; then
      git merge --abort 2>/dev/null
      rouge "La mise a jour de $BRANCHE depuis $BRANCHE_PRINCIPALE est en conflit."
      rouge "Resous le conflit, ou supprime la branche pour repartir a neuf."
      exit 1
    fi
  fi
else
  git checkout -b "$BRANCHE" --quiet
  vert "Branche creee : $BRANCHE"
fi

# ---------------------------------------------------------------------------
# Marquer en cours
# ---------------------------------------------------------------------------
TMP="$(mktemp)"
jq --arg id "$ID" '(.features[] | select(.id == $id) | .statut) = "en_cours"' "$BACKLOG" > "$TMP"
mv "$TMP" "$BACKLOG"

# ---------------------------------------------------------------------------
# Afficher la fiche de mission
# ---------------------------------------------------------------------------
TOTAL="$(jq -r '.features | length' "$BACKLOG")"
FAITS="$(jq -r '[.features[] | select(.statut == "termine")] | length' "$BACKLOG")"

cat <<FIN

===========================================================================
FICHE DE MISSION
===========================================================================
Identifiant   : $ID
Titre         : $TITRE
Etape         : $ETAPE
Branche       : $BRANCHE
Avancement    : $FAITS sur $TOTAL fonctionnalites terminees

DESCRIPTION
$(echo "$FICHE" | jq -r '.description')

COMPETENCES A MOBILISER
$(echo "$FICHE" | jq -r '.skills[] | "  /skill " + .')

CRITERES D ACCEPTATION
$(echo "$FICHE" | jq -r '.criteres[] | "  [ ] " + .')

RAPPELS NON NEGOCIABLES
  [ ] Aucun tiret cadratin nulle part
  [ ] Aucune valeur visuelle en dur hors du paquet DesignSystem
  [ ] Aucune chaine en dur dans les vues
  [ ] Aucun import SwiftUI dans un paquet autre que DesignSystem
  [ ] Tests ecrits avant ou avec le code, jamais apres coup

PROCHAINE ETAPE
  Developpe, puis lance ./scripts/boucle-terminer.sh
===========================================================================

FIN
