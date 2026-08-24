import Core
import XCTest

/// Erreur fictive, presente uniquement pour exercer le protocole.
private struct ErreurFactice: ErreurDomaine {
    let domaine: String
    let cause: String
    let sortie: String
}

final class ErreurDomaineTests: XCTestCase {
    func testMessageUtilisateurEnchaineLaCausePuisLaSortie() {
        let erreur = ErreurFactice(
            domaine: "Archive",
            cause: "L archive est illisible.",
            sortie: "Choisis un autre fichier."
        )

        XCTAssertEqual(
            erreur.messageUtilisateur,
            "L archive est illisible. Choisis un autre fichier."
        )
    }

    func testDescriptionEstPrefixeeParLeDomaine() {
        let erreur = ErreurFactice(
            domaine: "Storage",
            cause: "La base est verrouillee.",
            sortie: "Ferme les autres fenetres."
        )

        XCTAssertEqual(
            erreur.description,
            "[Storage] La base est verrouillee. Ferme les autres fenetres."
        )
    }

    func testUneErreurDeDomaineResteCapturableCommeErreur() {
        let erreur: any Error = ErreurFactice(
            domaine: "Sources",
            cause: "La source ne repond pas.",
            sortie: "Verifie l adresse du serveur."
        )

        XCTAssertTrue(erreur is any ErreurDomaine)
    }

    func testLeMarqueurDeDomaineNommeLePaquet() {
        XCTAssertEqual(DomaineCore.nom, "Core")
    }
}
