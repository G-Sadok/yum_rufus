# Cahier des charges DEVELOPPEMENT

## Application de lecture de manga pour macOS, iPadOS et iOS

**Destinataire : Claude Code**
**Version du document : 1.0**
**Nom de code du projet : TSUZUKI (a remplacer par le nom definitif)**

---

## 0. REGLES ABSOLUES

Lis cette section en entier avant toute action. Ces regles priment sur toute autre instruction du document.

### 0.1 Prerequis bloquant

**Tu ne commences a coder qu apres avoir lu le fichier `DESIGN-SPEC.md` produit par Claude Design.**

Concretement, ta premiere action est de verifier la presence de ce fichier a la racine du projet.

- S il est present : lis le en entier, puis extrais tous les jetons dans un fichier Swift genere avant d ecrire la moindre vue.
- S il est absent : arrete toi, dis le clairement, et ne produis aucune vue. Tu peux en revanche construire la couche Core (sections 4 a 8), qui ne depend d aucune decision visuelle.

Ne devine jamais une couleur, une taille, un rayon ou un libelle. Toutes ces valeurs viennent de `DESIGN-SPEC.md`. Aucune valeur en dur dans une vue.

### 0.2 Regle de redaction

**N utilise jamais le caractere tiret cadratin.** Ni dans le code, ni dans les commentaires, ni dans les chaines de caracteres, ni dans les fichiers de localisation, ni dans la documentation, ni dans les messages de commit, ni dans tes reponses. Remplace le par une virgule, un deux points, une parenthese ou une phrase separee.

### 0.3 Contraintes juridiques

- Le nom, l icone, les couleurs de marque et les textes marketing doivent etre originaux. Ne reprends aucun element identifiant d une application existante.
- Aucune ligne de code decompilee ou copiee depuis une application tierce.
- L application ne heberge, ne redistribue et ne met en cache aucun contenu sous droit d auteur sur un serveur que nous controlons. Elle ne fait que lire ce que l utilisateur possede ou ce qu une source publique expose via son API officielle.
- Les identifiants de connexion vont dans le trousseau du systeme, jamais dans `UserDefaults`, jamais dans un fichier en clair.

### 0.4 Discipline generale

- Swift 6 en mode concurrence stricte. Aucun `@unchecked Sendable` sans commentaire justifiant.
- Aucun avertissement de compilation dans la version livree.
- Aucun `force unwrap` en dehors des tests.
- Chaque module public documente avec la syntaxe de documentation Swift.

---

## 1. VISION PRODUIT

Un lecteur de manga, manhwa et manhua qui agrege des sources heterogenes et offre un moteur de lecture soigne.

L application ne heberge aucun contenu. Elle lit :

- des fichiers locaux (dossiers, archives, PDF),
- des serveurs auto heberges (Komga, Kavita, Jellyfin),
- des catalogues ouverts (OPDS),
- des partages reseau (SMB, NFS, WebDAV),
- des sources distantes via un systeme d extensions.

La priorite absolue est la **qualite de l experience de lecture** : fluidite, fidelite de l image, respect du sens de lecture, aucune interruption.

---

## 2. CIBLES ET PILE TECHNIQUE

### 2.1 Plateformes

| Plateforme | Version minimale |
|---|---|
| macOS | 14.0 Sonoma |
| iPadOS | 17.0 |
| iOS | 17.0 |

Une seule cible multiplateforme, un seul code de vue, avec des adaptations conditionnelles.

### 2.2 Pile

| Domaine | Choix | Justification |
|---|---|---|
| Langage | Swift 6, concurrence stricte | securite des donnees entre acteurs |
| Interface | SwiftUI, avec des ponts AppKit ou UIKit ponctuels | le lecteur a besoin d un controle fin du defilement |
| Persistance | GRDB.swift sur SQLite | requetes complexes sur des dizaines de milliers de chapitres, observation reactive, migrations explicites |
| Synchronisation | CloudKit, base privee | correspond au reglage Synchronisation iCloud |
| Reseau | URLSession et async await | pas de dependance tierce |
| Archives | libarchive via un paquet Swift | couvre ZIP, RAR, RAR5, 7z, TAR, LZH d un seul coup |
| Images | Image I/O et Core Graphics | decodage sous echantillonne accelere materiellement |
| Rendu du lecteur | Metal via `CAMetalLayer` pour le mode webtoon, `NSScrollView` ou `UICollectionView` pour le mode pagine | la limite de texture impose un decoupage en tuiles |
| PDF | PDFKit | natif, performant |
| IA embarquee | Core ML | surelevation, colorisation, detection de cases |
| Traduction | framework Translation d Apple pour le mode sur l appareil | gratuit et prive comme annonce dans les reglages |
| Achats | StoreKit 2 | abonnement premium |
| Partages reseau | AMSMB2 pour SMB, client WebDAV maison sur URLSession | NFS via un pont libnfs |

**Justification du choix de GRDB plutot que SwiftData** : la bibliotheque peut atteindre plusieurs dizaines de milliers de chapitres. SwiftData ne donne pas assez de controle sur les index et sur les requetes de comptage utilisees par les compteurs de non lus. La synchronisation iCloud sera implementee comme une couche explicite au dessus de CloudKit, avec un journal de changements, plutot que par le miroir automatique.

### 2.3 Organisation en paquets

```
Yum/
  Packages/
    Core/            modeles, protocoles, aucune dependance UI
    Storage/         GRDB, schema, migrations, requetes
    Sources/         implementations de SourceProvider
    Archive/         pont libarchive, lecture d archives
    ImagePipeline/   decodage, cache, traitements
    ReaderEngine/    pagination, tuilage, precharge
    Intelligence/    modeles Core ML, traduction
    Sync/            CloudKit, journal de changements
    DesignSystem/    jetons generes depuis DESIGN-SPEC.md, composants
  App/
    Yum/         cible multiplateforme, vues, navigation
```

**Regle d architecture stricte** : aucun paquet sous `Packages/` autre que `DesignSystem` n importe SwiftUI. Si tu ecris `import SwiftUI` dans `Core`, `Sources` ou `ReaderEngine`, tu as fait une erreur de conception.

---

## 3. MODELE DE DONNEES

### 3.1 Entites

**Source**
`id`, `type` (enum), `nom`, `configurationChiffree`, `versionExtension`, `langue`, `ordreAffichage`, `estActive`, `dateDerniereVerification`, `etatConnexion`.

**Manga**
`id`, `sourceId`, `identifiantDistant`, `titre`, `titresAlternatifs`, `auteurs`, `dessinateurs`, `resume`, `genres`, `statut` (enum), `langue`, `urlCouverture`, `cheminCouvertureLocale`, `sensLectureForce` (optionnel), `estDansBibliotheque`, `dateAjout`, `dateDerniereMiseAJour`, `dateDerniereLecture`.

**Chapitre**
`id`, `mangaId`, `identifiantDistant`, `numero` (decimal), `titre`, `groupeTraduction`, `langue`, `datePublication`, `nombrePages`, `estLu`, `pageAtteinte`, `dateLecture`, `ordreDansSerie`.

**Page**
`id`, `chapitreId`, `index`, `urlDistante`, `cheminLocal`, `largeur`, `hauteur`, `octets`.

**Categorie**
`id`, `nom`, `ordre`. Table de liaison vers Manga.

**OrdreDeLecture**
`id`, `nom`, `description`. Table de liaison ordonnee vers Chapitre, permettant de composer une sequence traversant plusieurs series.

**EntreeHistorique**
`id`, `chapitreId`, `dateLecture`, `dureeSeconde`, `pageAtteinte`.

**Signet**
`id`, `chapitreId`, `pageIndex`, `note`, `dateCreation`, `vignetteLocale`.

**Telechargement**
`id`, `chapitreId`, `etat` (enum), `progression`, `octetsTotal`, `dateAjout`, `messageErreur`.

**PrereglageLecture**
`id`, `nom`, `donneesReglages` (JSON encodant l ensemble des reglages du lecteur).

**LiaisonSuivi**
`id`, `mangaId`, `service` (enum), `identifiantDistant`, `statut`, `chapitreVu`, `note`, `dateSynchronisation`.

### 3.2 Index obligatoires

```sql
CREATE INDEX idx_chapitre_manga_ordre ON chapitre(mangaId, ordreDansSerie);
CREATE INDEX idx_chapitre_non_lu ON chapitre(mangaId) WHERE estLu = 0;
CREATE INDEX idx_manga_bibliotheque ON manga(estDansBibliotheque, dateDerniereLecture);
CREATE INDEX idx_historique_date ON entreeHistorique(dateLecture DESC);
```

Le compteur de non lus affiche sur chaque couverture doit provenir d une **vue materialisee** ou d une colonne denormalisee mise a jour par declencheur. Il ne doit jamais declencher un comptage a la volee pendant le defilement de la grille.

### 3.3 Migrations

Migrations versionnees et explicites via `DatabaseMigrator`. Chaque migration porte un identifiant date. Aucune migration destructive sans sauvegarde prealable automatique.

---

## 4. SYSTEME DE SOURCES

C est la piece centrale de l architecture. Toutes les sources, du dossier local au serveur distant, passent par un seul protocole.

### 4.1 Protocole

```swift
public protocol SourceProvider: Sendable {
    var id: SourceID { get }
    var nom: String { get }
    var capacites: SourceCapacites { get }

    func verifierConnexion() async throws -> EtatConnexion
    func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant>
    func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant>
    func detailsManga(_ identifiant: String) async throws -> MangaDistant
    func chapitres(pour identifiant: String) async throws -> [ChapitreDistant]
    func pages(pour chapitre: String) async throws -> [PageDistante]
    func requeteImage(pour page: PageDistante) async throws -> URLRequest
}

public struct SourceCapacites: OptionSet, Sendable {
    public static let recherche         = SourceCapacites(rawValue: 1 << 0)
    public static let filtres           = SourceCapacites(rawValue: 1 << 1)
    public static let pagination        = SourceCapacites(rawValue: 1 << 2)
    public static let telechargement    = SourceCapacites(rawValue: 1 << 3)
    public static let progressionDistante = SourceCapacites(rawValue: 1 << 4)
    public static let plusieursLangues  = SourceCapacites(rawValue: 1 << 5)
}
```

L interface ne propose que les actions correspondant aux capacites declarees. Une source sans capacite de recherche n affiche pas de champ de recherche.

### 4.2 Implementations a livrer

| Type | Transport | Notes |
|---|---|---|
| **Fichiers locaux** | systeme de fichiers | signet de securite pour conserver l acces au dossier entre deux lancements |
| **Dossier iCloud Drive** | `NSFileCoordinator` | gerer le telechargement a la demande des fichiers non locaux |
| **Komga** | API REST, authentification basique | endpoints series, books, pages |
| **Kavita** | API REST, jeton JWT | rafraichissement de jeton automatique |
| **Jellyfin** | API REST, cle d API | filtrer sur le type de media livre |
| **OPDS** | XML Atom, versions 1.2 et 2.0 | suivre les liens de pagination |
| **SMB / NAS** | AMSMB2 | decouverte des partages, lecture en flux sans copie complete |
| **NFS** | pont libnfs | montage en lecture seule |
| **WebDAV** | URLSession, methode PROPFIND | prise en charge de l authentification Digest |
| **Depot d extensions** | manifeste JSON sur HTTPS | liste d extensions installables |
| **Extension** | interprete dedie | voir 4.3 |
| **Transfert Wi-Fi** | serveur HTTP local | voir 4.4 |

### 4.3 Systeme d extensions

Ne charge jamais de code natif arbitraire. Une extension est un paquet declaratif signe, contenant :

- un manifeste JSON (identifiant, nom, version, langue, capacites, domaines autorises),
- un jeu de regles d extraction declaratives (selecteurs CSS ou chemins JSON, correspondances de champs, regles de pagination),
- une icone.

L executeur est un interprete que **nous** ecrivons, qui applique ces regles. Il n execute aucun code fourni par l extension.

Contraintes de securite :

- Chaque extension tourne derriere une liste blanche de domaines declares dans son manifeste. Toute requete hors liste est bloquee.
- Aucun acces au systeme de fichiers, au trousseau, ni aux autres sources.
- Delai maximal de 15 secondes par requete.
- L utilisateur voit la liste des domaines avant d installer et doit confirmer.

Affiche un avertissement clair au premier ajout d un depot : l utilisateur est responsable de la legalite des contenus auxquels il accede.

### 4.4 Transfert Wi-Fi

Serveur HTTP local sur le port 8080, actif uniquement pendant que la feuille est ouverte, protege par un code a six chiffres affiche a l ecran. Il expose une page de depot de fichiers. Les fichiers recus vont dans la source Fichiers locaux. Le serveur s arrete des que la feuille se ferme.

---

## 5. LECTURE DE DOCUMENTS LOCAUX

### 5.1 Protocole

```swift
public protocol DocumentLocal: Sendable {
    var nombrePages: Int { get }
    var metadonnees: MetadonneesComic? { get }
    func referencePage(_ index: Int) throws -> ReferencePage
    func decoder(_ reference: ReferencePage, tailleCible: CGSize?) async throws -> ImageDecodee
}
```

### 5.2 Formats a prendre en charge

**Conteneurs** : CBZ, CBR, CB7, CBT, ZIP, RAR, RAR5, 7z, TAR, TAR.GZ, dossier d images, PDF, EPUB image.

**CBA et ACE sont explicitement exclus** pour raison de securite. Affiche un message expliquant pourquoi et propose la conversion.

**Images** : JPEG, PNG, APNG, GIF, BMP, TIFF, WebP, AVIF, HEIC, JPEG 2000, JPEG XL, SVG.

### 5.3 Points durs a traiter

**Tri naturel des pages.** Le tri lexicographique place `page10.jpg` avant `page2.jpg`. Implemente un comparateur qui decoupe les suites de chiffres et les compare numeriquement. L ordre des entrees dans une archive ZIP n est pas garanti, tu tries toujours toi meme.

**Filtrage des entrees parasites.** Ignore `__MACOSX/`, `.DS_Store`, `Thumbs.db`, tout fichier commencant par un point, et les fichiers non image sauf `ComicInfo.xml` qui alimente les metadonnees.

**Acces aleatoire selon le conteneur.**

- ZIP : index central, acces direct a la page N.
- TAR : aucun index, scanne une fois et met l index en cache sur disque.
- 7z en mode solide : l acces aleatoire est impossible. Bascule sur une extraction complete en dossier temporaire, avec une barre de progression, et supprime le dossier a la fermeture.

**Metadonnees.** Lis `ComicInfo.xml` en priorite, `ComicBookInfo` dans le commentaire ZIP en secours.

---

## 6. CHAINE DE TRAITEMENT DES IMAGES

C est ici que se joue la difference entre un prototype et un produit utilisable.

### 6.1 Budget memoire

Une page de scan de 3000 par 4500 pixels occupe environ 54 Mo une fois decompressee en RGBA. Dix pages en cache font 540 Mo. La regle :

1. **Decode toujours sous echantillonne a la taille d affichage**, via `CGImageSourceCreateThumbnailAtIndex` avec `kCGImageSourceThumbnailMaxPixelSize`.
2. Ne charge la pleine resolution que pendant un zoom actif, et libere la des la fin du geste.
3. Cache memoire LRU limite a 6 pages ou 220 Mo, selon la premiere limite atteinte.
4. Cache disque separe, plafond configurable, purge par date d acces.
5. Reagis a `didReceiveMemoryWarning` en vidant immediatement le cache memoire sauf la page visible.

### 6.2 Precharge

Deux pages en avant et une en arriere dans le sens de lecture. File de priorite distincte de la file de decodage de la page visible. Une precharge est annulable et le devient des que l utilisateur change de page.

### 6.3 Traitements

Chaine appliquee dans cet ordre exact, chaque etape etant optionnelle :

1. Rognage automatique des bords
2. Division des images larges
3. Reduction du bruit
4. Amelioration IA en deux fois
5. Colorisation IA
6. Nettete
7. Contraste
8. Gamma
9. Luminosite
10. Chaleur

Les etapes 6 a 10 sont des filtres Core Image appliques en temps reel sur le GPU. Les etapes 1 a 5 sont couteuses et leur resultat est mis en cache sur disque avec une cle integrant le hachage des parametres.

**Rognage automatique** : detecte les lignes et colonnes dont la variance est inferieure a un seuil configurable et dont la valeur moyenne est proche du blanc ou du noir pur. Applique une marge de securite de 4 pixels. Ce reglage est celui qui apporte le plus de confort percu, soigne le.

**Division des images larges** : detecte un ratio superieur a 1 et coupe au milieu. **L ordre des deux moities depend du sens de lecture.** En mode droite a gauche, la moitie droite vient en premier.

---

## 7. MOTEUR DE LECTURE

### 7.1 Modes

| Mode | Rendu | Contrainte principale |
|---|---|---|
| Page simple | une page ajustee | aucune |
| Double page | deux pages cote a cote | ordre inverse en droite a gauche, couverture seule |
| Defilement continu | pages empilees verticalement, transitions nettes | recyclage des vues |
| Webtoon | defilement vertical sans separation | tuilage obligatoire |

### 7.2 Sens de lecture

Valeur du modele, jamais deduite a la volee : `droiteGauche` (manga), `gaucheDroite` (manhwa et comics), `hautBas` (webtoon). Reglable globalement et surchargeable par serie.

Le sens de lecture affecte : l ordre des pages, la composition des doubles pages, la direction du geste, le sens du curseur de progression, la fleche clavier, l ordre des moities apres division, et le sens des zones de toucher si l option Inverser les zones est active.

**Implemente cette propriete des le premier jour.** La rajouter apres coup impose de reprendre tout le moteur.

### 7.3 Webtoon et limite de texture

Les images de webtoon atteignent parfois 20000 pixels de haut. La limite de texture Metal est de 16384 pixels : au dela, le rendu echoue.

Solution obligatoire : decoupe chaque image en tuiles de 2048 pixels de haut maximum, recycle les tuiles hors ecran, maintiens un budget de tuiles vivantes fixe. Ne tente pas de charger l image entiere pour la reduire ensuite.

### 7.4 Enchainement de chapitres

En modes continu et webtoon, le chapitre suivant se charge sans quitter le lecteur, separe par un intercalaire portant son numero. Marque le chapitre precedent comme lu au passage.

### 7.5 Reprise de lecture

Sauvegarde la position toutes les deux secondes et a chaque passage en arriere plan. La position est un couple chapitre et index de page, plus un decalage de defilement en mode webtoon.

---

## 8. FONCTIONS D INTELLIGENCE EMBARQUEE

Tout tourne sur l appareil. Aucune image ne quitte l appareil sauf si l utilisateur choisit explicitement le moteur de traduction dans le nuage.

| Fonction | Modele | Notes |
|---|---|---|
| Amelioration en deux fois | Real ESRGAN converti en Core ML, variante anime | traitement par tuiles de 256 avec recouvrement de 16 |
| Colorisation | modele de colorisation de manga converti en Core ML | resultat mis en cache, jamais recalcule |
| Detection de cases | detecteur entraine sur un jeu de donnees public de pages de manga | sert au zoom automatique case par case |
| Traduction sur l appareil | detection de texte par Vision, puis framework Translation | rendu du texte traduit en surimpression sur une bulle floutee |

**Mention obligatoire dans la section A propos** : indique la provenance du jeu de donnees d entrainement du detecteur de cases. Verifie sa licence avant integration et documente la dans le depot.

Chaque traitement IA s execute dans un acteur dedie avec une file serialisee. Deux traitements ne tournent jamais en parallele sur le meme appareil.

---

## 9. INVENTAIRE COMPLET DES REGLAGES

Ordre strict, libelles exacts. Chaque ligne indique son type de controle, sa valeur par defaut, et si elle est reservee a l abonnement.

### Abonnement
| Libelle | Controle | Defaut | Premium |
|---|---|---|---|
| Passer a Premium | navigation | | |

Description sous la section : `Debloquez la traduction, la colorisation, les suivis, la sauvegarde et restauration, le mode incognito, les serveurs Komga, Kavita, Jellyfin et OPDS, la synchronisation iCloud et bien plus.`

### Confidentialite
| Libelle | Controle | Defaut | Premium |
|---|---|---|---|
| Incognito | interrupteur | inactif | oui |
| Verrouillage de l app | interrupteur | inactif | non |

Description : `Navigation privee : l activite de lecture n est pas enregistree dans l historique. Verrouillage de l app : Face ID ou code requis pour ouvrir l application.`

### General
| Libelle | Controle | Defaut | Premium |
|---|---|---|---|
| Langue | menu | Systeme | non |
| Apparence | menu (Systeme, Clair, Sombre) | Systeme | non |
| Theme | menu (Midnight, Obsidian, Slate, Paper) | Midnight | non |
| Notifications de nouveaux chapitres | interrupteur | inactif | non |
| Statistiques de lecture | navigation | | non |
| Signets | navigation | | non |
| Objectif quotidien | compteur (Desactive, puis 1 a 20 chapitres) | Desactive | non |

### Bibliotheque
| Libelle | Controle | Defaut |
|---|---|---|
| Trier par | menu (A a Z, Derniere lecture, Derniere mise a jour, Date d ajout, Non lu) | A a Z |

### Traduction
| Libelle | Controle | Defaut | Premium |
|---|---|---|---|
| Moteur de traduction | menu (Sur l appareil, IA dans le nuage) | Sur l appareil | le second choix oui |

Description : `La traduction sur l appareil est gratuite et privee. Le moteur dans le nuage donne de meilleurs resultats et consomme des credits.`

### Lecteur
| Libelle | Controle | Defaut |
|---|---|---|
| Sens de lecture | menu (Droite a gauche, Gauche a droite, Vertical) | Droite a gauche |
| Mise en page | menu (Page simple, Double page, Defilement continu, Webtoon) | Page simple |

### Prereglages de lecture
| Libelle | Controle |
|---|---|
| Enregistrer l actuel comme prereglage | action |

Description : `Un prereglage capture tous les reglages de lecture ci dessous, le sens, les filtres, la teinte et les traitements IA, puis les reapplique en une seule action.`

### Comportement du lecteur
| Libelle | Controle | Defaut | Premium |
|---|---|---|---|
| Rogner les bords | interrupteur | inactif | non |
| Masquer les barres en glissant | interrupteur | actif | non |
| Animer les transitions de page | interrupteur | actif | non |
| Arriere plan | menu (Noir OLED, Gris sombre, Blanc, Sepia) | Noir OLED | non |
| Luminosite | curseur 0 a 100 | 100 | non |
| Chaleur | curseur 0 a 100 | 0 | non |
| Zones de toucher | menu (Desactive, Standard, Bord, Kindle) | Desactive | non |
| Inverser les zones | interrupteur | inactif | non |
| Diviser les images larges | interrupteur | inactif | non |
| Reduction du bruit | interrupteur | inactif | non |
| Amelioration IA en deux fois | interrupteur | inactif | oui |
| Colorisation par IA | interrupteur | inactif | oui |
| Nettete | curseur 0 a 100 | 0 | non |
| Contraste | curseur 0 a 100 | 50 | non |
| Gamma | curseur 0 a 100 | 50 | non |

### Bibliotheque, comportement
| Libelle | Controle | Defaut |
|---|---|---|
| Ignorer les chapitres en double | interrupteur | inactif |
| Supprimer automatiquement les telechargements lus | interrupteur | inactif |

Description de la seconde ligne : `Liberez de l espace en supprimant le telechargement d un chapitre une fois que vous l avez termine.`

### Pont navigateur
| Libelle | Controle | Defaut |
|---|---|---|
| Activer le pont navigateur | interrupteur | inactif |

Fonction : une extension de navigateur permet d envoyer une serie vers l application depuis une page web ouverte. Le pont ouvre une socket locale authentifiee par jeton.

### Suivis
| Libelle | Controle | Premium |
|---|---|---|
| AniList | connexion OAuth | oui |
| MyAnimeList | connexion OAuth | oui |
| Kitsu | connexion OAuth | oui |
| MangaUpdates | connexion | oui |
| Synchroniser automatiquement la progression | interrupteur, defaut inactif | oui |

### Telechargements
| Libelle | Controle | Premium |
|---|---|---|
| Telecharger des chapitres | navigation | oui |

Le sous ecran contient : nombre de telechargements simultanes (1 a 5, defaut 3), telecharger uniquement en Wi-Fi, dossier de destination, nombre de chapitres a telecharger d avance automatiquement.

### Sauvegarde et restauration
| Libelle | Controle | Premium |
|---|---|---|
| Sauvegarde et restauration | navigation | oui |

Description : `Premium requis pour les fonctions de sauvegarde.`

Format d export : archive contenant un fichier JSON versionne. Il inclut la bibliotheque, les categories, la progression, les signets, les prereglages et la configuration des sources, **sans les mots de passe**. L import propose la fusion ou le remplacement.

### iCloud
| Libelle | Controle | Premium |
|---|---|---|
| Synchronisation iCloud | navigation | oui |

Description : `Synchronisez votre bibliotheque, votre progression de lecture et vos reglages sur tous vos appareils.`

### Stockage
| Libelle | Controle | Premium |
|---|---|---|
| Chapitres telecharges | navigation avec taille affichee | oui |
| Cache des chapitres | navigation avec taille affichee | oui |
| Cache des images | navigation avec taille affichee | oui |

### Assistance
| Libelle | Controle |
|---|---|
| Aide | lien externe |
| Communaute | lien externe |
| Demander une fonctionnalite | lien externe |
| Signaler un bug | ouvre un formulaire pre rempli avec la version et le journal recent |

### A propos
| Libelle | Valeur |
|---|---|
| Version | numero et numero de compilation |
| Moteur | version du moteur de rendu |
| Sources | nombre de sources installees |
| Bibliotheque | nombre de series |

Note en bas de section : mention de provenance du jeu de donnees du detecteur de cases, avec sa licence.

---

## 10. MATRICE PREMIUM

Le mur premium est le seul point d entree vers l achat. Il ne surgit jamais pendant la lecture.

**Gratuit** : sources locales, iCloud Drive, SMB, NFS, WebDAV, extensions, lecteur complet, filtres non IA, categories, historique, signets, statistiques, prereglages.

**Premium** : traduction, amelioration IA, colorisation IA, serveurs Komga, Kavita, Jellyfin, OPDS, tous les suivis, telechargements, sauvegarde et restauration, synchronisation iCloud, gestion du stockage, incognito.

Modele economique : abonnement mensuel et annuel, plus un achat definitif. Essai de sept jours. Restauration des achats obligatoire et accessible depuis le mur.

Regle de degradation : si l abonnement expire, aucune donnee n est supprimee. Les sources premium passent en lecture seule et affichent une banniere expliquant comment les reactiver.

---

## 11. SECURITE ET VIE PRIVEE

- Identifiants dans le trousseau, avec `kSecAttrAccessibleAfterFirstUnlock`.
- Aucune telemetrie par defaut. Si un diagnostic optionnel est ajoute, il est desactive au depart et explicitement decrit.
- Mode incognito : aucune ecriture dans l historique, aucune mise a jour de progression, aucune synchronisation vers les suivis. La banniere reste visible pendant toute la session.
- Verrouillage de l app : `LocalAuthentication`, avec repli sur le code de l appareil. Verrouillage au bout de 30 secondes en arriere plan.
- Toutes les requetes en HTTPS. Une exception en HTTP pour un serveur local doit etre confirmee explicitement par l utilisateur.
- Journalisation sans donnee personnelle. Ni titre de serie, ni adresse de serveur, ni identifiant.

---

## 12. PERFORMANCE

Budgets a tenir, mesures sur le materiel le plus modeste supporte.

| Mesure | Budget |
|---|---|
| Lancement a froid jusqu a la bibliotheque affichee | moins de 900 ms |
| Ouverture d un chapitre local jusqu a la premiere page | moins de 350 ms |
| Tourne de page en local | moins de 80 ms |
| Defilement de la grille de bibliotheque | 120 images par seconde soutenues |
| Defilement webtoon | 120 images par seconde soutenues |
| Memoire en lecture | moins de 400 Mo |
| Memoire au repos, bibliotheque de 5000 series | moins de 200 Mo |

Un jeu de test de 5000 series et 200000 chapitres doit exister dans le depot pour valider ces budgets.

---

## 13. LOCALISATION

Chaines dans un catalogue de chaines. Aucune chaine en dur dans une vue.

Langues de la premiere version : francais, anglais, espagnol, japonais.

Prise en charge complete de la disposition de droite a gauche de l interface pour l arabe, prevue mais non livree en version un. L architecture ne doit pas l empecher.

**Attention** : la direction de l interface et le sens de lecture du manga sont deux notions distinctes. Ne les confonds jamais dans le code.

---

## 14. TESTS

**Tests unitaires obligatoires** sur :

- le comparateur de tri naturel, avec un jeu de cas comprenant des numeros a zeros initiaux, des numeros decimaux, des prefixes mixtes,
- la composition des doubles pages dans les deux sens,
- l ordre des moities apres division d une image large,
- le parseur `ComicInfo.xml`, avec des fichiers malformes,
- l analyse des reponses de chaque source, avec des reponses figees.

**Tests d integration** sur : lecture d une archive de chaque format supporte, migration de base de donnees d une version a la suivante, cycle complet de sauvegarde puis restauration.

**Tests de performance** : un test qui echoue si un budget de la section 12 est depasse.

**Tests de captures** sur les composants du systeme de design, en mode clair et sombre.

---

## 15. ETAPES DE LIVRAISON

Ne passe pas a l etape suivante avant que l etape en cours soit complete et testee.

**Etape 0. Fondations**
Lecture de `DESIGN-SPEC.md`, generation des jetons Swift, mise en place des paquets, schema de base de donnees, migrations.

**Etape 1. Lire un fichier local**
Source Fichiers locaux, lecture ZIP, tri naturel, lecteur en page simple, sens de lecture, navigation clavier. Critere : lire un tome entier confortablement, sans bibliotheque, sans reglages.

**Etape 2. Chaine d images**
Cache LRU, precharge, decodage sous echantillonne, rognage automatique. Critere : les budgets de la section 12 sont tenus sur ce parcours.

**Etape 3. Bibliotheque**
Persistance, grille, categories, fiche de serie, liste des chapitres, reprise de lecture, historique.

**Etape 4. Formats etendus**
libarchive pour RAR, 7z, TAR. PDF via PDFKit. Metadonnees `ComicInfo.xml`.

**Etape 5. Sources distantes**
Komga, Kavita, Jellyfin, OPDS, WebDAV, SMB. Ecran Parcourir, ecran Rechercher.

**Etape 6. Modes de lecture avances**
Double page, defilement continu, webtoon avec tuilage, enchainement de chapitres, zones de toucher, prereglages.

**Etape 7. Telechargements**
File d attente, reprise, gestion du stockage.

**Etape 8. Premium et suivis**
StoreKit 2, mur premium, matrice de verrouillage, OAuth des quatre services de suivi.

**Etape 9. Intelligence**
Amelioration, colorisation, detection de cases, traduction.

**Etape 10. Synchronisation et sauvegarde**
CloudKit, journal de changements, export et import.

**Etape 11. Finition**
Premiere ouverture, accessibilite complete, localisation, mode clair, adaptations iPhone.

---

## 16. DEFINITION DU TERMINE

Une etape est terminee quand toutes ces conditions sont remplies.

- Le code compile sans aucun avertissement sur les trois plateformes.
- Les tests de l etape passent.
- Les budgets de performance concernes sont mesures et respectes.
- Aucune valeur visuelle en dur ne subsiste dans les vues.
- Aucune chaine en dur ne subsiste dans les vues.
- La navigation au clavier fonctionne sur tous les nouveaux ecrans.
- Le mode clair est correct sur tous les nouveaux ecrans.
- Aucun tiret cadratin n apparait dans le depot. Verifie avec une recherche avant de conclure.

---

## 17. CE QUI TUERA LE PROJET SI TU NE FAIS PAS ATTENTION

Par ordre de gravite, d apres l experience.

1. **Coder les vues avant d avoir lu `DESIGN-SPEC.md`.** Tu produiras une interface a refaire entierement.
2. **Oublier le sens de lecture dans le modele.** Le rajouter apres coup impose de reprendre le moteur, la pagination, les gestes et les tests.
3. **Charger les images en pleine resolution.** L application se fera terminer par le systeme au bout de quinze pages.
4. **Ignorer la limite de texture en mode webtoon.** Le rendu echouera silencieusement sur les chapitres les plus longs, c est a dire les plus lus.
5. **Compter les chapitres non lus a la volee pendant le defilement.** La grille saccadera des la centieme serie.
6. **Melanger la direction de l interface et le sens de lecture du manga.** Le bogue sera invisible en francais et systematique en arabe.
7. **Mettre SwiftUI dans un paquet Core.** Tu perdras la testabilite et la possibilite de porter le moteur.
