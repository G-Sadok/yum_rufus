# App/Yum

Emplacement de la cible multiplateforme decrite a la section 2.3 du cahier de
developpement. Les vues, la navigation et le catalogue de chaines vivent ici.

Le dossier est volontairement vide de code pour l instant.

## Pourquoi il n y a pas encore de projet Xcode

Le projet Xcode et la cible `Yum` sont produits par la fonctionnalite F008,
`Coquille de l application et navigation`, qui depend elle meme de F002 pour les
jetons du systeme de design. Creer une coquille avant F002 reviendrait a coder
une vue sans avoir lu `DESIGN-SPEC.md`, ce que la premiere regle du projet
interdit.

Tant que le projet Xcode n existe pas, `scripts/verifications.sh` compile et
teste les paquets Swift de `Packages/`. Des que `Yum.xcodeproj` apparait a la
racine du depot, le script bascule automatiquement sur `xcodebuild`.

## Regles qui s appliquent a ce dossier

- Aucune valeur visuelle en dur, tout vient de `DesignSystem`.
- Aucune chaine en dur dans une vue, tout passe par le catalogue de chaines.
- Aucune force unwrap.
