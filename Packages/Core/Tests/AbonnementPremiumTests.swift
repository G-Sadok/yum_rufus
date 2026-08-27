import Foundation
import Testing
@testable import Core

//
// Parcours d abonnement, joues sur le fichier de configuration StoreKit du
// depot.
//
// Aucun tarif, aucun identifiant et aucune duree d essai n est recopie ici. Tout
// vient de `App/Yum.storekit`, le fichier que le schema Xcode charge en
// developpement. Retirer l offre d essai du fichier, renommer un produit ou
// changer la periode fait virer cette suite au rouge, ce qui est exactement le
// but : la configuration et le code ne peuvent plus diverger en silence.
//
// Les dates sont fixes et le calendrier est gregorien. Un test d abonnement qui
// part de `Date()` echoue un jour de changement d heure, et personne ne sait
// pourquoi trois mois plus tard.
//
// La restauration, les cas limites de l etat et la garde du mur sont couverts
// par `RestaurationEtEtatPremiumTests`, qui partage ce materiel.
//

/// Materiel partage par les suites d abonnement.
enum MaterielDAbonnement {
    /// Calendrier des tests, sans surprise de fuseau ni de calendrier local.
    static var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        return calendrier
    }

    /// Une date fixe, point de depart de tous les parcours.
    static func date(_ jour: Int, _ mois: Int = 1, _ annee: Int = 2026) throws -> Date {
        let composants = DateComponents(year: annee, month: mois, day: jour)

        return try #require(calendrier.date(from: composants))
    }

    /// Produits declares par le fichier de configuration.
    static func produits() throws -> [ProduitPremium] {
        try ConfigurationStoreKit.charger().produits
    }

    /// Produit du fichier de configuration portant cet identifiant.
    static func produit(_ identifiant: String) throws -> ProduitPremium {
        try #require(try ConfigurationStoreKit.charger().produit(identifiant))
    }

    /// Boutique simulee, alimentee par le fichier de configuration.
    static func boutique(le maintenant: Date) throws -> BoutiqueDeTest {
        try BoutiqueDeTest(
            catalogue: produits(),
            maintenant: maintenant,
            calendrier: calendrier
        )
    }
}

/// Le fichier de configuration decrit bien ce que le code attend.
struct ConfigurationDeBoutiqueTests {
    @Test("Le fichier de configuration declare les trois produits du catalogue")
    func lesTroisProduitsSontDeclares() throws {
        let declares = try MaterielDAbonnement.produits().map(\.identifiant).sorted()

        #expect(declares == CataloguePremium.identifiants.sorted())
    }

    @Test("Chaque produit declare porte le genre que le catalogue lui donne")
    func chaqueProduitPorteSonGenre() throws {
        let produits = try MaterielDAbonnement.produits()

        for produit in produits {
            #expect(CataloguePremium.genre(de: produit.identifiant) == produit.genre)
        }

        #expect(Set(produits.map(\.genre)) == Set(GenreDeProduitPremium.allCases))
    }

    @Test("Les deux abonnements offrent un essai entierement gratuit de sept jours")
    func lEssaiDuFichierDureSeptJours() throws {
        let configuration = try ConfigurationStoreKit.charger()

        #expect(configuration.abonnements.isEmpty == false)

        for abonnement in configuration.abonnements {
            let offre = try #require(abonnement.introductoryOffer)

            #expect(offre.estGratuite, "L essai est offert, pas remise")
            #expect(offre.jours == EssaiPremium.periode.jours)
            #expect(offre.jours == 7)
        }
    }

    @Test("L achat definitif du fichier n offre aucun essai")
    func lAchatDefinitifNOffrePasDEssai() throws {
        let definitif = try MaterielDAbonnement.produit(CataloguePremium.definitif)

        #expect(definitif.essai == nil)
        #expect(definitif.genre.estUnAbonnement == false)
    }

    @Test("Le mur met en avant l abonnement mensuel, celui de la mention de prix")
    func leMurMetEnAvantLeMensuel() throws {
        let produits = try MaterielDAbonnement.produits()
        let misEnAvant = try #require(CataloguePremium.misEnAvant(parmi: produits))

        #expect(misEnAvant.identifiant == CataloguePremium.mensuel)
        #expect(misEnAvant.essai == EssaiPremium.periode)
    }
}

/// L essai de sept jours, du premier jour au huitieme.
struct EssaiDeSeptJoursTests {
    @Test("L achat d un abonnement ouvre un essai qui donne acces des le premier jour")
    func lEssaiSOuvreEtDonneAcces() async throws {
        let debut = try MaterielDAbonnement.date(1, 3)
        let boutique = try MaterielDAbonnement.boutique(le: debut)
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        #expect(await boutique.essaiDisponible())

        let resultat = try await boutique.acheter(mensuel)
        let transaction = try #require(resultat.transactionReussie)

        #expect(transaction.estUneOffreDEssai)

        let etat = await boutique.etatCourant()

        #expect(etat.donneAccesAuxFonctionsPremium)
        #expect(etat == .essai(finLe: EssaiPremium.fin(
            depuis: debut,
            calendrier: MaterielDAbonnement.calendrier
        )))
    }

    @Test("L acces reste ouvert la veille de la fin de l essai")
    func lAccesTientJusquALaVeille() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.avancerDe(jours: 6)

        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium)
    }

    @Test("L acces se ferme au septieme jour, et l etat dit une expiration")
    func lAccesSeFermeAuSeptiemeJour() async throws {
        let debut = try MaterielDAbonnement.date(1, 3)
        let boutique = try MaterielDAbonnement.boutique(le: debut)
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.avancerDe(jours: 7)

        let etat = await boutique.etatCourant()

        #expect(etat.donneAccesAuxFonctionsPremium == false)
        #expect(etat == .expire(le: EssaiPremium.fin(
            depuis: debut,
            calendrier: MaterielDAbonnement.calendrier
        )))
        #expect(etat.aDejaSouscrit, "Une expiration n est pas un retour a la case depart")
    }

    @Test("L essai ne s offre qu une fois, meme sur un autre produit du groupe")
    func lEssaiNeSOffreQuUneFois() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let annuel = try MaterielDAbonnement.produit(CataloguePremium.annuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.avancerDe(jours: 8)

        #expect(await boutique.essaiDisponible() == false)

        let resultat = try await boutique.acheter(annuel)
        let seconde = try #require(resultat.transactionReussie)

        #expect(seconde.estUneOffreDEssai == false)

        let etat = await boutique.etatCourant()

        #expect(etat.donneAccesAuxFonctionsPremium)

        if case let .abonne(genre, _) = etat {
            #expect(genre == .annuel)
        } else {
            Issue.record("Le second achat doit donner un abonnement, pas un essai")
        }
    }

    @Test("Un compte qui a deja un abonnement ne redevient jamais eligible")
    func lEligibiliteNeRevientPas() throws {
        let debut = try MaterielDAbonnement.date(1, 3)
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let essai = EssaiPremium.transaction(
            pour: mensuel,
            identifiant: 1,
            debut: debut,
            calendrier: MaterielDAbonnement.calendrier
        )

        #expect(EssaiPremium.estEligible(historique: []))
        #expect(EssaiPremium.estEligible(historique: [essai]) == false)

        let rembourse = TransactionPremium(
            identifiant: essai.identifiant,
            identifiantDeProduit: essai.identifiantDeProduit,
            genre: essai.genre,
            acheteeLe: essai.acheteeLe,
            expireLe: essai.expireLe,
            revoqueeLe: debut,
            estUneOffreDEssai: true
        )

        #expect(
            EssaiPremium.estEligible(historique: [rembourse]) == false,
            "Un remboursement ne redonne pas droit a une seconde periode gratuite"
        )
    }

    @Test("Une periode de sept jours est reconnue comme un essai, un mois ne l est pas")
    func laDureeDistingueLEssaiDeLAbonnement() throws {
        let debut = try MaterielDAbonnement.date(1, 3)
        let calendrier = MaterielDAbonnement.calendrier
        let finDeLEssai = EssaiPremium.fin(depuis: debut, calendrier: calendrier)
        let finDuMois = try #require(calendrier.date(byAdding: .month, value: 1, to: debut))

        #expect(EssaiPremium.correspondALEssai(debut: debut, fin: finDeLEssai, calendrier: calendrier))
        #expect(
            EssaiPremium.correspondALEssai(debut: debut, fin: finDuMois, calendrier: calendrier) == false
        )
        #expect(
            EssaiPremium.correspondALEssai(debut: debut, fin: nil, calendrier: calendrier) == false,
            "Un achat definitif n expire pas, il ne peut pas etre un essai"
        )
    }
}

extension ResultatDAchat {
    /// Transaction d un achat reussi, nulle dans les autres cas.
    var transactionReussie: TransactionPremium? {
        guard case let .reussi(transaction) = self else {
            return nil
        }

        return transaction
    }
}
