#!/usr/bin/env bash
#
# installer-hooks-git.sh
# Installe les hooks git versionnes du depot en pointant core.hooksPath sur
# le dossier githooks. A relancer apres un clone, une seule fois par copie
# de travail.
#
# Les hooks vivent dans le depot plutot que dans .git/hooks pour que la regle
# suive le code. Un hook range dans .git/hooks ne suit personne.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

if [ ! -d "githooks" ]; then
  echo "Dossier githooks introuvable." >&2
  exit 1
fi

chmod +x githooks/* 2>/dev/null || true

git config core.hooksPath githooks

echo "Hooks git installes depuis githooks."
echo "  pre-commit  refuse tout tiret cadratin dans les fichiers indexes"
echo "  pre-push    refuse la suppression et le push non fast forward"
echo "              sur main, master et dev"
echo ""
echo "Pour la protection cote GitHub, lance ./scripts/proteger-main.sh"
