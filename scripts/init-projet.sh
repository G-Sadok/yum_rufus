#!/usr/bin/env bash
#
# init-projet.sh
# Prepare la boucle dans un depot, existant ou non.
#
# Il ne cree un depot que s il n y en a pas, ne cree un distant que s il n y en
# a pas, et n ecrase aucun fichier deja present. Il aligne toute la boucle sur
# la branche principale reelle de ton depot.
#
# Usage :
#   ./scripts/init-projet.sh                    detecte la branche courante
#   BRANCHE=dev ./scripts/init-projet.sh        impose la branche principale
#   SANS_QUESTION=1 ./scripts/init-projet.sh    ne pose aucune question

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

BACKLOG="$RACINE/loop/backlog.json"

rouge() { printf '\033[31m  %s\033[0m\n' "$1"; }
vert()  { printf '\033[32m  %s\033[0m\n' "$1"; }
jaune() { printf '\033[33m  %s\033[0m\n' "$1"; }
gris()  { printf '\033[90m  %s\033[0m\n' "$1"; }
etape() { printf '\n\033[36m>> %s\033[0m\n' "$1"; }

demander() {
  local question="$1" defaut="$2" reponse
  if [ "${SANS_QUESTION:-0}" = "1" ]; then
    echo "$defaut"; return
  fi
  read -r -p "  $question [$defaut] : " reponse </dev/tty
  echo "${reponse:-$defaut}"
}

MANQUE=0

# ---------------------------------------------------------------------------
etape "1. Prerequis"
# ---------------------------------------------------------------------------
verifier() {
  if command -v "$1" >/dev/null 2>&1; then
    vert "$1 present"
  else
    rouge "$1 absent, installe avec : $2"
    MANQUE=1
  fi
}

verifier git         "xcode-select --install"
verifier gh          "brew install gh"
verifier jq          "brew install jq"
verifier python3     "fourni avec macOS"
verifier claude      "npm install -g @anthropic-ai/claude-code"
verifier xcodebuild  "installe Xcode depuis l App Store"

for outil in swiftlint swiftformat; do
  if command -v "$outil" >/dev/null 2>&1; then
    vert "$outil present"
  else
    jaune "$outil absent, recommande : brew install $outil"
  fi
done

if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  vert "timeout present"
else
  jaune "timeout absent, recommande : brew install coreutils"
  jaune "sans lui, une phase bloquee tourne sans limite de temps"
fi

[ "$MANQUE" -eq 0 ] || { rouge "Prerequis manquants, arret."; exit 1; }

if gh auth status >/dev/null 2>&1; then
  vert "gh authentifie"
else
  rouge "gh non authentifie, lance : gh auth login"
  exit 1
fi

# ---------------------------------------------------------------------------
etape "2. Droits d execution"
# ---------------------------------------------------------------------------
chmod +x scripts/*.sh scripts/*.py 2>/dev/null || true
vert "Scripts executables"

# ---------------------------------------------------------------------------
etape "3. Depot git"
# ---------------------------------------------------------------------------
DEPOT_EXISTANT=0

if git rev-parse --git-dir >/dev/null 2>&1; then
  DEPOT_EXISTANT=1
  vert "Depot git existant, aucune initialisation"
  gris "racine : $(git rev-parse --show-toplevel)"
else
  git init --quiet --initial-branch=main
  vert "Depot initialise"
fi

# ---------------------------------------------------------------------------
etape "4. Branche principale"
# ---------------------------------------------------------------------------
# Toute la boucle se cale sur cette branche : elle y revient entre deux
# fonctionnalites, y fusionne les pull requests, et y pousse le backlog.
BRANCHE_COURANTE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[ "$BRANCHE_COURANTE" = "HEAD" ] && BRANCHE_COURANTE=main

PRINCIPALE="${BRANCHE:-}"
if [ -z "$PRINCIPALE" ]; then
  gris "Tu es sur la branche : $BRANCHE_COURANTE"
  PRINCIPALE="$(demander "Branche principale de la boucle" "$BRANCHE_COURANTE")"
fi

vert "Branche principale retenue : $PRINCIPALE"

if ! git show-ref --verify --quiet "refs/heads/$PRINCIPALE"; then
  jaune "La branche $PRINCIPALE n existe pas localement, creation"
  git checkout -b "$PRINCIPALE" --quiet
elif [ "$BRANCHE_COURANTE" != "$PRINCIPALE" ]; then
  git checkout "$PRINCIPALE" --quiet
  vert "Bascule sur $PRINCIPALE"
fi

# 4a. Le backlog, lu par boucle.sh, boucle-demarrer.sh et boucle-terminer.sh
ANCIENNE="$(jq -r '.meta.branche_principale' "$BACKLOG")"
if [ "$ANCIENNE" != "$PRINCIPALE" ]; then
  TMP="$(mktemp)"
  jq --arg b "$PRINCIPALE" '.meta.branche_principale = $b' "$BACKLOG" > "$TMP"
  mv "$TMP" "$BACKLOG"
  vert "backlog.json : $ANCIENNE devient $PRINCIPALE"
else
  vert "backlog.json deja aligne"
fi

# 4b. Le hook qui refuse les commits directs sur la branche principale
HOOK="$RACINE/scripts/hook-protege-main.sh"
if [ -f "$HOOK" ] && ! grep -q "\"$PRINCIPALE\"" "$HOOK"; then
  python3 - "$HOOK" "$PRINCIPALE" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
ancien = 'if [ "$BRANCHE" = "main" ] || [ "$BRANCHE" = "master" ]; then'
nouveau = ('if [ "$BRANCHE" = "main" ] || [ "$BRANCHE" = "master" ] '
           '|| [ "$BRANCHE" = "%s" ]; then' % sys.argv[2])
if ancien in t:
    p.write_text(t.replace(ancien, nouveau), encoding="utf-8")
PY
  vert "hook-protege-main.sh : $PRINCIPALE desormais protegee"
else
  vert "hook de protection deja aligne"
fi

# 4c. Les chaines GitHub. Sans cela, aucun controle ne se declenche sur les
# pull requests, et boucle-terminer.sh attend indefiniment un resultat.
for FICHIER in .github/workflows/ci.yml .github/workflows/release.yml; do
  [ -f "$FICHIER" ] || continue
  if [ "$PRINCIPALE" != "main" ] && grep -q "branches: \[main\]" "$FICHIER"; then
    python3 - "$FICHIER" "$PRINCIPALE" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text(encoding="utf-8")
             .replace("branches: [main]", "branches: [%s]" % sys.argv[2]),
             encoding="utf-8")
PY
    vert "$FICHIER : declenchement sur $PRINCIPALE"
  fi
done

# 4d. La regle de refus de push direct
REGLES="$RACINE/.claude/settings.json"
if [ -f "$REGLES" ] && [ "$PRINCIPALE" != "main" ]; then
  TMP="$(mktemp)"
  jq --arg b "Bash(git push origin $PRINCIPALE:*)" \
     '.permissions.deny = (((.permissions.deny // [])
        - ["Bash(git push origin main:*)"]) + [$b] | unique)' \
     "$REGLES" > "$TMP" && mv "$TMP" "$REGLES"
  vert "settings.json : regle de refus alignee sur $PRINCIPALE"
fi

# ---------------------------------------------------------------------------
etape "5. Fichier .gitignore"
# ---------------------------------------------------------------------------
# On complete, on n ecrase jamais : le depot a peut etre ses propres regles.
touch .gitignore
AJOUTS=0
while IFS= read -r ligne; do
  [ -n "$ligne" ] || continue
  if ! grep -qxF "$ligne" .gitignore 2>/dev/null; then
    [ "$AJOUTS" -eq 0 ] && printf '\n# Ajoute par la boucle de developpement\n' >> .gitignore
    printf '%s\n' "$ligne" >> .gitignore
    AJOUTS=$((AJOUTS + 1))
  fi
done <<'LIGNES'
build/
DerivedData/
.build/
.swiftpm/
*.xcuserstate
*.xcodeproj/xcuserdata/
.env
*.p12
*.mobileprovision
*.cer
.claude/settings.local.json
loop/etat-boucle.json
loop/verdict.json
loop/journal/
.DS_Store
LIGNES

if [ "$AJOUTS" -gt 0 ]; then
  vert "$AJOUTS regles ajoutees a .gitignore"
else
  vert ".gitignore deja complet"
fi

# ---------------------------------------------------------------------------
etape "6. Etat volatil hors du suivi git"
# ---------------------------------------------------------------------------
# Suivis par git, ces fichiers se font ecraser par un checkout en pleine boucle.
SUIVIS="$(git ls-files loop/etat-boucle.json loop/verdict.json loop/journal 2>/dev/null || true)"
if [ -n "$SUIVIS" ]; then
  git rm --cached -r --quiet loop/etat-boucle.json loop/verdict.json loop/journal 2>/dev/null || true
  vert "Fichiers d etat retires de l index"
else
  vert "Etat volatil deja hors du suivi"
fi

# ---------------------------------------------------------------------------
etape "7. Depot distant"
# ---------------------------------------------------------------------------
if git remote get-url origin >/dev/null 2>&1; then
  vert "Distant deja configure"
  gris "$(git remote get-url origin)"
else
  jaune "Aucun distant. La boucle en a besoin pour pousser et ouvrir les pull requests."
  DEPOT="$(demander "Depot GitHub a creer, format compte/nom, vide pour ignorer" "")"
  if [ -n "$DEPOT" ]; then
    PRIVE="$(demander "Depot prive" "oui")"
    if [ "$PRIVE" = "oui" ]; then VISIBILITE="--private"; else VISIBILITE="--public"; fi
    gh repo create "$DEPOT" "$VISIBILITE" --source=. --remote=origin
    vert "Depot distant cree"
  else
    jaune "Ignore. Le preflight de la boucle refusera de demarrer."
  fi
fi

# ---------------------------------------------------------------------------
etape "8. Commit des fichiers de la boucle"
# ---------------------------------------------------------------------------
# On n ajoute que ce que la boucle apporte, jamais l ensemble du depot :
# un git add -A balaierait ton travail en cours.
A_AJOUTER=""
for c in CLAUDE.md GUIDE-UTILISATION.md LISEZ-MOI-DABORD.md .gitignore \
         loop scripts .claude .github docs wireframes; do
  [ -e "$c" ] && A_AJOUTER="$A_AJOUTER $c"
done

# shellcheck disable=SC2086
git add $A_AJOUTER >/dev/null 2>&1 || true

if git diff --cached --quiet 2>/dev/null; then
  vert "Rien de nouveau a commiter"
else
  NB="$(git diff --cached --name-only | wc -l | tr -d ' ')"
  printf '\n'
  gris "Fichiers qui seront commites :"
  git diff --cached --name-only | head -15 | sed 's/^/    /'
  [ "$NB" -gt 15 ] && gris "    et $((NB - 15)) autres"
  printf '\n'

  if [ "$(demander "Commiter ces $NB fichiers" "oui")" = "oui" ]; then
    git commit --quiet -m "chore: boucle de developpement, cahiers des charges et competences"
    vert "Commit cree"

    if git remote get-url origin >/dev/null 2>&1; then
      if [ "$(demander "Pousser sur origin/$PRINCIPALE" "oui")" = "oui" ]; then
        git push --quiet -u origin "$PRINCIPALE" && vert "Pousse sur origin/$PRINCIPALE"
      fi
    fi
  else
    jaune "Non commite, les fichiers restent dans l index."
    jaune "La boucle exige un arbre propre, commite avant de la lancer."
  fi
fi

# ---------------------------------------------------------------------------
etape "9. Protection de branche"
# ---------------------------------------------------------------------------
DEPOT_ACTUEL="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"
if [ -n "$DEPOT_ACTUEL" ]; then
  if gh api -X PUT "repos/$DEPOT_ACTUEL/branches/$PRINCIPALE/protection" \
      -H "Accept: application/vnd.github+json" \
      -f "required_status_checks[strict]=true" \
      -f "required_status_checks[contexts][]=Verifications" \
      -F "enforce_admins=false" \
      -F "required_pull_request_reviews[required_approving_review_count]=0" \
      -F "restrictions=null" >/dev/null 2>&1; then
    vert "Branche $PRINCIPALE protegee sur GitHub"
  else
    jaune "Protection non appliquee, courant sur un depot prive sans abonnement"
    jaune "Le hook local protege deja $PRINCIPALE de son cote"
  fi
fi

# ---------------------------------------------------------------------------
etape "10. Etat du projet"
# ---------------------------------------------------------------------------
TOTAL="$(jq -r '.features | length' "$BACKLOG")"
FAITS="$(jq -r '[.features[] | select(.statut == "termine")] | length' "$BACKLOG")"
vert "$TOTAL fonctionnalites, $FAITS deja terminees"

if [ -f DESIGN-SPEC.md ]; then
  vert "DESIGN-SPEC.md present, les fonctionnalites d interface sont realisables"
else
  UI="$(jq -r '[.features[] | select(.skills | index("design-systeme"))] | length' "$BACKLOG")"
  jaune "DESIGN-SPEC.md absent, $UI fonctionnalites d interface seront sautees"
  jaune "les $((TOTAL - UI)) autres sont traitables des maintenant"
fi

cat <<FIN

===========================================================================
PRET
===========================================================================
  Branche principale : $PRINCIPALE
  Depot distant      : $(git remote get-url origin 2>/dev/null || echo "aucun")

  Etapes suivantes :

    ./scripts/boucle.sh --simulation     rien n est modifie
    ./scripts/boucle.sh --une            une fonctionnalite, a lire
    ./scripts/boucle.sh                  la boucle complete

===========================================================================

FIN
