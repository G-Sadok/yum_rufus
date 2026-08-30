import Foundation

//
// SerieDeJoursConsecutifs
//
// La serie de jours de lecture de F059.
//
// Deux decisions gouvernent ce calcul, et toutes deux viennent du critere
// d ecriture de la fonctionnalite : aucune formulation culpabilisante.
//
// La premiere est le sort de la journee en cours. Une serie qui se remettrait a
// zero a minuit annoncerait zero a une personne qui n a simplement pas encore
// ouvert l application ce matin la. La serie se termine donc au jour en cours
// quand il compte deja, et a la veille sinon. Une journee entamee prolonge la
// serie, une journee pas encore commencee ne la casse pas.
//
// La seconde est ce qui fait compter une journee. La regle vit dans
// `ObjectifQuotidien.journeeComptee`, une seule fois : sans objectif un chapitre
// suffit, avec objectif il faut l atteindre. Le calcul ci dessous ne la
// redefinit pas, il la consulte.
//

/// Longueur de la serie de jours de lecture consecutifs.
public enum SerieDeJoursConsecutifs {
    /// Nombre de jours consecutifs qui comptent, en remontant depuis le jour en
    /// cours.
    ///
    /// - Parameters:
    ///   - journees: journees connues, dans n importe quel ordre.
    ///   - objectif: objectif en vigueur, qui decide de ce qui compte.
    ///   - date: instant de reference, ordinairement maintenant.
    ///   - calendrier: calendrier de l utilisateur.
    /// - Returns: la longueur de la serie, zero quand ni le jour en cours ni la
    ///   veille ne comptent.
    public static func longueur(
        journees: [JourneeDeLecture],
        objectif: ObjectifQuotidien,
        le date: Date,
        calendrier: Calendar = .autoupdatingCurrent
    ) -> Int {
        let comptees = joursComptes(journees: journees, objectif: objectif, calendrier: calendrier)

        guard let depart = departDeLaSerie(comptees, le: date, calendrier: calendrier) else {
            return 0
        }

        var jour = depart
        var longueur = 0

        while comptees.contains(jour) {
            longueur += 1

            guard let veille = calendrier.date(byAdding: .day, value: -1, to: jour) else {
                break
            }

            jour = veille
        }

        return longueur
    }

    /// Jours qui comptent, ramenes au debut de leur jour civil.
    private static func joursComptes(
        journees: [JourneeDeLecture],
        objectif: ObjectifQuotidien,
        calendrier: Calendar
    ) -> Set<Date> {
        var comptes: Set<Date> = []

        for journee in journees where objectif.journeeComptee(chapitresLus: journee.chapitresLus) {
            comptes.insert(calendrier.startOfDay(for: journee.jour))
        }

        return comptes
    }

    /// Jour ou la remontee commence.
    ///
    /// Le jour en cours quand il compte deja, la veille sinon. Rendre nul
    /// signifie que la serie est a zero.
    private static func departDeLaSerie(
        _ comptees: Set<Date>,
        le date: Date,
        calendrier: Calendar
    ) -> Date? {
        let aujourdHui = calendrier.startOfDay(for: date)

        if comptees.contains(aujourdHui) {
            return aujourdHui
        }

        guard let hier = calendrier.date(byAdding: .day, value: -1, to: aujourdHui),
              comptees.contains(hier)
        else {
            return nil
        }

        return hier
    }
}
