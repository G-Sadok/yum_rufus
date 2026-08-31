#!/usr/bin/env bash
#
# budgets-performance.sh
# Mesure les sept budgets de la section 12 et echoue des qu un seul deborde.
#
# Le corpus est genere s il manque. Une campagne sur un corpus absent rendrait
# des durees minuscules et des budgets tenus, ce qui est le pire resultat
# possible : vert et faux. La campagne le refuse de son cote, ce script se
# contente de lui eviter le refus.
#
# La mesure ne vit pas dans `swift test` et c est voulu. Deux des sept budgets
# sont des budgets memoire, et une empreinte se mesure sur un processus entier :
# les mesurer au milieu de deux cent cinquante suites reviendrait a mesurer
# l empreinte des autres suites. Chaque budget est donc mesure dans un processus
# qui n a rien fait d autre.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

if [ ! -f "Tests/JeuDeDonnees/genere/bibliotheque.sqlite" ]; then
  echo "Corpus absent, generation prealable"
  ./scripts/generer-jeu-de-test.sh
fi

echo "Construction de la campagne"
swift build --package-path Packages --product mesurer-budgets -c release

BINAIRE="$(swift build --package-path Packages -c release --show-bin-path)/mesurer-budgets"

if [ ! -x "$BINAIRE" ]; then
  echo "Executable introuvable apres construction : $BINAIRE" >&2
  exit 1
fi

"$BINAIRE" mesurer "$RACINE"
