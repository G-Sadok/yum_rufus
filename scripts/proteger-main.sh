#!/usr/bin/env bash
#
# proteger-main.sh
# Applique la protection de la branche principale cote GitHub.
#
# Le projet interdit les pull requests et fusionne en local, la boucle pousse
# donc directement sur main. Exiger une pull request casserait la boucle.
# La protection utile est donc celle qui empeche la destruction : pas de
# suppression de la branche, pas de reecriture d historique.
#
# Idempotent : relancer le script met le regle a jour au lieu d en creer une
# seconde. Necessite gh authentifie et un acces reseau.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

BRANCHE_PRINCIPALE="${BRANCHE_PRINCIPALE:-main}"
NOM_REGLE="protection-${BRANCHE_PRINCIPALE}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh n est pas installe. brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh n est pas authentifie. Lance gh auth login" >&2
  exit 1
fi

DEPOT="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

CORPS="$(cat <<JSON
{
  "name": "$NOM_REGLE",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/$BRANCHE_PRINCIPALE"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ]
}
JSON
)"

IDENTIFIANT="$(gh api "repos/$DEPOT/rulesets" --jq \
  ".[] | select(.name == \"$NOM_REGLE\") | .id" 2>/dev/null | head -1 || true)"

if [ -n "$IDENTIFIANT" ]; then
  printf '%s' "$CORPS" | gh api --method PUT "repos/$DEPOT/rulesets/$IDENTIFIANT" \
    --input - >/dev/null
  echo "Regle $NOM_REGLE mise a jour sur $DEPOT."
else
  printf '%s' "$CORPS" | gh api --method POST "repos/$DEPOT/rulesets" \
    --input - >/dev/null
  echo "Regle $NOM_REGLE creee sur $DEPOT."
fi

echo "  suppression de $BRANCHE_PRINCIPALE      refusee"
echo "  reecriture d historique sur $BRANCHE_PRINCIPALE  refusee"
echo "  push direct                              autorise, la boucle en depend"
