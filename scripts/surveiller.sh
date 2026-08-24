#!/usr/bin/env bash
#
# surveiller.sh
# Suit l avancement de la boucle depuis un second terminal et previent quand
# elle se termine, se bloque, ou cesse d avancer.
#
# Usage :
#   ./scripts/surveiller.sh                 rafraichit toutes les 60 secondes
#   INTERVALLE=30 ./scripts/surveiller.sh   change la cadence
#   SEUIL_INACTIF=45 ./scripts/surveiller.sh  alerte apres 45 minutes sans progres

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"
BACKLOG="$RACINE/loop/backlog.json"
ETAT="$RACINE/loop/etat-boucle.json"

INTERVALLE="${INTERVALLE:-60}"
SEUIL_INACTIF="${SEUIL_INACTIF:-40}"

notifier() {
  local titre="$1" texte="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$texte\" with title \"$titre\" sound name \"Glass\"" 2>/dev/null
  fi
  printf '\a'
}

compte() { jq -r --arg s "$1" '[.features[] | select(.statut == $s)] | length' "$BACKLOG" 2>/dev/null || echo 0; }

DERNIER_TERMINE=-1
DERNIER_CHANGEMENT="$(date +%s)"

printf '\033[36mSurveillance de la boucle, Ctrl+C pour arreter\033[0m\n\n'

while true; do
  FAITS="$(compte termine)"
  COURS="$(compte en_cours)"
  BLOQ="$(compte bloque)"
  RESTE="$(compte a_faire)"
  TOTAL=$((FAITS + COURS + BLOQ + RESTE))
  COUT="$(jq -r '.cout_total // "0"' "$ETAT" 2>/dev/null || echo 0)"

  MAINTENANT="$(date +%s)"
  if [ "$FAITS" != "$DERNIER_TERMINE" ]; then
    if [ "$DERNIER_TERMINE" -ge 0 ]; then
      EN_COURS_ID="$(jq -r 'first(.features[] | select(.statut == "en_cours")) | .id // "aucune"' "$BACKLOG")"
      notifier "Boucle : $FAITS sur $TOTAL" "En cours : $EN_COURS_ID, $COUT dollars"
    fi
    DERNIER_TERMINE="$FAITS"
    DERNIER_CHANGEMENT="$MAINTENANT"
  fi

  INACTIF=$(( (MAINTENANT - DERNIER_CHANGEMENT) / 60 ))

  printf '\r\033[K[%s] %s termine, %s en cours, %s bloque, %s restant, %s dollars, %s min sans progres' \
    "$(date +%H:%M:%S)" "$FAITS" "$COURS" "$BLOQ" "$RESTE" "$COUT" "$INACTIF"

  # La boucle a fini
  if [ "$RESTE" -eq 0 ] && [ "$COURS" -eq 0 ]; then
    printf '\n\n'
    if [ "$BLOQ" -gt 0 ]; then
      notifier "Boucle terminee avec $BLOQ blocages" "Intervention requise"
      printf '\033[33mFonctionnalites bloquees :\033[0m\n'
      jq -r '.features[] | select(.statut == "bloque")
        | "  " + .id + "  " + .titre + "\n      " + (.derniere_erreur // "raison non precisee")' "$BACKLOG"
    else
      notifier "Boucle terminee" "$FAITS fonctionnalites livrees, $COUT dollars"
      printf '\033[32mTout est livre. Publication possible.\033[0m\n'
    fi
    exit 0
  fi

  # Plus rien ne bouge depuis trop longtemps
  if [ "$INACTIF" -ge "$SEUIL_INACTIF" ]; then
    printf '\n'
    notifier "Boucle sans progres" "$INACTIF minutes sans fonctionnalite terminee"
    DERNIER_CHANGEMENT="$MAINTENANT"
  fi

  sleep "$INTERVALLE"
done
