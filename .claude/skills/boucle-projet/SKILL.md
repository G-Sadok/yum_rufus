---
name: boucle-projet
description: "Pilote la boucle de developpement fonctionnalite par fonctionnalite. A utiliser quand l utilisateur demande de demarrer, de continuer, de reprendre ou de faire avancer le projet, quand il dit prochaine fonctionnalite, quand il demande ou en est le projet, ou quand une fonctionnalite vient d etre terminee et qu il faut enchainer. Gere la creation de branche, le developpement, les verifications, le commit, le push, la pull request et le passage a la fonctionnalite suivante."
---

# Boucle de developpement

Tu pilotes la construction complete du projet, une fonctionnalite a la fois, du socle initial jusqu a la publication du DMG sur GitHub.

## Regles qui ne se negocient pas

1. **Une fonctionnalite, une branche, un commit.** La branche est poussee, puis recuperee dans la branche principale par un pull. Le projet n utilise pas de pull request.
2. **Jamais de tiret cadratin.** Ni dans le code, ni dans les commentaires, ni dans les chaines, ni dans les messages de commit, ni dans tes reponses. Le script de verification bloque le commit s il en trouve un.
3. **`DESIGN-SPEC.md` avant toute vue.** Si le fichier est absent et que la fonctionnalite touche a l interface, tu t arretes et tu le dis. Le script bloque deja, ne cherche pas a le contourner.
4. **Les verifications ne se contournent pas.** Si `verifications.sh` echoue, tu corriges. Tu ne desactives pas un controle, tu ne commentes pas un test, tu ne mets pas de commentaire d exemption sans raison ecrite.
5. **Tu ne sautes jamais une fonctionnalite** pour aller a une plus interessante. L ordre du backlog encode les dependances.

## Deroulement d une iteration

### 1. Demarrer

```bash
./scripts/boucle-demarrer.sh
```

Le script choisit la prochaine fonctionnalite, verifie ses dependances, cree la branche et affiche la fiche de mission. Lis la fiche en entier avant d ecrire une ligne.

### 2. Preparer

Avant de coder, dis a voix haute, en trois a cinq lignes maximum :

- ce que tu vas creer ou modifier comme fichiers,
- ce qui pourrait casser ailleurs,
- comment tu vas prouver que chaque critere d acceptation est rempli.

Si un critere ne te semble pas testable, dis le maintenant plutot qu a la fin.

### 3. Mobiliser les competences

La fiche de mission liste les competences a invoquer. Charge les avant de coder, pas apres.

| Competence | Quand |
|---|---|
| `developpement-swift` | toute fonctionnalite qui touche au code |
| `design-systeme` | toute fonctionnalite qui touche a l interface |
| `tests-qualite` | toute fonctionnalite avec des criteres verifiables |
| `release-dmg` | uniquement les fonctionnalites F066 et F067 |

### 4. Developper

Ordre impose : le test d abord quand le critere est verifiable automatiquement, l implementation ensuite.

Pour une fonctionnalite d interface, l ordre est : jeton, composant, vue, etat vide, etat de chargement, etat d erreur. Une vue livree sans ses trois etats est incomplete.

### 5. Verifier soi meme

```bash
./scripts/verifications.sh
```

Lance le avant de croire que tu as fini. Les neuf controles sont bloquants.

Reprends ensuite la liste des criteres d acceptation de la fiche et coche les un par un, en disant pour chacun **comment** tu l as verifie. Un critere coche sans preuve est un critere non rempli.

### 6. Cloturer

```bash
./scripts/boucle-terminer.sh
```

Le script verifie, commite, pousse la branche, bascule sur la branche principale, l y integre par un pull, pousse, supprime la branche, marque la fonctionnalite terminee et enchaine sur la suivante.

### 7. Recommencer

Tu continues jusqu a ce que le backlog soit vide. Tu ne t arretes pas de toi meme entre deux fonctionnalites sauf si l utilisateur le demande ou si tu es bloque.

## Quand tu es bloque

Ne bricole pas. Marque la fonctionnalite et explique.

```bash
./scripts/boucle-statut.sh --bloquer F0XX
```

Dis alors trois choses : ce qui bloque, ce que tu as essaye, ce dont tu as besoin pour avancer. Passe ensuite a la fonctionnalite suivante si elle ne depend pas de celle qui est bloquee.

## Fin de parcours

Quand toutes les fonctionnalites sont terminees, le script te le dit. Tu passes alors a la publication :

```bash
./scripts/build-dmg.sh
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

L etiquette declenche la chaine GitHub qui produit le DMG signe, sa somme de controle et les notes de version, dans une release en brouillon.

## Commandes utiles

```bash
./scripts/boucle-statut.sh              avancement
./scripts/boucle-statut.sh --detail     detail par etape
./scripts/boucle-demarrer.sh F014       forcer une fonctionnalite
./scripts/boucle-terminer.sh --sans-fusion    pousser sans integrer
./scripts/boucle-terminer.sh --garder-branche  ne pas supprimer la branche
```
