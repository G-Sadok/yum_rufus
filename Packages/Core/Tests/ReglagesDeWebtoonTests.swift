import Foundation
import Testing
@testable import Core

/// Couvre les deux reglages de mise en page du lecteur webtoon, section 5.8 de
/// DESIGN-SPEC.md : largeur de colonne reglable de quarante a cent pour cent, et
/// espacement entre pages reglable de zero a vingt quatre.
///
/// Les bornes sont testees sur les trois chemins par lesquels une valeur peut
/// entrer dans le modele : le constructeur, la fabrique de l enumeration, et le
/// decodage d une valeur persistee. Le dernier compte autant que les deux
/// autres. Une base ecrite par une version plus permissive, ou un prereglage
/// importe, entre par la et ne passe par aucun curseur d interface.
struct ReglagesDeWebtoonTests {
    // MARK: Largeur de colonne

    @Test("La part libre accepte toute la plage de quarante a cent pour cent")
    func plageDeLaPartLibre() {
        for pourcentage in PourcentageDeColonne.minimum...PourcentageDeColonne.maximum {
            #expect(PourcentageDeColonne(pourcentage).valeur == pourcentage)
        }
    }

    @Test("Une part sous quarante pour cent est remontee a quarante")
    func partTropEtroiteRemontee() {
        #expect(PourcentageDeColonne(39).valeur == 40)
        #expect(PourcentageDeColonne(0).valeur == 40)
        #expect(PourcentageDeColonne(-120).valeur == 40)
    }

    @Test("Une part au dessus de cent pour cent est ramenee a cent")
    func partTropLargeRamenee() {
        #expect(PourcentageDeColonne(101).valeur == 100)
        #expect(PourcentageDeColonne(4000).valeur == 100)
    }

    @Test("La fabrique de largeur libre borne elle aussi la part")
    func fabriqueDeLargeurLibreBornee() {
        #expect(LargeurDeColonne.libre(pourCent: 10).pourcentage?.valeur == 40)
        #expect(LargeurDeColonne.libre(pourCent: 65).pourcentage?.valeur == 65)
        #expect(LargeurDeColonne.libre(pourCent: 250).pourcentage?.valeur == 100)
    }

    @Test("Une part persistee hors plage est ramenee dans la plage au decodage")
    func partPersisteeHorsPlage() throws {
        let decodeur = JSONDecoder()

        let trop = try decodeur.decode(PourcentageDeColonne.self, from: Data("500".utf8))
        let pasAssez = try decodeur.decode(PourcentageDeColonne.self, from: Data("5".utf8))
        let juste = try decodeur.decode(PourcentageDeColonne.self, from: Data("72".utf8))

        #expect(trop.valeur == 100)
        #expect(pasAssez.valeur == 40)
        #expect(juste.valeur == 72)
    }

    @Test("Une largeur de colonne survit a un aller retour en base")
    func largeurDeColonneRetourEnBase() throws {
        let choix: [LargeurDeColonne] = [.ajustee, .pleineLargeur, .libre(pourCent: 55)]

        for largeur in choix {
            let octets = try JSONEncoder().encode(largeur)

            #expect(try JSONDecoder().decode(LargeurDeColonne.self, from: octets) == largeur)
        }
    }

    @Test("La part libre se traduit en points sur la largeur disponible")
    func partLibreEnPoints() {
        #expect(LargeurDeColonne.libre(pourCent: 40).largeur(dans: 1000) == 400)
        #expect(LargeurDeColonne.libre(pourCent: 100).largeur(dans: 1000) == 1000)
        #expect(LargeurDeColonne.libre(pourCent: 75).largeur(dans: 1000) == 750)
    }

    @Test("La pleine largeur prend toute la largeur disponible")
    func pleineLargeur() {
        #expect(LargeurDeColonne.pleineLargeur.largeur(dans: 1280, largeurNaturelle: 400) == 1280)
    }

    @Test("La colonne ajustee suit la page et peut descendre sous quarante pour cent")
    func colonneAjusteeSuitLaPage() {
        let largeur = LargeurDeColonne.ajustee.largeur(dans: 2500, largeurNaturelle: 800)

        #expect(largeur == 800)
        #expect(largeur / 2500 < Double(PourcentageDeColonne.minimum) / 100)
    }

    @Test("La colonne ajustee ne depasse jamais la largeur disponible")
    func colonneAjusteeBorneeParLaFenetre() {
        #expect(LargeurDeColonne.ajustee.largeur(dans: 900, largeurNaturelle: 1600) == 900)
        #expect(LargeurDeColonne.ajustee.largeur(dans: 900, largeurNaturelle: 0) == 900)
    }

    @Test("Aucun choix de largeur ne rend une valeur negative")
    func largeurJamaisNegative() {
        let choix: [LargeurDeColonne] = [.ajustee, .pleineLargeur, .libre(pourCent: 40)]

        for largeur in choix {
            #expect(largeur.largeur(dans: -500, largeurNaturelle: -20) == 0)
        }
    }

    // MARK: Espacement entre pages

    @Test("L espacement accepte toute la plage de zero a vingt quatre")
    func plageDeLEspacement() {
        for points in stride(
            from: EspacementEntrePages.minimum,
            through: EspacementEntrePages.maximum,
            by: EspacementEntrePages.pas
        ) {
            #expect(EspacementEntrePages(points: points).points == points)
        }
    }

    @Test("Un espacement hors plage est ramene a une borne")
    func espacementHorsPlage() {
        #expect(EspacementEntrePages(points: -30).points == EspacementEntrePages.minimum)
        #expect(EspacementEntrePages(points: 25).points == EspacementEntrePages.maximum)
        #expect(EspacementEntrePages(points: 4000).points == EspacementEntrePages.maximum)
    }

    @Test("Un espacement hors de l echelle de quatre est ramene au cran le plus proche")
    func espacementRamenALEchelle() {
        #expect(EspacementEntrePages(points: 1).points == 0)
        #expect(EspacementEntrePages(points: 3).points == 4)
        #expect(EspacementEntrePages(points: 7).points == 8)
        #expect(EspacementEntrePages(points: 23).points == 24)
    }

    @Test("Chaque espacement retenu est un cran de l echelle de la section 1.7")
    func espacementToujoursSurLEchelle() {
        for points in -10...40 {
            let espacement = EspacementEntrePages(points: points)

            #expect(espacement.points.isMultiple(of: EspacementEntrePages.pas))
            #expect(espacement.points >= EspacementEntrePages.minimum)
            #expect(espacement.points <= EspacementEntrePages.maximum)
        }
    }

    @Test("Le reglage ne propose que les sept crans de la plage")
    func valeursProposees() {
        #expect(EspacementEntrePages.valeursProposees.map(\.points) == [0, 4, 8, 12, 16, 20, 24])
    }

    @Test("Un espacement persiste hors plage est ramene dans la plage au decodage")
    func espacementPersisteHorsPlage() throws {
        let decodeur = JSONDecoder()

        let trop = try decodeur.decode(EspacementEntrePages.self, from: Data("64".utf8))
        let negatif = try decodeur.decode(EspacementEntrePages.self, from: Data("-8".utf8))
        let horsEchelle = try decodeur.decode(EspacementEntrePages.self, from: Data("17".utf8))

        #expect(trop.points == 24)
        #expect(negatif.points == 0)
        #expect(horsEchelle.points == 16)
    }

    @Test("L espacement se lit directement comme interstice de la pile")
    func espacementEnInterstice() {
        #expect(EspacementEntrePages(points: 12).interstice == 12)
        #expect(EspacementEntrePages.parDefaut.interstice == 0)
    }

    // MARK: Reglages assembles

    @Test("Les reglages par defaut posent une colonne ajustee et aucun espacement")
    func reglagesParDefaut() {
        #expect(ReglagesDeWebtoon.parDefaut.largeurDeColonne == .ajustee)
        #expect(ReglagesDeWebtoon.parDefaut.espacement == EspacementEntrePages(points: 0))
    }

    @Test("Les reglages rendent la largeur de colonne de leur choix")
    func largeurDeColonneDesReglages() {
        let reglages = ReglagesDeWebtoon(largeurDeColonne: .libre(pourCent: 60), espacement: .init(points: 8))

        #expect(reglages.largeurDeColonne(dans: 1200) == 720)
        #expect(reglages.espacement.points == 8)
    }

    @Test("Les reglages survivent a un aller retour en base")
    func reglagesRetourEnBase() throws {
        let reglages = ReglagesDeWebtoon(largeurDeColonne: .libre(pourCent: 88), espacement: .init(points: 20))
        let octets = try JSONEncoder().encode(reglages)

        #expect(try JSONDecoder().decode(ReglagesDeWebtoon.self, from: octets) == reglages)
    }
}
