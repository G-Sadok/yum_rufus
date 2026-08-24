# App/Yum

Cible multiplateforme macOS, iPadOS et iOS. Vues, navigation, cycle de vie.

## Ce qui vit ici

- `YumApp.swift`, le point d entree et la scene principale
- `Coquille/`, l assemblage de la coquille et le contenu de chaque destination
- `Chaines.swift`, le seul endroit du code ou une cle du catalogue apparait
- `Ressources/Localizable.xcstrings`, le catalogue de chaines

## Ce qui ne vivra jamais ici

- une couleur, une police, un rayon, un espacement ou une duree en clair,
  tout passe par le paquet `DesignSystem`
- une chaine en dur dans une vue, tout passe par le catalogue de chaines
- de la logique metier, qui appartient aux paquets sous `Packages/`

## Projet Xcode

`Yum.xcodeproj` est arrive avec F008. Il emploie un groupe synchronise sur le
dossier `Yum`, donc un fichier ajoute ici entre dans la cible sans passer par le
manifeste. Les paquets sont references en local depuis `../Packages`.

Le schema `Yum` est partage et ne declare aucune cible de test. La logique de la
coquille, ordre des destinations, repli, presentation par gabarit, raccourcis,
vit dans `Core` et `DesignSystem`, ou elle est couverte par les tests que Swift
Package Manager execute a chaque commit. Une cible de test propre a la cible
d application arrivera avec le premier code qui ne pourra pas descendre dans un
paquet.

`scripts/verifications.sh` compile et teste les paquets, puis compile
l application avec `xcodebuild` des que ce projet est present.
