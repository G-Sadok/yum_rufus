#!/usr/bin/env bash
#
# hook-protege-main.sh
# Hook PreToolUse sur Bash. Empeche tout commit ou push direct sur la branche
# principale en dehors des scripts de la boucle.
#
# Code 2 : la commande est refusee et le message est renvoye a Claude Code.

set -uo pipefail

ENTREE="$(cat)"
COMMANDE="$(printf '%s' "$ENTREE" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

[ -z "$COMMANDE" ] && exit 0

# Les scripts de la boucle ont le droit de toucher a main, c est leur travail
case "$COMMANDE" in
  *boucle-terminer.sh*|*boucle-demarrer.sh*) exit 0 ;;
esac

BRANCHE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo inconnue)"

if [ "$BRANCHE" = "main" ] || [ "$BRANCHE" = "master" ] || [ "$BRANCHE" = "dev" ]; then
  case "$COMMANDE" in
    *"git commit"*|*"git push"*)
      {
        echo "Commit ou push direct refuse sur la branche $BRANCHE."
        echo ""
        echo "Le projet fonctionne par branche de fonctionnalite."
        echo "Demarre une fonctionnalite avec ./scripts/boucle-demarrer.sh"
        echo "puis cloture la avec ./scripts/boucle-terminer.sh"
      } >&2
      exit 2
      ;;
  esac
fi

# Refuser la reecriture d historique distant
case "$COMMANDE" in
  *"push --force"*|*"push -f "*)
    {
      echo "Reecriture d historique distant refusee."
      echo "Si c est vraiment necessaire, fais le a la main hors de la boucle."
    } >&2
    exit 2
    ;;
esac

exit 0
