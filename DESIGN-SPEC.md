# DESIGN-SPEC, Yum

Document de reference pour l implementation. A lire en entier avant d ecrire la premiere ligne de code.

- Produit : lecteur de manga, manhwa et manhua pour macOS, iPadOS et iOS.
- Version du document : 1.1
- Livrables associes : `design-tokens.json`, `01 Jetons.dc.html`, `02 Composants.dc.html`, `03 Ecrans.dc.html`, `04 iPad et iPhone.dc.html`, `icone/`.

---

## 0. REGLES NON NEGOCIABLES

1. **Jamais de tiret cadratin**, dans aucun libelle, aucun texte, aucun commentaire de code. Virgule, deux points, parenthese ou phrase separee.
2. Libelles en francais, minuscule de phrase, sans point final sauf pour les phrases completes de description.
3. Aucun element de marque tiers. Le nom, l icone et l identite sont originaux.
4. Ordre d implementation : jetons, composants, ecrans. Jamais l inverse.
5. Tout ecran existe en quatre etats : vide, chargement, charge, erreur. Un ecran sans ses etats n est pas fini.
6. Mode sombre par defaut. Mode clair obligatoire mais secondaire.
7. Aucun point d exclamation dans l interface.

**La these** : l interface doit disparaitre. Une page de manga est une oeuvre graphique dense en noir et blanc. Toute interface qui se met a coter d elle entre en concurrence avec elle et perd. Le lecteur se comporte comme un cadre de musee, present, precis, invisible des qu on regarde l oeuvre.

**Critere de recette final** : ouvrir une page en plein ecran dans le lecteur. Si le regard est attire par un element d interface avant d etre attire par le dessin, l ecran est a refaire.

### 0.1 Hierarchie des sources, et conflits resolus

Deux sources gouvernent ce document : le cahier des charges redige, et les neuf wireframes de reference. Regle appliquee :

- **Le texte du cahier des charges est normatif pour toute valeur chiffree.**
- **Le wireframe est normatif pour tout contenu que le texte ne fixe pas** : libelles exacts, formats de sous ligne, largeurs de menu, ordre des lignes d une carte.

Conflits releves, et arbitrage retenu. Chacun est reversible sur demande.

| Point | Cahier des charges | Wireframe | Retenu |
|---|---|---|---|
| Gabarit de la fiche de serie | colonne 580, contrainte stricte (3.3) | pleine largeur, lignes de chapitre a 1108 (04) | **colonne 580**, parce que 5.6 declare que la fiche n existe pas dans les captures de reference |
| Fond d un chapitre lu | transparent (4.5) | `#1A1A1C` (04) | **transparent** |
| Titre d etat vide | `title1` 22 (4.10) | 15 gras (09) | **22**, le wireframe illustre le motif a echelle reduite |
| Glyphe d erreur | non precise | cercle avec barre et point, `warning` (09) | **cercle**, `exclamationmark.circle` |
| Bouton Reessayer | non precise | secondaire (09) | **secondaire** |
| Duree de l essai premium | non precisee | 7 jours (09) | **7 jours** |
| Rayon de la couverture de la fiche | 10 pour les cartes (4.3) | 12 (04) | **12** pour la seule couverture heros |

**Marques tierces ecartees.** Les wireframes citent MangaDex comme nom de source et AniList, MyAnimeList, Kitsu comme services de suivi. La regle 3 interdit ces reprises. Remplacements retenus : `Catalogue OPDS` pour la source, `Suivis sur vos services de suivi` pour l avantage premium. Komga, Kavita, Jellyfin, OPDS, SMB, NFS, WebDAV et iCloud Drive restent, parce que le cahier des charges les impose nommement dans le menu de la section 5.3.

---

## 1. JETONS

### 1.1 Surfaces, quatre themes, deux variantes

Les themes ne permutent que les surfaces. Les jetons de texte et les jetons semantiques dependent de la variante, pas du theme.

| Jeton | Midnight sombre | Midnight clair | Obsidian sombre | Obsidian clair |
|---|---|---|---|---|
| `surface.canvas` | `#0E0E10` | `#F2F2F5` | `#000000` | `#FFFFFF` |
| `surface.window` | `#131315` | `#FAFAFC` | `#000000` | `#FFFFFF` |
| `surface.chrome` | `#161618` | `#F0F0F4` | `#0B0B0C` | `#F7F7F9` |
| `surface.sidebar` | `#1B1B1D` | `#E9E9EE` | `#101012` | `#F0F0F3` |
| `surface.card` | `#202023` | `#FFFFFF` | `#161618` | `#F4F4F7` |
| `surface.cardHover` | `#26262A` | `#F4F4F8` | `#1B1B1D` | `#EDEDF1` |
| `surface.menu` | `#2C2C30` | `#E6E6EB` | `#202023` | `#E8E8EC` |
| `surface.selected` | `#3A3A3E` | `#D5D5DC` | `#2C2C30` | `#DADAE0` |
| `surface.field` | `#141416` | `#FFFFFF` | `#050506` | `#FFFFFF` |
| `surface.sheet` | `#1F1F22` | `#FFFFFF` | `#1A1A1D` | `#FFFFFF` |
| `surface.reader` | `#000000` | `#FFFFFF` | `#000000` | `#FFFFFF` |
| `surface.premium` | `#1C2740` | `#E4EDFB` | `#151E33` | `#E4EDFC` |

| Jeton | Slate sombre | Slate clair | Paper sombre | Paper clair |
|---|---|---|---|---|
| `surface.canvas` | `#0E0F13` | `#EDEFF4` | `#121110` | `#F5F5F7` |
| `surface.window` | `#131418` | `#F7F8FC` | `#171614` | `#FFFFFF` |
| `surface.chrome` | `#16171C` | `#EBEDF2` | `#1A1917` | `#F2F2F4` |
| `surface.sidebar` | `#1B1C22` | `#E4E7EE` | `#1F1E1B` | `#ECECEF` |
| `surface.card` | `#202128` | `#FFFFFF` | `#242320` | `#FFFFFF` |
| `surface.cardHover` | `#26272F` | `#F2F4F9` | `#2A2926` | `#F5F5F7` |
| `surface.menu` | `#2C2D36` | `#E0E4EC` | `#302F2B` | `#E8E8EB` |
| `surface.selected` | `#3A3B45` | `#D0D5E0` | `#3E3D39` | `#DBDBDF` |
| `surface.field` | `#141519` | `#FFFFFF` | `#171614` | `#FFFFFF` |
| `surface.sheet` | `#1F2027` | `#FFFFFF` | `#232220` | `#FFFFFF` |
| `surface.reader` | `#000000` | `#FFFFFF` | `#000000` | `#000000` |
| `surface.premium` | `#1C2740` | `#E2EBFA` | `#1C2740` | `#E8F0FC` |

Caractere de chaque theme :

- **Midnight** : defaut, gris neutre tres sombre.
- **Obsidian** : noir absolu pour ecrans OLED, toutes les surfaces descendent d un cran, `canvas` et `window` a `#000000`.
- **Slate** : gris bleute, teinte decalee de six degres vers le bleu, contraste interne reduit.
- **Paper** : theme concu pour la variante claire, inversion complete.

**Trois regles de surface a ne pas casser :**

1. `surface.canvas` peint **la zone de contenu a l interieur de la fenetre**, pas seulement l arriere plan hors fenetre. `surface.window` ne peint que la coquille et la gouttiere de la barre laterale. Confondre les deux supprime l ecart canvas vers carte, qui est la seule voie de hierarchie disponible puisque l ombre sur les cartes est interdite.
2. En variante claire, `card`, `field`, `menu` et `selected` restent quatre valeurs distinctes. Les ecraser toutes sur `#FFFFFF` fait disparaitre les pions de segment, les capsules de categorie et les contours de champ.
3. `surface.sheet` est le fond des modales et des feuilles de configuration. Il est distinct de `surface.menu`, qui reste le fond des menus contextuels et des boutons secondaires.

### 1.2 Texte

| Jeton | Sombre | Clair | Usage |
|---|---|---|---|
| `text.primary` | `#F2F2F7` | `#1C1C1E` | titres, libelles de ligne |
| `text.secondary` | `#C7C7CC` | `#3C3C43` | valeurs de reglage, texte courant |
| `text.tertiary` | `#8E8E93` | `#5C5C61` | descriptions, metadonnees |
| `text.quaternary` | `#6E6E73` | `#6E6E73` | mention legale, version, sous ligne d un chapitre lu |
| `text.disabled` | `#48484C` | `#ABABB0` | element inactif |
| `text.onAccent` | `#FFFFFF` | `#FFFFFF` | texte sur aplat accent |
| `text.emptyGlyph` | `#4A4A4F` | `#B4B4BA` | glyphe d etat vide |

En variante claire, `tertiary` et `quaternary` sont assombris par rapport a la table d origine pour tenir le seuil de 4.5:1.

### 1.3 Semantique

| Jeton | Sombre | Clair | Usage |
|---|---|---|---|
| `accent` | `#0A84FF` | `#0A84FF` | aplat d action, pastille de non lus, filet de progression |
| `accent.pressed` | `#0774E0` | `#0774E0` | etat presse |
| `accent.text` | `#0A84FF` | `#0B6BCB` | texte accentue sous 18 px |
| `success` | `#30D158` | `#248A3D` | serveur connecte, telechargement termine |
| `warning` | `#FF9F0A` | `#B25000` | avertissement, connexion instable |
| `danger` | `#FF453A` | `#D70015` | suppression, echec critique |
| `separator` | `#2E2E32` | `#E3E3E6` | filet entre deux lignes d une meme carte |
| `border` | `#3A3A3E` | `#D1D1D6` | contour de champ, contour de menu, contour de feuille |
| `focusRing` | `#0A84FF` | `#0A84FF` | contour de focus clavier |
| `scrim` | `rgba(0,0,0,0.45)` | `rgba(0,0,0,0.30)` | voile sous une modale |

`accent` ne change pas entre les variantes, conformement au cahier des charges. `accent.text` est une derivation **obligatoire** : `#0A84FF` sur fond blanc plafonne a 3.3:1 et ne peut pas porter du texte sous 18 px. En aplat on utilise toujours `accent`, jamais `accent.text`.

### 1.4 Fonds du lecteur

| Valeur du reglage | Fond |
|---|---|
| Noir OLED | `#000000` |
| Gris sombre | `#1A1A1C` |
| Blanc | `#FFFFFF` |
| Sepia | `#EFE3CE` |

### 1.5 Typographie

Police unique, `-apple-system` en premiere valeur de pile, puis `SF Pro Text`, `SF Pro Display`, `Helvetica Neue`, `sans-serif`. Aucune police tierce. La personnalite ne vient pas de la fonte, elle vient de la discipline de l echelle.

| Role | Taille | Graisse | Interlignage | Interlettrage | Usage |
|---|---|---|---|---|---|
| `display` | 28 | 700 | 34 | -0.02em | titre d une fiche de serie |
| `title1` | 22 | 700 | 28 | -0.01em | titre d etat vide |
| `title2` | 17 | 700 | 22 | -0.01em | titre de barre d outils, titre de feuille |
| `headline` | 15 | 700 | 20 | 0 | en tete de section de reglages |
| `body` | 15 | 400 | 20 | 0 | libelle de ligne, valeur de reglage |
| `callout` | 13 | 400 | 18 | 0 | texte courant, resume de serie |
| `footnote` | 12 | 400 | 16 | 0 | description sous une section, sous ligne |
| `caption` | 11 | 400 | 14 | 0.01em | mention legale, version |

Graisses autorisees : 400, 600, 700. La graisse 600 est reservee a cinq cas : libelle de barre laterale active, titre de carte de serie, texte de bouton principal, titre d un chapitre non lu, titre de serie dans la barre du lecteur.

**Chiffres tabulaires obligatoires** partout ou un nombre change en place : compteur de pages, pourcentage, taille de fichier, numero de chapitre, heure, compteur de categorie, compteur de resultats.

### 1.6 Rayons

| Valeur | Element |
|---|---|
| 6 | pastille, vignette d historique |
| 8 | onglet de categorie actif, bouton de barre d outils |
| 9 | champ de saisie, bouton d etat vide |
| 10 | bouton, conteneur d icone, couverture de carte, ligne de chapitre |
| 12 | carte, bouton principal du mur premium |
| 14 | barre laterale, menu contextuel, carte d etat de contenu |
| 16 | feuille de configuration, mur premium |
| 18 | fenetre |
| 20 | modale courte |
| capsule | boutons de modale et de feuille (rayon 17 sur une hauteur de 34), pastille de non lus |

### 1.7 Espacements

Echelle de 4. Valeurs autorisees : **4, 8, 12, 16, 20, 24, 32, 40, 56, 72**. Aucune autre valeur, y compris pour un ajustement optique.

### 1.8 Elevation

| Niveau | Ombre | Complement | Usage |
|---|---|---|---|
| 0 | aucune | aucun | contenu, cartes de reglages, cartes de serie |
| 1 | `0 8px 24px rgba(0,0,0,0.44)` | contour `border` | menu contextuel, popover, barre d actions de selection |
| 2 | `0 24px 64px rgba(0,0,0,0.60)` | voile `scrim` | modale, feuille de configuration, mur premium |

Aucune ombre sur les cartes. La hierarchie passe par la valeur de surface.

### 1.9 Mouvement

| Transition | Duree | Courbe |
|---|---|---|
| Survol, changement d etat local | 120 ms | `easeOut` |
| Apparition de menu ou popover | 180 ms | `spring(response: 0.28, damping: 0.86)` |
| Modale entrante | 240 ms | `spring(response: 0.34, damping: 0.82)` |
| Changement d ecran principal | 200 ms | fondu croise pur, aucun glissement |
| Tourne de page en mode pagine | 220 ms | `easeInOut`, desactivable par reglage |
| Barres du lecteur | 200 ms | fondu plus translation de 8 px |
| Pulsation de squelette | 1200 ms | opacite 0.4 vers 0.8, aller retour |
| Survol de carte de serie | 120 ms | echelle 1.02, `easeOut` |

`Reduire les animations` supprime toutes les translations et ramene chaque transition a un fondu de 100 ms.

Interdits : rebond sur les cartes, parallaxe, entree en cascade sur les grilles, rotation, particules.

Le mode webtoon n a **aucune** animation de transition, y compris de tourne de page.

### 1.10 Iconographie

SF Symbols exclusivement, graisse `regular`, echelle `medium`.

Tailles de rendu : 22 dans les lignes de reglages, 20 dans la barre laterale, 18 dans les barres d outils, 16 dans les menus.

| Element | Symbole |
|---|---|
| Bibliotheque | `books.vertical` |
| Historique | `clock` |
| Parcourir | `safari` |
| Rechercher | `magnifyingglass` |
| Reglages | `gearshape` |
| Premium | `crown` |
| Incognito | `eye.slash` |
| Verrouillage | `lock` |
| Sens de lecture | `text.book.closed` |
| Mise en page | `rectangle.split.2x1` |
| Rogner les bords | `crop` |
| Luminosite | `sun.max` |
| Chaleur | `thermometer.medium` |
| Amelioration IA | `wand.and.stars` |
| Colorisation IA | `paintbrush` |
| Telechargement | `arrow.down.circle` |
| Sauvegarde | `externaldrive` |
| iCloud | `icloud` |
| Aide | `questionmark.circle` |
| Signaler un bug | `ladybug` |
| Erreur de contenu | `exclamationmark.circle` |

---

## 2. MISE EN PAGE CHIFFREE

### 2.1 Fenetre macOS

| Propriete | Valeur |
|---|---|
| Taille minimale | 1024 par 720 |
| Taille par defaut a la premiere ouverture | 1280 par 860 |
| Barre de titre | unifiee avec la barre d outils, hauteur 60 |
| Filet sous la barre de titre | 1 px, `#2A2A2E` en sombre |
| Feux de circulation | natifs, position standard, premier centre a 28 du bord |
| Fond de fenetre | `surface.window` |
| Rayon de fenetre | 18 |
| Fond de la zone de contenu | `surface.canvas` |

### 2.2 Barre laterale

| Propriete | Valeur |
|---|---|
| Largeur | 196, fixe, non redimensionnable |
| Marge d encastrement | 12 sur les quatre cotes |
| Rayon | 14 |
| Fond | `surface.sidebar` |
| Hauteur de ligne | 40 |
| Rayon de ligne | 10 |
| Icone | a 14 du bord gauche, taille 20 |
| Libelle | a 40 du bord gauche, `body` 14 |
| Largeur repliee | 56, icones seules, info bulle au survol |

Cinq entrees dans cet ordre strict : Bibliotheque, Historique, Parcourir, Rechercher, Reglages.

| Etat | Fond | Libelle | Icone |
|---|---|---|---|
| Actif | `surface.selected` | `text.primary`, graisse 600 | `text.primary` |
| Repos | aucun | `text.secondary` | `text.tertiary` |
| Survol | `surface.card` | `text.secondary` | `text.tertiary` |

Le bloc d appel premium se cale en bas de la barre laterale : hauteur 52, rayon 12, fond `surface.premium`, couronne et titre `Passer a Premium` en `accent`, sous titre `7 jours offerts` en `text.tertiary`.

### 2.3 Zone de contenu, deux gabarits

**Gabarit large**, pour Bibliotheque, Historique, Parcourir, Rechercher : pleine largeur disponible, marge laterale 24, largeur maximale 1600 au dela de laquelle le contenu se centre.

**Gabarit colonne**, pour Reglages et le corps de la fiche de serie : colonne centree de **580 exactement**. Contrainte stricte. Une carte de reglages ne s etire jamais. Voir 0.1 pour le conflit avec le wireframe 04.

### 2.4 Grille de la bibliotheque

| Contexte | Colonnes | Gouttiere |
|---|---|---|
| macOS et iPad paysage | 5 | 20 |
| iPad portrait | 4 | 20 |
| iPhone | 2 | 12 |

Largeur de couverture comprise entre 150 et 200 selon la place. Ratio 2:3 non negociable.

### 2.5 iPad et iPhone

| Contexte | Barre de navigation | Marge laterale | Gabarit colonne |
|---|---|---|---|
| iPad paysage | `NavigationSplitView`, barre laterale complete de 196 | 24 | 580 |
| iPad portrait | barre laterale repliee a 56, deployee par glissement depuis le bord | 24 | 580 |
| iPhone | barre d onglets basse, cinq entrees, memes icones et memes libelles | 16 | pleine largeur |

Sur iPhone, les cartes de reglages se collent aux marges et conservent leur rayon de 12.

**Ce qui ne change jamais d une plateforme a l autre** : les jetons de couleur, l echelle typographique, le ratio 2:3 des couvertures, la geometrie de la pastille et du filet, le rayon 12 des cartes.

**Ce qui grossit au toucher** : la pastille du curseur du lecteur passe de 16 a 30, le bouton principal de la fiche de 38 a 44, les actions de la barre du lecteur de 28 a 34 avec retrait des libelles sur iPhone.

**Ce qui se replie sur iPhone** : les genres et la ligne d etat de la fiche partent dans une feuille de details, les actions secondaires de la liste de chapitres passent dans un menu, le champ de recherche de la barre d outils devient un bouton d icone, le texte d etat d une source disparait au profit de la seule pastille et du sous titre.

---

## 3. L ELEMENT SIGNATURE

La pastille de non lus et le filet de progression sont **le seul endroit du produit ou l accent bleu apparait en aplat sur du contenu**. Rien d autre ne se pose sur une couverture au repos : pas de note, pas d etoile, pas de badge de source.

| Propriete | Valeur |
|---|---|
| Pastille, ancrage | haut a droite, marge 10 |
| Pastille, hauteur | 20 |
| Pastille, rayon | 10 |
| Pastille, remplissage horizontal | 8 de chaque cote |
| Pastille, largeur minimale | 20 |
| Pastille, fond | `accent` |
| Pastille, texte | `caption` 11, graisse 700, `#FFFFFF`, chiffres tabulaires |
| Pastille, visibilite | masquee si zero non lu |
| Filet, hauteur | 4 |
| Filet, position | cale sur le bord inferieur de la couverture, a l interieur du rayon |
| Filet, couleur | `accent` |
| Filet, largeur | proportionnelle a la progression |
| Filet, visibilite | masque a zero et a cent pour cent |

Un voile de 40 de haut a `rgba(14,14,16,0.53)` est pose sur le bas de la couverture, sous le filet, pour que la pastille et le filet gardent leur contraste sur une couverture claire. C est le seul degrade tolere du produit, et il ne porte aucune couleur.

Ces deux marques doivent tenir sur couverture claire comme sur couverture sombre, sans contour ni ombre ajoutes. Le texte blanc sur `accent` mesure 3.5:1, accepte parce que l information est doublee par le chiffre lui meme et par une etiquette d accessibilite.

---

## 4. COMPOSANTS

### 4.1 Ligne de reglage

Composant le plus utilise du produit.

| Propriete | Valeur |
|---|---|
| Hauteur, version simple | 52 |
| Hauteur, avec description ou curseur | 76 |
| Marge laterale | 20 |
| Icone | 22, en `accent` |
| Gouttiere apres l icone | 16 |
| Debut du libelle | 58 du bord gauche |
| Libelle | `body` |

Cinq variantes :

1. **Interrupteur** : commutateur 48 par 28, rayon 14, pastille blanche de 24 avec 2 de jeu, fond `accent` a l etat actif et `surface.selected` a l etat inactif.
2. **Valeur et menu** : valeur en `text.secondary` alignee a droite, chevron double vertical en `text.tertiary` a 4 de la valeur. La valeur passe en `accent` quand elle designe un choix herite du systeme.
3. **Navigation** : chevron simple vers la droite en `text.tertiary`. Jamais de valeur vide a cote d un chevron double.
4. **Curseur** : libelle sur la premiere ligne, valeur numerique alignee a droite en `footnote`, curseur sur la seconde ligne occupant la largeur utile a partir de 58.
5. **Compteur** : valeur puis deux chevrons empiles dans un conteneur de 30 par 28, rayon 8, fond `surface.menu`.

**Variante premium**, deux formes :

- **Appel a l abonnement** : fond `surface.premium`, couronne en `accent` comme icone de gauche, libelle en `accent` graisse 600, chevron simple en `accent` a droite.
- **Fonction verrouillee** : fond `surface.premium`, icone propre a la fonction en `accent`, libelle en `accent`, couronne en `accent` a droite, aucun controle. Le clic ouvre le mur premium, pas le reglage.

Etats :

| Etat | Fond | Libelle | Icone | Complement |
|---|---|---|---|---|
| Repos | transparent sur `surface.card` | `text.primary` | `accent` | aucun |
| Survol | `surface.cardHover` | `text.primary` | `accent` | aucun |
| Presse | `surface.cardHover` | `text.primary` | `accent` | controle en `accent.pressed` |
| Focus clavier | inchange | inchange | inchange | contour 2 en `accent`, decalage 2 |
| Desactive | inchange | `text.disabled` | `text.disabled` | controle en `surface.cardHover` |
| Verrouille premium | `surface.premium` | `accent` | `accent` | couronne a droite |

Au dela de la taille de texte dynamique `large`, la ligne passe en disposition verticale : libelle sur la premiere ligne, controle sur la seconde, aligne a gauche a 58.

### 4.2 Carte de section

Une ou plusieurs lignes empilees dans un conteneur de rayon 12, fond `surface.card`.

| Propriete | Valeur |
|---|---|
| Separateur | 1 px en `separator`, encastre de 20 a gauche, affleurant a droite |
| Separateur apres la derniere ligne | aucun |
| En tete de section | `headline`, `text.primary`, 14 au dessus de la carte, aligne sur son bord gauche |
| Description de section | `footnote`, `text.tertiary`, 12 sous la carte, largeur maximale identique a la carte |
| Espacement entre deux sections | 32 |

### 4.3 Carte de serie

| Propriete | Valeur |
|---|---|
| Couverture | ratio 2:3, rayon 10, largeur 150 a 200 |
| Titre | `callout` graisse 600, deux lignes maximum, troncature |
| Source | `caption`, `text.tertiary`, une ligne |
| Gouttiere titre vers couverture | 10 |
| Voile de bas de couverture | 40 de haut, `rgba(14,14,16,0.53)` |
| Pastille de non lus | voir section 3 |
| Filet de progression | voir section 3 |
| Survol | echelle 1.02, 120 ms, apparition d un bouton d options 26 |
| Selection multiple | contour de 3 en `accent` a l interieur du rayon |

**Mode liste compacte**, alternative a la grille : vignette 48 par 72 rayon 6, titre en `body` graisse 600, source en `footnote`, compteur de non lus a droite en pastille, date du dernier chapitre en `caption` `text.quaternary`. Hauteur de ligne 88, rayon 12, fond `surface.card`.

### 4.4 Ligne de source

| Propriete | Valeur |
|---|---|
| Hauteur | 72 |
| Rayon | 12 |
| Fond | `surface.card`, `surface.cardHover` au survol |
| Icone de source | carre de 40, rayon 10, a 16 du bord gauche |
| Nom | `body` graisse 700, a 72 du bord gauche |
| Sous titre | `footnote`, `text.tertiary` |
| Pastille d etat | 10, `success` si le serveur repond, `warning` si la derniere tentative a echoue, aucune pastille pour une source locale |
| Bouton d options | trois points de 3, a l extreme droite |

**Format du sous titre**, impose par le wireframe 03. Le sous titre porte l information d etat en clair, ce qui satisfait la regle d accessibilite sans ajouter un libelle a droite de la pastille :

| Cas | Sous titre |
|---|---|
| Source locale | `v1.0` |
| Serveur qui repond | `https://komga.local  connecte` |
| Extension de catalogue | `v1.4  multilingue` |
| Serveur muet | `https://dav.exemple.net  sans reponse depuis 21:04` |

Reordonnancement par glisser deposer lorsque le tri est en mode Personnalise.

### 4.5 Ligne de chapitre

Structure a deux lignes, toujours. La sous ligne n est jamais vide.

| Propriete | Valeur |
|---|---|
| Hauteur | 56 |
| Rayon | 10 |
| Marge laterale | 18 |
| Titre | `body`, format `Chapitre N, Titre du chapitre` |
| Sous ligne | `footnote`, chiffres tabulaires |

| Etat | Fond | Titre | Sous ligne | Marque |
|---|---|---|---|---|
| Non lu | `surface.card` | `text.primary` graisse 600 | `text.tertiary`, `12 aout 2026  24 pages` | pastille pleine de 12 en `accent` a droite |
| Lu | transparent | `text.tertiary` graisse 400 | `text.quaternary`, `Lu` | aucune |
| En cours | transparent | `text.tertiary` | `Lu  page 14 sur 38` | filet de 3 en `accent` a 60 pour cent d opacite sur le bord inferieur |
| Telecharge | selon l etat de lecture | selon l etat de lecture | suffixe `  telecharge` | `arrow.down.circle` 22 en `accent` avant la pastille |
| Survol | `surface.cardHover` | inchange | inchange | inchange |
| Focus clavier | inchange | inchange | inchange | contour 2 en `accent`, decalage 2 |

Selection multiple par clic maintenu ou Cmd clic.

**Barre d actions de selection multiple** : hauteur 52, rayon 12, fond `surface.menu`, elevation 1, ancree en bas de la zone de liste. Compteur `N selectionnes` en `callout` graisse 700 a gauche, puis Marquer lu, Telecharger, Supprimer. Supprimer en `danger`.

### 4.6 Boutons

| Variante | Fond | Texte | Contour |
|---|---|---|---|
| Principal | `accent` | `#FFFFFF`, `body` graisse 600 | aucun |
| Secondaire | `surface.menu` | `text.primary`, `body` | `border` |
| Discret | transparent | `accent.text`, `body` | aucun |
| Destructif | transparent | `danger`, `body` | `danger` |

| Contexte | Hauteur | Rayon |
|---|---|---|
| Contenu | 38 | 10 |
| Modale et feuille | 34 | 17, capsule |
| Barre d outils | 28 | 8 |
| Etat vide et etat d erreur | 32 | 9 |
| Mur premium | 42 | 12 |
| iPhone, action principale | 44 | 10 |

Etats : survol eclaircit le fond d un cran, presse utilise `accent.pressed` ou le fond de survol assombri, focus clavier ajoute le contour de 2 en `accent` avec un decalage de 2, desactive passe le texte en `text.disabled` et le fond a une version desaturee du fond de repos. Un bouton de confirmation desactive dans une modale prend le fond `surface.selected` et le texte `text.primary` a opacite reduite.

### 4.7 Menu contextuel

| Propriete | Valeur |
|---|---|
| Fond | `surface.menu` |
| Rayon | 14 |
| Elevation | 1 |
| Largeur minimale | 220 |
| Largeur du menu plus de Parcourir | **324**, impose |
| Hauteur de ligne | 34 |
| Icone | 16 en `accent`, a gauche, a 18 du bord |
| Libelle | `body`, a 40 du bord |
| Coche | a gauche, pour un groupe a choix unique |
| Separateur | pleine largeur entre deux groupes |
| En tete de groupe | `caption`, `text.tertiary`, hauteur 26 |

### 4.8 Modale courte

| Propriete | Valeur |
|---|---|
| Largeur | 380 |
| Hauteur, cas de reference | 196 |
| Rayon | 20 |
| Fond | `surface.sheet`, contour 1 px `border` |
| Elevation | 2 |
| Marge interieure | 32 en haut et sur les cotes, 24 en bas |
| Titre | 16 graisse 700 |
| Description | `callout`, `text.secondary`, deux lignes maximum |
| Champ | 316 par 34, rayon 9 |
| Boutons | deux capsules de 150 par 34, rayon 17, gouttiere 16 |
| Confirmation | a droite |
| Fermeture | Echap, et clic sur le voile |

Toutes les modales rendent le focus a l element declencheur a la fermeture.

### 4.9 Feuille de configuration

| Propriete | Valeur |
|---|---|
| Largeur | 440 |
| Hauteur, cas de reference | 420 |
| Rayon | 16 |
| Fond | `surface.sheet`, contour 1 px `border` |
| Elevation | 2 |
| Titre | `title2` |
| Phrase d explication | `footnote`, `text.tertiary` |
| Etiquette de champ | `footnote`, `text.secondary`, 10 au dessus du champ |
| Champ | 384 par 34, rayon 9 |
| Ecart entre deux champs | 26 |
| Bouton de test | 180 par 34, rayon 9, secondaire |
| Retour de test | pastille de 12 plus texte `footnote`, en `success` ou en `danger` |
| Boutons de pied | 120 par 34, rayon 17, Annuler a gauche, Enregistrer a droite |

Enregistrer reste desactive tant que le test de connexion n a pas reussi.

Champ de saisie :

| Etat | Fond | Contour | Texte |
|---|---|---|---|
| Repos | `surface.field` | 1 px `border` | espace reserve en `text.quaternary` |
| Actif | `surface.field` | 2 px `accent` | `text.primary` |
| Rempli hors focus | `surface.field` | 1 px `border` | `text.primary` |
| Erreur | `surface.field` | 1.5 px `danger` | `danger` |

Rayon 9, hauteur 34 en feuille et en modale, 36 en contenu.

### 4.10 Etats de contenu

Carte de demonstration : 300 par 240, rayon 14, fond `surface.chrome`, contour 1 px `#2A2A2E`.

**Vide** : glyphe de 52 en `text.emptyGlyph`, trait de 3, titre en `title1`, phrase en `callout` `text.tertiary`, action facultative en bouton principal de 32 par 120, rayon 9. Bloc centre dans la zone de contenu, largeur maximale 420, texte centre. Aucune illustration vectorielle generique.

**Chargement** : squelettes aux dimensions exactes du contenu attendu, fond `surface.card`, pulsation d opacite de 0.4 a 0.8 sur 1200 ms. Jamais de roue de chargement seule sur une zone pleine.

**Erreur** : glyphe `exclamationmark.circle` de 52 en `warning`, trait de 3, titre qui nomme la cause reelle, phrase qui indique la sortie, **bouton Reessayer en variante secondaire**, plus un second bouton de repli quand il existe. L erreur ne s excuse pas et ne reste jamais vague.

### 4.11 File de telechargement

| Propriete | Valeur |
|---|---|
| Largeur du panneau | 324 |
| Ligne | 268 par 52, rayon 10, fond `surface.card` |
| Indicateur | 24, a 26 du bord gauche |
| Titre | `callout`, `text.primary` |
| Sous ligne | `caption`, `text.tertiary` |

| Etat | Indicateur | Sous ligne |
|---|---|---|
| En cours | anneau `accent` de 2.5, tirets 50 sur 25 | `14 sur 24 pages` |
| Termine | disque plein `success` | `Termine  32 Mo` |
| En attente | anneau `text.quaternary` de 2 | `En attente` |

Pause et reprise par ligne. Le libelle de l action produit l etat : `Telecharger` produit `Termine`.

---

## 5. ECRANS

### 5.1 Bibliotheque

**Barre d outils** : titre a gauche a 172 du bord de fenetre, puis a droite bouton plus, bouton de tri de 46 par 28, champ de recherche de 206 par 28.

**Menu de tri**, dans cet ordre : A a Z avec coche, Derniere lecture, Derniere mise a jour, Date d ajout, Non lu, separateur, Ordres de lecture.

**Barre de categories** sous la barre d outils : onglets textuels avec compteur, hauteur 30, l onglet actif porte un fond `surface.menu` de rayon 8, pas une capsule. Marge basse 12. Categorie Tout toujours en premier.

Libelles de reference : `Tout 128`, `En cours 24`, `Termines 61`, `Prevus 43`. Le compteur est en `text.tertiary`, chiffres tabulaires, a 7 du libelle.

**Grille** : voir 4.3 et 2.4.

**Mode liste compacte** : voir 4.3.

### 5.2 Historique

Regroupement par jour, en tete collant portant la date en `headline`.

| Propriete | Valeur |
|---|---|
| Hauteur d entree | 80 |
| Vignette | 44 par 66, rayon 6 |
| Titre de serie | `body` graisse 600 |
| Chapitre | `footnote`, `text.tertiary` |
| Heure | `footnote`, `text.quaternary`, chiffres tabulaires |
| Suppression | bouton 26 apparaissant au survol |

Bouton Effacer l historique dans la barre d outils, avec confirmation par modale courte.

### 5.3 Parcourir

**Barre d outils** : bouton plus de 52 par 28 avec chevron, bouton de tri de 52 par 28, champ `Rechercher des sources` de 242 par 28.

**Menu plus**, largeur **324**, ancre sur le bouton plus, dans cet ordre exact, separateur apres la premiere entree. Chaque entree ouvre une feuille de configuration dediee.

1. Transfert Wi-Fi
2. Ajouter un serveur Komga
3. Ajouter un serveur Kavita
4. Ajouter un serveur Jellyfin
5. Ajouter un catalogue OPDS
6. Ajouter SMB / NAS
7. Ajouter un partage NFS
8. Ajouter un serveur WebDAV
9. Parcourir un dossier local
10. Ajouter une bibliotheque iCloud Drive
11. Ajouter un depot
12. Installer une extension

**Menu de tri** : en tete `Trier`, puis Personnalise avec coche, Nom, Langue.

**Compteur** au dessus de la liste : `N installees` en `headline`, ou N est le nombre reel de sources.

**Ecran de catalogue d une source**, atteint en cliquant une source : onglets Populaires, Recents, Filtres, puis une grille identique a celle de la bibliotheque.

### 5.4 Rechercher

Champ pleine largeur dans la barre d outils, largeur 440 sur macOS et iPad, espace reserve `Manga, auteurs, genres...`

Resultats groupes par source. Chaque source forme une rangee horizontale defilante :

| Propriete | Valeur |
|---|---|
| Nom de source | `headline` |
| Compteur de resultats | `footnote`, `text.tertiary` |
| Lien Tout voir | `callout`, `accent.text`, aligne a droite |
| Vignette | 132 par 198, rayon 10 |
| Gouttiere entre vignettes | 16 |
| Espacement entre deux groupes | 28 |

Une source qui ne repond pas affiche a sa place une ligne d erreur de 52, rayon 12, fond `surface.card`, glyphe `warning`, texte nommant la source et le delai, lien Reessayer. Elle ne bloque pas les autres.

### 5.5 Reglages

Colonne de 580 centree. Dix sept sections dans cet ordre exact. Les quatre premieres et la sixieme ont leur contenu impose par le wireframe 05.

| Ordre | Section | Lignes | Type |
|---|---|---|---|
| 1 | Abonnement | Passer a Premium | premium, chevron |
| | | Restaurer les achats | navigation |
| 2 | Confidentialite | Incognito | premium, couronne |
| | | Verrouillage de l app | interrupteur |
| 3 | General | Langue | valeur `Systeme` en `accent` |
| | | Apparence | valeur |
| | | Theme | valeur |
| | | Notifications de nouveaux chapitres | interrupteur |
| 4 | Bibliotheque | Trier par, Ordre, Grouper par categorie | valeur, valeur, interrupteur |
| 5 | Traduction | Traduire les bulles, Langue cible, Police de remplacement | premium, valeur, navigation |
| 6 | Lecteur | Sens de lecture, Mise en page, Fond du lecteur, Rogner les bords | valeur, valeur, valeur, interrupteur |
| 7 | Prereglages de lecture | N prereglages, Appliquer au chapitre suivant | navigation, interrupteur |
| 8 | Comportement du lecteur | Tourne de page animee, Garder l ecran allume, Tourner avec les touches de volume, Pages gardees en memoire, Luminosite du lecteur | interrupteur, interrupteur, interrupteur, compteur, curseur |
| 9 | Bibliotheque | Marquer lu a la derniere page, Supprimer apres lecture, Mettre a jour au lancement | interrupteur, valeur, interrupteur |
| 10 | Pont navigateur | Extension Safari, Ouvrir les liens dans Yum | navigation, interrupteur |
| 11 | Suivis | N service connecte, Envoyer la progression, Confirmer avant d envoyer | navigation, interrupteur, interrupteur |
| 12 | Telechargements | Qualite, En Wi-Fi seulement, Chapitres a l avance, Emplacement | valeur, interrupteur, compteur, navigation |
| 13 | Sauvegarde et restauration | Sauvegarder maintenant, Sauvegarde automatique, Restaurer depuis un fichier | navigation, valeur, navigation |
| 14 | iCloud | Synchroniser la progression, Synchroniser la bibliotheque, Dernier envoi | interrupteur, interrupteur, valeur |
| 15 | Stockage | Detail du stockage, Vider le cache d images, Supprimer tous les telechargements | navigation, navigation, navigation |
| 16 | Assistance | Aide, Signaler un bug, Statistiques de lecture | navigation, navigation, navigation |
| 17 | A propos | Version, Nouveautes, Mentions legales | valeur, navigation, navigation |

Les sections 4 et 9 portent le meme nom, Bibliotheque. La 4 regle le tri, la 9 regle le comportement. Leurs descriptions les distinguent.

La section A propos se termine par une note en `caption` `text.quaternary`, alignee a gauche, sous la carte.

**Etats de l ecran Reglages** :

- **Vide** : installation neuve. La colonne est complete mais les valeurs disent l absence : `Aucun prereglage`, `Aucun service connecte`, `Jamais`, `0 octet`, interrupteurs de synchronisation inactifs.
- **Chargement** : squelettes de lignes de 52 aux bonnes hauteurs, en tetes de section deja lisibles.
- **Charge** : valeurs reelles.
- **Erreur** : banniere en haut de colonne, rayon 12, contour 1 px `warning`, titre en `headline`, phrase en `footnote`, boutons Reessayer et Ouvrir les reglages du systeme. Le reste de la colonne reste utilisable.

**Sous ecrans a concevoir en detail cote implementation** : Statistiques de lecture, Signets, Gestion des prereglages, Detail du stockage. Tous en gabarit colonne 580, tous avec leurs quatre etats.

### 5.6 Fiche de serie

**Banniere** : hauteur 300, largeur pleine a partir du bord droit de la barre laterale. Elle **passe sous la barre de titre**, qui devient translucide a 60 pour cent au dessus d elle. Couverture floutee a 40 px de rayon, puis voile `#131315` a 55 pour cent.

**Barre de titre en contexte de fiche** : les feux de circulation restent, le titre est remplace par un bouton de retour, chevron de 10 par 16 plus le libelle `Bibliotheque`, les deux en `accent`, `body`.

**Couverture nette** : 188 par 278, rayon 12, a 40 du bord gauche de la zone de contenu, centree verticalement dans la banniere.

**Metadonnees**, a 32 de la couverture : titre en `display`, auteurs en `callout` `#C7C7CC` au format `Nom  et  Nom`, ligne d etat en `callout` `#8E8E93` au format `En cours  Japonais  Komga serveur maison`, puis les genres en pastilles de 26, rayon 13, fond `rgba(255,255,255,0.14)`, texte `footnote`.

**Actions** : bouton principal contextuel de 38, puis Dans ma liste, Suivre, et un bouton d options de 48 par 38. Les trois boutons secondaires utilisent `rgba(255,255,255,0.16)` parce qu ils reposent sur la banniere assombrie, pas sur une surface du systeme.

Libelle du bouton principal selon l etat :

| Etat de la serie | Libelle |
|---|---|
| Aucun chapitre lu | `Commencer la lecture` |
| Lecture en cours | `Reprendre ch. N` |
| Tous les chapitres lus | `Tout est lu` |
| Aucun chapitre expose par la source | `Aucun chapitre`, bouton desactive |

**Corps** : gabarit colonne 580. Resume en `callout`, trois lignes maximum, bouton `Afficher plus` en `accent.text`. Filet `separator` pleine largeur, puis en tete de liste avec le compteur `N chapitres` en `title2` et les actions Filtrer, Trier, Tout marquer lu alignees a droite en `callout` `accent.text`. Puis les lignes de chapitre selon 4.5.

**Etats** : vide `Aucun chapitre dans cette serie`, chargement squelettes de 56, charge, erreur `La liste des chapitres n a pas pu etre lue`. Dans les trois cas, l en tete de la fiche reste intact. Seule la zone de liste change.

Sur iPad portrait la banniere descend a 260 et la couverture a 156 par 231. Sur iPhone la banniere passe a 400 en pile verticale, couverture de 120 par 178 centree au dessus des metadonnees, titre en `title1`, boutons a 44 de haut, genres et ligne d etat deplaces dans une feuille de details.

### 5.7 Lecteur pagine

Coeur du produit. C est l ecran qui merite le plus de soin.

**Fond** : `surface.reader`, reglable parmi Noir OLED, Gris sombre, Blanc, Sepia.

**Barres masquees par defaut.** Elles apparaissent au tap central, ou au deplacement de la souris sur macOS, et se retirent apres 3 secondes d inactivite. Transition 200 ms, fondu plus translation de 8 px. Masquage automatique au glissement si l option est active.

**Barre superieure** :

| Propriete | Valeur |
|---|---|
| Hauteur | 72, 96 sur iPhone avec l encoche |
| Fond | `surface.window` a 94 pour cent, flou d arriere plan 20 |
| Retour | a gauche, chevron 12 par 20 en `text.primary`, cible 28 |
| Titre | serie en `body` graisse 600 `text.primary`, chapitre en `footnote` `text.tertiary` au format `Chapitre 43  Le titre du chapitre` |
| Actions | a droite, dans cet ordre : Filtres, Traduire, Coloriser, Signet, Options |
| Forme d action | icone de 20 en trait de 1.8 `text.primary`, libelle de 9 en `text.quaternary` centre dessous |
| Cible d action | 28 au pointeur, 34 au doigt |

Sur iPhone les libelles d action disparaissent et la liste se limite a Filtres, Traduire, Options.

**Barre inferieure** :

| Propriete | Valeur |
|---|---|
| Hauteur | 64, 88 sur iPhone avec l indicateur de bas d ecran |
| Compteur de pages | a gauche a 40 du bord, `callout` `text.primary`, chiffres tabulaires, format `42 / 22` |
| Curseur | piste de 4 en `surface.selected`, remplissage `accent`, pastille de 16 au pointeur et 30 au doigt |
| Chapitre suivant | a droite, `callout` en `accent.text` |

**Le curseur s inverse en mode droite a gauche** : le remplissage part de la droite, la pastille se deplace vers la gauche quand la progression augmente. Au maintien prolonge, le curseur affiche une bande de vignettes.

**Zones de toucher** : trois colonnes verticales, gauche 28 pour cent, centre 44 pour cent, droite 28 pour cent.

| Zone | Action en mode droite a gauche |
|---|---|
| Gauche, 28 pour cent | page suivante |
| Centre, 44 pour cent | afficher ou masquer les barres |
| Droite, 28 pour cent | page precedente |

Les zones ne sont jamais visibles, sauf pendant le tutoriel de premiere ouverture ou elles apparaissent pendant 4 secondes, les deux zones laterales a 6 pour cent d `accent`, la zone centrale a 3 pour cent de blanc.

**Double page** : deux pages cote a cote, sans separateur, sans ombre, gouttiere de 4. En mode droite a gauche, la premiere page de la paire est a droite. Sur iPad paysage 556 par 834 par page. En portrait et sur iPhone, page unique.

**Panneau de filtres** : popover ancre au bouton Filtres, largeur 300, rayon 14, elevation 1. Curseurs Luminosite, Chaleur, Nettete, Contraste, Gamma. Separateur. Interrupteurs Reduction du bruit, Amelioration IA, Colorisation IA. Colorisation IA est verrouillee premium et porte une couronne au lieu d un interrupteur. Chaque modification s applique en direct sur la page visible.

**Etats** : vide `Ce chapitre ne contient aucune page`, chargement deux squelettes aux dimensions exactes des pages, charge, erreur `La page N est illisible`.

### 5.8 Lecteur webtoon

Defilement vertical continu, aucune animation de transition.

| Propriete | Valeur |
|---|---|
| Largeur de colonne | Ajustee, Pleine largeur, ou valeur libre de 40 a 100 pour cent, 32 pour cent au cas de reference |
| Filets de colonne | 1 px `separator` sur les deux bords de la colonne |
| Espacement entre pages | reglable de 0 a 24 |
| Progression | en pourcentage, jamais en numero de page, format `38 %` |
| Sous titre de barre | `Chapitre 118  defilement vertical` |
| Enchainement | automatique vers le chapitre suivant, sans quitter le lecteur |
| Separateur de chapitre | filet 1 px a 30 pour cent d opacite, numero du chapitre entrant en `footnote` `text.tertiary`, marges verticales 32 |

**Contrainte technique a respecter cote rendu** : les images longues sont obligatoirement decoupees en tuiles de 2048 px maximum. La limite de texture Metal est de 16384 px, au dela le rendu echoue. Les tuiles hors ecran sont recyclees, le budget memoire est fixe. Une tuile en avance est prechargee.

La barre inferieure du webtoon n a pas de pastille de curseur : la progression est une barre de lecture seule, parce que le defilement continu n a pas de position discrete a saisir.

### 5.9 Mur premium

| Propriete | Valeur |
|---|---|
| Largeur | 360 |
| Hauteur, cas de reference | 420 |
| Rayon | 16 |
| Fond | `#141A28` |
| Contour | 1 px `#24344F` |
| Elevation | 2 sur voile `scrim` |
| Couronne | 56 par 40 en `accent`, centree |
| Titre | `Premium`, 20 graisse 700, centre |
| Sous titre | `Debloquez toutes les fonctions avancees`, `footnote` `text.tertiary`, centre |
| Avantages | cinq lignes, `callout` `text.secondary`, coche `accent` de 14, gouttiere 12, interligne 14 |
| Bouton | 296 par 42, rayon 12, principal |
| Mention de prix | `caption` `text.quaternary`, centree |

Liste des avantages, dans cet ordre :

1. Traduction et colorisation par IA
2. Serveurs Komga, Kavita, Jellyfin, OPDS
3. Suivis sur vos services de suivi
4. Telechargements hors ligne
5. Sauvegarde et synchronisation iCloud

Aucun compte a rebours, aucune formulation qui presse l utilisateur.

**Etats** : vide et chargement montrent la meme feuille en squelettes, erreur montre `La boutique ne repond pas` avec deux capsules Plus tard et Reessayer.

### 5.10 Premiere ouverture

Trois etapes maximum, une seule decision par etape. Points de progression en haut a droite, 7 de diametre, actif en `accent`.

1. **Sens de lecture** : trois cartes de 300, rayon 16, apercu visuel de deux pages numerotees, contour de 3 en `accent` sur le choix actif. Droite a gauche a gauche de l ecran, Gauche a droite au centre, Vertical a droite. La carte Vertical montre deux pages empilees plutot que cote a cote.
2. **Premiere source** : les trois choix les plus courants en lignes de source de 72, Parcourir un dossier local, Ajouter un serveur Komga, Ajouter un catalogue OPDS, puis le lien `Voir les douze types de sources`. Les quatre etats de cette etape sont ceux d une source : rien, connexion en cours, connectee avec le nombre de series, adresse injoignable.
3. **Essai premium** : liste des avantages, bouton Commencer l essai, et **Plus tard aussi visible que le bouton d essai**, meme hauteur, meme rayon, fond `surface.menu` avec contour.

---

## 6. TEXTES D INTERFACE, LIBELLES EXACTS

Regles d ecriture : voix active, le bouton dit ce qui se passe. Le meme mot pour la meme action du debut a la fin d un parcours, `Telecharger` produit `Termine`. Un etat vide est une invitation a agir, pas un constat. Une erreur nomme la cause et donne la sortie, elle ne s excuse pas. Pas de tiret cadratin. Pas de point d exclamation. Pas de vocabulaire technique visible, on dit `serveur` et non `endpoint`, `source` et non `provider`.

### 6.1 Navigation

| Element | Libelle |
|---|---|
| Barre laterale 1 | Bibliotheque |
| Barre laterale 2 | Historique |
| Barre laterale 3 | Parcourir |
| Barre laterale 4 | Rechercher |
| Barre laterale 5 | Reglages |
| Bloc bas de barre laterale | Passer a Premium / 7 jours offerts |
| Retour depuis la fiche | Bibliotheque |

### 6.2 Espaces reserves de champ

| Ecran | Espace reserve |
|---|---|
| Bibliotheque | Rechercher la bibliotheque |
| Historique | Rechercher dans l historique |
| Parcourir | Rechercher des sources |
| Rechercher | Manga, auteurs, genres... |
| Reglages | Rechercher un reglage |
| Modale d ajout par adresse | https:// |
| Adresse de serveur | https://komga.exemple.fr |

### 6.3 Etats vides

| Ecran | Titre | Phrase | Action |
|---|---|---|---|
| Bibliotheque | Votre bibliotheque est vide | Parcourez les sources pour trouver des mangas et les ajouter a votre bibliotheque. | Parcourir les sources |
| Historique | Aucun historique | Les chapitres que vous lisez apparaitront ici. | Ouvrir la bibliotheque |
| Parcourir | Aucune source installee | Ajoutez un serveur, un dossier local ou un catalogue public pour commencer a lire. | Ajouter une source |
| Rechercher | Rechercher un manga | Recherche dans toutes les sources installees | aucune |
| Fiche de serie | Aucun chapitre dans cette serie | La source connait cette serie mais n expose encore aucun chapitre. Suivez la serie pour etre prevenu. | Suivre la serie |
| Lecteur pagine | Ce chapitre ne contient aucune page | Le fichier est present mais vide. Retelechargez le chapitre, ou ouvrez le chapitre suivant. | Retelecharger |
| Lecteur webtoon | Ce chapitre ne contient aucune image | Le dossier du chapitre est vide. Retelechargez le, ou passez au chapitre suivant. | Retelecharger |

### 6.4 Erreurs

| Ecran | Titre | Phrase | Actions |
|---|---|---|---|
| Bibliotheque | La bibliotheque n a pas pu etre lue | Le fichier d index est illisible. Yum peut le reconstruire depuis vos sources, la progression est conservee. | Reconstruire l index / Voir les telechargements |
| Historique | L historique n a pas pu etre lu | Le fichier d historique est corrompu. Yum peut le repartir de zero, votre bibliotheque n est pas touchee. | Repartir de zero |
| Parcourir | Deux sources ne repondent pas | dav.exemple.net et opds.exemple.org n ont pas repondu en 10 secondes. Verifiez votre reseau, ou lisez vos chapitres telecharges. | Reessayer / Voir les telechargements |
| Rechercher | Aucune source ne repond | Les cinq sources installees ont echoue. Verifiez votre reseau, la recherche locale reste disponible. | Reessayer / Chercher hors ligne |
| Rechercher, ligne par source | (ligne discrete) | dav.exemple.net n a pas repondu en 10 secondes | Reessayer |
| Reglages | iCloud n a pas synchronise depuis 6 jours | Le compte iCloud de cet appareil n autorise plus Yum. Ouvrez les reglages du systeme, puis reactivez Yum dans la liste des applications iCloud. | Reessayer / Ouvrir les reglages du systeme |
| Fiche de serie | La liste des chapitres n a pas pu etre lue | Komga serveur maison a repondu, puis a coupe la connexion. Les cinq chapitres telecharges restent lisibles. | Reessayer |
| Lecteur pagine | La page 14 est illisible | Le fichier contient une image que Yum ne sait pas ouvrir. Vous pouvez sauter cette page, ou signaler le fichier pour qu il soit pris en charge. | Sauter la page / Signaler le fichier |
| Lecteur webtoon | Le defilement s est arrete a 38 pour cent | Les images suivantes ne se telechargent plus. Votre position est gardee, vous reprendrez ici. | Reessayer / Revenir a la fiche |
| Feuille de configuration | Le serveur ne repond pas | Verifiez l adresse et la connexion. | Reessayer |
| Mur premium | La boutique ne repond pas | Yum n a pas pu lire les tarifs. Votre abonnement actuel, s il existe, reste actif. Reessayez dans un moment. | Plus tard / Reessayer |

Le nombre et le nom cites dans une erreur sont toujours les valeurs reelles. Une erreur qui ne peut pas nommer sa cause nomme au moins l heure de la derniere tentative.

### 6.5 Boutons et actions

| Contexte | Libelle |
|---|---|
| Fiche, aucun chapitre lu | Commencer la lecture |
| Fiche, lecture en cours | Reprendre ch. N |
| Fiche, tout lu | Tout est lu |
| Fiche, secondaires | Dans ma liste / Suivre |
| Fiche, resume | Afficher plus |
| Liste de chapitres | Filtrer / Trier / Tout marquer lu |
| Selection multiple | Marquer lu / Telecharger / Supprimer |
| Barre du lecteur | Filtres / Traduire / Coloriser / Signet / Options |
| Barre inferieure du lecteur | Chapitre suivant |
| Historique | Effacer l historique |
| Modale d ajout par adresse | Annuler / Ajouter |
| Feuille de configuration | Tester la connexion / Annuler / Enregistrer |
| Mur premium | Essayer 7 jours gratuitement / Plus tard |
| Premiere ouverture | Continuer / Passer / Commencer l essai / Plus tard |
| Recherche, par source | Tout voir |
| Reglages, banniere iCloud | Reessayer / Ouvrir les reglages du systeme |

### 6.6 Menus

**Menu de tri de la bibliotheque** : A a Z, Derniere lecture, Derniere mise a jour, Date d ajout, Non lu, separateur, Ordres de lecture.

**Menu de tri de Parcourir** : en tete Trier, puis Personnalise, Nom, Langue.

**Menu plus de Parcourir** : les douze entrees listees en 5.3, dans cet ordre, separateur apres Transfert Wi-Fi, largeur 324.

### 6.7 Valeurs de reglage

| Reglage | Valeurs |
|---|---|
| Langue | Systeme, Francais, English, Espanol, Deutsch, Japonais |
| Apparence | Systeme, Clair, Sombre |
| Theme | Midnight, Obsidian, Slate, Paper |
| Sens de lecture | Droite a gauche, Gauche a droite, Vertical |
| Mise en page | Page unique, Double page, Continu vertical |
| Fond du lecteur | Noir OLED, Gris sombre, Blanc, Sepia |
| Supprimer apres lecture | Jamais, Apres 1 jour, Apres 7 jours, Immediatement |
| Sauvegarde automatique | Desactivee, Chaque jour, Chaque semaine, Chaque mois |
| Qualite de telechargement | Originale, Elevee, Moyenne |
| Trier par | Nom, Derniere lecture, Derniere mise a jour, Date d ajout, Non lu |
| Ordre | Croissant, Decroissant |

### 6.8 Descriptions de section et mentions

| Emplacement | Texte |
|---|---|
| Sous la carte Abonnement | Debloquez la traduction, la colorisation, les suivis, la sauvegarde, le mode incognito, les serveurs Komga, Kavita, Jellyfin et OPDS, la synchronisation iCloud et bien plus. |
| Sous la carte Confidentialite | Navigation privee : l activite de lecture n est pas enregistree dans l historique. |
| Sous la carte Bibliotheque, tri | Ce tri s applique a la grille et au mode liste compacte. |
| Sous la carte Lecteur | La double page se replie automatiquement en portrait. |
| Sous la carte Bibliotheque, comportement | Deuxieme carte Bibliotheque, comportement, distincte de la carte de tri plus haut. |
| Sous la carte Pont navigateur | Le pont laisse une page de catalogue ouverte dans le navigateur envoyer une serie vers Yum. |
| Sous la carte Stockage | Les chapitres supprimes restent lisibles depuis leur source. |
| Sous la carte A propos | Yum ne heberge aucun contenu. L application lit les fichiers et les serveurs que vous lui indiquez. Vous restez responsable de la legalite de vos sources. |
| Feuille de configuration | Les identifiants sont stockes dans le trousseau du systeme. |
| Retour de test reussi | 4 bibliotheques trouvees |
| Sous le bouton du mur premium | Puis 3,99 euros par mois. Resiliable a tout moment. |
| Etape 2 de la premiere ouverture | Yum ne heberge aucun contenu. Il lit les fichiers et les serveurs que vous lui indiquez. |
| Liste des sources | Reordonnancement par glisser deposer lorsque le tri est en mode Personnalise. |

---

## 7. ACCESSIBILITE

| Regle | Valeur |
|---|---|
| Contraste, texte sous 18 px | 4.5:1 minimum |
| Contraste, texte 18 px et plus | 3:1 minimum |
| Cible de pointage, iOS et iPadOS | 44 par 44 |
| Cible de pointage, macOS | 28 par 28 |
| Focus clavier | contour 2 en `accent`, decalage 2, jamais supprime |
| Ordre de tabulation | haut vers bas, gauche vers droite |
| Texte dynamique | pris en charge jusqu a accessibilite extra extra large |
| Fermeture de modale | Echap, clic hors zone, et retour du focus a l element declencheur |

Ratios mesures sur `surface.card` :

| Paire | Sombre | Clair |
|---|---|---|
| `text.primary` | 14.9:1 | 16.7:1 |
| `text.secondary` | 9.6:1 | 10.9:1 |
| `text.tertiary` | 4.8:1 | 6.4:1 |
| `text.quaternary` | 3.1:1 | 4.9:1 |
| `accent` ou `accent.text` | 4.9:1 | 5.6:1 |

**Deux exceptions declarees**, a ne pas etendre :

1. `text.quaternary` en variante sombre mesure 3.1:1. Il est reserve au texte redondant, jamais porteur d une information unique : numero de version, mention legale, sous ligne d un chapitre deja lu, heure deja lisible ailleurs. Toute autre utilisation passe a `text.tertiary`.
2. Le texte blanc sur `accent` mesure 3.5:1 dans la pastille de non lus. Accepte parce que le chiffre lui meme et l etiquette d accessibilite portent l information.

Aucune information transmise par la couleur seule. La pastille de non lus porte un chiffre. L etat d une source est ecrit en clair dans son sous titre, a cote de la pastille de couleur.

Chaque icone sans libelle porte une etiquette d accessibilite. Au dela de la taille de texte `large`, les lignes de reglages passent en disposition verticale.

---

## 8. ICONE D APPLICATION

Concept : une case de manga vide, cadre et gouttiere seuls. Aucune lettre, aucun visage, aucun objet. Trois cases de tailles inegales separees par une gouttiere, dont une seule est remplie en `accent`.

| Declinaison | Fichier | Note |
|---|---|---|
| macOS, 1024 | `icone/yum-macos-1024.svg` | squircle dessine, marge interieure de 100, rayon 184 |
| iOS et iPadOS, 1024 | `icone/yum-ios-1024.svg` | pleine surface, le systeme applique le masque |
| Monochrome | `icone/yum-mono.svg` | barre de menus, mode teinte, une seule couleur, fond transparent |
| Clair | `icone/yum-macos-1024-clair.svg` | fond clair, cadres sombres |

Geometrie, version iOS sur une toile de 1024 : bloc de contenu de 672 centre, gouttiere de 48, trait de cadre de 32, rayon de case 6. Case superieure droite 384 par 384 en cadre, case superieure gauche 240 par 384 pleine en `accent`, case inferieure 672 par 240 en cadre.

Tailles a produire : 1024, 512, 256, 128, 64, 32, 16 pour macOS. 1024 pour la fiche de l App Store, le reste genere par le systeme sur iOS.

A 16 px, seules la masse bleue et la gouttiere restent lisibles. La composition est concue pour cela : deux masses et un vide, rien de plus.

---

## 9. RECETTE

A verifier avant de declarer un ecran fini.

- [ ] Aucun tiret cadratin dans le code, les libelles et les commentaires.
- [ ] Aucun point d exclamation.
- [ ] Les quatre etats existent : vide, chargement, charge, erreur.
- [ ] L etat vide invite a agir. L erreur nomme sa cause et donne une sortie.
- [ ] Le bouton Reessayer est secondaire, pas principal.
- [ ] Aucune valeur d espacement hors de l echelle de 4.
- [ ] Aucune ombre sur une carte.
- [ ] Aucun degrade sur une surface, le seul voile tolere est celui du bas de couverture.
- [ ] La zone de contenu utilise `surface.canvas`, la coquille utilise `surface.window`.
- [ ] Le gabarit colonne mesure 580 exactement et ne s etire pas.
- [ ] Le menu plus de Parcourir mesure 324 et compte douze entrees.
- [ ] Une ligne de navigation porte un chevron simple, jamais un chevron double sans valeur.
- [ ] Toute sous ligne de source ou de chapitre est renseignee, jamais vide.
- [ ] Tous les nombres qui changent en place sont en chiffres tabulaires.
- [ ] Chaque element interactif a un etat de focus clavier visible.
- [ ] Chaque icone sans libelle a une etiquette d accessibilite.
- [ ] Aucune information portee par la couleur seule.
- [ ] Aucune marque tierce, ni dans un nom de source, ni dans une liste d avantages.
- [ ] Les quatre themes et les deux variantes rendent correctement.
- [ ] Dans le lecteur, le regard va au dessin avant d aller a l interface.
