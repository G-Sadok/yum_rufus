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

# Secondes accordees a une campagne de tests avant de la declarer pendue.
#
# Sans cette borne, un seul test qui boucle fige tout, sans erreur ni trace :
# la boucle attend un processus qui n avancera jamais, et rien ne distingue la
# panne d une campagne lente. C est arrive avec l analyseur de chemin SVG de
# F024, qui a tenu quatre heures avant qu on le remarque.
DELAI_TESTS="${DELAI_TESTS:-1200}"

# timeout vient des coreutils GNU, absent de macOS par defaut. Sans lui, les
# tests tournent comme avant, sans borne, et on le dit.
LANCEUR_BORNE=""
if command -v timeout >/dev/null 2>&1; then
  LANCEUR_BORNE="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  LANCEUR_BORNE="gtimeout"
fi

# Lance une commande sous la borne de temps quand elle est disponible.
avec_borne() {
  if [ -n "$LANCEUR_BORNE" ]; then
    "$LANCEUR_BORNE" "$DELAI_TESTS" "$@"
  else
    "$@"
  fi
}

# Le dossier App existe des l etape 0, mais son projet Xcode n arrive qu avec
# la coquille de l application. Tester la seule presence du dossier ferait
# echouer xcodebuild sur un schema inexistant, alors que rien n est casse.
# On ajoute donc xcodebuild uniquement quand un projet existe vraiment.
#
# Trois corrections apportees avec F008, quand le projet Xcode est apparu.
#
# 1. L ancienne version appelait xcodebuild sans lui passer le projet trouve,
#    depuis la racine du depot, qui n en contient aucun. L appel echouait sur
#    "does not contain an Xcode project", quel que soit l etat du code.
# 2. L ancienne version remplacait la compilation et les tests de paquet par
#    ceux du projet Xcode. Le schema de l application ne porte pas les cibles
#    de test des paquets, la couche metier cessait donc d etre testee au moment
#    precis ou l interface arrivait. Les deux jeux tournent desormais.
# 3. xcodebuild test echoue quand le schema ne declare aucun testable. On ne
#    lance l action de test du projet que s il en declare un.
PROJET_XCODE=""
SCHEMA_A_DES_TESTS=0
if [ -d "App" ]; then
  PROJET_XCODE="$(find App -maxdepth 2 \
    \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) -print -quit 2>/dev/null || true)"
fi
if [ -n "$PROJET_XCODE" ] \
  && grep -rq "<TestableReference" "$PROJET_XCODE/xcshareddata/xcschemes" 2>/dev/null; then
  SCHEMA_A_DES_TESTS=1
fi

# Les controles de texte lisent l arborescence de travail, pas le code suivi par
# git. Depuis que Storage depend de GRDB, SwiftPM depose le depot amont sous
# Packages/.build/checkouts. Ce code tiers contient des tirets cadratins et des
# force unwrap parfaitement legitimes chez son auteur, et les controles 4, 5, 8
# et 9 le signalaient comme s il etait du notre. La regle porte sur ce que nous
# ecrivons, donc on retire des greps les dossiers d artefacts, exactement comme
# .swiftlint.yml et .swiftformat le font deja de leur cote.
EXCLUSIONS=(
  --exclude-dir=.build
  --exclude-dir=.swiftpm
  --exclude-dir=.git
  --exclude-dir=DerivedData
)

rouge()  { printf '\033[31m  ECHEC   %s\033[0m\n' "$1"; }
vert()   { printf '\033[32m  OK      %s\033[0m\n' "$1"; }
jaune()  { printf '\033[33m  IGNORE  %s\033[0m\n' "$1"; }
titre()  { printf '\n\033[36m%s\033[0m\n' "$1"; }

echouer() { rouge "$1"; ECHECS=$((ECHECS + 1)); }

# ---------------------------------------------------------------------------
titre "1. Compilation"
# ---------------------------------------------------------------------------
COMPILATION_TENTEE=0

if command -v swift >/dev/null 2>&1 && [ -f "Packages/Package.swift" ]; then
  # On se fie au code de sortie et non a la presence de la chaine error: dans
  # la sortie. Un echec de lien ou de manifeste ne l ecrit pas toujours, et le
  # controle repondait OK sur une compilation cassee.
  SORTIE="$(mktemp)"
  if swift build --package-path Packages > "$SORTIE" 2>&1; then
    NB_AVERT="$(grep -c "warning:" "$SORTIE" || true)"
    if [ "$NB_AVERT" -gt 0 ]; then
      echouer "Compilation des paquets avec $NB_AVERT avertissement(s)"
      grep "warning:" "$SORTIE" | head -10
    else
      vert "Compilation des paquets sans avertissement"
    fi
  else
    echouer "La compilation des paquets a echoue"
    tail -40 "$SORTIE"
  fi
  rm -f "$SORTIE"
  COMPILATION_TENTEE=1
fi

if command -v xcodebuild >/dev/null 2>&1 && [ -n "$PROJET_XCODE" ]; then
  SORTIE="$(mktemp)"
  if xcodebuild build \
      -project "$PROJET_XCODE" \
      -scheme "$SCHEMA" \
      -destination 'platform=macOS' \
      -quiet > "$SORTIE" 2>&1; then
    NB_AVERT="$(grep -c "warning:" "$SORTIE" || true)"
    if [ "$NB_AVERT" -gt 0 ]; then
      echouer "Compilation de l application avec $NB_AVERT avertissement(s)"
      grep "warning:" "$SORTIE" | head -10
    else
      vert "Compilation de l application sans avertissement"
    fi
  else
    echouer "La compilation de l application a echoue"
    tail -40 "$SORTIE"
  fi
  rm -f "$SORTIE"
  COMPILATION_TENTEE=1
fi

if [ "$COMPILATION_TENTEE" -eq 0 ]; then
  jaune "Aucun projet compilable detecte pour l instant"
fi

# ---------------------------------------------------------------------------
titre "2. Tests"
# ---------------------------------------------------------------------------
TESTS_TENTES=0

if command -v swift >/dev/null 2>&1 && [ -f "Packages/Package.swift" ]; then
  SORTIE="$(mktemp)"
  avec_borne swift test --package-path Packages > "$SORTIE" 2>&1
  CODE_TESTS=$?

  if [ "$CODE_TESTS" -eq 0 ]; then
    vert "Tests des paquets passes"
  elif [ "$CODE_TESTS" -eq 124 ]; then
    echouer "Les tests de paquet ont depasse $DELAI_TESTS secondes, un test est pendu"
    tail -20 "$SORTIE"
  else
    echouer "Des tests de paquet ont echoue"
    grep -E "(recorded an issue|failed|error:)" "$SORTIE" | head -20
  fi
  rm -f "$SORTIE"
  TESTS_TENTES=1
fi

if command -v xcodebuild >/dev/null 2>&1 && [ "$SCHEMA_A_DES_TESTS" -eq 1 ]; then
  SORTIE="$(mktemp)"
  if xcodebuild test \
      -project "$PROJET_XCODE" \
      -scheme "$SCHEMA" \
      -destination 'platform=macOS' \
      -quiet > "$SORTIE" 2>&1; then
    vert "Tests de l application passes"
  else
    echouer "Des tests de l application ont echoue"
    grep -E "(failed|error:)" "$SORTIE" | head -20
  fi
  rm -f "$SORTIE"
  TESTS_TENTES=1
elif [ -n "$PROJET_XCODE" ]; then
  jaune "Le schema $SCHEMA ne declare aucune cible de test"
fi

if [ "$TESTS_TENTES" -eq 0 ]; then
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
# Le motif est construit par printf en octal, jamais ecrit en clair et jamais
# via $'\\u...'. Le bash 3.2 livre par macOS n interprete pas cette echappee,
# le motif devenait alors la chaine litterale, et grep BRE la reduisait au
# simple mot du code du caractere. Resultat : le controle signalait ses propres
# fichiers et ne detectait aucun vrai tiret cadratin.
# La forme octale fonctionne sur bash 3.2 comme sur bash 5.
TIRET_CADRATIN="$(printf '\342\200\224')"

TROUVES="$(grep -rIln -e "$TIRET_CADRATIN" \
  --include='*.swift' --include='*.md' --include='*.json' \
  --include='*.yml' --include='*.yaml' --include='*.sh' \
  --include='*.strings' --include='*.xcstrings' \
  "${EXCLUSIONS[@]}" \
  . 2>/dev/null || true)"

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
  COULEURS="$(grep -rIn --include='*.swift' "${EXCLUSIONS[@]}" \
    -E 'Color\(red:|Color\(\.sRGB|#[0-9A-Fa-f]{6}|UIColor\(red:|NSColor\(red:' \
    App Packages 2>/dev/null \
    | grep -v 'Packages/DesignSystem' || true)"

  if [ -n "$COULEURS" ]; then
    echouer "Couleur en dur hors du paquet DesignSystem :"
    echo "$COULEURS" | head -10 | sed 's/^/          /'
  else
    vert "Aucune couleur en dur hors du systeme de design"
  fi

  POLICES="$(grep -rIn --include='*.swift' "${EXCLUSIONS[@]}" \
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
  FUITES="$(grep -rIln --include='*.swift' "${EXCLUSIONS[@]}" \
    'import SwiftUI' Packages 2>/dev/null \
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
  "${EXCLUSIONS[@]}" \
  -E '(api[_-]?key|client[_-]?secret|password)[[:space:]]*[:=][[:space:]]*"[^"]{8,}"' \
  . 2>/dev/null | grep -v 'Tests/' || true)"

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
  FORCES="$(grep -rIn --include='*.swift' "${EXCLUSIONS[@]}" \
    -E 'try!|as!' App Packages 2>/dev/null \
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
