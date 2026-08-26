import Core
import Foundation

//
// LectureDExtension
//
// Les deux traductions que l interprete applique aux valeurs brutes d un
// catalogue : le mot qui designe un statut editorial, et le texte qui designe
// une date.
//
// Les deux echouent vers l inconnu plutot que vers une valeur plausible. Un
// statut devine se propage jusqu aux filtres de la bibliotheque, et un chapitre
// date d aujourd hui par erreur remonte en tete des nouveautes. Dans les deux
// cas, l absence se voit et se corrige, la valeur fausse ne se voit pas.
//

// MARK: - Statut

extension StatutSerie {
    /// Le statut que designe un mot publie par un catalogue.
    ///
    /// La correspondance couvre le francais et l anglais, les deux langues dans
    /// lesquelles les catalogues publient ce champ. Un mot inconnu rend
    /// `inconnu` plutot que d etre devine : un statut faux se propage jusqu aux
    /// filtres de la bibliotheque.
    static func depuisUneExtension(_ mot: String?) -> StatutSerie {
        guard let mot = mot?.lowercased() else {
            return .inconnu
        }

        return correspondancesDeStatut.first { mot.contains($0.mot) }?.statut ?? .inconnu
    }
}

/// Les mots reconnus, du plus specifique au plus general.
///
/// L ordre compte : `en pause` contient `en`, et une table dont l ordre
/// changerait ferait basculer un statut d une valeur a l autre.
private let correspondancesDeStatut: [(mot: String, statut: StatutSerie)] = [
    ("abandonne", .abandonne),
    ("cancelled", .abandonne),
    ("canceled", .abandonne),
    ("dropped", .abandonne),
    ("en pause", .enPause),
    ("hiatus", .enPause),
    ("paused", .enPause),
    ("termine", .termine),
    ("completed", .termine),
    ("finished", .termine),
    ("ended", .termine),
    ("en cours", .enCours),
    ("ongoing", .enCours),
    ("releasing", .enCours),
    ("publishing", .enCours),
]

// MARK: - Dates

/// Lecture des dates publiees par un catalogue.
struct LecteurDeDateDExtension: Sendable {
    private let format: String?

    init(format: String?) {
        self.format = format
    }

    /// Lit une date, ou rend nul quand le texte n en decrit pas une.
    ///
    /// Sans format declare, la lecture suit ISO 8601, avec et sans heure. Une
    /// date illisible rend nul plutot que la date du jour : un chapitre date
    /// d aujourd hui par erreur remonterait en tete de la liste des nouveautes.
    func lire(_ texte: String?) -> Date? {
        guard let texte, texte.isEmpty == false else {
            return nil
        }
        guard let format else {
            // Les secondes fractionnaires sont essayees en premier : la
            // strategie sans fraction refuse une date qui en porte, alors que
            // l inverse n est pas vrai.
            if let avecFraction = try? Date(texte, strategy: Self.iso8601AvecFraction) {
                return avecFraction
            }

            return try? Date(texte, strategy: Self.iso8601)
        }

        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.timeZone = TimeZone(secondsFromGMT: 0)
        formateur.dateFormat = format

        return formateur.date(from: texte)
    }

    // Les deux formats sont des valeurs et non des `ISO8601DateFormatter`.
    // Ce dernier est une classe, donc un etat mutable partage des qu il est
    // range dans une propriete statique, ce que Swift 6 refuse a juste titre :
    // l interprete lit des dates depuis plusieurs sources en parallele.
    private static let iso8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let iso8601AvecFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
