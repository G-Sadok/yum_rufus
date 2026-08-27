import Foundation

//
// Libelles de l abonnement, sortis du catalogue principal.
//
// `Chaines.swift` porte les libelles de toute l application et grossit a chaque
// fonctionnalite livree. Il a franchi la longueur de fichier que l analyse
// statique accepte avec l arrivee de la banniere de reactivation, ce qui est le
// bon moment pour le decouper plutot que pour elargir la regle.
//
// Le decoupage suit le produit et non l alphabet : tout ce qui parle de
// l abonnement vit ici, le bloc de la barre laterale, le mur, et la banniere de
// degradation de la section 10. Les trois se lisent ensemble et se relisent
// ensemble le jour ou le modele economique change.
//

extension Chaines {
    /// Bloc d appel a l abonnement, tableau 6.1.
    enum Premium {
        static let titre = String(localized: "premium.titre")
        static let sousTitre = String(localized: "premium.sousTitre")
    }

    /// Mur premium, section 5.9 et tableaux 6.4, 6.5 et 6.8.
    ///
    /// Trois libelles sont empruntes plutot que reecrits. La restauration
    /// reprend le libelle de la ligne de reglages qui fait la meme chose,
    /// `Reessayer` celui de tout etat d erreur, et l etiquette de la couronne
    /// celle des reglages et du panneau de filtres. Le meme mot pour la meme
    /// action d un bout a l autre du parcours, regle d ecriture de la section 6.
    ///
    /// Un seul libelle ne vient pas du document, le bouton principal quand
    /// l essai est deja consomme. La section 6.5 ne dessine que le cas de
    /// l essai. Il suit les regles d ecriture de la section 6 : voix active, le
    /// bouton dit ce qui se passe.
    ///
    /// La mention de prix est un motif et non une phrase. Le tarif vient de la
    /// boutique, dans la devise du compte, et un prix ecrit dans le catalogue
    /// serait faux hors de la zone euro.
    enum MurPremium {
        static let titre = String(localized: "murPremium.titre")
        static let sousTitre = String(localized: "murPremium.sousTitre")
        static let commencerLEssai = String(localized: "murPremium.commencerLEssai")
        static let sAbonner = String(localized: "murPremium.sAbonner")
        static let mentionDePrix = String(localized: "murPremium.mentionDePrix")
        static let plusTard = String(localized: "murPremium.plusTard")
        static let restaurerLesAchats = String(
            localized: "reglages.ligne.abonnement.restaurerLesAchats"
        )
        static let reessayer = String(localized: "erreur.reessayer")
        static let couronne = String(localized: "reglages.couronne")
        static let erreurTitre = String(localized: "erreur.boutique.titre")
        static let erreurPhrase = String(localized: "erreur.boutique.phrase")

        /// Les cinq avantages, dans l ordre de la section 5.9.
        static let avantageTraductionEtColorisation = String(
            localized: "murPremium.avantage.traductionEtColorisation"
        )
        static let avantageServeurs = String(localized: "murPremium.avantage.serveurs")
        static let avantageSuivis = String(localized: "murPremium.avantage.suivis")
        static let avantageTelechargements = String(
            localized: "murPremium.avantage.telechargements"
        )
        static let avantageSauvegardeEtSynchronisation = String(
            localized: "murPremium.avantage.sauvegardeEtSynchronisation"
        )
    }

    /// Banniere de reactivation, regle de degradation de la section 10 du
    /// cahier de developpement.
    ///
    /// La section 6 ne dessine pas cette banniere, le cahier de developpement
    /// se contente d exiger qu elle explique comment reactiver. Les trois
    /// textes suivent donc les regles d ecriture de la section 6 : voix active,
    /// la phrase nomme la cause et donne la sortie, et elle nomme d abord ce
    /// qui n a pas bouge, parce que c est la premiere question que se pose
    /// quelqu un dont l abonnement vient de finir.
    ///
    /// Le bouton reprend le libelle de la ligne de reglages qui fait la meme
    /// chose, `Passer a Premium`. Le meme mot pour la meme action d un bout a
    /// l autre du parcours.
    enum BanniereDeReactivation {
        static let titre = String(localized: "banniere.reactivation.titre")
        static let apresExpiration = String(localized: "banniere.reactivation.apresExpiration")
        static let sansAbonnement = String(localized: "banniere.reactivation.sansAbonnement")
        static let passerAPremium = String(
            localized: "reglages.ligne.abonnement.passerAPremium"
        )
    }
}
