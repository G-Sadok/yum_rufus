---
name: tests-qualite
description: "Ecrit et fait respecter la strategie de test du projet. A utiliser des qu il faut ecrire un test, verifier un critere d acceptation, mesurer une performance, couvrir un cas limite, ou decider si une fonctionnalite peut etre consideree comme terminee. A utiliser aussi avant tout commit pour valider que les controles bloquants passent."
---

# Tests et qualite

## Principe

Un critere d acceptation qui n est pas verifie automatiquement est un critere qui regressera. Ecris le test avant l implementation chaque fois que le critere est mesurable.

Un test qui ne peut pas echouer ne sert a rien. Avant de le declarer bon, casse volontairement le code qu il couvre et verifie qu il vire au rouge.

## Ce qui doit etre couvert sans discussion

Ces zones ont produit des bogues dans tous les lecteurs de manga existants. Elles sont non negociables.

### Tri naturel des pages

Le tri lexicographique place `page10.jpg` avant `page2.jpg`. Couvre au minimum : zeros initiaux, numeros decimaux, prefixes mixtes, extensions differentes, majuscules et minuscules melangees, noms sans numero, doublons de numero.

### Composition des doubles pages

Dans les deux sens de lecture. En droite a gauche, la premiere page de la paire est **a droite**. Une page large est affichee seule. Le decalage de couverture change toute la sequence qui suit.

### Ordre des moities apres division d une image large

En droite a gauche, la moitie **droite** vient en premier. C est le bogue le plus frequent et le plus invisible en test manuel si tu lis dans le mauvais sens.

### Analyse des reponses de source

Une reponse figee par source, plus une reponse malformee, plus une reponse vide, plus une reponse tronquee. Une source qui echoue ne doit jamais faire tomber les autres.

### Metadonnees

`ComicInfo.xml` valide, malforme, encode differemment, avec champs manquants. Un fichier de metadonnees casse n interrompt jamais l ouverture d un chapitre.

### Migrations de base

Chaque migration testee depuis la version precedente et depuis une base vide. Une migration qui perd des donnees est un incident, pas un bogue.

## Tests de performance

Les budgets de la section 12 du cahier de developpement sont des tests, pas des intentions. Un depassement fait echouer l integration continue.

| Mesure | Budget |
|---|---|
| Lancement a froid jusqu a la bibliotheque | 900 ms |
| Ouverture d un chapitre local | 350 ms |
| Tourne de page en local | 80 ms |
| Defilement de la grille | 120 images par seconde |
| Defilement webtoon | 120 images par seconde |
| Memoire en lecture | 400 Mo |
| Memoire au repos avec 5000 series | 200 Mo |

Le jeu de test de 5000 series et 200000 chapitres se genere par script et vit dans le depot. Sans lui, les mesures ne veulent rien dire.

## Tests de captures

Sur les composants du systeme de design, dans les quatre themes, en clair et en sombre, aux tailles de texte standard et accessibilite extra extra large.

Une capture qui change doit etre relue par un humain avant d etre acceptee. Ne regenere jamais les references en masse pour faire passer la suite.

## Ce qu il ne faut pas tester

Ne teste pas les accesseurs triviaux, la bibliotheque standard, ni le comportement de SwiftUI. Un test qui verifie que le framework fonctionne encombre la suite et ralentit tout le monde.

## Avant de declarer une fonctionnalite terminee

1. Lance `./scripts/verifications.sh`. Les neuf controles passent.
2. Reprends la liste des criteres d acceptation de la fiche de mission.
3. Pour chaque critere, dis **comment** tu l as verifie. Un critere coche sans preuve est un critere non rempli.
4. Verifie qu aucun test n a ete desactive, commente ou marque a ignorer pendant le developpement.
5. Verifie que la couverture n a pas baisse sur les zones critiques listees plus haut.

## Ce qui est interdit pour faire passer les controles

- Desactiver une regle d analyse statique.
- Commenter un test.
- Ajouter un commentaire d exemption sans justification ecrite a cote.
- Regenerer une capture de reference sans l avoir regardee.
- Elargir un budget de performance parce qu il ne passe plus.

Si un controle bloque a tort, la bonne reponse est de corriger le controle et de dire pourquoi, pas de le contourner en silence.
