import Core
import Foundation

//
// Libelles de la fiche de serie, tableaux 6.3, 6.4 et 6.5 de DESIGN-SPEC.md.
//
// Aucune chaine n est ecrite ici. Ce type transporte celles que l application a
// lues dans son catalogue, et sait laquelle correspond a quel etat. C est la
// seule chose que le paquet DesignSystem ajoute : le choix, pas le texte.
//

/// Libelles de la fiche de serie et de sa liste de chapitres.
public struct LibellesDeFicheDeSerie: Sendable, Equatable {
    /// Bouton principal, aucun chapitre lu.
    public let commencerLaLecture: String

    /// Bouton principal, lecture en cours. Motif `Reprendre ch. %@`.
    public let reprendreChapitre: String

    /// Bouton principal, tous les chapitres lus.
    public let toutEstLu: String

    /// Bouton principal, aucun chapitre expose par la source.
    public let aucunChapitre: String

    /// Action secondaire, ajout a la bibliotheque.
    public let dansMaListe: String

    /// Action secondaire, suivi de la serie.
    public let suivre: String

    /// Etiquette d accessibilite du bouton d options.
    public let options: String

    /// Bascule du resume, resume replie.
    public let afficherPlus: String

    /// Bascule du resume, resume deplie.
    public let afficherMoins: String

    /// Compteur de l en tete de liste. Motif `%lld chapitres`.
    public let compteurDeChapitres: String

    /// Action Filtrer de l en tete de liste.
    public let filtrer: String

    /// Action Trier de l en tete de liste.
    public let trier: String

    /// Action Tout marquer lu de l en tete de liste.
    public let toutMarquerLu: String

    /// Motifs des lignes de chapitre.
    public let chapitres: LibellesDeChapitre

    /// Libelles de la barre de selection multiple.
    public let selection: LibellesDeSelectionDeChapitres

    public init(
        commencerLaLecture: String,
        reprendreChapitre: String,
        toutEstLu: String,
        aucunChapitre: String,
        dansMaListe: String,
        suivre: String,
        options: String,
        afficherPlus: String,
        afficherMoins: String,
        compteurDeChapitres: String,
        filtrer: String,
        trier: String,
        toutMarquerLu: String,
        chapitres: LibellesDeChapitre,
        selection: LibellesDeSelectionDeChapitres
    ) {
        self.commencerLaLecture = commencerLaLecture
        self.reprendreChapitre = reprendreChapitre
        self.toutEstLu = toutEstLu
        self.aucunChapitre = aucunChapitre
        self.dansMaListe = dansMaListe
        self.suivre = suivre
        self.options = options
        self.afficherPlus = afficherPlus
        self.afficherMoins = afficherMoins
        self.compteurDeChapitres = compteurDeChapitres
        self.filtrer = filtrer
        self.trier = trier
        self.toutMarquerLu = toutMarquerLu
        self.chapitres = chapitres
        self.selection = selection
    }

    /// Libelle du bouton principal pour l etat de lecture donne.
    ///
    /// C est la traduction directe du tableau de la section 5.6 : un cas de
    /// `ActionPrincipaleDeFiche` donne un libelle et un seul.
    public func libelleDuBoutonPrincipal(_ action: ActionPrincipaleDeFiche) -> String {
        switch action {
        case .commencerLaLecture:
            commencerLaLecture

        case let .reprendre(_, numero):
            String(format: reprendreChapitre, TexteDeChapitre.numero(numero))

        case .toutEstLu:
            toutEstLu

        case .aucunChapitre:
            aucunChapitre
        }
    }

    /// Libelle de la bascule du resume.
    public func libelleDeLaBascule(resumeDeplie: Bool) -> String {
        resumeDeplie ? afficherMoins : afficherPlus
    }
}
