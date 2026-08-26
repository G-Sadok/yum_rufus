import Core
import Foundation

//
// ProgressionKomga
//
// La moitie distante de la progression de lecture : ce que le serveur sait, et
// ce que l application lui apprend.
//
// Tout le fichier tourne autour d un ecart d une unite. Komga compte ses pages
// a partir de un, le modele a partir de zero. La conversion se fait ici, aux
// deux extremites du meme aller retour, et nulle part ailleurs. Une seule des
// deux conversions oubliee deplacerait la reprise d une page a chaque chapitre,
// ce qui ne se voit pas a la relecture du code et se voit a chaque ouverture.
//

extension SourceKomga: SourceAProgressionDistante {
    public func progression(pour chapitre: String) async throws -> ProgressionDistante? {
        do {
            let livre = try await client().lire(LivreDeKomga.self, chemin: Self.cheminDuLivre(chapitre))

            return livre.progressionDistante(nombreDePages: livre.media?.pagesCount ?? 0)
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }

    public func publier(_ progression: ProgressionDistante) async throws {
        try exiger(.progressionDistante)

        do {
            let charge = try JSONEncoder().encode(ChargeDeProgressionKomga(progression))

            try await client().envoyer(
                chemin: Self.cheminDeProgression(progression.identifiantChapitre),
                methode: .patch,
                corpsJson: charge
            )
        } catch {
            throw traduire(
                error,
                siIntrouvable: .chapitreIntrouvable(identifiant: progression.identifiantChapitre)
            )
        }
    }

    public func effacerLaProgression(pour chapitre: String) async throws {
        try exiger(.progressionDistante)

        do {
            try await client().envoyer(chemin: Self.cheminDeProgression(chapitre), methode: .delete)
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }
}

/// Ce que la source envoie a Komga pour publier une progression.
///
/// Les deux champs sont optionnels et l encodage omet ceux qui manquent, ce qui
/// est exactement ce que le serveur attend : une charge sans `page` marque le
/// livre lu de bout en bout, une charge avec `page` deplace le signet sans
/// toucher au marquage.
struct ChargeDeProgressionKomga: Encodable, Sendable {
    let page: Int?
    let completed: Bool?

    init(_ progression: ProgressionDistante) {
        guard progression.estLu == false else {
            // Un chapitre lu n envoie aucune page. Komga refuse par un 400 une
            // page superieure au nombre de pages du livre, et le seul moment ou
            // ce nombre est incertain est justement celui ou le chapitre vient
            // d etre marque lu depuis la liste, sans avoir ete ouvert.
            page = nil
            completed = true

            return
        }

        page = Self.pageDeKomga(progression)
        completed = false
    }

    /// La page a envoyer, comptee a partir de un et bornee au chapitre.
    private static func pageDeKomga(_ progression: ProgressionDistante) -> Int {
        let page = progression.pageAtteinte + 1

        guard progression.nombreDePages > 0 else {
            return page
        }

        return min(page, progression.nombreDePages)
    }
}
