import Core
import Foundation
@testable import Sources

//
// PontDeTest
//
// Les doubles du pont navigateur : la reception qui ne range rien, et
// l ecriture des requetes que l extension enverrait.
//
// L ecoute simulee n est pas redefinie ici. `EcouteSimulee` porte deja
// l adresse du pair jusqu au traitement, et c est exactement ce dont les tests
// du pont ont besoin : une requete envoyee depuis une adresse choisie, sans
// jamais ouvrir de port. Un second double aurait diverge du premier au premier
// correctif.
//

/// Reception qui garde ce qu on lui donne, sans rien ranger.
actor ReceptionDuNavigateurSimulee: ReceptionDuNavigateur {
    /// Ce qui a ete recu, dans l ordre.
    private(set) var recus: [EnvoiDuNavigateur] = []

    /// Refus a lever au prochain appel, pour exercer le chemin d erreur.
    private var refusAOpposer: ErreurDuPont?

    func recevoir(_ envoi: EnvoiDuNavigateur) async throws {
        if let refusAOpposer {
            throw refusAOpposer
        }

        recus.append(envoi)
    }

    func opposer(_ refus: ErreurDuPont?) {
        refusAOpposer = refus
    }
}

/// Magasin de jeton qui refuse de repondre, comme un trousseau verrouille.
struct MagasinDeJetonEnPanne: MagasinDeJetonDuPont {
    func jeton() throws -> JetonDuPont? {
        throw ErreurDeTrousseau.donneeIllisible
    }

    func enregistrer(_ jeton: JetonDuPont) throws {
        throw ErreurDeTrousseau.donneeIllisible
    }

    func revoquer() throws {
        throw ErreurDeTrousseau.donneeIllisible
    }
}

/// Ecriture des requetes envoyees au pont pendant les tests.
enum RequeteDuPontDeTest {
    /// Adresse d une page de catalogue, telle qu une extension l enverrait.
    static let adresseDUnCatalogue = "https://catalogue.exemple.net/serie/4217"

    /// Une requete d envoi de serie.
    static func envoi(
        _ corps: String = corpsDUnEnvoi(),
        jeton: String? = nil,
        methode: String = "POST",
        chemin: String = CheminsDuPont.serie,
        typeDeContenu: String? = "application/json"
    ) -> Data {
        var tete = "\(methode) \(chemin) HTTP/1.1\r\nHost: 127.0.0.1:\(PontNavigateur.portParDefaut)\r\n"

        if let typeDeContenu {
            tete += "Content-Type: \(typeDeContenu)\r\n"
        }
        if let jeton {
            tete += "Authorization: Bearer \(jeton)\r\n"
        }

        tete += "Content-Length: \(corps.utf8.count)\r\n\r\n"

        return Data((tete + corps).utf8)
    }

    /// Le corps JSON d un envoi.
    static func corpsDUnEnvoi(
        adresse: String = adresseDUnCatalogue,
        titre: String = "Le Chant du Cygne"
    ) -> String {
        """
        {"adresse": "\(adresse)", "titre": "\(titre)"}
        """
    }
}

/// Le materiel commun aux suites du pont.
enum MaterielDuPont {
    /// Un jeton valable, ecrit en clair pour que les tests le presentent.
    static func jeton(_ motif: Character = "a") -> String {
        String(repeating: motif, count: JetonDuPont.nombreDeChiffres)
    }

    /// Les reglages d une installation ou le pont est actif.
    static var reglagesAvecPontActif: ReglagesDeLApplication {
        ReglagesDeLApplication([.activerLePontNavigateur: .booleen(true)])
    }
}
