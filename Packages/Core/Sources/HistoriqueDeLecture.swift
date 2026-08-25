import Foundation

//
// HistoriqueDeLecture
//
// Ce que l ecran Historique de la section 5.2 de DESIGN-SPEC.md a besoin de
// savoir, et la seule regle qu il porte : le regroupement par jour.
//
// Le jour est celui du calendrier de l utilisateur, jamais celui du temps
// universel. Une lecture a 00 h 30 a Paris tombe encore la veille en temps
// universel : grouper sur la date brute ferait apparaitre deux en tetes la ou
// l utilisateur n a lu qu une fois, et deplacerait la frontiere de minuit d une
// a douze heures selon le fuseau.
//

/// Une lecture consignee, telle que la liste de la section 5.2 l affiche.
///
/// La couverture voyage sous forme de chemin et d adresse, jamais d image :
/// Core ne decode rien, et la vignette de 44 par 66 se decode a sa taille
/// d affichage comme toutes les images du produit.
public struct EntreeDHistorique: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant de l entree, cible de la suppression unitaire.
    public let id: UUID

    /// Chapitre lu, ouvert quand la ligne est activee.
    public let chapitreId: UUID

    /// Serie a laquelle le chapitre appartient.
    public let serieId: UUID

    /// Titre de la serie, premiere ligne de l entree.
    public let titreDeLaSerie: String

    /// Numero du chapitre, seconde ligne de l entree.
    public let numeroDeChapitre: Double

    /// Titre du chapitre, absent chez beaucoup de sources.
    public let titreDuChapitre: String?

    /// Instant de la lecture, qui donne le jour et l heure affiches.
    public let dateLecture: Date

    /// Couverture deja telechargee, quand elle existe.
    public let cheminCouvertureLocale: String?

    /// Adresse de la couverture chez la source.
    public let urlCouverture: String?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        serieId: UUID,
        titreDeLaSerie: String,
        numeroDeChapitre: Double,
        titreDuChapitre: String? = nil,
        dateLecture: Date,
        cheminCouvertureLocale: String? = nil,
        urlCouverture: String? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.serieId = serieId
        self.titreDeLaSerie = titreDeLaSerie
        self.numeroDeChapitre = numeroDeChapitre
        self.titreDuChapitre = titreDuChapitre
        self.dateLecture = dateLecture
        self.cheminCouvertureLocale = cheminCouvertureLocale
        self.urlCouverture = urlCouverture
    }
}

/// Un jour d historique et les lectures qu il contient.
///
/// C est une section de la liste : l en tete collant porte le jour, les lignes
/// portent les entrees.
public struct JourneeDHistorique: Sendable, Equatable, Identifiable {
    /// Minuit du jour, dans le calendrier employe pour le regroupement.
    public let debutDuJour: Date

    /// Lectures de ce jour, la plus recente en tete.
    public let entrees: [EntreeDHistorique]

    public init(debutDuJour: Date, entrees: [EntreeDHistorique]) {
        self.debutDuJour = debutDuJour
        self.entrees = entrees
    }

    public var id: Date {
        debutDuJour
    }
}

/// Regroupement des lectures par jour, section 5.2.
public enum RegroupementParJour {
    /// Groupe les entrees par jour civil, le jour le plus recent en tete.
    ///
    /// Le calendrier est un parametre et non une constante globale, pour deux
    /// raisons. Il porte le fuseau, qui decide ou tombe minuit. Et il rend la
    /// regle verifiable : un test peut poser un fuseau precis au lieu d esperer
    /// que celui de la machine de compilation lui convienne.
    ///
    /// - Parameters:
    ///   - entrees: lectures a grouper, dans n importe quel ordre.
    ///   - calendrier: calendrier de l utilisateur, fuseau compris.
    /// - Returns: les journees non vides, triees du plus recent au plus ancien.
    public static func grouper(
        _ entrees: [EntreeDHistorique],
        calendrier: Calendar = .autoupdatingCurrent
    ) -> [JourneeDHistorique] {
        let triees = entrees.sorted { premiere, seconde in
            if premiere.dateLecture == seconde.dateLecture {
                return premiere.id.uuidString > seconde.id.uuidString
            }

            return premiere.dateLecture > seconde.dateLecture
        }

        var journees: [JourneeDHistorique] = []
        var jourCourant: Date?
        var lecturesDuJour: [EntreeDHistorique] = []

        for entree in triees {
            let jour = calendrier.startOfDay(for: entree.dateLecture)

            if jour != jourCourant {
                if let jourCourant {
                    journees.append(
                        JourneeDHistorique(debutDuJour: jourCourant, entrees: lecturesDuJour)
                    )
                }

                jourCourant = jour
                lecturesDuJour = []
            }

            lecturesDuJour.append(entree)
        }

        if let jourCourant {
            journees.append(JourneeDHistorique(debutDuJour: jourCourant, entrees: lecturesDuJour))
        }

        return journees
    }
}
