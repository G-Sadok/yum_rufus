#!/usr/bin/env bash
#
# boucle.sh
# Orchestrateur autonome. Construit le projet fonctionnalite par fonctionnalite
# jusqu a la publication du DMG, sans intervention humaine.
#
# Principe : Claude Code implemente, mais c est verifications.sh qui decide.
# Le verdict du modele explique, il ne tranche pas.
#
# Usage :
#   ./scripts/boucle.sh                    lance ou reprend la boucle
#   ./scripts/boucle.sh --jusqu-a F030     s arrete apres cette fonctionnalite
#   ./scripts/boucle.sh --etape 5          ne traite que l etape 5
#   ./scripts/boucle.sh --une              une seule fonctionnalite puis sortie
#   ./scripts/boucle.sh --simulation       montre ce qui serait fait, sans agir
#   ./scripts/boucle.sh --sans-publication ne publie pas a la fin
#   ./scripts/boucle.sh --reprendre F041   force la reprise sur une fonctionnalite
#
# Reglages par variables d environnement :
#   MAX_TENTATIVES=3          essais par fonctionnalite avant blocage
#   MAX_ECHECS_CONSECUTIFS=3  disjoncteur global
#   BUDGET_USD=150            plafond de depense cumulee
#   DELAI_PAR_PHASE=3600      secondes par appel a Claude Code
#   MAX_TOURS=40              tours agentiques par appel
#   MODELE=                   vide pour le defaut, sinon sonnet ou opus
#   PERMISSIONS=acceptEdits   ou dontAsk, ou bypassPermissions

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

BACKLOG="$RACINE/loop/backlog.json"
ETAT="$RACINE/loop/etat-boucle.json"
VERDICT="$RACINE/loop/verdict.json"
JOURNAL_DIR="$RACINE/loop/journal"
PROMPTS="$RACINE/loop/prompts"

mkdir -p "$JOURNAL_DIR"
FICHIER_JOURNAL="$JOURNAL_DIR/boucle-$(date +%Y%m%d-%H%M%S).log"

# shellcheck source=lib-boucle.sh
source "$RACINE/scripts/lib-boucle.sh"

# ---------------------------------------------------------------------------
# Reglages
# ---------------------------------------------------------------------------
MAX_TENTATIVES="${MAX_TENTATIVES:-3}"
MAX_ECHECS_CONSECUTIFS="${MAX_ECHECS_CONSECUTIFS:-3}"
BUDGET_USD="${BUDGET_USD:-150}"
DELAI_PAR_PHASE="${DELAI_PAR_PHASE:-3600}"
MAX_TOURS="${MAX_TOURS:-40}"
MODELE="${MODELE:-}"
PERMISSIONS="${PERMISSIONS:-acceptEdits}"

JUSQU_A=""
ETAPE_CIBLE=""
UNE_SEULE=0
SIMULATION=0
PUBLIER=1
REPRENDRE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --jusqu-a)          JUSQU_A="${2:?identifiant requis}"; shift 2 ;;
    --etape)            ETAPE_CIBLE="${2:?numero requis}"; shift 2 ;;
    --une)              UNE_SEULE=1; shift ;;
    --simulation)       SIMULATION=1; shift ;;
    --sans-publication) PUBLIER=0; shift ;;
    --reprendre)        REPRENDRE="${2:?identifiant requis}"; shift 2 ;;
    -h|--aide|--help)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                  erreur "Option inconnue : $1"; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Arret propre
# ---------------------------------------------------------------------------
INTERROMPU=0

sur_interruption() {
  INTERROMPU=1
  printf '\n'
  alerte "Interruption demandee. Arret apres la phase en cours."
}
trap sur_interruption INT TERM

# ---------------------------------------------------------------------------
# Verifications prealables
# ---------------------------------------------------------------------------
preflight() {
  titre "Verifications prealables"
  local ko=0

  if [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
    erreur "bash 3.2 minimum requis"
    ko=1
  else
    succes "bash ${BASH_VERSION%%(*}"
  fi

  for outil in claude git jq python3; do
    if command -v "$outil" >/dev/null 2>&1; then
      succes "$outil present"
    else
      erreur "$outil absent"
      ko=1
    fi
  done

  if ! delai_disponible; then
    alerte "timeout absent, les phases ne seront pas bornees dans le temps"
    alerte "installe le avec : brew install coreutils"
  fi

  # gh ne sert plus au cycle, seulement a la publication de la release
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    succes "gh authentifie, publication de release possible"
  else
    alerte "gh absent ou non authentifie, le cycle fonctionne quand meme"
  fi

  if [ -f "$BACKLOG" ] && jq empty "$BACKLOG" 2>/dev/null; then
    succes "backlog valide, $(bl '.features | length') fonctionnalites"
  else
    erreur "backlog absent ou invalide"
    ko=1
  fi

  if [ -d .git ]; then
    succes "depot git present"
  else
    erreur "pas de depot git, lance ./scripts/init-projet.sh"
    ko=1
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    succes "depot distant configure"
  else
    erreur "pas de depot distant, lance ./scripts/init-projet.sh"
    ko=1
  fi

  if arbre_propre; then
    succes "arbre de travail propre"
  else
    erreur "arbre de travail sale, commite ou remise avant de lancer"
    git status --short | head -10
    ko=1
  fi

  # L etat de la boucle ne doit jamais etre suivi par git : un checkout
  # pendant la cloture ecraserait le compteur de depense en pleine execution.
  local suivis
  suivis="$(git ls-files loop/etat-boucle.json loop/verdict.json loop/journal 2>/dev/null)"
  if [ -n "$suivis" ]; then
    alerte "Fichiers d etat suivis par git, retrait de l index :"
    printf '%s\n' "$suivis" | sed 's/^/   /'
    git rm --cached -r --quiet loop/etat-boucle.json loop/verdict.json loop/journal 2>/dev/null
    grep -q '^loop/etat-boucle.json$' .gitignore 2>/dev/null || {
      printf '\nloop/etat-boucle.json\nloop/verdict.json\nloop/journal/\n' >> .gitignore
    }
    git add .gitignore >/dev/null 2>&1
    git commit --quiet -m "chore: sortir l etat volatil de la boucle du suivi git" 2>/dev/null
    succes "Fichiers d etat retires du suivi"
  else
    succes "Etat de la boucle hors du suivi git"
  fi

  for s in verifications.sh boucle-demarrer.sh boucle-terminer.sh; do
    if [ -x "scripts/$s" ]; then
      succes "scripts/$s executable"
    else
      erreur "scripts/$s absent ou non executable"
      ko=1
    fi
  done

  # Le design conditionne une grande partie du backlog
  local besoin_design
  besoin_design="$(jq -r '[.features[] | select(.statut == "a_faire")
      | select(.skills | index("design-systeme"))] | length' "$BACKLOG")"

  if [ -f DESIGN-SPEC.md ]; then
    succes "DESIGN-SPEC.md present"
  else
    if [ "$besoin_design" -gt 0 ]; then
      alerte "DESIGN-SPEC.md absent, $besoin_design fonctionnalites d interface seront sautees"
      alerte "la boucle traitera d abord tout ce qui ne depend pas du design"
    fi
  fi

  [ "$ko" -eq 0 ] || { erreur "Verifications prealables en echec, arret."; exit 1; }
}

# ---------------------------------------------------------------------------
# Selection de la prochaine fonctionnalite realisable
# ---------------------------------------------------------------------------
# Contrairement a boucle-demarrer.sh, cette fonction saute ce qui n est pas
# realisable maintenant, au lieu de s arreter dessus.
selectionner() {
  local id fiche etape besoin_design dep_manquante

  while read -r id; do
    [ -n "$id" ] || continue

    fiche="$(fiche_de "$id")"
    etape="$(echo "$fiche" | jq -r '.etape')"

    # Filtre d etape
    if [ -n "$ETAPE_CIBLE" ] && [ "$etape" != "$ETAPE_CIBLE" ]; then
      continue
    fi

    # Dependances
    if ! dep_manquante="$(dependances_pretes "$id")"; then
      continue
    fi

    # Prerequis design
    besoin_design="$(echo "$fiche" | jq -r '[.skills[] | select(. == "design-systeme")] | length')"
    if [ "$besoin_design" -gt 0 ] && [ ! -f DESIGN-SPEC.md ]; then
      continue
    fi

    echo "$id"
    return 0
  done < <(jq -r '.features[] | select(.statut == "a_faire") | .id' "$BACKLOG")

  return 1
}

# ---------------------------------------------------------------------------
# Construction du prompt a partir du gabarit et de la fiche
# ---------------------------------------------------------------------------
construire_prompt() {
  local gabarit="$1" id="$2" tentative="$3" sortie="$4" extra="${5:-}"
  python3 "$RACINE/scripts/construire-prompt.py" \
    --gabarit "$gabarit" \
    --backlog "$BACKLOG" \
    --id "$id" \
    --tentative "$tentative" \
    --max-tentatives "$MAX_TENTATIVES" \
    --branche "$(branche_courante)" \
    --extra "$extra" \
    --sortie "$sortie"
}

# ---------------------------------------------------------------------------
# Appel a Claude Code, avec affichage en direct et extraction du resultat
# ---------------------------------------------------------------------------
# Renvoie 0 si l appel s est termine sans erreur, 1 sinon.
# Ecrit le cout et l identifiant de session dans les variables globales
# COUT_APPEL et SESSION_ID.
appeler_claude() {
  local fichier_prompt="$1" session_a_reprendre="${2:-}"
  local flux; flux="$(mktemp)"

  COUT_APPEL=0
  SESSION_ID=""

  local cmd
  cmd=(claude -p
    --output-format stream-json
    --verbose
    --permission-mode "$PERMISSIONS"
    --max-turns "$MAX_TOURS")

  [ -n "$MODELE" ] && cmd=("${cmd[@]}" --model "$MODELE")
  [ -n "$session_a_reprendre" ] && cmd=("${cmd[@]}" --resume "$session_a_reprendre")

  if [ "$SIMULATION" -eq 1 ]; then
    info "Simulation, commande qui serait lancee :"
    printf '%s   %s < %s%s\n' "$C_GRIS" "${cmd[*]}" "$fichier_prompt" "$C_FIN"
    rm -f "$flux"
    return 0
  fi

  # Un seul pipeline : claude ecrit le flux, tee le conserve, le formateur
  # l affiche en direct. PIPESTATUS donne le code de claude lui meme.
  avec_delai "$DELAI_PAR_PHASE" "${cmd[@]}" < "$fichier_prompt" 2>>"$FICHIER_JOURNAL" \
    | tee "$flux" \
    | formater_flux
  local code=${PIPESTATUS[0]}

  # Derniere ligne de type result
  local resultat
  resultat="$(jq -c 'select(.type == "result")' "$flux" 2>/dev/null | tail -1)"

  if [ -n "$resultat" ]; then
    COUT_APPEL="$(echo "$resultat" | jq -r '.total_cost_usd // 0')"
    SESSION_ID="$(echo "$resultat" | jq -r '.session_id // empty')"
    local tours; tours="$(echo "$resultat" | jq -r '.num_turns // 0')"
    local en_erreur; en_erreur="$(echo "$resultat" | jq -r '.is_error // false')"
    local motif; motif="$(echo "$resultat" | jq -r '.subtype // "success"')"
    info "Session ${SESSION_ID:0:8}, $tours tours, $motif, cout $COUT_APPEL dollars"
    [ "$en_erreur" = "true" ] && code=1
    [ "$motif" = "error_max_turns" ] && alerte "Plafond de $MAX_TOURS tours atteint"
  else
    alerte "Aucun evenement de resultat dans le flux"
    code=1
  fi

  cp "$flux" "$JOURNAL_DIR/flux-$(date +%H%M%S)-$$.jsonl" 2>/dev/null
  rm -f "$flux"

  case $code in
    124) alerte "Delai de $DELAI_PAR_PHASE secondes depasse"; return 1 ;;
    143) alerte "Phase interrompue par un signal"; return 1 ;;
  esac

  return $code
}

# Affiche les evenements interessants au fil de l eau
formater_flux() {
  local ligne type texte outil
  while IFS= read -r ligne; do
    type="$(printf '%s' "$ligne" | jq -r '.type // empty' 2>/dev/null)"
    [ -n "$type" ] || continue

    if [ "$type" = "assistant" ]; then
      texte="$(printf '%s' "$ligne" | jq -r '
        [.message.content[]? | select(.type == "text") | .text] | join(" ")' 2>/dev/null)"
      if [ -n "$texte" ] && [ "$texte" != "null" ]; then
        printf '%s   %.150s%s\n' "$C_GRIS" "$texte" "$C_FIN"
      fi

      outil="$(printf '%s' "$ligne" | jq -r '
        [.message.content[]? | select(.type == "tool_use")
         | .name + " " + ((.input.file_path // .input.command // .input.pattern // "")
                          | tostring)] | join(" | ")' 2>/dev/null)"
      if [ -n "$outil" ] && [ "$outil" != "null" ]; then
        printf '%s   > %.110s%s\n' "$C_BLEU" "$outil" "$C_FIN"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Lecture du verdict ecrit par Claude Code
# ---------------------------------------------------------------------------
lire_verdict() {
  local champ="$1"
  [ -f "$VERDICT" ] || { echo ""; return; }
  jq -r --arg c "$champ" '.[$c] // empty' "$VERDICT" 2>/dev/null || echo ""
}

afficher_verdict() {
  [ -f "$VERDICT" ] || return 0
  local statut; statut="$(lire_verdict statut)"
  local resume; resume="$(lire_verdict resume)"

  printf '   verdict du modele : %s\n' "${statut:-inconnu}"
  [ -n "$resume" ] && printf '   %s\n' "$resume"

  jq -r '.criteres[]? |
    (if .satisfait then "   [x] " else "   [ ] " end) + .critere' \
    "$VERDICT" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Traitement complet d une fonctionnalite
# ---------------------------------------------------------------------------
# Renvoie 0 si terminee, 1 si bloquee.
traiter() {
  local id="$1"
  local fiche titre_f reference tentative
  fiche="$(fiche_de "$id")"
  titre_f="$(echo "$fiche" | jq -r '.titre')"

  banniere "$id  $titre_f"

  # Ouverture de la branche
  if [ "$SIMULATION" -eq 1 ]; then
    info "Simulation, la branche serait creee ici"
  else
    if ! ./scripts/boucle-demarrer.sh "$id" > >(sed 's/^/   /') 2>&1; then
      erreur "Impossible d ouvrir la fonctionnalite $id"
      return 1
    fi
  fi

  reference="$(tete_courante)"
  rm -f "$VERDICT"

  local session=""
  local fichier_verif_precedent=""

  for tentative in $(seq 1 "$MAX_TENTATIVES"); do
    [ "$INTERROMPU" -eq 1 ] && return 1

    titre "Tentative $tentative sur $MAX_TENTATIVES"

    local prompt; prompt="$(mktemp)"

    if [ "$tentative" -eq 1 ]; then
      construire_prompt "$PROMPTS/implementer.md" "$id" "$tentative" "$prompt"
      appeler_claude "$prompt"
    else
      construire_prompt "$PROMPTS/reparer.md" "$id" "$tentative" "$prompt" "$fichier_verif_precedent"
      appeler_claude "$prompt" "$session"
    fi

    local code_appel=$?
    rm -f "$prompt"

    [ -n "$SESSION_ID" ] && session="$SESSION_ID"

    # Budget
    local total; total="$(ajouter_cout "${COUT_APPEL:-0}")"
    info "Depense cumulee : $total dollars sur $BUDGET_USD"
    if depasse "$total" "$BUDGET_USD"; then
      erreur "Plafond de depense atteint"
      definir_statut "$id" "bloque"
      noter_echec "$id" "plafond de depense atteint"
      return 1
    fi

    if [ "$SIMULATION" -eq 1 ]; then
      succes "Simulation, on considere la fonctionnalite comme traitee"
      return 0
    fi

    if [ $code_appel -ne 0 ]; then
      alerte "L appel a Claude Code s est termine en erreur"
    fi

    afficher_verdict

    # Le modele declare un blocage, on ne s acharne pas
    if [ "$(lire_verdict statut)" = "bloque" ]; then
      erreur "Blocage declare : $(lire_verdict blocage)"
      info "Besoin exprime : $(lire_verdict besoin)"
      definir_statut "$id" "bloque"
      noter_echec "$id" "$(lire_verdict blocage)"
      return 1
    fi

    # Detection d absence de progres, evite de tourner a vide
    if ! progression_depuis "$reference"; then
      alerte "Aucun changement produit par cette tentative"
      if [ "$tentative" -ge 2 ]; then
        erreur "Deux tentatives sans le moindre changement, on arrete"
        definir_statut "$id" "bloque"
        noter_echec "$id" "aucune progression sur deux tentatives"
        return 1
      fi
      continue
    fi

    # C est ici que la boucle decide reellement, pas sur le verdict du modele
    titre "Verification independante"
    local fichier_verif; fichier_verif="$(mktemp)"
    if ./scripts/verifications.sh > "$fichier_verif" 2>&1; then
      sed 's/^/   /' < "$fichier_verif"
      rm -f "$fichier_verif" "$fichier_verif_precedent" 2>/dev/null
      succes "Les neuf controles passent"

      titre "Cloture"
      if ./scripts/boucle-terminer.sh --sans-enchainer > >(sed 's/^/   /') 2>&1; then
        succes "$id livre et fusionne"
        ecrire_etat derniere_reussie "$id"
        return 0
      fi
      erreur "La cloture a echoue, la branche reste poussee mais non integree"
      definir_statut "$id" "bloque"
      noter_echec "$id" "echec de la cloture, conflit de fusion ou push refuse"
      return 1
    fi

    sed 's/^/   /' < "$fichier_verif"
    [ -n "$fichier_verif_precedent" ] && rm -f "$fichier_verif_precedent"
    fichier_verif_precedent="$fichier_verif"
    alerte "Verifications en echec, nouvelle tentative"
  done

  erreur "$MAX_TENTATIVES tentatives epuisees sur $id"
  definir_statut "$id" "bloque"
  noter_echec "$id" "tentatives epuisees, verifications toujours en echec"
  return 1
}

# ---------------------------------------------------------------------------
# Retour a une base saine apres un echec
# ---------------------------------------------------------------------------
# Le backlog est suivi par git. Un reset --hard effacerait le statut qui vient
# d etre ecrit, et la boucle reessaierait indefiniment la meme fonctionnalite.
# On le met donc de cote pendant la remise a plat, puis on le publie.
#
# Le travail de la tentative en echec est remise, jamais detruit. Un reset seul
# effacait sans retour les modifications des fichiers deja suivis, ce qui rendait
# le reste du travail incoherent : les fichiers neufs survivaient et appelaient
# une interface qui venait de disparaitre. Ces memes fichiers neufs salissaient
# ensuite la branche principale et faisaient echouer l ouverture des trois
# fonctionnalites suivantes, jusqu au disjoncteur.
revenir_au_propre() {
  local principale sauvegarde etiquette
  principale="$(bl '.meta.branche_principale')"
  sauvegarde="$(mktemp)"
  cp "$BACKLOG" "$sauvegarde"

  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    etiquette="boucle: travail mis de cote le $(date '+%Y-%m-%d %H:%M:%S')"
    if git stash push --include-untracked --quiet --message "$etiquette" 2>/dev/null; then
      info "Travail non commite mis de cote, retrouve le avec git stash list"
    fi
  fi

  git checkout "$principale" --quiet 2>/dev/null
  git reset --hard "origin/$principale" --quiet 2>/dev/null

  # Filet de securite si la remise a echoue. Sans -x, les fichiers ignores,
  # dont l etat de la boucle et ses journaux, ne sont pas touches.
  git clean -fdq 2>/dev/null

  cp "$sauvegarde" "$BACKLOG"
  rm -f "$sauvegarde"

  if ! arbre_propre; then
    git add "$BACKLOG" >/dev/null 2>&1
    git commit --quiet -m "chore: mise a jour des statuts du backlog" 2>/dev/null
    git push --quiet origin "$principale" 2>/dev/null
  fi
}

# ---------------------------------------------------------------------------
# Publication finale
# ---------------------------------------------------------------------------
publier() {
  banniere "PUBLICATION"

  local version
  version="$(jq -r '.meta.version_cible // "1.0.0"' "$BACKLOG")"

  if [ "$SIMULATION" -eq 1 ]; then
    info "Simulation, la version $version serait publiee"
    return 0
  fi

  titre "Construction locale du DMG"
  if ! ./scripts/build-dmg.sh "$version" > >(sed 's/^/   /') 2>&1; then
    erreur "La construction du DMG a echoue, aucune etiquette n est posee"
    return 1
  fi
  succes "DMG construit et valide"

  titre "Pose de l etiquette de version"
  if git rev-parse "v$version" >/dev/null 2>&1; then
    alerte "L etiquette v$version existe deja"
  else
    git tag -a "v$version" -m "Version $version"
    git push origin "v$version"
    succes "Etiquette v$version poussee"
  fi

  info "La chaine de publication GitHub construit la release en brouillon."
  info "Suis la avec : gh run watch"
  return 0
}

# ---------------------------------------------------------------------------
# Rapport final
# ---------------------------------------------------------------------------
rapport() {
  local faits bloques restants cout
  faits="$(compte_statut termine)"
  bloques="$(compte_statut bloque)"
  restants="$(compte_statut a_faire)"
  cout="$(lire_etat cout_total)"

  banniere "RAPPORT DE SESSION"
  printf '  Terminees   : %s\n' "$faits"
  printf '  Bloquees    : %s\n' "$bloques"
  printf '  Restantes   : %s\n' "$restants"
  printf '  Depense     : %s dollars\n' "${cout:-0}"
  printf '  Journal     : %s\n' "$FICHIER_JOURNAL"

  if [ "$bloques" -gt 0 ]; then
    printf '\n%sFonctionnalites bloquees :%s\n' "$C_JAUNE" "$C_FIN"
    jq -r '.features[] | select(.statut == "bloque")
      | "  " + .id + "  " + .titre
      + "\n      raison : " + (.derniere_erreur // "non precisee")' "$BACKLOG"
    printf '\n  Debloque avec : ./scripts/boucle-statut.sh --debloquer F0XX\n'
  fi
  printf '\n'
}

# ---------------------------------------------------------------------------
# Programme principal
# ---------------------------------------------------------------------------
main() {
  banniere "BOUCLE DE DEVELOPPEMENT AUTONOME"

  preflight

  [ -f "$ETAT" ] || printf '{"cout_total":"0"}' > "$ETAT"

  if [ -n "$REPRENDRE" ]; then
    info "Reprise forcee sur $REPRENDRE"
    definir_statut "$REPRENDRE" "a_faire"
  fi

  # Une fonctionnalite restee en cours d une session precedente
  local en_cours
  en_cours="$(jq -r 'first(.features[] | select(.statut == "en_cours")) | .id // empty' "$BACKLOG")"
  if [ -n "$en_cours" ]; then
    alerte "$en_cours etait en cours, remise a faire"
    definir_statut "$en_cours" "a_faire"
    git checkout "$(bl '.meta.branche_principale')" --quiet 2>/dev/null
  fi

  local echecs_consecutifs=0
  local traitees=0

  while true; do
    [ "$INTERROMPU" -eq 1 ] && { alerte "Boucle interrompue"; break; }

    local id
    if ! id="$(selectionner)"; then
      succes "Plus aucune fonctionnalite realisable"
      break
    fi

    if traiter "$id"; then
      echecs_consecutifs=0
    else
      echecs_consecutifs=$((echecs_consecutifs + 1))
      alerte "Echecs consecutifs : $echecs_consecutifs sur $MAX_ECHECS_CONSECUTIFS"

      # Toujours revenir au propre, y compris avant de declencher le disjoncteur
      revenir_au_propre

      if [ "$echecs_consecutifs" -ge "$MAX_ECHECS_CONSECUTIFS" ]; then
        erreur "Disjoncteur declenche, $MAX_ECHECS_CONSECUTIFS echecs de suite"
        erreur "Quelque chose de systemique ne va pas, arret de la boucle"
        break
      fi
    fi

    traitees=$((traitees + 1))

    [ "$UNE_SEULE" -eq 1 ] && { info "Mode une seule fonctionnalite, arret"; break; }
    [ -n "$JUSQU_A" ] && [ "$id" = "$JUSQU_A" ] && { info "Cible $JUSQU_A atteinte, arret"; break; }
  done

  rapport

  # Publication uniquement si tout est reellement fini
  local restants bloques
  restants="$(compte_statut a_faire)"
  bloques="$(compte_statut bloque)"

  if [ "$PUBLIER" -eq 1 ] && [ "$restants" -eq 0 ] && [ "$bloques" -eq 0 ] \
     && [ "$INTERROMPU" -eq 0 ] && [ -z "$ETAPE_CIBLE" ] && [ "$UNE_SEULE" -eq 0 ]; then
    publier
  elif [ "$PUBLIER" -eq 1 ] && [ "$restants" -eq 0 ] && [ "$bloques" -gt 0 ]; then
    alerte "Publication non lancee, $bloques fonctionnalites restent bloquees"
  fi

  [ "$bloques" -gt 0 ] && return 1
  return 0
}

main
