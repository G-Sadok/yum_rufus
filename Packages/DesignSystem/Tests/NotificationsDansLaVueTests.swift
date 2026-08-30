import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Textes des notifications de nouveaux chapitres, F060.
//
// Le deuxieme critere de la fonctionnalite se voit aussi dans le texte : une
// notification qui porte quatorze chapitres doit le dire en une phrase, sans
// quoi le regroupement fait par le domaine se perdrait au dernier metre.
//
// Le troisieme critere se lit ici par la negative. La notification ne cite ni
// progression, ni chapitres non lus, ni date de derniere lecture : ce qui
// s affiche sur un ecran verrouille se lit par dessus l epaule, et la section 11
// interdit d y poser une trace de lecture.
//

struct NotificationsDansLaVueTests {
    private let berserk = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()

    /// Libelles tels que le catalogue de l application les porte.
    private func libellesDuCatalogue() throws -> LibellesDeNotificationsDeChapitres {
        let catalogue = try CatalogueDeChaines.charger()

        return try LibellesDeNotificationsDeChapitres(
            unChapitre: #require(catalogue["notifications.chapitres.un"]),
            plusieursChapitres: #require(catalogue["notifications.chapitres.plusieurs"])
        )
    }

    /// Notification portant le nombre de chapitres demande.
    private func notification(chapitres: Int, dernierNumero: Double) -> NotificationDeSerie {
        let parus = (0..<chapitres).map { rang in
            NouveauChapitre(
                serie: berserk,
                titreDeLaSerie: "Berserk",
                source: SourceID(),
                identifiant: "c\(rang)",
                numero: rang == chapitres - 1 ? dernierNumero : Double(rang),
                ordre: rang
            )
        }

        return NotificationDeSerie(serie: berserk, titreDeLaSerie: "Berserk", chapitres: parus)
    }

    @Test("Le titre de la notification est celui de la serie")
    func titreDeLaSerie() {
        let notification = notification(chapitres: 3, dernierNumero: 12)

        #expect(TexteDeNotificationDeChapitres.titre(de: notification) == "Berserk")
    }

    @Test("Un seul chapitre paru se dit au singulier, avec son numero")
    func unSeulChapitre() throws {
        let corps = try TexteDeNotificationDeChapitres.corps(
            de: notification(chapitres: 1, dernierNumero: 375.5),
            libelles: libellesDuCatalogue()
        )

        #expect(corps.contains("375,5") || corps.contains("375.5"))
        #expect(corps.contains("Chapitre"))
    }

    @Test("Quatorze chapitres parus tiennent dans une seule phrase, qui les compte")
    func plusieursChapitres() throws {
        let corps = try TexteDeNotificationDeChapitres.corps(
            de: notification(chapitres: 14, dernierNumero: 42),
            libelles: libellesDuCatalogue()
        )

        #expect(corps.contains("14"))
        #expect(corps.contains("42"))
    }

    @Test("Aucun texte de notification ne parle de ce qui a ete lu")
    func aucuneTraceDeLecture() throws {
        let libelles = try libellesDuCatalogue()
        let textes = [
            libelles.unChapitre,
            libelles.plusieursChapitres,
            TexteDeNotificationDeChapitres.corps(
                de: notification(chapitres: 5, dernierNumero: 20),
                libelles: libelles
            ),
        ]

        // Les mots de la lecture, ceux que la section 11 interdit de poser sur
        // un ecran de verrouillage.
        let interdits = ["lu", "lus", "lue", "non lu", "progression", "reprendre", "page"]

        for texte in textes {
            let mots = texte.lowercased().split(whereSeparator: { $0.isLetter == false }).map(String.init)

            for interdit in interdits {
                #expect(mots.contains(interdit) == false, "\(texte) contient \(interdit)")
            }
        }
    }
}
