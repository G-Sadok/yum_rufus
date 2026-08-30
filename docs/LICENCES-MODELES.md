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
2. un fichier de licence accompagne le modele dans son dossier, sous l un des
   noms `LICENSE`, `LICENSE.txt`, `LICENCE`, `LICENCE.txt` ;
3. ce fichier contient le marqueur de la licence attendue.

Si l une des trois manque, le modele ne se charge pas, l erreur est
`ErreurDeTraitementIA.licenceNonDocumentee`, et la fonction reste indisponible.
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

Un test de la suite `LicencesDeModelesTests` compare ce tableau au catalogue
Swift, ligne par ligne. Les deux ne peuvent donc pas diverger sans que
l integration continue le dise.

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

## Ajouter un modele

1. Ajouter la ligne au registre ci dessus.
2. Ajouter la fiche correspondante dans `CatalogueDesModelesIA.fiches`.
3. Poser le fichier de licence du projet amont a cote du `mlmodelc` livre.
4. Lancer `./scripts/verifications.sh` : le test de concordance echoue tant que
   le registre et le catalogue ne disent pas la meme chose.

Le detecteur de cases et le moteur de traduction de la section 8 ne figurent pas
encore ici. Ils arriveront avec leurs fonctionnalites, par la meme porte.
