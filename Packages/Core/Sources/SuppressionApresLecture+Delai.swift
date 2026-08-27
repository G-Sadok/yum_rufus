import Foundation

//
// Suppression automatique des telechargements lus
//
// La regle qui decide, et elle seule. Ni disque, ni base, ni horloge implicite :
// la liste des chapitres lus entre, la liste des chapitres a supprimer sort.
//
// Le delai vit ici plutot que dans l appelant parce que le tableau 6.7 fixe
// quatre valeurs et qu un seul endroit doit savoir ce qu elles veulent dire.
// Deux couches qui le traduiraient chacune de leur cote finiraient par ne pas
// supprimer au meme moment, et une suppression qui part trop tot est une perte
// de donnees, pas un ecart de style.
//
// Un chapitre lu dont la date de lecture est inconnue n est jamais supprime par
// un reglage a delai. La base ne remplit `dateLecture` que depuis le marquage au
// passage ; un chapitre marque lu autrement, par une restauration ou par une
// synchronisation, arrive sans date. Le supprimer reviendrait a traiter une date
// absente comme une date tres ancienne, donc a effacer immediatement ce que
// l utilisateur a demande de garder sept jours. `Immediatement` fait exception,
// puisque son delai est nul et qu aucune date ne pourrait le repousser.
//

extension SuppressionApresLecture {
    /// Delai entre la lecture et la suppression, nul quand rien ne part.
    ///
    /// Les durees sont comptees en secondes de calendrier grossieres, un jour
    /// valant vingt quatre heures. La precision suffit : le reglage promet de
    /// liberer de la place apres un jour ou apres une semaine, pas a la seconde
    /// pres, et un calcul de calendrier ferait dependre la suppression du fuseau
    /// horaire de l appareil.
    public var delaiApresLecture: TimeInterval? {
        switch self {
        case .jamais: nil
        case .immediatement: 0
        case .apres1Jour: Self.secondesParJour
        case .apres7Jours: 7 * Self.secondesParJour
        }
    }

    /// Vrai quand le reglage supprime quelque chose.
    public var supprimeLesTelechargementsLus: Bool {
        delaiApresLecture != nil
    }

    /// Nombre de secondes dans un jour.
    static let secondesParJour: TimeInterval = 24 * 60 * 60
}

/// Un chapitre lu dont le telechargement est encore pose sur le disque.
public struct TelechargementLu: Sendable, Equatable, Hashable {
    /// Chapitre vise.
    public let chapitreId: UUID

    /// Instant de la lecture, nul quand la base ne le connait pas.
    public let dateLecture: Date?

    public init(chapitreId: UUID, dateLecture: Date?) {
        self.chapitreId = chapitreId
        self.dateLecture = dateLecture
    }
}

/// Decision de la suppression automatique des telechargements lus.
public enum SuppressionAutomatiqueDesTelechargements {
    /// Chapitres que le reglage autorise a supprimer a cet instant.
    ///
    /// - Parameters:
    ///   - lus: chapitres lus dont le telechargement est sur le disque.
    ///   - reglage: valeur de la ligne Supprimer apres lecture, tableau 6.7.
    ///   - maintenant: instant de reference, injecte pour que la suite de tests
    ///     porte sur des delais choisis et non sur l horloge de la machine.
    /// - Returns: les chapitres a supprimer, dans l ordre recu.
    public static func chapitresASupprimer(
        parmi lus: [TelechargementLu],
        reglage: SuppressionApresLecture,
        maintenant: Date
    ) -> [UUID] {
        guard let delai = reglage.delaiApresLecture else {
            return []
        }

        return lus
            .filter { estEchu($0, delai: delai, maintenant: maintenant) }
            .map(\.chapitreId)
    }

    /// Vrai quand le delai est ecoule depuis la lecture de ce chapitre.
    private static func estEchu(_ lu: TelechargementLu, delai: TimeInterval, maintenant: Date) -> Bool {
        guard delai > 0 else {
            return true
        }

        guard let date = lu.dateLecture else {
            return false
        }

        return date.addingTimeInterval(delai) <= maintenant
    }
}
