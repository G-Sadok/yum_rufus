#!/usr/bin/env bash
#
# boucle-statut.sh
# Affiche l avancement, et permet de debloquer ou de reinitialiser une fonctionnalite.
#
# Usage :
#   ./scripts/boucle-statut.sh                    tableau d avancement
#   ./scripts/boucle-statut.sh --detail           detail par etape
#   ./scripts/boucle-statut.sh --bloquer F014     marque une fonctionnalite bloquee
#   ./scripts/boucle-statut.sh --debloquer F014   la remet a faire
#   ./scripts/boucle-statut.sh --reinitialiser    remet tout a faire, demande confirmation

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$RACINE/loop/backlog.json"

vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
rouge() { printf '\033[31m%s\033[0m\n' "$1"; }

modifier_statut() {
  local ID="$1" NOUVEAU="$2"
  local TMP; TMP="$(mktemp)"
  jq --arg id "$ID" --arg s "$NOUVEAU" \
    '(.features[] | select(.id == $id) | .statut) = $s' "$BACKLOG" > "$TMP"
  mv "$TMP" "$BACKLOG"
  vert "$ID est maintenant : $NOUVEAU"
}

case "${1:-}" in
  --bloquer)
    modifier_statut "${2:?identifiant requis}" "bloque"; exit 0 ;;
  --debloquer)
    modifier_statut "${2:?identifiant requis}" "a_faire"; exit 0 ;;
  --reinitialiser)
    read -r -p "Remettre les 67 fonctionnalites a faire. Confirmer avec oui : " REPONSE
    if [ "$REPONSE" = "oui" ]; then
      TMP="$(mktemp)"
      jq '(.features[].statut) = "a_faire" | del(.features[].termine_le)' "$BACKLOG" > "$TMP"
      mv "$TMP" "$BACKLOG"
      vert "Backlog reinitialise"
    else
      jaune "Annule"
    fi
    exit 0 ;;
esac

TOTAL="$(jq -r '.features | length' "$BACKLOG")"
FAITS="$(jq -r '[.features[] | select(.statut == "termine")] | length' "$BACKLOG")"
COURS="$(jq -r '[.features[] | select(.statut == "en_cours")] | length' "$BACKLOG")"
BLOQ="$(jq -r '[.features[] | select(.statut == "bloque")] | length' "$BACKLOG")"
RESTE=$((TOTAL - FAITS - COURS - BLOQ))

POURCENT=$((FAITS * 100 / TOTAL))
REMPLI=$((POURCENT / 4))
VIDE=$((25 - REMPLI))
BARRE="$(printf '%*s' "$REMPLI" '' | tr ' ' '#')$(printf '%*s' "$VIDE" '' | tr ' ' '.')"

cat <<FIN

===========================================================================
AVANCEMENT DU PROJET
===========================================================================
  [$BARRE] $POURCENT pour cent

  Terminees   : $FAITS
  En cours    : $COURS
  Bloquees    : $BLOQ
  A faire     : $RESTE
  Total       : $TOTAL
===========================================================================
FIN

if [ "$COURS" -gt 0 ]; then
  jaune "En cours :"
  jq -r '.features[] | select(.statut == "en_cours") | "  " + .id + "  " + .titre' "$BACKLOG"
fi

if [ "$BLOQ" -gt 0 ]; then
  rouge "Bloquees :"
  jq -r '.features[] | select(.statut == "bloque") | "  " + .id + "  " + .titre' "$BACKLOG"
fi

if [ "${1:-}" = "--detail" ]; then
  echo ""
  jq -r '
    def marque:
      if   . == "termine"  then "[x]"
      elif . == "en_cours" then "[>]"
      elif . == "bloque"   then "[!]"
      else "[ ]" end;
    .features
    | group_by(.etape)
    | .[]
    | "Etape \(.[0].etape)",
      (.[] | "  " + (.statut | marque) + " " + .id + "  " + .titre),
      ""
  ' "$BACKLOG"
fi

SUIVANTE="$(jq -r 'first(.features[] | select(.statut == "a_faire")) | .id + "  " + .titre // empty' "$BACKLOG")"
if [ -n "$SUIVANTE" ] && [ "$COURS" -eq 0 ]; then
  echo ""
  jaune "Prochaine : $SUIVANTE"
  echo "Demarre avec ./scripts/boucle-demarrer.sh"
fi
echo ""
