import Core
import Foundation

//
// Textes du mur premium, sections 5.9, 6.4, 6.5 et 6.8 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
// sait lequel c est.
//
// La mention de prix est un motif et non une phrase figee. Le tableau 6.8 ecrit
// `Puis 3,99 euros par mois`, mais le tarif reel vient de la boutique, dans la
// devise du compte. Un prix recopie dans le catalogue serait faux des la premiere
// vente hors de la zone euro, et faux en justice avant de l etre a l ecran.
//

/// Textes du mur premium.
public struct LibellesDuMurPremium: Sendable, Equatable {
    /// Titre de la feuille, section 5.9.
    public let titre: String

    /// Sous titre pose sous le titre.
    public let sousTitre: String

    /// Libelles des cinq avantages, indexes par leur representation persistee.
    public let avantages: [String: String]

    /// Bouton principal quand l essai est encore ouvert, tableau 6.5.
    public let commencerLEssai: String

    /// Bouton principal quand l essai est ferme.
    public let sAbonner: String

    /// Motif de la mention de prix, tableau 6.8.
    public let mentionDePrix: String

    /// Commande qui referme la feuille, tableau 6.5.
    public let plusTard: String

    /// Commande de restauration, obligatoire sur le mur.
    ///
    /// Le libelle est celui de la ligne de reglages qui fait la meme chose. Le
    /// meme mot pour la meme action d un bout a l autre du parcours.
    public let restaurerLesAchats: String

    /// Titre de l etat d erreur, tableau 6.4.
    public let erreurTitre: String

    /// Phrase de l etat d erreur, tableau 6.4.
    public let erreurPhrase: String

    /// Bouton Reessayer de l etat d erreur, tableau 6.5.
    public let reessayer: String

    /// Etiquette d accessibilite de la couronne, qui n a pas de libelle visible.
    public let etiquetteDeLaCouronne: String

    public init(
        titre: String,
        sousTitre: String,
        avantages: [String: String],
        commencerLEssai: String,
        sAbonner: String,
        mentionDePrix: String,
        plusTard: String,
        restaurerLesAchats: String,
        erreurTitre: String,
        erreurPhrase: String,
        reessayer: String,
        etiquetteDeLaCouronne: String
    ) {
        self.titre = titre
        self.sousTitre = sousTitre
        self.avantages = avantages
        self.commencerLEssai = commencerLEssai
        self.sAbonner = sAbonner
        self.mentionDePrix = mentionDePrix
        self.plusTard = plusTard
        self.restaurerLesAchats = restaurerLesAchats
        self.erreurTitre = erreurTitre
        self.erreurPhrase = erreurPhrase
        self.reessayer = reessayer
        self.etiquetteDeLaCouronne = etiquetteDeLaCouronne
    }

    /// Libelle d un avantage.
    ///
    /// Un avantage sans libelle retombe sur sa representation persistee. Le cas
    /// signale un trou dans le catalogue, et la suite de tests le detecte avant
    /// qu il n arrive a l ecran.
    public func libelle(de avantage: AvantagePremium) -> String {
        avantages[avantage.rawValue] ?? avantage.rawValue
    }
}

/// Une commande offerte par la feuille du mur premium.
public enum CommandeDuMurPremium: String, Sendable, CaseIterable, Hashable, Identifiable {
    /// Achat du produit mis en avant.
    case acheter

    /// Restauration des achats deja faits, obligatoire sur le mur.
    case restaurer

    /// Sortie sans achat.
    case plusTard

    /// Nouvelle tentative de lecture des tarifs, apres un echec.
    case reessayer

    public var id: String {
        rawValue
    }
}

/// Assemblage des textes du mur premium.
public enum TexteDuMurPremium {
    /// Libelle du bouton principal, selon que l essai est ouvert ou non.
    ///
    /// Le bouton ne promet sept jours qu a qui peut encore les prendre. La
    /// section 5.9 interdit toute formulation qui presse, et une offre annoncee
    /// puis refusee par la feuille de paiement en est une.
    public static func boutonPrincipal(
        pour offre: OffrePremium,
        libelles: LibellesDuMurPremium
    ) -> String {
        offre.essaiDisponible ? libelles.commencerLEssai : libelles.sAbonner
    }

    /// Mention de prix, avec le tarif rendu par la boutique.
    public static func mentionDePrix(
        pour offre: OffrePremium,
        libelles: LibellesDuMurPremium
    ) -> String {
        String(format: libelles.mentionDePrix, offre.produit.prixAffiche)
    }

    /// Commandes offertes par la feuille dans un etat donne.
    ///
    /// La liste est celle que la feuille rend, et non une description posee a
    /// cote : les boutons de pied et les capsules d erreur sont construits en la
    /// parcourant. Elle ne peut donc pas mentir sur ce que l ecran offre, ce qui
    /// vaut surtout pour la restauration, obligatoire depuis le mur.
    public static func commandes(dans etat: EtatDuMurPremium) -> [CommandeDuMurPremium] {
        switch etat {
        case .chargement: []
        case .chargee: [.acheter, .restaurer, .plusTard]
        case .erreur: [.plusTard, .reessayer]
        }
    }

    /// Commandes posees en pied de feuille, celles qui ne sont pas l achat.
    public static func commandesDePied(dans etat: EtatDuMurPremium) -> [CommandeDuMurPremium] {
        commandes(dans: etat).filter { $0 != .acheter }
    }

    /// Libelle d une commande de pied.
    ///
    /// L achat n en fait pas partie : son libelle depend de l offre, et il est
    /// compose par `boutonPrincipal`.
    public static func libelle(
        de commande: CommandeDuMurPremium,
        libelles: LibellesDuMurPremium
    ) -> String {
        switch commande {
        case .acheter: libelles.sAbonner
        case .restaurer: libelles.restaurerLesAchats
        case .plusTard: libelles.plusTard
        case .reessayer: libelles.reessayer
        }
    }

    /// Etiquette lue par VoiceOver pour une ligne d avantage.
    ///
    /// La coche n est pas lue : elle ne porte aucune information que la ligne ne
    /// dise deja, et la section 7 interdit de transmettre une information par la
    /// seule presence d un glyphe.
    public static func etiquette(
        de avantage: AvantagePremium,
        libelles: LibellesDuMurPremium
    ) -> String {
        libelles.libelle(de: avantage)
    }
}
