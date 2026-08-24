---
name: design-systeme
description: "Applique et fait respecter le systeme de design du projet. A utiliser des qu il s agit d ecrire ou de modifier une vue, un composant d interface, un ecran, un theme, une couleur, une typographie, un espacement, une animation ou un libelle visible par l utilisateur. A utiliser aussi pour verifier qu une interface existante est conforme au DESIGN-SPEC."
---

# Systeme de design

## Prealable bloquant

Avant toute vue, verifie que `DESIGN-SPEC.md` existe a la racine du depot.

- Present : lis le en entier. Pas en diagonale, en entier.
- Absent : arrete toi. Dis le clairement. N invente aucune valeur visuelle. Tu peux continuer a travailler sur la couche metier, qui ne depend d aucune decision de design.

## La regle qui structure tout

**Aucune valeur visuelle n existe en dehors du paquet `DesignSystem`.**

Cela vaut pour les couleurs, les tailles de police, les graisses, les rayons, les espacements, les durees d animation et les courbes.

```swift
// Interdit, le controle 5 le detecte et bloque le commit
.foregroundStyle(Color(red: 0.04, green: 0.52, blue: 1.0))
.font(.system(size: 15, weight: .semibold))
.padding(20)

// Attendu
.foregroundStyle(Jetons.Couleur.accent)
.font(Jetons.Typo.headline)
.padding(Jetons.Espace.x5)
```

Si un jeton te manque, tu ne l inventes pas dans la vue. Tu l ajoutes au paquet `DesignSystem`, en citant la ligne du `DESIGN-SPEC.md` qui le justifie. Si le document ne le justifie pas, la question remonte au design, pas au code.

## La these du produit

L interface doit **disparaitre**. Une page de manga est une oeuvre graphique dense. Toute interface qui se met a coter d elle entre en concurrence avec elle et perd.

Consequences que tu appliques sans qu on te les redemande :

- Le lecteur est noir, sans chrome permanent, sans bordure autour de la page, sans ombre.
- Les barres se retirent des que la lecture commence.
- Aucune couleur saturee dans le champ de vision pendant la lecture.
- L accent bleu signale ce sur quoi on peut agir. Il ne decore jamais.
- Le mouvement explique une transition. Il n impressionne pas.

## L element signature

La pastille de non lus et le filet de progression sur les couvertures sont **le seul endroit du produit ou l accent bleu apparait en aplat sur du contenu**.

Ils meritent une precision absolue : geometrie exacte, alignement optique, contraste verifie sur couverture claire comme sur couverture sombre. Ne les traite pas comme un detail.

## Trois etats par ecran, toujours

Une vue livree sans ses trois etats est incomplete. Le script de verification ne le detecte pas, c est a toi de ne pas tricher.

**Vide** : icone, titre, une phrase qui dit quoi faire, action facultative. C est une invitation a agir, pas un constat.

**Chargement** : squelettes aux dimensions exactes du contenu attendu. Jamais une roue de chargement seule sur une zone pleine.

**Erreur** : la cause reelle nommee, la sortie indiquee, un bouton pour reessayer. L erreur ne s excuse pas et ne reste jamais vague.

## Textes d interface

- Voix active. Le bouton dit ce qui se passe : `Enregistrer`, pas `Valider`.
- Le meme mot pour la meme action du debut a la fin d un parcours. Le bouton `Telecharger` produit l etat `Telecharge`.
- Pas de vocabulaire technique visible. On dit `serveur`, pas `endpoint`. On dit `source`, pas `provider`.
- Pas de point d exclamation.
- Pas de tiret cadratin.
- Aucune chaine en dur dans une vue. Tout passe par le catalogue de chaines.

## Accessibilite, non negociable

- Contraste minimal 4.5:1 sous 18 px, 3:1 au dela.
- Cible de pointage 44 par 44 sur iOS, 28 par 28 sur macOS.
- Focus clavier visible partout, contour de 2 en accent avec un decalage de 2. Jamais supprime.
- Texte dynamique jusqu a la taille accessibilite extra extra large. Au dela d une certaine taille, les lignes de reglages passent en disposition verticale.
- Aucune information transmise par la couleur seule. La pastille porte un chiffre, l etat de connexion porte un texte.
- Chaque icone sans libelle porte une etiquette d accessibilite.
- Le reglage systeme Reduire les animations supprime toutes les translations.

## Adaptation multiplateforme

| Contexte | Comportement |
|---|---|
| macOS | barre laterale encastree de 196, repliable |
| iPad paysage | identique a macOS |
| iPad portrait | barre laterale repliee, ouverture par glissement |
| iPhone | barre laterale remplacee par une barre d onglets basse |

Le gabarit colonne de 580 devient pleine largeur sur iPhone, avec une marge de 16. Les cartes gardent leur rayon de 12.

## Controle avant de conclure

1. Compare ta vue aux maquettes correspondantes du dossier `wireframes/`.
2. Verifie chaque valeur contre `DESIGN-SPEC.md`.
3. Lance `./scripts/verifications.sh` et regarde les controles 4, 5 et 6.
4. Teste en mode clair et en mode sombre, dans les quatre themes.
5. Navigue au clavier uniquement, du debut a la fin de l ecran.

## Le test final

Ouvre une page de manga en plein ecran. Si ton regard est attire par un element d interface avant d etre attire par le dessin, l ecran a echoue. Reprends le.
