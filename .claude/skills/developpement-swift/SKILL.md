---
name: developpement-swift
description: "Conventions d architecture et de code du projet. A utiliser des qu il faut ecrire, modifier ou relire du code Swift, choisir ou creer un module, definir un protocole, gerer la concurrence, traiter une image, manipuler la base de donnees, ou implementer une source de contenu. A utiliser aussi pour verifier qu une modification respecte les frontieres entre paquets."
---

# Developpement Swift

## Frontieres entre paquets

C est la regle d architecture la plus importante du projet, et le controle 7 de `verifications.sh` la fait respecter.

**Aucun paquet sous `Packages/` n importe SwiftUI, sauf `DesignSystem`.**

Si tu ecris `import SwiftUI` dans `Core`, `Sources`, `ReaderEngine` ou `Storage`, tu as fait une erreur de conception. Remonte la logique concernee dans la couche vue, ou expose une abstraction neutre.

```
Core            modeles et protocoles, aucune dependance
Storage         GRDB, schema, requetes
Sources         implementations de SourceProvider
Archive         pont libarchive
ImagePipeline   decodage, cache, traitements
ReaderEngine    pagination, tuilage, precharge
Intelligence    Core ML, traduction
Sync            CloudKit
DesignSystem    jetons et composants, seul paquet a voir SwiftUI
```

`Core` ne depend de rien. Tous les autres peuvent dependre de `Core`. Aucune dependance circulaire.

## Concurrence

Swift 6 en mode strict. Pas d exception silencieuse.

- Un acteur par ressource partagee mutable.
- `@MainActor` uniquement sur ce qui touche reellement l interface.
- `@unchecked Sendable` autorise uniquement avec un commentaire qui explique pourquoi c est sur.
- Les traitements IA tournent dans un acteur dedie a file serialisee. Deux traitements ne tournent jamais en parallele sur le meme appareil.
- Toute tache longue est annulable, et l annulation est reellement propagee.

## Gestion d erreur

- Erreurs typees par domaine. Pas de `NSError` generique qui remonte jusqu a la vue.
- Chaque erreur porte une traduction en message utilisateur, qui nomme la cause et indique la sortie.
- Aucune force unwrap hors des tests. Le controle 9 la detecte.
- Une source qui echoue ne fait jamais tomber les autres. Isole chaque source.

## Memoire et images

C est ici que les lecteurs de manga meurent. Une page de 3000 par 4500 fait environ 54 Mo en RGBA.

1. Decode **toujours** sous echantillonne a la taille d affichage, via `CGImageSourceCreateThumbnailAtIndex` avec `kCGImageSourceThumbnailMaxPixelSize`.
2. Ne charge la pleine resolution que pendant un zoom actif, et libere la a la fin du geste.
3. Cache memoire LRU plafonne a six pages ou 220 Mo, premiere limite atteinte.
4. Cache disque separe, purge par date d acces.
5. Une alerte memoire vide tout sauf la page visible.

En mode webtoon, la limite de texture Metal est de 16384 pixels. Decoupe en tuiles de 2048 maximum et recycle. Ne tente jamais de charger l image entiere pour la reduire ensuite.

## Base de donnees

- Migrations versionnees et explicites, jamais destructives sans sauvegarde prealable.
- Le compteur de non lus est denormalise et maintenu par declencheur. Il ne se calcule jamais a la volee pendant le defilement de la grille.
- Les requetes de liste sont observables et reactives, pas rechargees a la main.
- Index avant optimisation. Mesure ensuite.

## Sens de lecture

C est une propriete **du modele**, persistee, globale et surchargeable par serie. Elle n est jamais deduite a la volee.

Elle affecte l ordre des pages, la composition des doubles pages, la direction du geste, le sens du curseur, la fleche clavier, l ordre des moities apres division, et l orientation des zones de toucher.

Ne la confonds jamais avec la direction de l interface. Ce sont deux notions distinctes. Le bogue sera invisible en francais et systematique en arabe.

## Securite

- Identifiants dans le trousseau, avec `kSecAttrAccessibleAfterFirstUnlock`. Jamais dans `UserDefaults`, jamais dans la base, jamais dans un fichier.
- Aucun secret en clair dans le depot. Le controle 8 le detecte.
- Journalisation sans donnee personnelle. Ni titre de serie, ni adresse de serveur, ni identifiant.
- Une extension n execute jamais de code fourni par un tiers. L interprete applique des regles declaratives, derriere une liste blanche de domaines.
- Toute requete en HTTPS. Une exception locale en HTTP se confirme explicitement.

## Style

- Nommage en francais pour le domaine metier, en anglais pour les API systeme. Reste coherent dans un meme fichier.
- Une fonction fait une chose. Si tu as besoin d un commentaire pour expliquer un bloc, extrais une fonction nommee.
- Les commentaires expliquent le **pourquoi**, jamais le **quoi**.
- Chaque type public documente avec la syntaxe de documentation Swift.
- Aucun avertissement de compilation dans la version livree.
- Pas de tiret cadratin, y compris dans les commentaires et les chaines.

## Avant de conclure

```bash
./scripts/verifications.sh
```

Les neuf controles sont bloquants. Si l un echoue, tu corriges. Tu ne desactives pas la regle.

## Les sept erreurs qui tuent ce projet

Par ordre de gravite.

1. Coder les vues avant d avoir lu `DESIGN-SPEC.md`.
2. Oublier le sens de lecture dans le modele.
3. Charger les images en pleine resolution.
4. Ignorer la limite de texture en mode webtoon.
5. Compter les chapitres non lus a la volee pendant le defilement.
6. Melanger la direction de l interface et le sens de lecture.
7. Mettre SwiftUI dans un paquet metier.
