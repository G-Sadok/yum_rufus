#!/usr/bin/env bash
#
# lib-boucle.sh
# Fonctions partagees par les scripts de la boucle.
# Ce fichier ne s execute pas seul, il se source.

# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ "${SANS_COULEUR:-0}" != "1" ]; then
  C_ROUGE=$'\033[31m'; C_VERT=$'\033[32m'; C_JAUNE=$'\033[33m'
  C_BLEU=$'\033[36m';  C_GRIS=$'\033[90m'; C_GRAS=$'\033[1m'; C_FIN=$'\033[0m'
else
  C_ROUGE=''; C_VERT=''; C_JAUNE=''; C_BLEU=''; C_GRIS=''; C_GRAS=''; C_FIN=''
fi

horodatage() { date -u +%Y-%m-%dT%H:%M:%SZ; }
heure()      { date +%H:%M:%S; }

_journaliser() {
  local niveau="$1"; shift
  if [ -n "${FICHIER_JOURNAL:-}" ]; then
    printf '%s [%s] %s\n' "$(horodatage)" "$niveau" "$*" >> "$FICHIER_JOURNAL"
  fi
}

info()    { printf '%s[%s]%s %s\n'      "$C_GRIS" "$(heure)" "$C_FIN" "$*"; _journaliser INFO "$*"; }
succes()  { printf '%s[%s] %s%s\n'      "$C_VERT" "$(heure)" "$*" "$C_FIN"; _journaliser OK "$*"; }
alerte()  { printf '%s[%s] %s%s\n'      "$C_JAUNE" "$(heure)" "$*" "$C_FIN"; _journaliser ALERTE "$*"; }
erreur()  { printf '%s[%s] %s%s\n' "$C_ROUGE" "$(heure)" "$*" "$C_FIN" >&2; _journaliser ERREUR "$*"; }

titre() {
  printf '\n%s%s%s\n' "$C_BLEU$C_GRAS" "$*" "$C_FIN"
  printf '%s%s%s\n' "$C_GRIS" "$(printf '%.0s-' $(seq 1 72))" "$C_FIN"
  _journaliser TITRE "$*"
}

banniere() {
  printf '\n%s%s\n' "$C_BLEU$C_GRAS" "$(printf '%.0s=' $(seq 1 72))"
  printf '%s\n' "$*"
  printf '%s%s\n\n' "$(printf '%.0s=' $(seq 1 72))" "$C_FIN"
  _journaliser BANNIERE "$*"
}

# ---------------------------------------------------------------------------
# Portabilite
# ---------------------------------------------------------------------------

# macOS n a pas timeout par defaut, coreutils fournit gtimeout.
avec_delai() {
  local secondes="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --preserve-status "$secondes" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout --preserve-status "$secondes" "$@"
  else
    "$@"
  fi
}

delai_disponible() {
  command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Backlog
# ---------------------------------------------------------------------------
bl() { jq -r "$1" "$BACKLOG"; }

fiche_de() { jq -c --arg id "$1" '.features[] | select(.id == $id)' "$BACKLOG"; }

statut_de() { jq -r --arg id "$1" '.features[] | select(.id == $id) | .statut' "$BACKLOG"; }

definir_statut() {
  local id="$1" statut="$2" tmp
  tmp="$(mktemp)"
  jq --arg id "$id" --arg s "$statut" --arg d "$(horodatage)" \
    '(.features[] | select(.id == $id) | .statut) = $s
     | (.features[] | select(.id == $id) | .modifie_le) = $d' \
    "$BACKLOG" > "$tmp" && mv "$tmp" "$BACKLOG"
}

noter_echec() {
  local id="$1" raison="$2" tmp
  tmp="$(mktemp)"
  jq --arg id "$id" --arg r "$raison" \
    '(.features[] | select(.id == $id) | .derniere_erreur) = $r' \
    "$BACKLOG" > "$tmp" && mv "$tmp" "$BACKLOG"
}

prochaine_a_faire() {
  jq -r 'first(.features[] | select(.statut == "a_faire")) | .id // empty' "$BACKLOG"
}

compte_statut() {
  jq -r --arg s "$1" '[.features[] | select(.statut == $s)] | length' "$BACKLOG"
}

dependances_pretes() {
  local id="$1" dep statut
  for dep in $(jq -r --arg id "$id" \
      '.features[] | select(.id == $id) | .depend_de[]?' "$BACKLOG"); do
    statut="$(statut_de "$dep")"
    [ "$statut" = "termine" ] || { echo "$dep"; return 1; }
  done
  return 0
}

# ---------------------------------------------------------------------------
# Etat de la boucle, pour la reprise
# ---------------------------------------------------------------------------
lire_etat() {
  [ -f "$ETAT" ] || printf '{}' > "$ETAT"
  jq -r --arg k "$1" '.[$k] // empty' "$ETAT"
}

ecrire_etat() {
  local tmp; tmp="$(mktemp)"
  [ -f "$ETAT" ] || printf '{}' > "$ETAT"
  jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$ETAT" > "$tmp" && mv "$tmp" "$ETAT"
}

ajouter_cout() {
  local ajout="${1:-0}" total
  total="$(lire_etat cout_total)"
  total="${total:-0}"
  total="$(awk -v a="$total" -v b="$ajout" 'BEGIN { printf "%.4f", a + b }')"
  ecrire_etat cout_total "$total"
  echo "$total"
}

# Compare deux nombres decimaux, renvoie 0 si le premier depasse le second
depasse() {
  [ "$(awk -v a="$1" -v b="$2" 'BEGIN { print (a > b) ? 1 : 0 }')" = "1" ]
}

# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------
arbre_propre()      { [ -z "$(git status --porcelain)" ]; }
branche_courante()  { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo inconnue; }
tete_courante()     { git rev-parse HEAD 2>/dev/null || echo aucune; }

# Y a t il eu un changement reel depuis un point de reference.
# Les fichiers de pilotage de la boucle ne comptent pas : boucle-demarrer.sh
# modifie backlog.json a chaque ouverture, ce qui rendrait l arbre sale en
# permanence et masquerait une session qui tourne a vide.
progression_depuis() {
  local reference="$1" modifs
  modifs="$(git status --porcelain -- . ':(exclude)loop' 2>/dev/null \
            || git status --porcelain | grep -v '^.. loop/')"
  [ -n "$modifs" ] && return 0
  [ "$(tete_courante)" != "$reference" ] && return 0
  return 1
}
