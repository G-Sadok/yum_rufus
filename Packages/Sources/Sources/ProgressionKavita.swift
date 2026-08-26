import Core
import Foundation

//
// ProgressionKavita
//
// La moitie distante de la progression de lecture chez Kavita.
//
// Le fichier de Komga tournait autour d un ecart d une unite, celui ci tourne
// autour d une absence. Kavita indexe ses pages a partir de zero, comme le
// modele : il n y a donc rien a convertir, et cette absence de conversion est le
// point le plus fragile du fichier. Recopier la conversion de Komga par
// symetrie decalerait chaque reprise d une page, sans que rien ne le signale a
// la relecture.
//
// Ce qui remplace le decalage, c est le marquage. Kavita ne publie aucun
// drapeau de lecture par chapitre : il compare le nombre de pages lues au total
// du chapitre. Un chapitre lu s envoie donc a son nombre de pages, et non a
// l index de sa derniere page, sans quoi il resterait a une page de la fin pour
// toujours.
//

extension SourceKavita: SourceAProgressionDistante {
    public func progression(pour chapitre: String) async throws -> ProgressionDistante? {
        let repere = try await repere(deChapitre: chapitre)

        do {
            let lue = try await client().lire(
                ProgressionDeKavita.self,
                chemin: CheminsKavita.progressionLue,
                parametres: ParametresKavita.chapitre(repere.chapitre)
            )

            return lue.progressionDistante(chapitre: chapitre, nombreDePages: repere.nombreDePages)
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }

    public func publier(_ progression: ProgressionDistante) async throws {
        try exiger(.progressionDistante)

        let repere = try await repere(deChapitre: progression.identifiantChapitre)

        try await envoyer(
            ChargeDeProgressionKavita(progression, repere: repere),
            pour: progression.identifiantChapitre
        )
    }

    public func effacerLaProgression(pour chapitre: String) async throws {
        try exiger(.progressionDistante)

        let repere = try await repere(deChapitre: chapitre)

        try await envoyer(ChargeDeProgressionKavita(remiseAZero: repere), pour: chapitre)
    }

    /// Envoie une charge de progression et nomme le chapitre en cas d absence.
    private func envoyer(_ charge: ChargeDeProgressionKavita, pour chapitre: String) async throws {
        do {
            try await client().envoyer(
                chemin: CheminsKavita.progressionPubliee,
                methode: .post,
                corpsJson: JSONEncoder().encode(charge)
            )
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }
}
