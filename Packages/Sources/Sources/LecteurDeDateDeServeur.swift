import Foundation

//
// LecteurDeDateDeServeur
//
// Les quatre formes de date que les serveurs auto heberges emploient, lues par
// un seul lecteur.
//
// Le lecteur est arrive avec Komga et portait son nom. Kavita emploie
// exactement les memes formes, parce que les deux serialisent des dates ISO
// 8601 depuis leur pile respective, et un second lecteur nomme d apres le
// second serveur aurait diverge du premier au premier champ inhabituel. Le nom
// dit donc ce que le type sait faire, pas de quel serveur il vient.
//
// Les formes sont essayees dans l ordre, de la plus precise a la plus courte.
// L ordre compte : le motif de la date seule accepterait le debut d un instant
// complet et rendrait minuit, ce qui decalerait toutes les dates de lecture.
//

/// Lecture des dates rendues par un serveur de contenu.
enum LecteurDeDateDeServeur {
    /// La date lue, ou nul quand la chaine est absente ou d une autre forme.
    static func lire(_ texte: String?) -> Date? {
        guard let texte = texte?.trimmingCharacters(in: .whitespacesAndNewlines), texte.isEmpty == false else {
            return nil
        }
        if let avecFraction = lecteurAvecFraction.date(from: texte) {
            return avecFraction
        }
        if let sansFraction = lecteurSansFraction.date(from: texte) {
            return sansFraction
        }
        if let sansFuseau = lecteurSansFuseau.date(from: texte) {
            return sansFuseau
        }

        return lecteurDeJour.date(from: texte)
    }

    /// Lecteurs des instants avec fuseau, avec puis sans fraction de seconde.
    ///
    /// Ils sont ecrits en `DateFormatter` et non en `ISO8601DateFormatter`, qui
    /// serait plus court : ce dernier n est pas `Sendable`, et une instance
    /// partagee entre plusieurs taches ne compile pas en concurrence stricte.
    /// Le motif `XXXXX` accepte les deux ecritures du fuseau, `Z` et `+01:00`.
    private static let lecteurAvecFraction = formateur("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")

    private static let lecteurSansFraction = formateur("yyyy-MM-dd'T'HH:mm:ssXXXXX")

    /// Lecteur des instants sans fuseau, que les serveurs rendent pour leurs
    /// propres horodatages.
    ///
    /// Le fuseau est fixe a GMT parce que le serveur publie ces instants en
    /// temps universel sans le dire. Laisser le fuseau de l appareil decider
    /// decalerait la date affichee de plusieurs heures selon le voyage.
    private static let lecteurSansFuseau = formateur("yyyy-MM-dd'T'HH:mm:ss")

    private static let lecteurDeJour = formateur("yyyy-MM-dd")

    private static func formateur(_ format: String) -> DateFormatter {
        let lecteur = DateFormatter()
        lecteur.locale = Locale(identifier: "en_US_POSIX")
        lecteur.timeZone = TimeZone(secondsFromGMT: 0)
        lecteur.dateFormat = format

        return lecteur
    }
}
