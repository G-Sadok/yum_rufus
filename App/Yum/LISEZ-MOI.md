# App/Yum

Cible multiplateforme macOS, iPadOS et iOS. Vues, navigation, cycle de vie.

Ce dossier est volontairement vide de code a l etape 0. La coquille de
l application et sa navigation arrivent avec F008, apres la generation des
jetons de design (F002) et le schema de base de donnees (F003).

## Ce qui vivra ici

- le point d entree de l application et la scene principale
- les vues et la navigation, qui n existent que dans cette cible
- le catalogue de chaines localisees
- les ressources de la cible, icone comprise

## Ce qui ne vivra jamais ici

- une couleur, une police, un rayon, un espacement ou une duree en clair,
  tout passe par le paquet `DesignSystem`
- une chaine en dur dans une vue, tout passe par le catalogue de chaines
- de la logique metier, qui appartient aux paquets sous `Packages/`

Le projet Xcode de cette cible n existe pas encore. Tant qu il est absent,
`scripts/verifications.sh` compile et teste la couche metier avec Swift Package
Manager, puis bascule automatiquement sur `xcodebuild` des que le projet
apparait ici.
