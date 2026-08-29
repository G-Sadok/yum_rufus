import Foundation
import Security
import Testing
@testable import Core

//
// Couvre l etat de connexion des quatre services et le rangement de leurs
// jetons, premier critere de la fonctionnalite.
//
// Le trousseau reel n est pas sollicite : un binaire de test lance par SwiftPM
// n est pas signe et ne porte aucun droit de trousseau. Ce que le vrai
// trousseau doit garantir se verifie sur la forme des requetes, comme pour les
// identifiants de source.
//

@Suite("Connexion aux services de suivi")
struct ConnexionDeSuiviTests {
    static let compte = CompteDeSuivi(identifiant: "1", pseudonyme: "lectrice")

    @Test("Une installation neuve n a aucun service connecte")
    func installationNeuve() {
        let etats = EtatDesSuivis.aucun

        #expect(etats.estVide)
        #expect(etats.nombreDeServicesConnectes == 0)

        for service in ServiceDeSuivi.allCases {
            #expect(etats[service] == .deconnecte)
        }
    }

    @Test("Les quatre services se connectent independamment")
    func connexionDesQuatre() {
        var etats = EtatDesSuivis.aucun

        for service in ServiceDeSuivi.allCases {
            etats.connecter(service, compte: Self.compte)
        }

        #expect(etats.nombreDeServicesConnectes == 4)
        #expect(Set(etats.servicesConnectes) == Set(ServiceDeSuivi.allCases))
    }

    @Test("Deconnecter un service n en efface aucun autre")
    func deconnexionIsolee() {
        var etats = EtatDesSuivis.aucun
        etats.connecter(.aniList, compte: Self.compte)
        etats.connecter(.kitsu, compte: Self.compte)
        etats.deconnecter(.aniList)

        #expect(etats[.aniList] == .deconnecte)
        #expect(etats[.kitsu] == .connecte(Self.compte))
        #expect(etats.nombreDeServicesConnectes == 1)
    }

    @Test("Deconnecter les quatre laisse la table vide")
    func deconnexionComplete() {
        var etats = EtatDesSuivis.aucun

        for service in ServiceDeSuivi.allCases {
            etats.connecter(service, compte: Self.compte)
        }
        for service in ServiceDeSuivi.allCases {
            etats.deconnecter(service)
        }

        #expect(etats.estVide)
        #expect(etats.nombreDeServicesConnectes == 0)
    }

    @Test("Un jeton perime garde le compte et cesse d envoyer")
    func sessionExpiree() {
        var etats = EtatDesSuivis.aucun
        etats.connecter(.myAnimeList, compte: Self.compte)
        etats.marquerExpire(.myAnimeList)

        #expect(etats[.myAnimeList] == .expire(Self.compte))
        #expect(etats[.myAnimeList].peutEnvoyer == false)
        #expect(etats[.myAnimeList].compte == Self.compte)
        #expect(etats.servicesExpires == [.myAnimeList])
        #expect(etats.nombreDeServicesConnectes == 0)
    }

    @Test("Un service jamais connecte ne peut pas expirer")
    func expirationSansCompte() {
        var etats = EtatDesSuivis.aucun
        etats.marquerExpire(.kitsu)

        #expect(etats[.kitsu] == .deconnecte)
        #expect(etats.estVide)
    }

    @Test("Le magasin en memoire range et rend un jeton par service")
    func magasinParService() async throws {
        let magasin = MagasinDeJetonsDeSuiviEnMemoire()
        let jeton = IdentifiantsDeSource.jeton(acces: "jeton-anilist")

        try await magasin.enregistrer(jeton, pour: .aniList)

        #expect(await magasin.identifiants(pour: .aniList) == jeton)
        #expect(await magasin.identifiants(pour: .kitsu) == .aucun)
        #expect(await magasin.servicesConnus == [.aniList])
    }

    @Test("Deconnecter efface la ligne du service et rien de plus")
    func suppressionParService() async throws {
        let magasin = MagasinDeJetonsDeSuiviEnMemoire()
        try await magasin.enregistrer(.jeton(acces: "un"), pour: .aniList)
        try await magasin.enregistrer(.jeton(acces: "deux"), pour: .kitsu)

        try await magasin.supprimer(pour: .aniList)

        #expect(await magasin.identifiants(pour: .aniList) == .aucun)
        #expect(await magasin.identifiants(pour: .kitsu) == .jeton(acces: "deux"))
    }

    @Test("La purge complete ne laisse aucun jeton")
    func purgeComplete() async throws {
        let magasin = MagasinDeJetonsDeSuiviEnMemoire()

        for service in ServiceDeSuivi.allCases {
            try await magasin.enregistrer(.jeton(acces: "jeton-" + service.rawValue), pour: service)
        }

        try await magasin.toutSupprimer()

        #expect(await magasin.servicesConnus.isEmpty)
    }

    @Test("Les lignes de suivi sont rangees hors du service des sources")
    func serviceDeTrousseauDistinct() {
        #expect(RequeteDeTrousseau.serviceDesSuivis != RequeteDeTrousseau.serviceParDefaut)
    }

    @Test("Chaque service occupe une ligne distincte, accessible apres deverrouillage")
    func requeteDeTrousseauDesSuivis() {
        let requetes = RequeteDeTrousseau(service: RequeteDeTrousseau.serviceDesSuivis)
        var cles: Set<String> = []

        for service in ServiceDeSuivi.allCases {
            let cle = TrousseauDesSuivis.cle(de: service)
            cles.insert(cle)

            let creation = requetes.creation(deCle: cle, donnees: Data("jeton".utf8))

            #expect(creation[kSecAttrAccount as String] as? String == cle)
            #expect(creation[kSecAttrService as String] as? String == RequeteDeTrousseau.serviceDesSuivis)
            #expect(creation[kSecAttrAccessible as String] as? String == RequeteDeTrousseau.accessibilite)
        }

        #expect(cles.count == 4)
    }

    @Test("La cle d une source et celle d un suivi ne se confondent pas")
    func clesDistinctes() {
        let requetes = RequeteDeTrousseau(service: "test.jetons-de-suivi")
        let source = SourceID(UUID(uuidString: "6C4F0B02-6D6F-4D5E-9A1B-2F3E4D5C6B7A") ?? UUID())
        let designationDeSource = requetes.designation(de: source)
        let designationDeSuivi = requetes.designation(deCle: TrousseauDesSuivis.cle(de: .aniList))

        #expect(
            designationDeSource[kSecAttrAccount as String] as? String
                != designationDeSuivi[kSecAttrAccount as String] as? String
        )
    }
}
