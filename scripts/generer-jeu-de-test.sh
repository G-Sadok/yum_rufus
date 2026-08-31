#!/usr/bin/env bash
#
# generer-jeu-de-test.sh
# Materialise le corpus de 5000 series et 200000 chapitres de la section 12.
#
# Le corpus n est pas suivi en binaire par le depot : la base pese une
# quarantaine de mega octets et se reconstruit a l identique depuis la graine du
# manifeste. Ce qui est suivi est Tests/JeuDeDonnees/manifeste.json, que ce
# script lit, et le generateur, qui est deterministe.
#
# Les nombres viennent du manifeste et de nulle part ailleurs. Un corpus dont la
# taille se passerait en argument finirait genere a mille series sur une machine
# pressee, et les budgets de la section 12 seraient mesures sur autre chose que
# ce que le cahier demande.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

MANIFESTE="Tests/JeuDeDonnees/manifeste.json"

if [ ! -f "$MANIFESTE" ]; then
  echo "Manifeste introuvable : $MANIFESTE" >&2
  exit 1
fi

echo "Construction du generateur"
swift build --package-path Packages --product mesurer-budgets -c release

BINAIRE="$(swift build --package-path Packages -c release --show-bin-path)/mesurer-budgets"

if [ ! -x "$BINAIRE" ]; then
  echo "Executable introuvable apres construction : $BINAIRE" >&2
  exit 1
fi

"$BINAIRE" generer "$RACINE"
