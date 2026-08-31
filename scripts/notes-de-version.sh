#!/usr/bin/env bash
#
# notes-de-version.sh
# Redige les notes de version d une etiquette a partir des messages de commit,
# et les ecrit sur la sortie standard.
#
# Usage :
#   ./scripts/notes-de-version.sh v1.0.0
#   ./scripts/notes-de-version.sh v1.0.0 build/Yum-1.0.0.dmg.sha256
#
# Ce script existe pour que la redaction des notes soit du code teste plutot
# qu un tas de lignes shell noyees dans un fichier de flux de travail, ou rien
# ne s execute avant la publication elle meme. tests-publication.sh le couvre.
#
# Trois defauts de la version qui vivait dans .github/workflows/release.yml sont
# corriges ici, et chacun a son test.
#
# 1. Les sections vides sortaient vides. Le repli `git log | grep | sed || echo`
#    ne se declenchait jamais : dans un tube, bash rend le code de sortie de la
#    derniere commande, ici sed, qui reussit toujours. Une version sans
#    correction publiait donc un titre "Corrections" suivi de rien.
# 2. Les commits sans portee etaient recopies bruts. Le motif exigeait
#    `feat(F0XX):` et laissait passer `feat:` tel quel, prefixe compris, au
#    milieu d une liste censee etre lisible par un humain.
# 3. La premiere version n avait aucune note. Le cas "pas d etiquette
#    precedente" ecrivait "Premiere version publiee." et sautait la liste, alors
#    que c est justement la version qui a le plus de choses a annoncer.

set -uo pipefail

# Ce script ne se deplace pas dans la racine du depot : il resume le depot
# courant, et ses tests l appellent depuis des depots jetables.
NOM_APP="${NOM_APP:-Yum}"

ETIQUETTE="${1:-}"
FICHIER_SOMME="${2:-}"

rouge() { printf '\033[31m%s\033[0m\n' "$1" >&2; }

if [ -z "$ETIQUETTE" ]; then
  rouge "Usage : $0 vMAJEUR.MINEUR.CORRECTIF [chemin/vers/somme.sha256]"
  exit 1
fi

# L etiquette gouverne le nom du DMG et le titre des notes. Une etiquette
# approximative produirait des notes qui pointent vers un fichier inexistant.
if ! printf '%s' "$ETIQUETTE" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  rouge "Etiquette $ETIQUETTE non conforme, attendu vMAJEUR.MINEUR.CORRECTIF"
  exit 1
fi

VERSION="${ETIQUETTE#v}"
NOM_DMG="$NOM_APP-$VERSION.dmg"

if [ -n "$FICHIER_SOMME" ] && [ ! -s "$FICHIER_SOMME" ]; then
  rouge "Somme de controle absente ou vide : $FICHIER_SOMME"
  rouge "Publier des notes qui annoncent une somme qui n existe pas est pire que ne rien annoncer."
  exit 1
fi

# ---------------------------------------------------------------------------
# Plage de commits a resumer
# ---------------------------------------------------------------------------
# La chaine de publication tourne sur l etiquette poussee, qui existe donc. En
# local, on redige souvent les notes avant d etiqueter, et HEAD fait l affaire.
if git rev-parse -q --verify "refs/tags/$ETIQUETTE" >/dev/null 2>&1; then
  FIN="refs/tags/$ETIQUETTE^{commit}"
else
  FIN="HEAD"
fi

if ! git rev-parse -q --verify "$FIN" >/dev/null 2>&1; then
  rouge "Aucun commit a resumer, le depot est vide."
  exit 1
fi

# L etiquette courante est exclue, sinon git describe la retrouve elle meme et
# la plage devient vide. Une absence d etiquette precedente n est pas une
# erreur : c est la premiere version.
PRECEDENTE="$(git describe --tags --abbrev=0 --exclude="$ETIQUETTE" "$FIN" 2>/dev/null || true)"

if [ -n "$PRECEDENTE" ]; then
  PLAGE="$PRECEDENTE..$FIN"
else
  PLAGE="$FIN"
fi

# Les commits de fusion repetent le titre d une branche deja resumee par son
# propre commit. Les compter deux fois donnerait une liste en double.
SUJETS="$(git log "$PLAGE" --no-merges --pretty=format:'%s' 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# Mise en forme d un type de commit
# ---------------------------------------------------------------------------
# `feat(F012): Grille de bibliotheque` devient `- Grille de bibliotheque (F012)`
# `feat: Grille de bibliotheque`       devient `- Grille de bibliotheque`
# Tout ce qui ne porte pas le type demande est ignore, y compris chore, docs,
# refactor et test, qui n interessent pas la personne qui telecharge le DMG.
lignes_de_type() {
  local type="$1"
  local sujet reste portee titre

  while IFS= read -r sujet; do
    [ -n "$sujet" ] || continue
    portee=""
    titre=""

    case "$sujet" in
      "$type: "*)
        titre="${sujet#"$type": }"
        ;;
      "$type!: "*)
        titre="${sujet#"$type"!: }"
        ;;
      "$type("*)
        reste="${sujet#"$type"(}"
        portee="${reste%%)*}"
        titre="${reste#*)}"
        case "$titre" in
          "!: "*) titre="${titre#!: }" ;;
          ": "*)  titre="${titre#: }" ;;
          *) continue ;;
        esac
        ;;
      *)
        continue
        ;;
    esac

    [ -n "$titre" ] || continue

    # Majuscule initiale, pour que la liste se lise comme des phrases et non
    # comme un extrait de journal git.
    titre="$(printf '%s' "${titre:0:1}" | tr '[:lower:]' '[:upper:]')${titre:1}"

    if printf '%s' "$portee" | grep -Eq '^F[0-9]+$'; then
      printf -- '- %s (%s)\n' "$titre" "$portee"
    else
      printf -- '- %s\n' "$titre"
    fi
  done
}

# La deduplication garde le premier passage. Une fonctionnalite reprise en trois
# commits sous le meme titre n apparait qu une fois.
NOUVEAUTES="$(printf '%s\n' "$SUJETS" | lignes_de_type feat | awk '!vu[$0]++')"
CORRECTIONS="$(printf '%s\n' "$SUJETS" | lignes_de_type fix | awk '!vu[$0]++')"

# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------
NOTES="$(
  echo "## Version $VERSION"
  echo ""

  if [ -z "$PRECEDENTE" ]; then
    echo "Premiere version publiee."
    echo ""
  fi

  echo "### Nouveautes"
  echo ""
  if [ -n "$NOUVEAUTES" ]; then
    printf '%s\n' "$NOUVEAUTES"
  else
    echo "Aucune nouvelle fonctionnalite dans cette version."
  fi
  echo ""

  echo "### Corrections"
  echo ""
  if [ -n "$CORRECTIONS" ]; then
    printf '%s\n' "$CORRECTIONS"
  else
    echo "Aucune correction dans cette version."
  fi
  echo ""

  echo "### Installation"
  echo ""
  echo "Telecharge le DMG, ouvre le, glisse l application dans le dossier Applications."
  echo ""
  echo "L application est signee et notarisee par Apple. Aucun avertissement de securite ne doit apparaitre."
  echo ""

  echo "### Verification de l integrite"
  echo ""
  echo "Place le fichier $NOM_DMG.sha256 a cote du DMG telecharge, puis :"
  echo ""
  echo '```'
  echo "shasum -a 256 -c $NOM_DMG.sha256"
  echo '```'
  if [ -n "$FICHIER_SOMME" ]; then
    echo ""
    echo "Somme attendue :"
    echo ""
    echo '```'
    cut -d' ' -f1 < "$FICHIER_SOMME"
    echo '```'
  fi
  echo ""

  echo "### Configuration requise"
  echo ""
  echo "macOS 14 Sonoma ou plus recent."
)"

# ---------------------------------------------------------------------------
# Controle de redaction
# ---------------------------------------------------------------------------
# Un message de commit fautif ne doit pas glisser un tiret cadratin dans une
# page publique. Le motif se construit en octal, jamais en clair : le bash 3.2
# livre par macOS n interprete pas l echappee unicode et le controle
# s autodetecterait sans rien trouver de reel.
TIRET_CADRATIN="$(printf '\342\200\224')"
if printf '%s' "$NOTES" | grep -q -e "$TIRET_CADRATIN"; then
  rouge "Tiret cadratin dans les notes de version, il vient d un message de commit."
  printf '%s' "$NOTES" | grep -n -e "$TIRET_CADRATIN" >&2
  exit 1
fi

printf '%s\n' "$NOTES"
