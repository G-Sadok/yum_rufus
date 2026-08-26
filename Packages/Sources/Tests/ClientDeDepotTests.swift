import Core
import CryptoKit
import Foundation
import Testing
@testable import Sources

/// Couvre le depot d extensions du tableau 4.2 et la regle qui lui est propre :
/// un paquet ne se telecharge que depuis l hote de son depot.
///
/// Sans cette regle, un depot pourrait publier une entree dont l adresse de
/// paquet pointe ailleurs, et l utilisateur qui ajoute un depot de confiance se
/// retrouverait a interroger un tiers. La signature protege du contenu, pas de
/// la fuite de la requete elle meme.
struct ClientDeDepotTests {
    private static let adresseDuDepot = "https://depot.exemple.net/index.json"

    @Test("Le catalogue d un depot se lit et ecarte les entrees inutilisables")
    func lectureDuCatalogue() async throws {
        let client = ClientDeDepot(transport: TransportEspion([.json(Self.adresseDuDepot, Self.catalogue)]))
        let lu = try await client.catalogue(de: depot())

        #expect(lu.nom == "Depot Exemple")
        #expect(lu.extensions.map(\.identifiant) == ["exemple.catalogue"])
    }

    @Test("Un depot muet leve une erreur de transport")
    func depotMuet() async throws {
        let client = ClientDeDepot(transport: TransportEspion())

        await #expect(throws: ErreurReseau.ressourceIntrouvable) {
            try await client.catalogue(de: depot())
        }
    }

    @Test("Un paquet signe et servi par le depot est prepare")
    func paquetServiParLeDepot() async throws {
        let signataire = Curve25519.Signing.PrivateKey()
        let manifeste = Data(CatalogueDeclaratifDeTest.manifeste.utf8)
        let enveloppe = try PaquetDExtensionSigne(
            manifeste: manifeste,
            signature: signataire.signature(for: manifeste),
            clePublique: signataire.publicKey.rawRepresentation
        ).enveloppe()
        let client = ClientDeDepot(transport: TransportEspion([
            .init(
                "https://depot.exemple.net/exemple-1.4.json",
                ReponseHttp(code: 200, corps: enveloppe)
            ),
        ]))
        let installateur = InstallateurDExtensions(
            verificateur: VerificateurDeSignature(
                trousseau: TrousseauDeClesDePublication(cles: [signataire.publicKey.rawRepresentation])
            )
        )
        let pret = try await client.paquet(
            de: entree(paquet: "https://depot.exemple.net/exemple-1.4.json"),
            depot: depot(),
            installateur: installateur
        )

        #expect(pret.manifeste.identifiant == "exemple.catalogue")
        #expect(pret.avertissement.domainesAffiches.isEmpty == false)
    }

    @Test("Un paquet servi par un autre hote que le depot est refuse")
    func paquetDUnAutreHote() async throws {
        let espion = TransportEspion()
        let client = ClientDeDepot(transport: espion)

        await #expect(throws: ErreurReseau.domaineNonAutorise(domaine: "attaquant.org")) {
            try await client.paquet(
                de: entree(paquet: "https://attaquant.org/exemple-1.4.json"),
                depot: depot(),
                installateur: InstallateurDExtensions()
            )
        }

        #expect(await espion.adressesDemandees.isEmpty)
    }

    @Test("Un paquet servi en clair est refuse")
    func paquetEnClair() async throws {
        let espion = TransportEspion()
        let client = ClientDeDepot(transport: espion)

        await #expect(throws: ErreurReseau.transportNonChiffre) {
            try await client.paquet(
                de: entree(paquet: "http://depot.exemple.net/exemple-1.4.json"),
                depot: depot(),
                installateur: InstallateurDExtensions()
            )
        }

        #expect(await espion.adressesDemandees.isEmpty)
    }

    // MARK: Outils

    private func depot() throws -> DepotConfigure {
        guard let adresse = URL(string: Self.adresseDuDepot) else {
            throw ErreurReseau.serveurIntrouvable
        }

        return try DepotConfigure(adresse: adresse)
    }

    private func entree(paquet: String) throws -> EntreeDeDepot {
        guard let adresse = URL(string: paquet) else {
            throw ErreurReseau.serveurIntrouvable
        }

        return try EntreeDeDepot(
            identifiant: "exemple.catalogue",
            nom: "Catalogue Exemple",
            version: VersionDExtension("1.4"),
            langue: "fr",
            paquet: adresse
        )
    }

    private static let catalogue = """
    {
      "format": 1,
      "nom": "Depot Exemple",
      "extensions": [
        {
          "identifiant": "exemple.catalogue",
          "nom": "Catalogue Exemple",
          "version": "1.4",
          "langue": "fr",
          "paquet": "https://depot.exemple.net/exemple-1.4.json"
        },
        {
          "identifiant": "clair.catalogue",
          "nom": "En clair",
          "version": "1.0",
          "langue": "fr",
          "paquet": "http://depot.exemple.net/clair.json"
        }
      ]
    }
    """
}
