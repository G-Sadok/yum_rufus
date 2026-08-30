# Licences des modeles embarques

La section 8 du cahier de developpement demande de verifier la licence d un
modele avant integration et de la documenter dans le depot. Ce fichier est cette
documentation, et il n est pas seulement declaratif : le code le fait respecter
au chargement.

## Pourquoi une verification executable

Aucun poids de modele ne vit dans ce depot. Un reseau converti pese plusieurs
dizaines de megaoctets, il arrive au moment de l empaquetage, par une main qui
n aura pas relu ce fichier. Une phrase ici ne protege donc de rien le jour ou
quelqu un remplace un `mlmodelc` par un autre reseau.

Le catalogue `CatalogueDesModelesIA`, dans le paquet `Intelligence`, reprend
exactement le tableau ci dessous. Avant d ouvrir le moindre fichier de modele,
les chargeurs Core ML verifient trois choses :

1. l identifiant du modele figure au catalogue, pour le traitement demande ;
2. son jeu de donnees d entrainement autorise la distribution des poids, et il
   est documente des que la section 8 l exige, ce qu elle fait pour le detecteur
   de cases ;
3. un fichier de licence accompagne le modele dans son dossier, sous l un des
   noms `LICENSE`, `LICENSE.txt`, `LICENCE`, `LICENCE.txt` ;
4. ce fichier contient le marqueur de la licence attendue.

Si l une des quatre manque, le modele ne se charge pas, l erreur est
`ErreurDeTraitementIA.licenceNonDocumentee` ou
`ErreurDeTraitementIA.jeuDeDonneesNonAutorise`, et la fonction reste
indisponible.
La verification echoue de maniere fermee : dans le doute, la page reste lisible
telle quelle plutot que d etre traitee par un reseau dont personne ne peut dire
sous quelles conditions il est distribue.

Le tableau est donc un contrat et non un constat. Il dit ce que le depot exige
du fichier livre. Un modele distribue sous une autre licence que celle inscrite
ici ne se charge pas, et le desaccord se voit a la premiere execution.

## Registre

| Identifiant | Traitement | Provenance | Licence SPDX | Marqueur attendu |
|---|---|---|---|---|
| `real-esrgan-anime-x2` | amelioration | https://github.com/xinntao/Real-ESRGAN | BSD-3-Clause | `Redistribution and use in source and binary forms` |
| `manga-colorization-v2` | colorisation | https://github.com/qweasdd/manga-colorization-v2 | MIT | `Permission is hereby granted, free of charge` |
| `detecteur-de-cases-domaine-public-v1` | detectionDeCases | https://github.com/G-Sadok/yum_rufus | CC0-1.0 | `CC0 1.0 Universal` |

Un test de la suite `LicencesDeModelesTests` compare ce tableau au catalogue
Swift, ligne par ligne. Les deux ne peuvent donc pas diverger sans que
l integration continue le dise.

## Jeux de donnees d entrainement

La section 8 demande une chose de plus pour le detecteur de cases, et d elle
seule : verifier la licence du jeu de donnees d entrainement avant integration,
la documenter dans le depot, et porter la provenance dans la section A propos.

Le tableau suivant est le registre des jeux de donnees. Il est compare au champ
`jeuDeDonnees` des fiches par la meme suite de tests que le tableau precedent.

| Modele | Jeu de donnees | Provenance | Licence SPDX |
|---|---|---|---|
| `detecteur-de-cases-domaine-public-v1` | Planches du domaine public du Digital Comic Museum | https://digitalcomicmuseum.com | CC0-1.0 |

La licence des poids et celle du jeu de donnees sont deux choses distinctes, et
c est ce qui rend cette section necessaire. Un modele peut etre publie sous
licence permissive tout en ayant ete entraine sur des donnees dont les
conditions interdisent l usage commercial du resultat. La fiche porte donc un
drapeau, `redistributionDesPoids`, et `CatalogueDesModelesIA` refuse de charger
un modele dont ce drapeau est faux, ou un detecteur dont le jeu de donnees n est
pas documente du tout. L erreur est alors
`ErreurDeTraitementIA.jeuDeDonneesNonAutorise`, et la fonction reste
indisponible.

### Candidats examines et ecartes

Yum est une application vendue. Le mur premium de la section 10 en fait une
distribution commerciale, ce qui exclut les jeux de donnees reserves a la
recherche, meme quand ils sont les meilleurs du domaine. Les trois candidats
evidents ont donc ete ecartes, et la raison est ecrite ici pour qu elle ne soit
pas a retrouver.

| Jeu de donnees | Ce qu il apporte | Pourquoi il est ecarte |
|---|---|---|
| Manga109 | le jeu de reference, annotations de cadres sur 109 series | usage academique seulement, l usage commercial demande un accord separe avec les auteurs |
| eBDtheque | planches annotees, cadres et bulles | licence de recherche non commerciale |
| DCM772 | 772 planches du domaine public annotees | les planches sont libres, les annotations ne le sont pas pour un usage commercial |

Le choix retenu contourne le probleme par la source plutot que par la licence :
les planches du Digital Comic Museum sont des comics americains anterieurs a
1964 dont le droit d auteur n a pas ete renouvele, donc dans le domaine public,
et les annotations de cases sont produites par le projet et publiees sous
CC0 1.0. Le detecteur est ainsi le seul des trois modeles dont le depot maitrise
toute la chaine.

Deux limites de cette verification doivent etre dites, parce qu elles portent
sur du droit et non sur du code. La premiere est que le domaine public des
comics d avant 1964 se juge titre par titre, sur le renouvellement effectif du
depot : la selection des planches doit etre tracee au moment de la constitution
du jeu de donnees, et cette trace fait partie de la livraison du modele. La
seconde est que ce document fixe l etat des conditions telles qu elles ont ete
lues, et qu une licence amont peut changer. Toute livraison de poids repasse
donc par ce fichier avant d etre empaquetee.

## Obligations a tenir

Les deux licences du registre sont permissives et portent la meme obligation
pratique : conserver l avis de droit d auteur et le texte de la licence dans
toute redistribution. C est exactement ce que la verification impose, puisque le
modele ne se charge pas sans son fichier de licence a cote.

Aucune des deux n impose de reciprocite sur le code de l application, aucune ne
restreint l usage commercial, et aucune ne couvre les donnees d entrainement,
qui relevent de leurs propres conditions cote projet amont.

## Mentions dans la section A propos

`CatalogueDesModelesIA.mentionsAPropos` rend les lignes a afficher, dans l ordre
du registre :

- Amelioration IA : Real ESRGAN, variante anime, licence BSD 3 clauses.
- Colorisation IA : manga colorization v2, licence MIT.
- Detection de cases : detecteur du projet, entraine sur des planches du domaine
  public du Digital Comic Museum, annotations du projet publiees sous licence
  CC0 1.0.

La troisieme est la seule que la section 8 impose. C est elle que la note de fin
de la section A propos porte, sous la cle `reglages.note` du catalogue de
chaines, et un test compare cette chaine a la fiche du catalogue Swift.
`CatalogueDesModelesIA.mentionDuDetecteurDeCases` la rend a part pour cette
raison.

## Ajouter un modele

1. Ajouter la ligne au registre ci dessus.
2. Ajouter la fiche correspondante dans `CatalogueDesModelesIA.fiches`.
3. Quand le modele est entraine sur un jeu de donnees que le depot documente,
   ajouter la ligne au registre des jeux de donnees et le champ `jeuDeDonnees` a
   la fiche.
4. Poser le fichier de licence du projet amont a cote du `mlmodelc` livre.
5. Lancer `./scripts/verifications.sh` : le test de concordance echoue tant que
   le registre et le catalogue ne disent pas la meme chose.

Le moteur de traduction de la section 8 ne figure pas encore ici. Il arrivera
avec sa fonctionnalite, par la meme porte.
