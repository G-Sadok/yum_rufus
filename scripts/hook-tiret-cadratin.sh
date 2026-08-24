#!/usr/bin/env bash
#
# hook-tiret-cadratin.sh
# Hook PostToolUse. Signale a Claude Code tout tiret cadratin introduit
# dans un fichier qui vient d etre ecrit ou modifie.
#
# Sortie sur stderr avec code 2 : Claude Code recoit le message et corrige.

set -uo pipefail

ENTREE="$(cat)"
FICHIER="$(printf '%s' "$ENTREE" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

[ -z "$FICHIER" ] && exit 0
[ -f "$FICHIER" ] || exit 0

case "$FICHIER" in
  *.swift|*.md|*.json|*.yml|*.yaml|*.sh|*.strings|*.xcstrings|*.html|*.txt) ;;
  *) exit 0 ;;
esac

# bash 3.2, celui de macOS, ne developpe pas l echappement \u dans $'...'.
# Le motif cherchait alors le texte u2014, jamais le caractere U+2014.
# On le construit depuis ses trois octets UTF-8.
TIRET_CADRATIN="$(printf '\342\200\224')"

LIGNES="$(grep -nF "$TIRET_CADRATIN" "$FICHIER" 2>/dev/null || true)"

if [ -n "$LIGNES" ]; then
  {
    echo "Regle de redaction du projet enfreinte dans $FICHIER."
    echo "Le caractere tiret cadratin est interdit partout dans ce depot."
    echo ""
    echo "Lignes concernees :"
    echo "$LIGNES" | head -20
    echo ""
    echo "Remplace le par une virgule, un deux points, une parenthese, ou coupe la phrase."
  } >&2
  exit 2
fi

exit 0
