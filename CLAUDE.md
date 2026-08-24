# Contexte projet

Lecteur de manga, manhwa et manhua pour macOS, iPadOS et iOS. Nom de code TSUZUKI, a remplacer par le nom definitif.

L application n heberge aucun contenu. Elle lit ce que l utilisateur possede deja : fichiers locaux, serveurs auto heberges, catalogues ouverts, partages reseau.

## Documents de reference

| Fichier | Role |
|---|---|
| `docs/CAHIER-DES-CHARGES-DEV.md` | specification fonctionnelle et technique complete |
| `docs/CAHIER-DES-CHARGES-DESIGN.md` | intention et systeme de design |
| `DESIGN-SPEC.md` | jetons et composants produits par l equipe design, **prerequis bloquant** |
| `loop/backlog.json` | les 67 fonctionnalites ordonnees, source de verite de la boucle |
| `wireframes/` | neuf maquettes filaires annotees |

## Regles qui priment sur tout le reste

**1. Jamais de tiret cadratin.** Nulle part. Ni code, ni commentaire, ni chaine, ni message de commit, ni reponse en conversation. Un hook bloque l ecriture, un controle bloque le commit, l integration continue bloque la fusion.

**2. `DESIGN-SPEC.md` avant toute vue.** Absent, tu ne codes aucune interface. Tu peux travailler la couche metier, qui n en depend pas.

**3. Une fonctionnalite, une branche, une pull request.** Jamais deux fonctionnalites sur la meme branche. Jamais de commit direct sur `main`.

**4. Aucune valeur visuelle hors de `DesignSystem`.** Couleurs, polices, rayons, espacements, durees.

**5. Aucun `import SwiftUI` hors de `DesignSystem`.**

## Boucle de developpement

```bash
./scripts/boucle.sh               boucle autonome, du debut a la publication
./scripts/boucle.sh --une         une seule fonctionnalite
./scripts/boucle-statut.sh        ou en est le projet
./scripts/verifications.sh        les neuf controles bloquants
```

En manuel, fonctionnalite par fonctionnalite :

```bash
./scripts/boucle-demarrer.sh      ouvrir la prochaine
./scripts/boucle-terminer.sh      cloturer et enchainer
```

Regle du systeme : c est `verifications.sh` qui decide qu une fonctionnalite est
terminee, jamais le verdict du modele. Le verdict explique, il ne tranche pas.

La competence `boucle-projet` decrit le deroulement complet. Charge la quand l utilisateur demande de demarrer, de continuer ou de faire avancer le projet.

## Competences du projet

| Competence | Quand la charger |
|---|---|
| `boucle-projet` | piloter le cycle, demarrer, cloturer, enchainer |
| `design-systeme` | toute vue, tout composant, tout libelle visible |
| `developpement-swift` | tout code, toute architecture, toute frontiere de paquet |
| `tests-qualite` | tout test, tout critere d acceptation, toute mesure |
| `release-dmg` | signature, notarisation, DMG, publication |

## Architecture

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

## Pieges connus de ce domaine

Ces sept erreurs ont coule des projets comparables. Elles sont listees par gravite.

1. Coder les vues avant d avoir lu `DESIGN-SPEC.md`.
2. Oublier le sens de lecture dans le modele. Le rajouter apres coup impose de reprendre le moteur, la pagination, les gestes et les tests.
3. Charger les images en pleine resolution. Une page fait environ 54 Mo decompressee.
4. Ignorer la limite de texture de 16384 pixels en mode webtoon. L echec est silencieux et frappe les chapitres les plus lus.
5. Compter les chapitres non lus a la volee pendant le defilement de la grille.
6. Confondre la direction de l interface et le sens de lecture du manga. Invisible en francais, systematique en arabe.
7. Mettre SwiftUI dans un paquet metier.

## Contraintes juridiques

- Nom, icone et identite visuelle originaux. Ne reprends aucun element identifiant d une application existante.
- Aucune ligne de code copiee ou decompilee depuis une application tierce.
- Aucun contenu sous droit d auteur heberge ou redistribue.
- Identifiants dans le trousseau, jamais dans `UserDefaults`, jamais en clair.
- Une extension n execute jamais de code fourni par un tiers.

## Style de reponse attendu

Direct. Dis ce qui ne va pas plutot que de resumer ce que fait le code. Quand un critere d acceptation n est pas rempli, dis le au lieu de le cocher. Quand tu es bloque, marque la fonctionnalite bloquee et explique ce dont tu as besoin, ne bricole pas.
