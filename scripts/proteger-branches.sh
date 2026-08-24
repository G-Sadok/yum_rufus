#!/usr/bin/env bash
#
# proteger-branches.sh
# Applique la protection de branche sur main et sur dev.
#
# Le script est idempotent. Relance le autant de fois que tu veux, il remet
# simplement la configuration voulue. Il a besoin de gh authentifie avec un
# jeton qui porte le droit d administration du depot.
#
#   ./scripts/proteger-branches.sh
#   ./scripts/proteger-branches.sh proprietaire/depot

set -euo pipefail

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
bleu()  { printf '\033[36m%s\033[0m\n' "$1"; }

if ! command -v gh >/dev/null 2>&1; then
  rouge "gh est absent. Installe le avec brew install gh."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  rouge "gh n est pas authentifie. Lance gh auth login."
  exit 1
fi

DEPOT="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

# Nom du controle d integration continue exige avant toute fusion sur dev.
# Il doit correspondre au champ name du job dans .github/workflows/ci.yml.
CONTROLE_CI="Verifications"

appliquer() {
  BRANCHE="$1"
  CHARGE="$2"

  bleu "Protection de la branche $BRANCHE sur $DEPOT"
  printf '%s' "$CHARGE" | gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/$DEPOT/branches/$BRANCHE/protection" \
    --input - > /dev/null
  vert "Branche $BRANCHE protegee"
}

# main recoit le code par pull request uniquement. Aucun controle distant n est
# exige ici, l integration continue tourne sur dev et le code arrive sur main
# deja verifie. Le nombre de relecteurs est a zero parce que le depot n a qu un
# mainteneur, mais le passage par une pull request reste obligatoire.
#
# enforce_admins reste a false volontairement. Avec un seul mainteneur, le
# mettre a true rendrait toute reparation d urgence impossible. La regle
# "jamais de commit direct sur main" est deja tenue localement par
# scripts/hook-protege-main.sh.
CHARGE_MAIN='{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}'

# dev est la branche d integration. Elle exige le job de verification, sans
# strict, sinon la boucle attendrait une remise a niveau manuelle avant chaque
# fusion. Les pull requests ne demandent pas de relecteur, la boucle fusionne
# elle meme apres que les controles distants sont passes.
CHARGE_DEV="$(cat <<JSON
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["$CONTROLE_CI"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
)"

appliquer "main" "$CHARGE_MAIN"
appliquer "dev" "$CHARGE_DEV"

vert "Protection de branche a jour."
