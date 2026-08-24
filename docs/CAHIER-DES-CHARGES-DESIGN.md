# Cahier des charges DESIGN

## Application de lecture de manga pour macOS, iPadOS et iOS

**Destinataire : Claude Design**
**Version du document : 1.0**
**Nom de code du projet : TSUZUKI (a remplacer par le nom definitif avant livraison)**

---

## 0. REGLES DE REDACTION ET DE TRAVAIL

Ces regles sont non negociables et s appliquent a tout ce que tu produis.

1. **N utilise jamais le caractere tiret cadratin.** Ni dans les libelles d interface, ni dans les textes de l application, ni dans tes reponses, ni dans les commentaires de code. Utilise a la place une virgule, un deux points, une parenthese ou une phrase separee. Si tu vois un tiret cadratin dans un texte source, reformule la phrase.
2. Ecris tous les libelles d interface en francais, en minuscule de phrase, sans point final sauf pour les phrases completes de description.
3. Ne produis aucun element de marque appartenant a un tiers : pas de logo existant, pas de nom d application existante, pas d icone reprise d une autre application. Le nom, l icone et l identite visuelle doivent etre originaux.
4. Livre un systeme de design complet avant toute maquette d ecran. Les jetons viennent en premier, les composants ensuite, les ecrans en dernier.
5. Chaque ecran doit exister en trois etats au minimum : vide, charge, en erreur. Un ecran livre sans ses etats est considere incomplet.
6. Tu travailles en mode sombre par defaut. Le mode clair est un livrable obligatoire mais secondaire.

---

## 1. CONTEXTE ET INTENTION

### 1.1 Ce que fait le produit

C est un lecteur de manga, manhwa et manhua. Il agrege des sources de contenu tres differentes, depuis un simple dossier local jusqu a un serveur auto heberge, et il offre un moteur de lecture soigne avec des traitements d image avances.

L application ne heberge aucun contenu. Elle se connecte a ce que l utilisateur possede deja ou a des catalogues publics.

### 1.2 Qui l utilise

Un lecteur assidu, entre 18 et 40 ans, qui lit plusieurs heures par semaine, souvent le soir, souvent dans le noir. Il a deja une collection organisee quelque part : un NAS, un serveur Komga, un dossier de fichiers CBZ. Il est exigeant sur le rendu des images et sur la fluidite. Il deteste les interfaces qui l interrompent.

### 1.3 Le seul travail de l interface

**Disparaitre.**

C est la these de ce design. Une page de manga est une oeuvre graphique dense en noir et blanc. Toute interface qui se met a coter d elle entre en concurrence avec elle et perd. L application doit se comporter comme un cadre de musee : presente, precise, invisible une fois qu on regarde l oeuvre.

Consequences concretes de cette these :

- Le lecteur est noir pur, sans chrome permanent, sans bordure, sans ombre autour de la page.
- Les barres d outils se retirent des que la lecture commence.
- Aucune couleur saturee n apparait dans le champ de vision pendant la lecture.
- L accent bleu ne sert qu a signaler ce sur quoi on peut agir, jamais a decorer.
- Aucune animation gratuite. Le mouvement sert a expliquer une transition, jamais a impressionner.

### 1.4 L element signature

**La pastille de progression sur la couverture.**

Chaque serie de la bibliotheque porte deux informations superposees a sa couverture : une pastille bleue en haut a droite avec le nombre de chapitres non lus, et un filet bleu de progression sur le bord inferieur. Rien d autre. Pas de note, pas d etoiles, pas de badge de source visible au repos.

Ces deux marques sont le seul endroit du produit ou l accent bleu apparait en aplat sur du contenu. Elles constituent la signature visuelle et elles doivent etre executees avec une precision absolue : geometrie, alignement optique, contraste sur couverture claire comme sur couverture sombre.

### 1.5 Ce qu il faut eviter

Les trois directions suivantes sont interdites parce qu elles sont des reflexes plutot que des choix :

- Le fond creme avec une serif a fort contraste et un accent terre cuite.
- Le fond noir avec un unique accent vert acide ou vermillon.
- La mise en page facon journal avec filets fins, angles vifs et colonnes denses.

Interdit egalement : les degrades sur les surfaces, les effets de verre depoli decoratifs, les ombres portees colorees, les illustrations vectorielles generiques dans les etats vides.

---

## 2. SYSTEME DE JETONS

Reference visuelle : `wireframes/08-composants-et-jetons.svg`

### 2.1 Couleurs de surface, theme Midnight, mode sombre

| Jeton | Valeur | Usage |
|---|---|---|
| `surface.canvas` | `#0E0E10` | Arriere plan hors fenetre, fond de la zone de contenu |
| `surface.window` | `#131315` | Fond de la fenetre |
| `surface.chrome` | `#161618` | Barre de titre et barre d outils |
| `surface.sidebar` | `#1B1B1D` | Barre laterale encastree |
| `surface.card` | `#202023` | Cartes de reglages, lignes de liste |
| `surface.cardHover` | `#26262A` | Survol de carte, ligne selectionnee dans une liste |
| `surface.menu` | `#2C2C30` | Menus contextuels, boutons secondaires |
| `surface.selected` | `#3A3A3E` | Element actif de la barre laterale, piste de curseur |
| `surface.field` | `#141416` | Fond de champ de saisie |
| `surface.reader` | `#000000` | Fond du lecteur en mode OLED |
| `surface.premium` | `#1C2740` | Fond des lignes verrouillees par l abonnement |

### 2.2 Couleurs de texte

| Jeton | Valeur | Usage |
|---|---|---|
| `text.primary` | `#F2F2F7` | Titres, libelles de ligne |
| `text.secondary` | `#C7C7CC` | Valeurs de reglage, texte courant |
| `text.tertiary` | `#8E8E93` | Descriptions sous les sections, metadonnees |
| `text.quaternary` | `#6E6E73` | Mentions legales, texte d espace reserve |
| `text.disabled` | `#48484C` | Element inactif |

### 2.3 Couleurs semantiques

| Jeton | Valeur | Usage |
|---|---|---|
| `accent` | `#0A84FF` | Action, lien, element interactif, pastille non lu |
| `accent.pressed` | `#0774E0` | Etat presse |
| `success` | `#30D158` | Serveur connecte, telechargement termine |
| `warning` | `#FF9F0A` | Avertissement, connexion instable |
| `danger` | `#FF453A` | Suppression, echec critique |
| `separator` | `#2E2E32` | Filet entre deux lignes d une meme carte |
| `border` | `#3A3A3E` | Contour de champ, contour de menu |

### 2.4 Themes additionnels

Le reglage Theme accepte quatre valeurs. Chacune est une permutation des jetons de surface uniquement. Les jetons de texte et les jetons semantiques ne changent pas, sauf mention contraire.

| Theme | Caractere | Modification |
|---|---|---|
| **Midnight** | defaut, gris neutre tres sombre | valeurs du tableau 2.1 |
| **Obsidian** | noir absolu, pour ecrans OLED | toutes les surfaces descendent d un cran, `canvas` et `window` passent a `#000000` |
| **Slate** | gris bleute, moins contraste | teinte de +6 degres vers le bleu sur toutes les surfaces |
| **Paper** | mode clair | inversion complete, `canvas` a `#F5F5F7`, cartes a `#FFFFFF`, texte primaire a `#1C1C1E`, accent inchange |

Le reglage Apparence (Systeme, Clair, Sombre) choisit entre la variante claire et la variante sombre du theme actif.

### 2.5 Typographie

Police unique : **SF Pro** sur les plateformes Apple, avec `-apple-system` en premiere valeur de pile. Aucune police tierce.

La personnalite typographique ne vient pas du choix de la fonte, qui doit rester native, mais de la **discipline de l echelle** : peu de tailles, des sauts nets, et un usage tres retenu du gras.

| Role | Taille | Graisse | Interlignage | Usage |
|---|---|---|---|---|
| `display` | 28 | 700 | 34 | Titre d une fiche de serie |
| `title1` | 22 | 700 | 28 | Titre d etat vide |
| `title2` | 17 | 700 | 22 | Titre de barre d outils |
| `headline` | 15 | 700 | 20 | En tete de section de reglages |
| `body` | 15 | 400 | 20 | Libelle de ligne, valeur de reglage |
| `callout` | 13 | 400 | 18 | Texte courant, resume de serie |
| `footnote` | 12 | 400 | 16 | Description sous une section |
| `caption` | 11 | 400 | 14 | Mention legale, version, note de bas de page |

Chiffres tabulaires obligatoires partout ou un nombre change en place : compteur de pages, pourcentages, tailles de fichier, numeros de chapitre.

### 2.6 Rayons, espacements, elevation

**Rayons** : 6 pastille, 9 champ de saisie, 10 bouton et icone conteneur, 12 carte, 14 barre laterale et menu, 16 feuille de configuration, 18 fenetre, 20 modale courte.

**Espacements** : echelle de 4. Valeurs autorisees 4, 8, 12, 16, 20, 24, 32, 40, 56, 72. Aucune autre valeur.

**Elevation** : trois niveaux seulement.

- Niveau 0, le contenu : aucune ombre.
- Niveau 1, les menus et popovers : `0 8px 24px rgba(0,0,0,0.44)` plus un contour `border`.
- Niveau 2, les modales : `0 24px 64px rgba(0,0,0,0.60)` plus un voile d arriere plan noir a 45 pour cent.

Aucune ombre sur les cartes de reglages. La hierarchie passe par la valeur de surface, pas par l ombre.

### 2.7 Iconographie

SF Symbols exclusivement, graisse `regular`, echelle `medium`. Taille de rendu 22 dans les lignes de reglages, 20 dans la barre laterale, 18 dans les barres d outils.

Correspondances imposees par les captures de reference :

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

### 2.8 Mouvement

| Transition | Duree | Courbe |
|---|---|---|
| Survol, changement d etat local | 120 ms | `easeOut` |
| Apparition de menu ou popover | 180 ms | `spring(response: 0.28, damping: 0.86)` |
| Modale entrante | 240 ms | `spring(response: 0.34, damping: 0.82)` |
| Changement d ecran principal | 200 ms | fondu croise pur, aucun glissement |
| Tourne de page en mode pagine | 220 ms | `easeInOut`, desactivable par reglage |
| Apparition ou retrait des barres du lecteur | 200 ms | fondu plus translation de 8 px |

Le reglage systeme Reduire les animations supprime toutes les translations et ramene chaque transition a un fondu de 100 ms.

Interdit : rebond sur les cartes, effet parallaxe, animation d entree en cascade sur les grilles, rotation, effet de particule.

---

## 3. STRUCTURE ET MISE EN PAGE

### 3.1 Fenetre macOS

Reference : `wireframes/01-coquille-bibliotheque-vide.svg`

- Taille minimale 1024 par 720. Taille par defaut a la premiere ouverture 1280 par 860.
- Barre de titre unifiee avec la barre d outils, hauteur 60.
- Feux de circulation natifs a la position standard.
- Fond de fenetre `surface.window`.

### 3.2 Barre laterale

- Largeur fixe 196. Non redimensionnable.
- Encastree avec une marge de 12 sur les quatre cotes, rayon 14, fond `surface.sidebar`.
- Cinq entrees, dans cet ordre strict : Bibliotheque, Historique, Parcourir, Rechercher, Reglages.
- Ligne d entree : hauteur 40, rayon 10, icone a 14 du bord gauche, libelle a 40 du bord gauche.
- Entree active : fond `surface.selected`, libelle en `text.primary` graisse 600, icone en `text.primary`.
- Entree au repos : pas de fond, libelle en `text.secondary`, icone en `text.tertiary`.
- Survol : fond `surface.card`.
- La barre laterale se replie via le bouton dedie en haut a gauche. Repliee, une barre d icones de 56 de large la remplace, sans libelle, avec info bulle au survol.

### 3.3 Zone de contenu

Deux gabarits selon l ecran.

**Gabarit large** pour Bibliotheque, Historique, Parcourir, Rechercher : le contenu occupe toute la largeur disponible avec une marge laterale de 24, et une largeur maximale de 1600 au dela de laquelle il se centre.

**Gabarit colonne** pour Reglages et la fiche de serie : colonne centree de 580 de large exactement. Cette contrainte est stricte. Une carte de reglages ne s etire jamais.

### 3.4 Adaptation iPad et iPhone

**iPad en paysage** : identique a macOS, barre laterale native `NavigationSplitView`.

**iPad en portrait** : barre laterale repliee par defaut, ouverture par glissement depuis le bord.

**iPhone** : la barre laterale devient une barre d onglets basse a cinq entrees avec les memes icones et les memes libelles. Le gabarit colonne devient pleine largeur avec une marge de 16. Les cartes de reglages conservent leur rayon de 12 et se collent aux marges.

---

## 4. BIBLIOTHEQUE DE COMPOSANTS

Reference : `wireframes/08-composants-et-jetons.svg`

Livre chaque composant dans tous ses etats : repos, survol, presse, focus clavier, desactive, verrouille premium.

### 4.1 Ligne de reglage

Le composant le plus utilise du produit. Hauteur 52 en version simple, 76 en version avec description ou curseur.

Structure horizontale : marge 20, icone 22 en `accent`, gouttiere 16, libelle en `body`, espace flexible, controle a droite, marge 20.

Cinq variantes :

1. **Interrupteur** : commutateur 48 par 28, pastille blanche de 24, fond `accent` a l etat actif et `surface.selected` a l etat inactif.
2. **Valeur et menu** : valeur en `text.secondary` alignee a droite, chevron double vertical en `text.tertiary` a 4 de la valeur.
3. **Navigation** : chevron simple vers la droite en `text.tertiary`.
4. **Curseur** : libelle sur la premiere ligne avec la valeur numerique alignee a droite en `footnote`, curseur sur la seconde ligne occupant toute la largeur utile.
5. **Compteur** : deux chevrons empiles a droite pour incrementer et decrementer.

**Variante premium** : fond de ligne `surface.premium`, libelle en `accent`, couronne en `accent` a droite. Le clic ouvre le mur premium plutot que le reglage.

### 4.2 Carte de section

Un ou plusieurs lignes empilees dans un conteneur de rayon 12, fond `surface.card`. Separateur de 1 px en `separator`, encastre de 20 a gauche et affleurant a droite. Pas de separateur apres la derniere ligne.

En tete de section : libelle en `headline`, `text.primary`, positionne 14 au dessus de la carte, aligne sur le bord gauche de la carte.

Description de section : `footnote` en `text.tertiary`, positionnee 12 sous la carte, aligne sur le bord gauche, largeur maximale identique a celle de la carte.

### 4.3 Carte de serie

Reference : `wireframes/02-bibliotheque-grille.svg`

- Couverture au ratio 2:3, rayon 10, largeur comprise entre 150 et 200 selon la place.
- Titre en dessous, `callout` graisse 600, deux lignes maximum avec troncature.
- Source en dessous, `caption` en `text.tertiary`, une ligne.
- Pastille de non lus : ancree en haut a droite avec une marge de 10, hauteur 20, rayon 10, remplissage horizontal de 8, fond `accent`, chiffre blanc en `caption` graisse 700. Masquee si zero.
- Filet de progression : hauteur 4, cale sur le bord inferieur de la couverture, `accent`, largeur proportionnelle a la progression. Masque si zero ou cent pour cent.
- Survol : echelle 1.02, transition 120 ms, apparition d un bouton d options en haut a gauche.
- Selection multiple : contour de 3 en `accent` a l interieur du rayon.

### 4.4 Ligne de source

Reference : `wireframes/03-parcourir-menu-ajouter.svg`

Hauteur 72, rayon 12, fond `surface.card`. Icone de source dans un carre de 40 a rayon 10. Nom en `body` graisse 700. Sous titre en `footnote` avec l adresse ou la version. Pastille d etat a droite : `success` si le serveur repond, `warning` si la derniere tentative a echoue, aucune pastille pour une source locale. Bouton d options a l extreme droite.

### 4.5 Ligne de chapitre

Reference : `wireframes/04-fiche-serie.svg`

Hauteur 56, rayon 10.

- **Non lu** : fond `surface.card`, titre en `text.primary`, pastille pleine de 12 en `accent` a droite.
- **Lu** : fond transparent, titre en `text.tertiary`, pas de pastille.
- **En cours** : titre en `text.tertiary`, sous titre indiquant la page atteinte, filet de progression de 3 en `accent` a 60 pour cent d opacite sur le bord inferieur.
- **Telecharge** : petite icone `arrow.down.circle.fill` en `text.tertiary` avant la pastille.

### 4.6 Boutons

| Variante | Fond | Texte | Contour |
|---|---|---|---|
| Principal | `accent` | blanc, `body` graisse 600 | aucun |
| Secondaire | `surface.menu` | `text.primary`, `body` | `border` |
| Discret | transparent | `accent`, `body` | aucun |
| Destructif | transparent | `danger`, `body` | `danger` |

Hauteur 38 en contexte de contenu, 34 en contexte de modale, 28 en barre d outils. Rayon 10, sauf dans les modales courtes ou les boutons sont en capsule.

### 4.7 Menu contextuel

Fond `surface.menu`, rayon 14, elevation 1, largeur minimale 220. Ligne de 34 de haut, icone 16 en `accent` a gauche, libelle en `body`. Coche a gauche pour les groupes a choix unique. Separateur pleine largeur entre deux groupes.

### 4.8 Modale courte

Reference : `wireframes/09-modales-et-etats.svg`

Largeur 380, rayon 20, elevation 2. Titre en `title2`, description en `callout`, champ, puis deux boutons en capsule cote a cote de largeur egale. Le bouton de confirmation est a droite. Fermeture par Echap et par clic sur le voile.

### 4.9 Feuille de configuration

Largeur 440, rayon 16. Titre, phrase d explication, champs etiquetes, bouton de test de connexion avec retour visuel immediat, puis Annuler a gauche et Enregistrer a droite. Le bouton Enregistrer reste desactive tant que le test n a pas reussi.

### 4.10 Etats de contenu

Trois etats obligatoires par ecran.

**Vide** : icone de 52 en `#4A4A4F`, titre en `title1`, phrase en `callout` `text.tertiary`, action facultative. Bloc centre dans la zone de contenu, largeur maximale 420, texte centre.

**Chargement** : squelettes aux dimensions exactes du contenu attendu, fond `surface.card`, pulsation d opacite de 0.4 a 0.8 sur 1200 ms. Jamais de roue de chargement seule sur une zone pleine.

**Erreur** : icone d avertissement en `warning`, titre qui nomme la cause reelle, phrase qui indique la sortie, bouton Reessayer. L erreur ne s excuse pas et ne reste jamais vague.

---

## 5. ECRANS

### 5.1 Bibliotheque

Reference : `wireframes/01-coquille-bibliotheque-vide.svg` et `wireframes/02-bibliotheque-grille.svg`

**Barre d outils** : titre a gauche, puis a droite un bouton plus, un bouton de tri avec chevron, et un champ de recherche de 206 de large avec l espace reserve `Rechercher la bibliotheque`.

**Menu de tri** : A a Z avec coche, Derniere lecture, Derniere mise a jour, Date d ajout, Non lu, separateur, Ordres de lecture.

**Barre de categories** sous la barre d outils : onglets textuels avec compteur, l onglet actif porte un fond `surface.menu` en capsule. Categorie Tout toujours en premier.

**Grille** : voir 4.3.

**Etat vide** : titre `Votre bibliotheque est vide`, phrase `Parcourez les sources pour trouver des mangas et les ajouter a votre bibliotheque.`

**A concevoir en plus** : le mode liste compacte, alternative a la grille, avec une vignette de 48 par 72, le titre, la source, le compteur de non lus, et la date de dernier chapitre.

### 5.2 Historique

Etat vide : titre `Aucun historique`, phrase `Les chapitres que vous lisez apparaitront ici.`

**A concevoir** : la liste peuplee. Regroupement par jour avec un en tete collant portant la date en `headline`. Chaque entree affiche une vignette de couverture de 44 par 66, le titre de la serie, le chapitre, l heure de lecture, et un bouton de suppression au survol. Un bouton Effacer l historique dans la barre d outils, avec confirmation.

### 5.3 Parcourir

Reference : `wireframes/03-parcourir-menu-ajouter.svg`

**Barre d outils** : bouton plus avec chevron, bouton de tri avec chevron, champ `Rechercher des sources`.

**Menu plus**, dans cet ordre exact :

Transfert Wi-Fi, separateur, Ajouter un serveur Komga, Ajouter un serveur Kavita, Ajouter un serveur Jellyfin, Ajouter un catalogue OPDS, Ajouter SMB / NAS, Ajouter un partage NFS, Ajouter un serveur WebDAV, Parcourir un dossier local, Ajouter une bibliotheque iCloud Drive, Ajouter un depot, Installer une extension.

**Menu de tri** : en tete `Trier`, puis Personnalise avec coche, Nom, Langue.

**Compteur** au dessus de la liste : `N installees` en `headline`.

**A concevoir** : l ecran de catalogue d une source, atteint en cliquant sur une source. Il propose des onglets Populaires, Recents, Filtres, et une grille identique a celle de la bibliotheque.

### 5.4 Rechercher

Champ de recherche pleine largeur dans la barre d outils, espace reserve `Manga, auteurs, genres...`

Etat vide : titre `Rechercher un manga`, phrase `Recherche dans toutes les sources installees`.

**A concevoir** : les resultats groupes par source. Chaque source forme une rangee horizontale defilante avec son nom en `headline`, un compteur de resultats, et un lien `Tout voir`. Une source qui ne repond pas affiche une ligne d erreur discrete a sa place sans bloquer les autres.

### 5.5 Reglages

Reference : `wireframes/05-reglages.svg`

Colonne de 580 centree. Sections dans cet ordre exact, avec leurs lignes exactes. Le detail complet figure dans le cahier des charges DEV, section 9. Ton travail consiste a maquetter la colonne complete en respectant cet ordre.

1. Abonnement
2. Confidentialite
3. General
4. Bibliotheque (tri)
5. Traduction
6. Lecteur
7. Prereglages de lecture
8. Comportement du lecteur
9. Bibliotheque (comportement)
10. Pont navigateur
11. Suivis
12. Telechargements
13. Sauvegarde et restauration
14. iCloud
15. Stockage
16. Assistance
17. A propos

La section A propos se termine par une note en `caption` `text.quaternary`, alignee a gauche, sous la carte.

**A concevoir en plus** : les sous ecrans Statistiques de lecture, Signets, Gestion des prereglages, Detail du stockage.

### 5.6 Fiche de serie

Reference : `wireframes/04-fiche-serie.svg`

Cet ecran n existe pas dans les captures de reference. Tu le concois entierement.

**En tete** : banniere de 300 de haut utilisant la couverture floutee a 40 px de rayon et assombrie a 55 pour cent, couverture nette de 188 par 278 posee dessus a gauche, metadonnees a droite.

**Metadonnees** : titre en `display`, auteurs en `callout`, ligne d etat en `footnote` combinant statut, langue et source, puis les genres en pastilles.

**Actions** : bouton principal contextuel dont le libelle change selon l etat (`Commencer la lecture`, `Reprendre ch. N`, `Tout est lu`), puis Dans ma liste, Suivre, et un bouton d options.

**Resume** : trois lignes maximum, bouton `Afficher plus` en `accent`.

**Liste des chapitres** : en tete avec le compteur en `title2` et les actions Filtrer, Trier, Tout marquer lu. Lignes selon 4.5. Selection multiple avec barre d actions contextuelle en bas.

### 5.7 Lecteur pagine

Reference : `wireframes/06-lecteur-pagine.svg`

Ecran entierement a concevoir. C est le coeur du produit, il merite le plus de soin.

**Fond** : `surface.reader`, reglable parmi Noir OLED, Gris sombre, Blanc, Sepia.

**Barres masquees par defaut.** Elles apparaissent au tap central ou au deplacement de la souris sur macOS, et se retirent apres 3 secondes d inactivite.

**Barre superieure** : hauteur 72, fond `surface.window` a 94 pour cent, flou d arriere plan. Retour a gauche, titre de serie et chapitre au centre gauche sur deux lignes, actions a droite : Filtres, Traduire, Coloriser, Signet, Options.

**Barre inferieure** : hauteur 64. Compteur de pages a gauche en chiffres tabulaires, curseur au centre, lien Chapitre suivant a droite. **Le curseur s inverse en mode droite a gauche.** Au maintien, il affiche une bande de vignettes.

**Zones de toucher** : trois colonnes verticales, gauche 28 pour cent, centre 44 pour cent, droite 28 pour cent. Elles ne sont jamais visibles sauf pendant le tutoriel de premiere ouverture, ou elles apparaissent en surimpression a 6 pour cent d opacite pendant 4 secondes.

**Double page** : deux pages cote a cote sans separateur ni ombre, gouttiere de 4. En mode droite a gauche, la premiere page de la paire est a droite.

**Panneau de filtres** : popover ancre au bouton Filtres, contenant les curseurs Luminosite, Chaleur, Nettete, Contraste, Gamma, et les interrupteurs Reduction du bruit, Amelioration IA, Colorisation IA. Chaque modification s applique en direct sur la page visible.

### 5.8 Lecteur webtoon

Reference : `wireframes/07-lecteur-webtoon.svg`

Defilement vertical continu. Colonne centree de largeur reglable : Ajustee, Pleine largeur, ou valeur libre entre 40 et 100 pour cent. Espacement entre pages reglable de 0 a 24. Aucune animation de transition. Progression exprimee en pourcentage plutot qu en numero de page. Enchainement automatique vers le chapitre suivant sans quitter le lecteur, avec un separateur discret portant le numero du chapitre entrant.

### 5.9 Mur premium

Reference : `wireframes/09-modales-et-etats.svg`

Feuille de 360 de large, fond `#141A28`, contour `#24344F`. Couronne en `accent`, titre, liste des avantages avec coche, bouton principal pleine largeur, mention de prix en `caption`. Aucun compte a rebours, aucune formulation qui presse l utilisateur.

### 5.10 Premiere ouverture

Ecran a concevoir. Trois etapes maximum, chacune avec une seule decision.

1. Choisir le sens de lecture par defaut, avec un apercu visuel des deux options.
2. Ajouter une premiere source, avec les trois choix les plus courants mis en avant et un lien vers la liste complete.
3. Proposer l essai premium, avec un bouton Plus tard aussi visible que le bouton d essai.

---

## 6. ACCESSIBILITE

- Contraste minimal 4.5:1 pour tout texte sous 18 px, 3:1 au dela. Verifie chaque paire de jetons.
- Cible de pointage minimale 44 par 44 sur iOS et iPadOS, 28 par 28 sur macOS.
- Focus clavier visible partout : contour de 2 en `accent` avec un decalage de 2. Jamais supprime.
- Ordre de tabulation logique, de haut en bas et de gauche a droite.
- Texte dynamique pris en charge jusqu a la taille accessibilite extra extra large. Les lignes de reglages passent alors en disposition verticale.
- Chaque icone sans libelle porte une etiquette d accessibilite.
- Aucune information transmise par la couleur seule. La pastille de non lus porte un chiffre, l etat de connexion porte un texte en plus de la pastille.

---

## 7. TEXTES D INTERFACE

Regles d ecriture :

- Voix active. Le bouton dit ce qui se passe : `Enregistrer`, pas `Valider`.
- Le meme mot pour la meme action du debut a la fin d un parcours. Le bouton `Telecharger` produit l etat `Telecharge`.
- Un etat vide est une invitation a agir, pas un constat.
- Une erreur nomme la cause et donne la sortie. Elle ne s excuse pas.
- Pas de tiret cadratin, jamais.
- Pas de point d exclamation.
- Pas de vocabulaire technique visible : on dit `serveur`, pas `endpoint`, on dit `source`, pas `provider`.

---

## 8. LIVRABLES ATTENDUS

Livre dans cet ordre. Chaque etape doit etre validee avant la suivante.

1. **`design-tokens.json`** : tous les jetons des sections 2.1 a 2.6, dans les quatre themes, en mode clair et sombre.
2. **Planche de composants** : chaque composant de la section 4 dans tous ses etats.
3. **Maquettes d ecrans** : les dix ecrans de la section 5, chacun en etat vide, charge et en erreur, en mode sombre puis en mode clair.
4. **Declinaisons iPad et iPhone** des cinq ecrans principaux.
5. **`DESIGN-SPEC.md`** : le document de reference que Claude Code lira avant d ecrire la moindre ligne. Il contient les jetons sous forme de tableau, les regles de mise en page chiffrees, la specification de chaque composant, et le texte exact de chaque libelle d interface.
6. **Icone d application** originale, en 1024 par 1024, avec ses declinaisons.

Le fichier `DESIGN-SPEC.md` est le livrable critique. Sans lui, le developpement ne peut pas commencer.

---

## 9. CRITERE DE REUSSITE

Ouvre une page de manga en plein ecran dans ta maquette de lecteur. Si ton regard est attire par un element d interface avant d etre attire par le dessin, le design a echoue. Recommence.
