#!/usr/bin/env bash
#
# verifications.sh
# Controles bloquants executes avant chaque commit de la boucle.
# Chaque controle absent du systeme est signale mais n echoue pas,
# sauf les controles de texte qui ne dependent d aucun outil externe.

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

SCHEMA="${SCHEMA_XCODE:-Yum}"
ECHECS=0

# La presence du dossier App ne prouve pas qu un projet Xcode existe. Tant que
# la coquille de l application n est pas construite, App ne contient que de la
# documentation, et xcodebuild n a rien a compiler. On teste donc le projet
# lui meme, pas le dossier qui l accueillera.
PROJET_XCODE=""
for CANDIDAT in ./*.xcworkspace ./*.xcodeproj; do
  if [ -e "$CANDIDAT" ]; then
    PROJET_XCODE="$CANDIDAT"
    break
  fi
done

rouge()  { printf '\033[31m  ECHEC   %s\033[0m\n' "$1"; }
vert()   { printf '\033[32m  OK      %s\033[0m\n' "$1"; }
jaune()  { printf '\033[33m  IGNORE  %s\033[0m\n' "$1"; }
titre()  { printf '\n\033[36m%s\033[0m\n' "$1"; }

echouer() { rouge "$1"; ECHECS=$((ECHECS + 1)); }

# ---------------------------------------------------------------------------
titre "1. Compilation"
# ---------------------------------------------------------------------------
if command -v xcodebuild >/dev/null 2>&1 && [ -n "$PROJET_XCODE" ]; then
  SORTIE="$(mktemp)"
  if xcodebuild build \
      -scheme "$SCHEMA" \
      -destination 'platform=macOS' \
      -quiet > "$SORTIE" 2>&1; then
    NB_AVERT="$(grep -c "warning:" "$SORTIE" || true)"
    if [ "$NB_AVERT" -gt 0 ]; then
      echouer "Compilation avec $NB_AVERT avertissement(s)"
      grep "warning:" "$SORTIE" | head -10
    else
      vert "Compilation sans avertissement"
    fi
  else
    echouer "La compilation a echoue"
    tail -40 "$SORTIE"
  fi
  rm -f "$SORTIE"
elif command -v swift >/dev/null 2>&1 && [ -d "Packages" ]; then
  if swift build --package-path Packages 2>&1 | tee /tmp/swiftbuild.log | grep -q "error:"; then
    echouer "La compilation des paquets a echoue"
    grep "error:" /tmp/swiftbuild.log | head -20
  else
    vert "Compilation des paquets reussie"
  fi
else
  jaune "Aucun projet compilable detecte pour l instant"
fi

# ---------------------------------------------------------------------------
titre "2. Tests"
# ---------------------------------------------------------------------------
if command -v xcodebuild >/dev/null 2>&1 && [ -n "$PROJET_XCODE" ]; then
  SORTIE="$(mktemp)"
  if xcodebuild test \
      -scheme "$SCHEMA" \
      -destination 'platform=macOS' \
      -quiet > "$SORTIE" 2>&1; then
    vert "Tests passes"
  else
    echouer "Des tests ont echoue"
    grep -E "(failed|error:)" "$SORTIE" | head -20
  fi
  rm -f "$SORTIE"
elif command -v swift >/dev/null 2>&1 && [ -d "Packages" ]; then
  if swift test --package-path Packages >/dev/null 2>&1; then
    vert "Tests des paquets passes"
  else
    echouer "Des tests de paquet ont echoue"
  fi
else
  jaune "Aucune cible de test detectee pour l instant"
fi

# ---------------------------------------------------------------------------
titre "3. Analyse statique"
# ---------------------------------------------------------------------------
if command -v swiftlint >/dev/null 2>&1; then
  if swiftlint lint --quiet --strict >/dev/null 2>&1; then
    vert "SwiftLint sans infraction"
  else
    echouer "SwiftLint signale des infractions"
    swiftlint lint --quiet --strict 2>&1 | head -20
  fi
else
  jaune "SwiftLint non installe, installe le avec brew install swiftlint"
fi

if command -v swiftformat >/dev/null 2>&1; then
  if swiftformat --lint . >/dev/null 2>&1; then
    vert "SwiftFormat conforme"
  else
    echouer "SwiftFormat signale des ecarts, lance swiftformat ."
  fi
else
  jaune "SwiftFormat non installe"
fi

# ---------------------------------------------------------------------------
titre "4. Regle de redaction, aucun tiret cadratin"
# ---------------------------------------------------------------------------
# bash 3.2, la version que macOS installe, ne developpe pas l echappement \u
# dans $'...'. Le motif restait litteral et cherchait le texte u2014 au lieu du
# caractere U+2014. Le controle signalait donc ses propres scripts et laissait
# passer les vrais tirets cadratins. On construit le caractere depuis ses trois
# octets UTF-8, ce qui marche sur toutes les versions de bash.
TIRET_CADRATIN="$(printf '\342\200\224')"

TROUVES="$(grep -rIlF "$TIRET_CADRATIN" \
  --include='*.swift' --include='*.md' --include='*.json' \
  --include='*.yml' --include='*.yaml' --include='*.sh' \
  --include='*.strings' --include='*.xcstrings' \
  . 2>/dev/null | grep -v '.git/' || true)"

if [ -n "$TROUVES" ]; then
  echouer "Tiret cadratin trouve dans :"
  echo "$TROUVES" | sed 's/^/          /'
else
  vert "Aucun tiret cadratin"
fi

# ---------------------------------------------------------------------------
titre "5. Aucune valeur visuelle en dur hors du systeme de design"
# ---------------------------------------------------------------------------
if [ -d "App" ] || [ -d "Packages" ]; then
  COULEURS="$(grep -rIn --include='*.swift' \
    -E 'Color\(red:|Color\(\.sRGB|#[0-9A-Fa-f]{6}|UIColor\(red:|NSColor\(red:' \
    App Packages 2>/dev/null \
    | grep -v 'Packages/DesignSystem' || true)"

  if [ -n "$COULEURS" ]; then
    echouer "Couleur en dur hors du paquet DesignSystem :"
    echo "$COULEURS" | head -10 | sed 's/^/          /'
  else
    vert "Aucune couleur en dur hors du systeme de design"
  fi

  POLICES="$(grep -rIn --include='*.swift' \
    -E '\.font\(\.system\(size:|Font\.system\(size:' \
    App Packages 2>/dev/null \
    | grep -v 'Packages/DesignSystem' || true)"

  if [ -n "$POLICES" ]; then
    echouer "Taille de police en dur hors du paquet DesignSystem :"
    echo "$POLICES" | head -10 | sed 's/^/          /'
  else
    vert "Aucune taille de police en dur hors du systeme de design"
  fi
else
  jaune "Pas encore de code source a analyser"
fi

# ---------------------------------------------------------------------------
titre "6. Aucune chaine en dur dans les vues"
# ---------------------------------------------------------------------------
if [ -d "App" ]; then
  CHAINES="$(grep -rIn --include='*.swift' \
    -E '(Text|Button|Label|navigationTitle)\("[A-Za-zÀ-ÿ][^"]{2,}"' \
    App 2>/dev/null \
    | grep -v 'LocalizedStringKey' \
    | grep -v '// i18n-exempt' || true)"

  if [ -n "$CHAINES" ]; then
    echouer "Chaine en dur dans une vue :"
    echo "$CHAINES" | head -10 | sed 's/^/          /'
    jaune "Utilise le catalogue de chaines, ou annote la ligne avec // i18n-exempt"
  else
    vert "Aucune chaine en dur dans les vues"
  fi
fi

# ---------------------------------------------------------------------------
titre "7. Aucune interface dans les paquets metier"
# ---------------------------------------------------------------------------
if [ -d "Packages" ]; then
  FUITES="$(grep -rIln --include='*.swift' 'import SwiftUI' Packages 2>/dev/null \
    | grep -v 'Packages/DesignSystem' || true)"

  if [ -n "$FUITES" ]; then
    echouer "import SwiftUI dans un paquet metier :"
    echo "$FUITES" | sed 's/^/          /'
  else
    vert "Aucune fuite d interface dans les paquets metier"
  fi
fi

# ---------------------------------------------------------------------------
titre "8. Aucun secret dans le depot"
# ---------------------------------------------------------------------------
SECRETS="$(grep -rIn --include='*.swift' --include='*.json' --include='*.plist' \
  -E '(api[_-]?key|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*"[^"]{8,}"' \
  . 2>/dev/null | grep -v '.git/' | grep -v 'Tests/' || true)"

if [ -n "$SECRETS" ]; then
  echouer "Secret potentiel en clair :"
  echo "$SECRETS" | head -5 | sed 's/^/          /'
else
  vert "Aucun secret en clair detecte"
fi

# ---------------------------------------------------------------------------
titre "9. Aucune force unwrap hors des tests"
# ---------------------------------------------------------------------------
if [ -d "App" ] || [ -d "Packages" ]; then
  FORCES="$(grep -rIn --include='*.swift' -E 'try!|as!' App Packages 2>/dev/null \
    | grep -v '/Tests/' | grep -v '// force-ok' || true)"

  if [ -n "$FORCES" ]; then
    echouer "Force unwrap hors des tests :"
    echo "$FORCES" | head -10 | sed 's/^/          /'
  else
    vert "Aucune force unwrap hors des tests"
  fi
fi

# ---------------------------------------------------------------------------
titre "Resultat"
# ---------------------------------------------------------------------------
if [ "$ECHECS" -gt 0 ]; then
  printf '\033[31m%d controle(s) en echec. Le commit est bloque.\033[0m\n\n' "$ECHECS"
  exit 1
fi

printf '\033[32mTous les controles sont passes.\033[0m\n\n'
exit 0
