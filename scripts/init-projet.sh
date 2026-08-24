#!/usr/bin/env bash
#
# init-projet.sh
# A lancer une seule fois, avant la premiere iteration de la boucle.
# Verifie les prerequis, initialise le depot, cree le depot GitHub,
# protege la branche principale et rend les scripts executables.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }
jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
etape() { printf '\n\033[36m>> %s\033[0m\n' "$1"; }

MANQUE=0

# ---------------------------------------------------------------------------
etape "1. Verification des prerequis"
# ---------------------------------------------------------------------------
verifier() {
  if command -v "$1" >/dev/null 2>&1; then
    vert "  $1 present"
  else
    rouge "  $1 absent    installe avec : $2"
    MANQUE=1
  fi
}

verifier git    "xcode-select --install"
verifier gh     "brew install gh"
verifier jq     "brew install jq"
verifier xcodebuild "installe Xcode depuis l App Store"

if command -v swiftlint >/dev/null 2>&1; then
  vert "  swiftlint present"
else
  jaune "  swiftlint absent, recommande : brew install swiftlint"
fi

if command -v swiftformat >/dev/null 2>&1; then
  vert "  swiftformat present"
else
  jaune "  swiftformat absent, recommande : brew install swiftformat"
fi

if [ "$MANQUE" -eq 1 ]; then
  rouge "Des prerequis manquent. Installe les puis relance ce script."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  rouge "gh n est pas authentifie. Lance : gh auth login"
  exit 1
fi
vert "  gh authentifie"

# ---------------------------------------------------------------------------
etape "2. Rendre les scripts executables"
# ---------------------------------------------------------------------------
chmod +x scripts/*.sh
vert "  Scripts executables"

# ---------------------------------------------------------------------------
etape "3. Initialisation du depot"
# ---------------------------------------------------------------------------
if [ -d .git ]; then
  jaune "  Depot deja initialise"
else
  git init --quiet --initial-branch=main
  vert "  Depot initialise sur la branche main"
fi

if [ ! -f .gitignore ]; then
  cat > .gitignore <<'FIN'
# Xcode
build/
DerivedData/
*.xcuserstate
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/

# Swift Package Manager
.build/
.swiftpm/

# Secrets et signature
.env
*.p12
*.mobileprovision
*.cer

# Claude Code, configuration locale non partagee
.claude/settings.local.json

# Etat volatil de la boucle, ne doit jamais etre suivi par git
# sinon un checkout l ecrase en pleine execution
loop/etat-boucle.json
loop/verdict.json
loop/journal/

# Systeme
.DS_Store

# Jeux de test volumineux
Tests/JeuDeDonnees/genere/
FIN
  vert "  .gitignore cree"
else
  jaune "  .gitignore deja present"
fi

# ---------------------------------------------------------------------------
etape "4. Premier commit"
# ---------------------------------------------------------------------------
if [ -z "$(git log --oneline 2>/dev/null || true)" ]; then
  git add -A
  git commit --quiet -m "chore: socle du projet, boucle de developpement et documentation"
  vert "  Premier commit cree"
else
  jaune "  Le depot a deja des commits"
fi

# ---------------------------------------------------------------------------
etape "5. Depot distant"
# ---------------------------------------------------------------------------
if git remote get-url origin >/dev/null 2>&1; then
  jaune "  Le depot distant est deja configure : $(git remote get-url origin)"
else
  read -r -p "  Nom du depot GitHub a creer, par exemple moncompte/yum : " DEPOT
  read -r -p "  Depot prive, repondre oui ou non : " PRIVE

  if [ "$PRIVE" = "oui" ]; then
    VISIBILITE="--private"
  else
    VISIBILITE="--public"
  fi

  gh repo create "$DEPOT" $VISIBILITE --source=. --remote=origin --push
  vert "  Depot cree et pousse"
fi

# ---------------------------------------------------------------------------
etape "6. Protection de la branche principale"
# ---------------------------------------------------------------------------
DEPOT_ACTUEL="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"

if [ -n "$DEPOT_ACTUEL" ]; then
  if gh api -X PUT "repos/$DEPOT_ACTUEL/branches/main/protection" \
      -H "Accept: application/vnd.github+json" \
      -f "required_status_checks[strict]=true" \
      -f "required_status_checks[contexts][]=Verifications" \
      -F "enforce_admins=false" \
      -F "required_pull_request_reviews[required_approving_review_count]=0" \
      -F "restrictions=null" \
      >/dev/null 2>&1; then
    vert "  Branche main protegee"
  else
    jaune "  Protection de branche non appliquee."
    jaune "  Sur un depot prive, elle demande un abonnement GitHub payant."
    jaune "  Les hooks locaux protegent deja main de leur cote."
  fi
fi

# ---------------------------------------------------------------------------
etape "7. Etat du backlog"
# ---------------------------------------------------------------------------
TOTAL="$(jq -r '.features | length' loop/backlog.json)"
vert "  $TOTAL fonctionnalites chargees"

# ---------------------------------------------------------------------------
etape "8. Verification du prerequis design"
# ---------------------------------------------------------------------------
if [ -f DESIGN-SPEC.md ]; then
  vert "  DESIGN-SPEC.md present, la boucle peut traiter les fonctionnalites d interface"
else
  jaune "  DESIGN-SPEC.md absent."
  jaune "  Les fonctionnalites d interface seront bloquees jusqu a ce qu il arrive."
  jaune "  Fais le produire par Claude Design avec le cahier des charges design."
fi

cat <<'FIN'

===========================================================================
PROJET INITIALISE
===========================================================================

Pour demarrer :

  claude

Puis dans Claude Code :

  Lis CLAUDE.md, charge la competence boucle-projet, et demarre la
  premiere fonctionnalite du backlog.

Ou en ligne de commande :

  ./scripts/boucle-statut.sh
  ./scripts/boucle-demarrer.sh

===========================================================================

FIN
