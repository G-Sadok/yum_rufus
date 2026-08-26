import Core
import Foundation
import Testing
@testable import Sources

//
// AnalyseDesReponsesOpdsTests
//
// Premier critere de la fonctionnalite, moitie analyse : les deux versions du
// protocole se lisent, et les quatre reponses defectueuses que la strategie de
// test exige se traitent sans faire tomber la source.
//
// Ce fichier ne fait partir aucune requete. Il compare des octets figes a la
// forme commune de `ModeleOpds`, ce qui isole les defauts d analyse des defauts
// de transport. La chaine complete est reprise par `SourceOpdsTests`.
//

struct AnalyseDesReponsesOpdsTests {
    // MARK: Choix de la version

    @Test("Le type de contenu decide de la version quand il la nomme")
    func versionAnnonceeParLeType() {
        let atom = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": "application/atom+xml;profile=opds-catalog"],
            corps: Data("<feed/>".utf8)
        )
        let json = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": "application/opds+json"],
            corps: Data("{}".utf8)
        )

        #expect(AnalyseurOpds.version(de: atom) == .atom)
        #expect(AnalyseurOpds.version(de: json) == .json)
    }

    @Test("Un type de contenu muet laisse les premiers octets decider")
    func versionDeduiteDesOctets() {
        // Un proxy inverse mal regle annonce ce type sur les deux versions. La
        // source doit rester lisible malgre lui.
        let opaque = "application/octet-stream"
        let atom = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": opaque],
            corps: Data("\n  <?xml version=\"1.0\"?><feed/>".utf8)
        )
        let json = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": opaque],
            corps: Data("  {\"metadata\": {}}".utf8)
        )

        #expect(AnalyseurOpds.version(de: atom) == .atom)
        #expect(AnalyseurOpds.version(de: json) == .json)
    }

    @Test("Un flux JSON annonce en XML se lit quand meme")
    func versionAnnonceeAFaux() throws {
        let mentie = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": "application/xml"],
            corps: Data(ReponsesFigeesDOpds.catalogueJsonPage1.utf8)
        )

        let flux = try AnalyseurOpds.analyser(mentie)

        #expect(flux.series.map(\.titre) == ["Berserk", "Vinland Saga", "Yotsuba"])
    }

    // MARK: OPDS 1.2

    @Test("Le flux Atom rend ses series, sans celle qui n a pas de titre")
    func seriesDuFluxAtom() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.cataloguePage1.utf8)))

        #expect(flux.titre == "Catalogue de test")
        #expect(flux.series.map(\.titre) == ["Berserk", "Vinland Saga"])
        // L entree sans titre est bien arrivee jusqu a l analyseur, elle a ete
        // ecartee a la construction et non perdue en chemin.
        #expect(flux.entrees.count == 2)
    }

    @Test("Les metadonnees d une entree Atom sont traduites champ par champ")
    func metadonneesDuFluxAtom() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.cataloguePage1.utf8)))
        let berserk = try #require(flux.series.first)

        #expect(berserk.identifiant == "urn:tsuzuki:serie:berserk")
        #expect(berserk.auteurs == ["Kentaro Miura"])
        #expect(berserk.resume == "Un mercenaire marque par un sacrifice.")
        #expect(berserk.categories == ["Action", "Fantasy"])
        #expect(berserk.langue == "ja")
        #expect(berserk.miseAJour == DatesDeTest.instant(2026, 1, 4, HeureDeTest(8, 30)))
        #expect(berserk.couverture?.adresse == "/opds/v1.2/series/berserk/couverture")
    }

    @Test("Le lien suivant du flux Atom est celui de la relation next")
    func lienSuivantDuFluxAtom() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.cataloguePage1.utf8)))

        #expect(flux.suivante?.adresse == "/opds/v1.2/series?page=1&jeton=suite-imprevisible")
        #expect(flux.section(RelationOpds.nouveautes)?.adresse == "/opds/v1.2/series/nouveautes")
    }

    @Test("La derniere page du flux Atom n annonce aucune suite")
    func derniereePageDuFluxAtom() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.cataloguePage2.utf8)))

        #expect(flux.suivante == nil)
        #expect(flux.series.map(\.titre) == ["Yotsuba"])
    }

    @Test("Un lien vers le document d une seule entree n est pas un sous catalogue")
    func documentDEntreeIgnore() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.seriePage1.utf8)))
        let premier = try #require(flux.chapitres.first)

        // L entree porte un lien `alternate` de type `entry`. S il passait pour
        // un sous catalogue, ce chapitre deviendrait une serie vide.
        #expect(premier.estUnChapitre)
        #expect(premier.estUneSerie == false)
        #expect(flux.series.isEmpty)
    }

    @Test("La diffusion page par page est lue avec son compte")
    func diffusionLueDansLeFluxAtom() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.seriePage1.utf8)))
        let premier = try #require(flux.chapitres.first)
        let diffusion = try #require(premier.diffusionDePages)

        #expect(diffusion.nombreDePages == 3)
        #expect(diffusion.adresse.contains("{pageNumber}"))
        #expect(flux.chapitres.last?.diffusionDePages == nil)
    }

    @Test("Une acquisition declinee reste une acquisition")
    func acquisitionDeclinee() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.seriePage1.utf8)))
        let second = try #require(flux.chapitres.last)

        #expect(second.acquisition?.relation == "http://opds-spec.org/acquisition/open-access")
        #expect(second.acquisition?.adresse == "/opds/v1.2/books/2/file")
    }

    // MARK: OPDS 2.0

    @Test("Le flux JSON rend ses series, groupes compris")
    func seriesDuFluxJson() throws {
        let flux = try #require(AnalyseJsonOpds.analyser(Data(ReponsesFigeesDOpds.catalogueJsonPage1.utf8)))

        #expect(flux.titre == "Catalogue de test")
        #expect(flux.series.map(\.titre) == ["Berserk", "Vinland Saga", "Yotsuba"])
    }

    @Test("Une relation ecrite en liste vaut une relation ecrite en chaine")
    func relationEnListe() throws {
        let flux = try #require(AnalyseJsonOpds.analyser(Data(ReponsesFigeesDOpds.catalogueJsonPage1.utf8)))

        #expect(flux.suivante?.adresse == "/opds/v2/series?page=1")
    }

    @Test("Les quatre formes d auteur et de sujet sont acceptees")
    func formesSouplesDesNoms() throws {
        let flux = try #require(AnalyseJsonOpds.analyser(Data(ReponsesFigeesDOpds.serieJson.utf8)))
        let premier = try #require(flux.chapitres.first)
        let second = try #require(flux.chapitres.last)

        #expect(premier.auteurs == ["Kentaro Miura"])
        #expect(premier.categories == ["Action", "Fantasy"])
        #expect(second.auteurs == ["Kentaro Miura"])
    }

    @Test("Les metadonnees d une publication JSON sont traduites champ par champ")
    func metadonneesDuFluxJson() throws {
        let flux = try #require(AnalyseJsonOpds.analyser(Data(ReponsesFigeesDOpds.serieJson.utf8)))
        let premier = try #require(flux.chapitres.first)

        #expect(premier.identifiant == "urn:tsuzuki:livre:1")
        #expect(premier.resume == "Le premier chapitre.")
        #expect(premier.langue == "ja")
        #expect(premier.nombreDePages == 3)
        #expect(premier.miseAJour == DatesDeTest.instant(2026, 1, 2, HeureDeTest(10, 0)))
        #expect(premier.couverture?.adresse == "/opds/v2/books/1/couverture")
        #expect(premier.diffusionDePages?.nombreDePages == 3)
    }

    // MARK: Reponses defectueuses

    @Test("Une reponse vide est refusee avant tout decodage")
    func reponseVide() {
        let vide = ReponseHttp(code: 200, entetes: ["Content-Type": "application/atom+xml"])

        #expect(throws: ErreurReseau.reponseVide) {
            _ = try AnalyseurOpds.analyser(vide)
        }
    }

    @Test("Un document qui n est pas un flux est refuse dans les deux versions")
    func documentSansFluxRefuse() {
        let page = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": "application/atom+xml"],
            corps: Data(ReponsesFigeesDOpds.documentSansFlux.utf8)
        )

        #expect(throws: ErreurReseau.reponseIllisible) {
            _ = try AnalyseurOpds.analyser(page)
        }
    }

    @Test("Un JSON malforme est refuse et non lu a moitie")
    func jsonMalformeRefuse() {
        let coupe = ReponseHttp(
            code: 200,
            entetes: ["Content-Type": "application/opds+json"],
            corps: Data("{\"publications\": [".utf8)
        )

        #expect(throws: ErreurReseau.reponseIllisible) {
            _ = try AnalyseurOpds.analyser(coupe)
        }
    }

    @Test("Un flux Atom tronque rend ce qui precede la cassure")
    func fluxTronqueExploitable() throws {
        let flux = try #require(AnalyseAtomOpds.analyser(Data(ReponsesFigeesDOpds.fluxTronque.utf8)))

        // La seconde entree est coupee en plein milieu et disparait. La
        // premiere est complete et reste lisible : une page de catalogue
        // amputee vaut mieux qu une source muette.
        #expect(flux.series.map(\.titre) == ["Berserk"])
    }
}
