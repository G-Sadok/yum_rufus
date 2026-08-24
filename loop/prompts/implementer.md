Tu travailles en mode autonome. Personne ne peut te repondre pendant cette execution. Ne pose aucune question, ne demande aucune confirmation, ne termine jamais par une proposition du type dis moi si tu veux que je fasse aussi. Prends les decisions toi meme et documente les.

# Mission

Identifiant : {{ID}}
Titre : {{TITRE}}
Etape : {{ETAPE}}
Branche : {{BRANCHE}}
Tentative : {{TENTATIVE}} sur {{MAX_TENTATIVES}}

## Description

{{DESCRIPTION}}

## Criteres d acceptation

{{CRITERES}}

## Competences a charger avant de coder

{{SKILLS}}

# Marche a suivre

1. Lis `CLAUDE.md` si ce n est pas deja fait.
2. Charge chacune des competences listees ci dessus.
3. Consulte `docs/CAHIER-DES-CHARGES-DEV.md` pour la section correspondant a l etape {{ETAPE}}.
4. Si la mission touche a l interface, lis `DESIGN-SPEC.md` en entier avant d ecrire la moindre vue, et consulte les maquettes du dossier `wireframes/`.
5. Ecris les tests avant l implementation chaque fois que le critere est mesurable.
6. Implemente.
7. Lance `./scripts/verifications.sh` et corrige jusqu a ce que les neuf controles passent.
8. Ecris ton verdict dans `loop/verdict.json` selon le format ci dessous.

# Regles non negociables

- Aucun tiret cadratin nulle part, ni code, ni commentaire, ni chaine, ni message.
- Aucune valeur visuelle en dur hors du paquet DesignSystem.
- Aucune chaine en dur dans une vue, tout passe par le catalogue de chaines.
- Aucun import SwiftUI dans un paquet autre que DesignSystem.
- Aucune force unwrap hors des tests.
- Ne commite pas, ne pousse pas, ne cree pas de branche. Le script s en charge apres toi.
- Ne modifie jamais `loop/backlog.json`.
- Ne desactive aucun controle, ne commente aucun test, n elargis aucun budget de performance pour faire passer les verifications. Si un controle bloque a tort, corrige le controle et explique pourquoi dans ton verdict.

# Verdict a ecrire dans loop/verdict.json

```json
{
  "id": "{{ID}}",
  "statut": "termine | partiel | bloque",
  "resume": "deux phrases maximum sur ce que tu as fait",
  "criteres": [
    {
      "critere": "texte exact du critere",
      "satisfait": true,
      "preuve": "comment tu l as verifie, fichier et test a l appui"
    }
  ],
  "fichiers": ["chemins des fichiers crees ou modifies"],
  "blocage": "si statut vaut bloque, ce qui bloque precisement",
  "besoin": "si statut vaut bloque, ce dont tu as besoin pour avancer"
}
```

Regles du verdict :

- `termine` uniquement si les neuf controles de `verifications.sh` passent **et** si chaque critere est satisfait avec une preuve verifiable.
- `partiel` si tu as avance mais que quelque chose reste a faire.
- `bloque` si tu ne peux pas avancer sans une information ou une decision exterieure.
- Un critere marque satisfait sans preuve concrete est un mensonge qui coutera cher plus tard. Dans le doute, marque le a false et explique.

Le script relancera `verifications.sh` de son cote. Ton verdict ne remplace pas cette verification, il l explique.
