import Foundation

//
// RappelDObjectif
//
// Le rappel facultatif de F059 : une notification, une par jour au plus, et
// jamais quand elle n aurait rien a dire.
//
// La planification est une fonction pure. Elle rend l instant du prochain
// rappel, ou rien du tout, et n appelle aucun service du systeme. C est ce qui
// la rend verifiable : les quatre cas ou le rappel ne part pas se testent sans
// centre de notifications, sans horloge et sans autorisation a demander.
//
// Le rappel se tait dans quatre cas, et chacun a sa raison.
//
// 1. Le rappel est eteint. C est le reglage lui meme.
// 2. Aucun objectif n est fixe. Rappeler un objectif qui n existe pas
//    n aurait pas de contenu.
// 3. Une session incognito court. La section 11 interdit toute trace de
//    lecture, et une notification qui parle du nombre de chapitres lus dans la
//    journee en est une, posee sur l ecran de verrouillage.
// 4. L objectif est deja atteint. Le rappel est une aide, pas un rappel a
//    l ordre : une fois la journee faite, il n a plus rien a dire et se reporte
//    au lendemain.
//

/// Reglage du rappel quotidien.
public struct RappelDObjectif: Sendable, Codable, Equatable, Hashable {
    /// Heure du rappel sur une installation neuve.
    ///
    /// Le document ne la fixe pas. Vingt heures est le seul moment de la
    /// journee ou la lecture du soir n a pas encore commence et ou la journee
    /// n est pas finie.
    public static let heureParDefaut = 20

    /// Minute du rappel sur une installation neuve.
    public static let minuteParDefaut = 0

    /// Rappel eteint, valeur livree.
    public static let eteint = RappelDObjectif(actif: false)

    /// Vrai quand le rappel est arme.
    public let actif: Bool

    /// Heure du rappel, de zero a vingt trois.
    public let heure: Int

    /// Minute du rappel, de zero a cinquante neuf.
    public let minute: Int

    public init(
        actif: Bool,
        heure: Int = RappelDObjectif.heureParDefaut,
        minute: Int = RappelDObjectif.minuteParDefaut
    ) {
        self.actif = actif
        self.heure = min(max(heure, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

/// Calcul de l instant du prochain rappel.
public enum PlanificationDuRappel {
    /// Instant du prochain rappel, nul quand aucun rappel ne doit partir.
    ///
    /// - Parameters:
    ///   - rappel: reglage du rappel.
    ///   - objectif: objectif en vigueur.
    ///   - chapitresLusAujourdHui: ce que la journee en cours a deja compte.
    ///   - session: etat du mode incognito, section 11.
    ///   - date: instant de reference.
    ///   - calendrier: calendrier de l utilisateur.
    public static func prochainRappel(
        rappel: RappelDObjectif,
        objectif: ObjectifQuotidien,
        chapitresLusAujourdHui: Int,
        session: SessionIncognito = .inactive,
        le date: Date,
        calendrier: Calendar = .autoupdatingCurrent
    ) -> Date? {
        guard rappel.actif, objectif.estActif, session.estActive == false else {
            return nil
        }

        guard let echeanceDuJour = echeance(rappel, le: date, calendrier: calendrier) else {
            return nil
        }

        let journeeFaite = objectif.estAtteint(chapitresLus: chapitresLusAujourdHui)

        if journeeFaite == false, echeanceDuJour > date {
            return echeanceDuJour
        }

        return calendrier.date(byAdding: .day, value: 1, to: echeanceDuJour)
    }

    /// Echeance du rappel dans la journee de la date donnee.
    private static func echeance(
        _ rappel: RappelDObjectif,
        le date: Date,
        calendrier: Calendar
    ) -> Date? {
        calendrier.date(
            bySettingHour: rappel.heure,
            minute: rappel.minute,
            second: 0,
            of: date,
            matchingPolicy: .nextTime
        )
    }
}
