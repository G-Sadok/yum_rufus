#!/usr/bin/env bash
#
# lib-dmg.sh
# Assemblage et verification du DMG, sans signature ni notarisation.
#
# Cette moitie de la chaine est separee de build-dmg.sh pour une seule raison :
# elle est la seule qui puisse etre exercee sans certificat Developer ID ni
# identifiants Apple. Les tests de scripts/tests-empaquetage.sh l appellent
# telle quelle, sur une fausse application, et verifient le contenu du DMG
# produit. Sans cette separation, le lien vers Applications et le fond de
# fenetre ne seraient verifiables que sur un poste habilite, c est a dire
# jamais dans l integration continue.
#
# Ce fichier se source, il ne s execute pas.

# Zone de contenu de la fenetre du DMG, en points. Le fond fabrique par
# fabriquer-fond-dmg.py fait exactement cette taille, et les deux positions
# d icones ci dessous sont celles qu il dessine. Les trois valeurs bougent
# ensemble ou pas du tout.
DMG_LARGEUR_FENETRE=660
DMG_HAUTEUR_FENETRE=400
DMG_ICONE_APPLICATION_X=170
DMG_ICONE_APPLICATION_Y=200
DMG_ICONE_DOSSIER_X=490
DMG_ICONE_DOSSIER_Y=200
DMG_TAILLE_ICONE=128

dmg_rouge() { printf '\033[31m%s\033[0m\n' "$1" >&2; }
dmg_jaune() { printf '\033[33m%s\033[0m\n' "$1"; }
dmg_vert()  { printf '\033[32m%s\033[0m\n' "$1"; }

# Lance une commande sous une borne de temps, sans dependre des coreutils GNU,
# absents de macOS. La disposition de la fenetre passe par Finder, et Finder
# reste pendu indefiniment quand aucune session graphique ne repond, ce qui est
# le cas courant sur une machine d integration continue.
dmg_borne() {
  local delai="$1"
  shift
  "$@" &
  local pid=$!
  local ecoule=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ecoule" -ge "$delai" ]; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    ecoule=$((ecoule + 1))
  done
  wait "$pid"
}

# Demonte un volume s il traine d une construction precedente. Sans cela,
# hdiutil monte le second volume sous un nom suffixe d un chiffre, Finder
# dispose alors la mauvaise fenetre et le fond n arrive jamais dans le DMG.
# Liste les points de montage d un volume, y compris les doublons numerotes
# que le systeme cree quand le nom est deja pris. Un volume oublie sous
# "/Volumes/Yum 1" suffit a faire echouer la construction suivante sur une
# ressource occupee, sans que rien ne dise lequel occupe quoi.
dmg_points_de_montage() {
  local volume="$1"
  local point
  mount | sed -n 's/^.* on \(\/Volumes\/.*\) (.*)$/\1/p' | while IFS= read -r point; do
    case "$(basename "$point")" in
      "$volume" | "$volume "*) printf '%s\n' "$point" ;;
    esac
  done
}

# Demonte tout ce qui occupe deja le nom de volume vise. On ne teste pas la
# presence du dossier avant : lire /Volumes peut etre refuse dans un bac a
# sable, et le refus se lisait alors comme un volume absent.
dmg_liberer_volume() {
  local volume="$1"
  local point
  while IFS= read -r point; do
    [ -n "$point" ] || continue
    dmg_jaune "Volume deja monte, demontage de $point"
    hdiutil detach "$point" -force >/dev/null 2>&1 || true
  done < <(dmg_points_de_montage "$volume")
}

# Demonte avec patience. Finder garde le volume ouvert quelques secondes apres
# avoir dispose la fenetre, et un demontage immediat, meme force, echoue. Le
# demontage par Finder lui meme compte comme une reussite : le but est que le
# volume ne soit plus la, pas que ce soit nous qui l ayons enleve.
dmg_detacher() {
  local point="$1"
  local volume
  volume="$(basename "$point")"
  local essais=0

  while [ "$essais" -lt 10 ]; do
    hdiutil detach "$point" >/dev/null 2>&1 && return 0
    [ -z "$(dmg_points_de_montage "$volume")" ] && return 0
    sleep 2
    essais=$((essais + 1))
  done

  hdiutil detach "$point" -force >/dev/null 2>&1 && return 0
  [ -z "$(dmg_points_de_montage "$volume")" ] && return 0
  return 1
}

# dmg_preparer_staging <application> <dossier de staging> [fond]
#
# Le lien vers /Applications est pose ici et nulle part ailleurs. C est le seul
# endroit du projet ou il est cree, donc le seul a tester.
dmg_preparer_staging() {
  local application="$1"
  local staging="$2"
  local fond="${3:-}"

  [ -d "$application" ] || { dmg_rouge "Application introuvable : $application"; return 1; }

  rm -rf "$staging"
  mkdir -p "$staging"
  cp -R "$application" "$staging/"
  ln -s /Applications "$staging/Applications"

  if [ -n "$fond" ] && [ -f "$fond" ]; then
    mkdir -p "$staging/.fond"
    cp "$fond" "$staging/.fond/fond.png"
  else
    dmg_jaune "Fond absent, la fenetre du DMG restera grise"
  fi
}

# dmg_disposer_fenetre <nom du volume> <nom du fichier de l application>
#
# Retourne 0 si Finder a dispose la fenetre, autre chose sinon. L appelant ne
# doit pas traiter l echec comme fatal : la mise en page est un confort, alors
# que le lien vers Applications et le fond, eux, sont deja dans le volume.
dmg_disposer_fenetre() {
  local volume="$1"
  local nom_fichier="$2"

  command -v osascript >/dev/null 2>&1 || return 1

  local droite=$((200 + DMG_LARGEUR_FENETRE))
  local bas=$((120 + DMG_HAUTEUR_FENETRE))

  dmg_borne "${DMG_DELAI_FINDER:-45}" osascript <<SCRIPT >/dev/null 2>&1
tell application "Finder"
  tell disk "$volume"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $droite, $bas}
    set options to the icon view options of container window
    set arrangement of options to not arranged
    set icon size of options to $DMG_TAILLE_ICONE
    set text size of options to 12
    set background picture of options to file ".fond:fond.png"
    set position of item "$nom_fichier" of container window to {$DMG_ICONE_APPLICATION_X, $DMG_ICONE_APPLICATION_Y}
    set position of item "Applications" of container window to {$DMG_ICONE_DOSSIER_X, $DMG_ICONE_DOSSIER_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
SCRIPT
}

# dmg_fabriquer <staging> <nom du volume> <chemin du dmg> <nom du fichier app>
#
# Passe par une image inscriptible avant l image compressee. Une image creee
# directement en UDZO ne peut pas recevoir la mise en page de la fenetre, qui
# vit dans un .DS_Store que Finder ecrit dans le volume monte.
dmg_fabriquer() {
  local staging="$1"
  local volume="$2"
  local dmg="$3"
  local nom_fichier="$4"

  local brut="${dmg%.dmg}-inscriptible.dmg"
  local point="/Volumes/$volume"

  rm -f "$brut" "$dmg"
  dmg_liberer_volume "$volume"

  # Marge de securite au dessus du contenu. Un volume rempli a ras bord refuse
  # l ecriture du .DS_Store, et la mise en page disparait sans message.
  local taille
  taille=$(du -sm "$staging" | cut -f1)
  taille=$((taille + 64))

  hdiutil create \
    -volname "$volume" \
    -srcfolder "$staging" \
    -fs HFS+ \
    -format UDRW \
    -size "${taille}m" \
    -ov \
    "$brut" >/dev/null

  hdiutil attach "$brut" \
    -mountpoint "$point" \
    -nobrowse \
    -noverify \
    -noautoopen >/dev/null

  if dmg_disposer_fenetre "$volume" "$nom_fichier"; then
    dmg_vert "Fenetre du DMG disposee"
  else
    dmg_jaune "Finder n a pas repondu, le DMG garde la disposition par defaut"
  fi

  chmod -Rf go-w "$point" 2>/dev/null || true
  sync

  if ! dmg_detacher "$point"; then
    dmg_rouge "Impossible de demonter $point"
    return 1
  fi

  hdiutil convert "$brut" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$dmg" >/dev/null

  rm -f "$brut"
}

# dmg_verifier <chemin du dmg> <nom du fichier app>
#
# Monte l image et controle ce que l utilisateur verra. Le lien vers
# Applications est verifie comme lien, pas comme simple entree presente : un
# dossier copie porterait le meme nom et casserait l installation.
dmg_verifier() {
  local dmg="$1"
  local nom_fichier="$2"
  local echecs=0

  [ -f "$dmg" ] || { dmg_rouge "DMG introuvable : $dmg"; return 1; }

  hdiutil verify "$dmg" >/dev/null 2>&1 || {
    dmg_rouge "Image corrompue, hdiutil verify refuse $dmg"
    return 1
  }

  local point
  point="$(mktemp -d)/volume"
  mkdir -p "$point"

  hdiutil attach "$dmg" \
    -mountpoint "$point" \
    -readonly \
    -nobrowse \
    -noverify \
    -noautoopen >/dev/null || {
    dmg_rouge "Montage impossible : $dmg"
    return 1
  }

  if [ -L "$point/Applications" ]; then
    local cible
    cible="$(readlink "$point/Applications")"
    if [ "$cible" = "/Applications" ]; then
      dmg_vert "Lien vers le dossier Applications present"
    else
      dmg_rouge "Le lien Applications pointe vers $cible et non vers /Applications"
      echecs=$((echecs + 1))
    fi
  else
    dmg_rouge "Aucun lien symbolique Applications dans le DMG"
    echecs=$((echecs + 1))
  fi

  if [ -d "$point/$nom_fichier" ]; then
    dmg_vert "Application presente dans le DMG"
  else
    dmg_rouge "Application $nom_fichier absente du DMG"
    echecs=$((echecs + 1))
  fi

  if [ -f "$point/.fond/fond.png" ]; then
    dmg_vert "Fond de fenetre present dans le DMG"
  else
    dmg_rouge "Fond de fenetre absent du DMG"
    echecs=$((echecs + 1))
  fi

  hdiutil detach "$point" -force >/dev/null 2>&1 || true
  rm -rf "$(dirname "$point")"

  return "$echecs"
}
