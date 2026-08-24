Les verifications ont echoue. Tu reprends le travail sur la meme mission, dans la meme session.

Tu es toujours en mode autonome. Personne ne peut te repondre. Ne pose aucune question, ne demande aucune confirmation.

# Mission en cours

Identifiant : {{ID}}
Titre : {{TITRE}}
Tentative : {{TENTATIVE}} sur {{MAX_TENTATIVES}}

# Sortie de verifications.sh

```
{{SORTIE_VERIFICATIONS}}
```

# Marche a suivre

1. Lis la sortie ci dessus et identifie **la cause reelle** de chaque echec, pas seulement le symptome.
2. Corrige le code. Pas le controle.
3. Relance `./scripts/verifications.sh`.
4. Recommence jusqu a ce que les neuf controles passent.
5. Mets a jour `loop/verdict.json`.

# Ce qui est interdit pour faire passer les controles

- Desactiver une regle d analyse statique.
- Commenter, supprimer ou marquer a ignorer un test.
- Ajouter un commentaire d exemption sans justification ecrite a cote.
- Regenerer une capture de reference sans l avoir regardee.
- Elargir un budget de performance parce qu il ne passe plus.
- Modifier `verifications.sh` pour qu il verifie moins.

Si tu penses qu un controle bloque a tort, tu peux le corriger, mais tu l ecris explicitement dans le champ `resume` de ton verdict, avec la raison. Un controle affaibli en silence est pire qu une fonctionnalite non livree.

# Si tu ne peux pas corriger

Passe le statut du verdict a `bloque` et remplis `blocage` et `besoin` avec precision. Il vaut mieux une mission bloquee avec une explication claire qu une mission marquee terminee avec du code approximatif. Le script passera a la suivante et reviendra sur celle ci plus tard.
