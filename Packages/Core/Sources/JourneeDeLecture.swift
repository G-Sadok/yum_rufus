import Foundation

//
// JourneeDeLecture
//
// Ce qu une journee civile a compte, une ligne par jour.
//
// Le comptage est denormalise, pour la meme raison que le compteur de non lus
// de la section 3.2 : l ecran de statistiques et la serie de jours consecutifs
// se lisent d un coup, sans agreger l historique a chaque affichage. Une base
// de deux ans de lecture donne sept cent trente lignes, pas des centaines de
// milliers d evenements.
//
// La cle est le debut du jour civil du calendrier de l utilisateur. Un fuseau
// change donc ou tombe la coupure, ce qui est le comportement attendu : la
// journee de lecture est celle que l utilisateur vit, pas celle d un serveur.
//

/// Ce qu une journee a compte.
public struct JourneeDeLecture: Sendable, Codable, Equatable, Hashable, Identifiable {
    /// Debut du jour civil, cle de la journee.
    public let jour: Date

    /// Chapitres passes a l etat lu pendant la journee.
    public let chapitresLus: Int

    /// Pages nouvelles parcourues pendant la journee.
    public let pagesLues: Int

    public var id: Date {
        jour
    }

    public init(jour: Date, chapitresLus: Int = 0, pagesLues: Int = 0) {
        self.jour = jour
        self.chapitresLus = max(chapitresLus, 0)
        self.pagesLues = max(pagesLues, 0)
    }

    /// Vrai quand quelque chose a ete lu ce jour la.
    public var porteUneLecture: Bool {
        chapitresLus > 0 || pagesLues > 0
    }

    /// Journee vide, pour un jour que la base ne connait pas.
    public static func vide(le jour: Date) -> JourneeDeLecture {
        JourneeDeLecture(jour: jour)
    }
}

/// Ce que l ecran de statistiques montre, deja calcule.
///
/// La structure est un instantane : elle est batie une fois a partir des
/// journees lues en base, puis relue autant de fois que la vue en a besoin.
/// Rien n y est recalcule pendant le defilement.
public struct StatistiquesDeLecture: Sendable, Equatable {
    /// Journees connues, de la plus ancienne a la plus recente.
    public let journees: [JourneeDeLecture]

    /// Objectif en vigueur, qui decide de ce qui compte dans la serie.
    public let objectif: ObjectifQuotidien

    /// Debut du jour ou l ecran est ouvert.
    public let aujourdHui: Date

    private let calendrier: Calendar
    private let parJour: [Date: JourneeDeLecture]

    /// Nombre de journees montrees par la carte des derniers jours.
    ///
    /// Une semaine. Le document ne chiffre pas ce sous ecran, et sept jours est
    /// la seule periode que l utilisateur compare sans effort a la sienne.
    public static let joursMontres = 7

    /// Assemble l instantane.
    ///
    /// - Parameters:
    ///   - journees: lignes lues en base, dans n importe quel ordre.
    ///   - objectif: objectif en vigueur.
    ///   - date: instant d ouverture de l ecran.
    ///   - calendrier: calendrier de l utilisateur, qui decide ou tombe minuit.
    public init(
        journees: [JourneeDeLecture],
        objectif: ObjectifQuotidien,
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) {
        let normalisees = journees
            .map { journee in
                JourneeDeLecture(
                    jour: calendrier.startOfDay(for: journee.jour),
                    chapitresLus: journee.chapitresLus,
                    pagesLues: journee.pagesLues
                )
            }
            .sorted { $0.jour < $1.jour }

        self.journees = normalisees
        self.objectif = objectif
        self.calendrier = calendrier
        aujourdHui = calendrier.startOfDay(for: date)
        parJour = Dictionary(normalisees.map { ($0.jour, $0) }, uniquingKeysWith: { _, seconde in seconde })
    }

    /// Journee demandee, vide quand la base ne la connait pas.
    public func journee(du jour: Date) -> JourneeDeLecture {
        let debut = calendrier.startOfDay(for: jour)
        return parJour[debut] ?? .vide(le: debut)
    }

    /// Journee en cours.
    public var journeeDuJour: JourneeDeLecture {
        journee(du: aujourdHui)
    }

    /// Longueur de la serie de jours consecutifs, section F059.
    public var serieDeJours: Int {
        SerieDeJoursConsecutifs.longueur(
            journees: journees,
            objectif: objectif,
            le: aujourdHui,
            calendrier: calendrier
        )
    }

    /// Les sept derniers jours, du plus ancien au jour en cours.
    ///
    /// Les jours sans lecture sont presents et valent zero. Les sauter ferait
    /// une carte a longueur variable, ou une semaine qui ne se lit plus de
    /// gauche a droite.
    public var derniersJours: [JourneeDeLecture] {
        let rangs = (0..<Self.joursMontres).reversed()

        return rangs.compactMap { recul in
            calendrier.date(byAdding: .day, value: -recul, to: aujourdHui).map(journee(du:))
        }
    }

    /// Total de chapitres lus depuis l installation.
    public var totalDeChapitres: Int {
        journees.reduce(0) { total, journee in total + journee.chapitresLus }
    }

    /// Total de pages parcourues depuis l installation.
    public var totalDePages: Int {
        journees.reduce(0) { total, journee in total + journee.pagesLues }
    }

    /// Nombre de journees qui portent au moins une lecture.
    public var joursDeLecture: Int {
        journees.reduce(0) { total, journee in total + (journee.porteUneLecture ? 1 : 0) }
    }

    /// Vrai quand rien n a jamais ete compte, ce qui donne l etat vide.
    public var estVide: Bool {
        joursDeLecture == 0
    }

    /// Plus grand nombre de chapitres lus dans une des journees montrees.
    ///
    /// Sert d echelle aux barres de la carte des derniers jours. Une semaine
    /// sans lecture rend un, pour qu aucune barre ne divise par zero.
    public var maximumDesDerniersJours: Int {
        max(derniersJours.map(\.chapitresLus).max() ?? 0, 1)
    }
}
