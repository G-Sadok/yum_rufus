import Core
import Foundation

//
// Acces au catalogue de chaines.
//
// Aucune vue n ecrit un libelle. Elle passe par ce type, qui est le seul point
// du code ou une cle du catalogue apparait. Les libelles eux memes vivent dans
// Ressources/Localizable.xcstrings, et sont ceux de la section 6 de
// DESIGN-SPEC.md, au caractere pres.
//

/// Libelles de l interface, pris dans le catalogue de chaines.
enum Chaines {
    /// Libelle d une destination de la navigation principale, tableau 6.1.
    static func navigation(_ destination: DestinationPrincipale) -> String {
        switch destination {
        case .bibliotheque: Navigation.bibliotheque
        case .historique: Navigation.historique
        case .parcourir: Navigation.parcourir
        case .rechercher: Navigation.rechercher
        case .reglages: Navigation.reglages
        }
    }

    /// Navigation principale, tableau 6.1.
    enum Navigation {
        static let bibliotheque = String(localized: "navigation.bibliotheque")
        static let historique = String(localized: "navigation.historique")
        static let parcourir = String(localized: "navigation.parcourir")
        static let rechercher = String(localized: "navigation.rechercher")
        static let reglages = String(localized: "navigation.reglages")
        static let repli = String(localized: "navigation.repli")
    }

    /// Barre de categories, section 5.1.
    ///
    /// Seul `tout` est fixe par le document. La section 6 ne nomme pas les
    /// commandes de gestion des categories, l ecran n etant pas dessine : elles
    /// suivent les regles d ecriture de la section 6, voix active, le libelle
    /// dit ce qui se passe.
    ///
    /// Les deux deplacements parlent de rang dans la barre et non de gauche ou
    /// de droite. Une direction d ecran s inverserait avec la direction de
    /// l interface, le rang non.
    enum Categorie {
        static let tout = String(localized: "categorie.tout")
        static let creer = String(localized: "categorie.creer")
        static let renommer = String(localized: "categorie.renommer")
        static let supprimer = String(localized: "categorie.supprimer")
        static let deplacerAvant = String(localized: "categorie.deplacerAvant")
        static let deplacerApres = String(localized: "categorie.deplacerApres")
    }

    /// Bloc d appel a l abonnement, tableau 6.1.
    enum Premium {
        static let titre = String(localized: "premium.titre")
        static let sousTitre = String(localized: "premium.sousTitre")
    }

    /// Fiche de serie, sections 5.6 et 4.5, tableaux 6.1 et 6.5.
    ///
    /// Trois libelles ne figurent pas dans la section 6 : le repli du resume,
    /// l etiquette d accessibilite du bouton d options, et les deux commandes de
    /// selection du menu contextuel. Le document ne dessine ni le resume deplie
    /// ni ce menu. Ils suivent les regles d ecriture de la section 6 : voix
    /// active, le libelle dit ce qui se passe.
    enum Fiche {
        static let commencerLaLecture = String(localized: "fiche.commencerLaLecture")
        static let reprendreChapitre = String(localized: "fiche.reprendreChapitre")
        static let toutEstLu = String(localized: "fiche.toutEstLu")
        static let aucunChapitre = String(localized: "fiche.aucunChapitre")
        static let dansMaListe = String(localized: "fiche.dansMaListe")
        static let suivre = String(localized: "fiche.suivre")
        static let options = String(localized: "fiche.options")
        static let afficherPlus = String(localized: "fiche.afficherPlus")
        static let afficherMoins = String(localized: "fiche.afficherMoins")
        static let retour = String(localized: "fiche.retour")
    }

    /// En tete de la liste de chapitres, section 5.6 et tableau 6.5.
    enum Liste {
        static let compteurDeChapitres = String(localized: "liste.compteurDeChapitres")
        static let filtrer = String(localized: "liste.filtrer")
        static let trier = String(localized: "liste.trier")
        static let toutMarquerLu = String(localized: "liste.toutMarquerLu")
    }

    /// Ligne de chapitre, tableau 4.5.
    enum Chapitre {
        static let numerote = String(localized: "chapitre.numerote")
        static let lu = String(localized: "chapitre.lu")
        static let nombreDePages = String(localized: "chapitre.nombreDePages")
        static let pageSurTotal = String(localized: "chapitre.pageSurTotal")
        static let telecharge = String(localized: "chapitre.telecharge")
        static let etiquetteDeTelechargement = String(
            localized: "chapitre.etiquetteDeTelechargement"
        )
    }

    /// Barre d actions de selection multiple, section 4.5 et tableau 6.5.
    enum Selection {
        static let compteur = String(localized: "selection.compteur")
        static let marquerLu = String(localized: "selection.marquerLu")
        static let telecharger = String(localized: "selection.telecharger")
        static let supprimer = String(localized: "selection.supprimer")
        static let fermer = String(localized: "selection.fermer")
        static let selectionner = String(localized: "selection.selectionner")
        static let etendreLaSelection = String(localized: "selection.etendreLaSelection")
    }

    /// Statut editorial d une serie, premier fragment de la ligne d etat de la
    /// section 5.6.
    ///
    /// Seul `En cours` figure dans le document, dans l exemple de ligne d etat.
    /// Les trois autres reprennent les cas de `StatutSerie` et suivent les
    /// memes regles d ecriture.
    enum Statut {
        static let enCours = String(localized: "statut.enCours")
        static let termine = String(localized: "statut.termine")
        static let enPause = String(localized: "statut.enPause")
        static let abandonne = String(localized: "statut.abandonne")
    }

    /// Historique, section 5.2, tableau 6.5, et modale de la section 4.8.
    ///
    /// Le tableau 6.5 ne nomme que `Effacer l historique`. Les deux en tetes de
    /// jour, l etiquette du bouton de suppression et les trois textes de la
    /// modale de confirmation ne sont pas dessines par le document : ils
    /// suivent les regles d ecriture de la section 6, voix active, le libelle
    /// dit ce qui se passe, la description nomme ce qui n est pas touche.
    enum Historique {
        static let effacer = String(localized: "historique.effacer")
        static let aujourdHui = String(localized: "historique.aujourdHui")
        static let hier = String(localized: "historique.hier")
        static let supprimerLEntree = String(localized: "historique.supprimerLEntree")
        static let confirmationTitre = String(localized: "historique.confirmation.titre")
        static let confirmationDescription = String(
            localized: "historique.confirmation.description"
        )
        static let confirmationAnnuler = String(localized: "historique.confirmation.annuler")
        static let confirmationEffacer = String(localized: "historique.confirmation.effacer")
    }

    /// Panneau de filtres du lecteur, section 5.7 et tableau 6.5.
    ///
    /// Le titre est celui de l action de la barre du lecteur qui ouvre le
    /// panneau, `Filtres`, au tableau 6.5. Les huit lignes sont nommees par la
    /// section 5.7 elle meme, qui enumere les cinq curseurs puis les trois
    /// interrupteurs.
    ///
    /// L etiquette de la couronne est celle des reglages, et c est voulu : la
    /// couronne dit la meme chose au meme endroit du parcours, une fonction
    /// verrouillee par l abonnement. Lui donner deux formulations selon l ecran
    /// romprait la regle du meme mot pour la meme action.
    enum Filtres {
        static let titre = String(localized: "filtres.titre")
        static let luminosite = String(localized: "filtres.luminosite")
        static let chaleur = String(localized: "filtres.chaleur")
        static let nettete = String(localized: "filtres.nettete")
        static let contraste = String(localized: "filtres.contraste")
        static let gamma = String(localized: "filtres.gamma")
        static let reductionDuBruit = String(localized: "filtres.reductionDuBruit")
        static let ameliorationIA = String(localized: "filtres.ameliorationIA")
        static let colorisationIA = String(localized: "filtres.colorisationIA")
        static let couronne = String(localized: "reglages.couronne")
    }

    /// Gestion des prereglages, sous ecran de la section 5.5 et section 9 du
    /// cahier de developpement.
    ///
    /// Le titre et la description viennent du document. Les quatre commandes du
    /// menu d une ligne ne sont pas dessinees : elles suivent les regles
    /// d ecriture de la section 6, voix active, le libelle dit ce qui se passe,
    /// et reprennent les mots deja employes ailleurs pour les memes actions.
    ///
    /// Le titre de l etat vide est celui de la section 5.5, `Aucun prereglage`,
    /// et non une seconde formulation : c est le meme mot au meme endroit du
    /// parcours, de la ligne de reglages jusqu a l ecran qu elle ouvre.
    enum Prereglages {
        static let titre = String(localized: "prereglages.titre")
        static let enregistrerLActuel = String(localized: "prereglages.enregistrerLActuel")
        static let description = String(localized: "prereglages.description")
        static let options = String(localized: "prereglages.options")
        static let appliquer = String(localized: "prereglages.appliquer")
        static let renommer = String(localized: "prereglages.renommer")
        static let remplacerParLActuel = String(localized: "prereglages.remplacerParLActuel")
        static let supprimer = String(localized: "prereglages.supprimer")
        static let videTitre = String(localized: "reglages.aucunPrereglage")
        static let videPhrase = String(localized: "etatVide.prereglages.phrase")

        /// Libelle d une valeur de menu, sous la cle de l ecran Reglages.
        ///
        /// La cle est composee, ce que l extraction automatique ne saurait pas
        /// suivre. Le catalogue du projet est tenu a la main, `extractionState`
        /// vaut `manual` sur chacune de ses entrees, et la suite de tests
        /// verifie que la table couvre bien tous les cas des trois
        /// enumerations concernees.
        static func valeur(_ brute: String) -> String {
            String(localized: String.LocalizationValue("reglages.valeur.\(brute)"))
        }
    }

    /// Signets, sous ecran de la section 5.5 et section 3.1 du cahier de
    /// developpement.
    ///
    /// Le document nomme l ecran, `Signets`, et nomme le bouton qui pose un
    /// signet, `Signet` au tableau 6.5. Il ne dessine ni la description, ni les
    /// deux commandes du menu d une ligne, ni l etat vide : ils suivent les
    /// regles d ecriture de la section 6, voix active, le libelle dit ce qui se
    /// passe, et reprennent les mots deja employes ailleurs pour les memes
    /// actions.
    ///
    /// Le motif du chapitre est celui de la ligne de chapitre du tableau 4.5, et
    /// non une seconde formulation : c est le meme objet nomme au meme mot d un
    /// bout a l autre du parcours.
    enum Signets {
        static let titre = String(localized: "signets.titre")
        static let description = String(localized: "signets.description")
        static let chapitreNumerote = String(localized: "chapitre.numerote")
        static let pageNumerotee = String(localized: "signets.pageNumerotee")
        static let options = String(localized: "signets.options")
        static let ouvrirLaPage = String(localized: "signets.ouvrirLaPage")
        static let supprimer = String(localized: "signets.supprimer")
        static let videTitre = String(localized: "etatVide.signets.titre")
        static let videPhrase = String(localized: "etatVide.signets.phrase")
        static let videAction = String(localized: "etatVide.signets.action")
    }

    /// File de telechargement, section 4.11 et section 12 de l ecran Reglages.
    ///
    /// Le document nomme la section, `Telechargements`, et donne trois sous
    /// lignes exactes : `14 sur 24 pages`, `Termine  32 Mo` et `En attente`.
    /// Elles sont reprises au mot pres, y compris la paire d espaces qui separe
    /// deux fragments d une meme ligne.
    ///
    /// Le reste, commandes de ligne et etat vide, suit les regles d ecriture de
    /// la section 6 : voix active, le bouton dit ce qui se passe, et le meme mot
    /// pour la meme action d un bout a l autre du parcours. C est pourquoi
    /// l action produit bien l etat que le document annonce, `Telecharger`
    /// produit `Termine`.
    enum Telechargements {
        static let titre = String(localized: "telechargements.titre")
        static let description = String(localized: "telechargements.description")
        static let chapitreNumerote = String(localized: "chapitre.numerote")
        static let pagesFaites = String(localized: "telechargements.pagesFaites")
        static let enAttente = String(localized: "telechargements.enAttente")
        static let termineAvecPoids = String(localized: "telechargements.termineAvecPoids")
        static let termine = String(localized: "telechargements.termine")
        static let enPause = String(localized: "telechargements.enPause")
        static let annulee = String(localized: "telechargements.annulee")
        static let poidsEnOctets = String(localized: "telechargements.poidsEnOctets")
        static let poidsEnKo = String(localized: "telechargements.poidsEnKo")
        static let poidsEnMo = String(localized: "telechargements.poidsEnMo")
        static let poidsEnGo = String(localized: "telechargements.poidsEnGo")
        static let mettreEnPause = String(localized: "telechargements.mettreEnPause")
        static let reprendre = String(localized: "telechargements.reprendre")
        static let passerEnPremier = String(localized: "telechargements.passerEnPremier")
        static let annuler = String(localized: "telechargements.annuler")
        static let options = String(localized: "telechargements.options")
        static let videTitre = String(localized: "etatVide.telechargements.titre")
        static let videPhrase = String(localized: "etatVide.telechargements.phrase")
        static let videAction = String(localized: "etatVide.telechargements.action")
    }

    /// Gestion du stockage, section 15 de l ecran Reglages.
    ///
    /// La section 6 ne dessine pas ces ecrans. Les trois categories reprennent
    /// mot pour mot l inventaire de la section 9 du cahier de developpement,
    /// `Chapitres telecharges`, `Cache des chapitres` et `Cache des images`. Le
    /// reste suit les regles d ecriture de la section 6 : voix active, le bouton
    /// dit ce qui se passe, et l erreur comme la confirmation nomment ce dont
    /// elles parlent.
    ///
    /// Neuf libelles sont empruntes plutot que reecrits. Le titre et la
    /// description viennent de la ligne de reglages qui mene ici, la sous ligne
    /// `Lu` du tableau 4.5, le compteur et les commandes de la barre de
    /// selection de la section 4.5, les paliers de poids de la section 4.11. Le
    /// meme mot pour la meme chose d un bout a l autre du produit.
    enum Stockage {
        static let titre = String(localized: "reglages.ligne.stockage.detail")
        static let description = String(localized: "reglages.description.stockage")
        static let chapitreNumerote = String(localized: "chapitre.numerote")
        static let chapitreLu = String(localized: "chapitre.lu")
        static let chapitreNonLu = String(localized: "stockage.chapitreNonLu")
        static let cacheDUneSource = String(localized: "stockage.cacheDUneSource")
        static let elementsAnonymes = String(localized: "stockage.elementsAnonymes")
        static let supprimer = String(localized: "selection.supprimer")
        static let toutSupprimer = String(localized: "stockage.toutSupprimer")
        static let compteurDeSelection = String(localized: "selection.compteur")
        static let fermerLaSelection = String(localized: "selection.fermer")
        static let selectionner = String(localized: "selection.selectionner")
        static let confirmationTitre = String(localized: "stockage.confirmation.titre")
        static let confirmationDescription = String(
            localized: "stockage.confirmation.description"
        )
        static let confirmationAnnuler = String(localized: "historique.confirmation.annuler")
        static let videTitre = String(localized: "etatVide.stockage.titre")
        static let videPhrase = String(localized: "etatVide.stockage.phrase")

        /// Libelle d une categorie, inventaire de la section 9.
        static let categorieChapitresTelecharges = String(
            localized: "stockage.categorie.chapitresTelecharges"
        )
        static let categorieCacheDeChapitres = String(
            localized: "stockage.categorie.cacheDeChapitres"
        )
        static let categorieCacheDImages = String(localized: "stockage.categorie.cacheDImages")

        /// Titre du poste qui regroupe les elements que rien ne nomme.
        static let anonymesChapitresTelecharges = String(
            localized: "stockage.anonymes.chapitresTelecharges"
        )
        static let anonymesCacheDeChapitres = String(
            localized: "stockage.anonymes.cacheDeChapitres"
        )
        static let anonymesCacheDImages = String(localized: "stockage.anonymes.cacheDImages")
    }

    /// Etats d erreur, tableau 6.4.
    enum Erreur {
        static let reessayer = String(localized: "erreur.reessayer")
        static let ficheDeSerieTitre = String(localized: "erreur.ficheDeSerie.titre")
        static let ficheDeSeriePhrase = String(localized: "erreur.ficheDeSerie.phrase")
        static let historiqueTitre = String(localized: "erreur.historique.titre")
        static let historiquePhrase = String(localized: "erreur.historique.phrase")
        static let historiqueRepartirDeZero = String(
            localized: "erreur.historique.repartirDeZero"
        )
    }

    /// Etats vides, tableau 6.3.
    enum EtatVide {
        static let bibliothequeTitre = String(localized: "etatVide.bibliotheque.titre")
        static let bibliothequePhrase = String(localized: "etatVide.bibliotheque.phrase")
        static let bibliothequeAction = String(localized: "etatVide.bibliotheque.action")

        static let historiqueTitre = String(localized: "etatVide.historique.titre")
        static let historiquePhrase = String(localized: "etatVide.historique.phrase")
        static let historiqueAction = String(localized: "etatVide.historique.action")

        static let parcourirTitre = String(localized: "etatVide.parcourir.titre")
        static let parcourirPhrase = String(localized: "etatVide.parcourir.phrase")

        static let rechercherTitre = String(localized: "etatVide.rechercher.titre")
        static let rechercherPhrase = String(localized: "etatVide.rechercher.phrase")

        static let ficheDeSerieTitre = String(localized: "etatVide.ficheDeSerie.titre")
        static let ficheDeSeriePhrase = String(localized: "etatVide.ficheDeSerie.phrase")
        static let ficheDeSerieAction = String(localized: "etatVide.ficheDeSerie.action")
    }
}
