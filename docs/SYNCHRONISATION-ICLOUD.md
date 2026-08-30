# Synchronisation iCloud

Annexe de la section 2.2 du cahier de developpement, qui annonce une couche
explicite au dessus de CloudKit, avec journal de changements, plutot que le
miroir automatique.

Le document existe pour une raison precise : le deuxieme critere de la
fonctionnalite demande qu un conflit soit resolu de facon **deterministe et
documentee**. La regle est ecrite ici en francais, et une seule fois en Swift,
dans `Packages/Core/Sources/ResolutionDeConflit.swift`.

## Ce qui circule

Une ligne de journal, et rien d autre.

| Champ | Role |
|---|---|
| `cle` | nature de l objet et son identifiant, stable entre appareils |
| `charge` | etat complet de l objet, encode par la couche qui le connait |
| `horodatage` | instant du geste sur l appareil qui l a produit, jamais celui de l envoi |
| `appareil` | identifiant stable de l appareil emetteur |
| `supprime` | vrai quand la ligne dit que l objet a disparu |

Deux entites circulent aujourd hui, une par interrupteur de la section iCloud
des reglages : la progression d un chapitre et la presence d une serie dans la
bibliotheque.

## La regle de conflit

Quand deux appareils ont modifie le meme objet, la version retenue est designee
par les trois lignes suivantes, dans cet ordre.

1. **L horodatage le plus recent gagne.** C est la regle utile : le dernier
   geste de l utilisateur est celui qu il s attend a retrouver.
2. **A horodatage egal, l identifiant d appareil le plus grand gagne**, au sens
   de la comparaison lexicographique. Cette ligne n a aucun sens metier, et ce
   n est pas ce qu on lui demande : elle garantit que la reponse ne depend pas
   de l ordre d arrivee. Sans elle, deux appareils qui recoivent les memes deux
   versions dans deux ordres differents en gardent chacun une autre, et la
   divergence est definitive puisque plus rien ne bouge ensuite.
3. **A horodatage et appareil egaux, la charge la plus grande gagne**, comparee
   octet par octet. Le cas suppose deux ecritures distinctes du meme appareil
   dans la meme milliseconde. Il est rare, il n est pas impossible, et le
   laisser sans reponse rendrait la regle non deterministe precisement la ou on
   affirme qu elle l est.

La regle est commutative et son resultat ne depend d aucun ordre. Elle est
appliquee aux quatre endroits ou deux versions peuvent se rencontrer, et
toujours par le meme code : au journal local, a l ecriture chez le distant, a
la reception d un lot, et a l ecriture en base.

**Ce que la regle ne fait pas**, volontairement : elle ne fusionne rien. Une
position de lecture n a pas de fusion sensee, la moyenne de deux pages n existe
pas. Le choix porte sur deux etats complets, jamais sur leurs champs.

Deux garde fous s ajoutent a la regle, cote application locale.

- Un chapitre marque lu ne redevient jamais non lu par synchronisation. Seul un
  demarquage explicite depuis la fiche de serie le fait revenir.
- Une lecture locale plus recente que la ligne recue resiste. Le cas arrive
  apres une session incognito, ou apres une periode ou l interrupteur etait
  inactif : la position locale n est alors jamais passee par le journal.

## Cadence et budget de propagation

`CadenceDeSynchronisation.parDefaut` porte les durees du produit.

| Duree | Valeur | Role |
|---|---|---|
| Delai de regroupement | 2 s | laisse murir une rafale de tournes de page avant d envoyer |
| Intervalle de sondage | 15 s | filet quand aucune notification CloudKit n arrive |
| Marge reseau | 5 s | allers retours |
| Budget de propagation | 30 s | le critere d acceptation |

Pire cas : 2 + 15 + 5 = 22 secondes, sous les 30 du critere. Le chemin normal
est plus court, la notification poussee par CloudKit declenchant un echange
immediat sans attendre le sondage.

## Mode hors ligne

Ce qui est autorise mais empeche attend ; ce qui est interdit ne s ecrit nulle
part.

- Un changement refuse par le reseau entre au journal et repart a la
  reconnexion.
- Un changement refuse par le mode incognito, par l abonnement ou par un
  interrupteur inactif n entre pas au journal. Il ne repartira donc pas plus
  tard : une session incognito qui deposerait sa trace a la fin de la session
  aurait laisse une trace, avec du retard.
- Rien ne sort du journal sans accuse du distant. Un envoi qui echoue laisse le
  journal intact.
- Le journal est regroupe par cle. Une journee de lecture hors ligne pese autant
  de lignes qu il y a de chapitres touches, pas autant qu il y a eu
  d enregistrements de position.

## Indicateur d etat

`EtatDeSynchronisationICloud` est une valeur du domaine, pas une chaine. La
couche vue lui donne son libelle et sa couleur.

| Etat | Ce qu il dit |
|---|---|
| `inactive` | les interrupteurs sont eteints, ou l abonnement manque |
| `aJour(le:)` | tout est parti, a cet instant |
| `enAttente(changements:)` | des lignes attendent leur echeance |
| `echangeEnCours` | un echange est en cours |
| `horsLigne(changements:)` | le reseau manque, les lignes sont gardees |
| `enEchec(changements:)` | la derniere tentative a echoue, les lignes sont gardees |

## Ce qui n est pas encore couvert

- Les categories, dont la fusion n est pas un choix entre deux etats mais une
  reunion de deux ensembles ordonnes. La regle par horodatage perdrait une
  categorie ajoutee des deux cotes.
- Les abonnements CloudKit qui declenchent la notification poussee, et le
  pilotage temporel des tics. Le moteur expose `tic` et
  `synchroniserMaintenant` ; l appelant decide de la cadence reelle.
