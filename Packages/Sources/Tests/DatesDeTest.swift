import Foundation

//
// DatesDeTest
//
// Fabrique des instants attendus par les tests, en temps universel.
//
// Les dates sont construites par composants et non lues depuis une chaine : un
// test qui relirait la chaine avec le meme lecteur que le code teste ne
// prouverait rien d autre que la coherence du lecteur avec lui meme.
//

/// Une heure de la journee, pour ne pas aligner six nombres a la suite.
struct HeureDeTest {
    let heures: Int
    let minutes: Int
    let secondes: Int

    init(_ heures: Int, _ minutes: Int, _ secondes: Int = 0) {
        self.heures = heures
        self.minutes = minutes
        self.secondes = secondes
    }
}

/// Les instants de reference des tests, tous en temps universel.
enum DatesDeTest {
    /// Un jour a minuit.
    static func jour(_ annee: Int, _ mois: Int, _ jour: Int) -> Date? {
        instant(annee, mois, jour, HeureDeTest(0, 0))
    }

    /// Un instant a la seconde pres.
    static func instant(_ annee: Int, _ mois: Int, _ jour: Int, _ heure: HeureDeTest) -> Date? {
        var composants = DateComponents()
        composants.year = annee
        composants.month = mois
        composants.day = jour
        composants.hour = heure.heures
        composants.minute = heure.minutes
        composants.second = heure.secondes

        return calendrier.date(from: composants)
    }

    /// Calendrier gregorien en temps universel.
    ///
    /// Le fuseau est fixe : sans lui, la meme suite de tests donnerait des
    /// instants differents selon le reglage de la machine qui la lance.
    private static let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        return calendrier
    }()
}
