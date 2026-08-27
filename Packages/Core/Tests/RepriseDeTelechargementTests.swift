import Foundation
import Testing
@testable import Core

//
// Couvre le point de reprise et sa traduction en HTTP.
//
// C est la moitie calculee du premier critere d acceptation : un telechargement
// interrompu reprend ou il s est arrete. L autre moitie, celle qui va chercher
// les octets, vit dans le moteur et dans sa suite de tests.
//

struct RepriseDeTelechargementTests {
    // MARK: Point de reprise

    @Test("Une interruption entre deux pages reprend a la page suivante")
    func repriseEntreDeuxPages() throws {
        let inventaire = InventaireDeTelechargement(pagesCompletes: 7, octetsDuFragment: 0)
        let point = try #require(RepriseDeTelechargement.point(depuis: inventaire, nombreDePages: 24))

        #expect(point.pageIndex == 7)
        #expect(point.repartDeZero)
    }

    @Test("Une interruption au milieu d une page reprend au milieu du fichier")
    func repriseAuMilieuDUnePage() throws {
        let inventaire = InventaireDeTelechargement(pagesCompletes: 7, octetsDuFragment: 4096)
        let point = try #require(RepriseDeTelechargement.point(depuis: inventaire, nombreDePages: 24))

        #expect(point.pageIndex == 7)
        #expect(point.octetsDejaRecus == 4096)
        #expect(point.repartDeZero == false)
    }

    @Test("Un chapitre deja complet ne designe aucune page a reprendre")
    func chapitreDejaComplet() {
        let inventaire = InventaireDeTelechargement(pagesCompletes: 24)

        #expect(RepriseDeTelechargement.point(depuis: inventaire, nombreDePages: 24) == nil)
    }

    @Test("Une longueur inconnue ne fait pas demander une page au hasard")
    func longueurInconnue() {
        #expect(RepriseDeTelechargement.point(depuis: .vierge, nombreDePages: 0) == nil)
    }

    @Test("Un chapitre vierge repart de sa premiere page")
    func chapitreVierge() throws {
        let point = try #require(RepriseDeTelechargement.point(depuis: .vierge, nombreDePages: 24))

        #expect(point.pageIndex == 0)
        #expect(point.repartDeZero)
    }

    @Test("Un inventaire ne compte jamais de pages negatives")
    func inventaireBorne() {
        let inventaire = InventaireDeTelechargement(pagesCompletes: -4, octetsDuFragment: -9)

        #expect(inventaire.pagesCompletes == 0)
        #expect(inventaire.octetsDuFragment == 0)
    }

    // MARK: Entete de demande

    @Test("Une reprise au milieu demande la tranche qui manque")
    func enteteDePlage() {
        #expect(RepriseDeTelechargement.enteteDePlage(a: 4096) == "bytes=4096-")
    }

    @Test("Une page qui repart de zero ne demande aucune tranche")
    func aucuneTrancheDepuisZero() {
        // Un `bytes=0-` ferait repondre 206 la ou 200 est attendu, et le code de
        // la reponse ne dirait plus rien de ce qui s est passe.
        #expect(RepriseDeTelechargement.enteteDePlage(a: 0) == nil)
        #expect(RepriseDeTelechargement.enteteDePlage(a: -5) == nil)
    }

    // MARK: Accueil de la reprise

    @Test("Un 206 dont la tranche commence au bon octet est une reprise")
    func trancheServie() {
        let accueil = RepriseDeTelechargement.accueil(
            code: 206,
            contentRange: "bytes 4096-8191/8192",
            attendu: 4096
        )

        #expect(accueil == .tranche)
    }

    @Test("Un serveur qui ignore la demande renvoie tout, et le fragment est jete")
    func serveurQuiIgnoreLaDemande() {
        let accueil = RepriseDeTelechargement.accueil(code: 200, contentRange: nil, attendu: 4096)

        #expect(accueil == .fichierEntier)
    }

    @Test("Un refus de tranche fait repartir la page de zero")
    func trancheRefusee() {
        let accueil = RepriseDeTelechargement.accueil(
            code: 416,
            contentRange: "bytes */2048",
            attendu: 4096
        )

        #expect(accueil == .refusee)
    }

    @Test("Un 206 dont la tranche commence ailleurs est refuse")
    func trancheMalPlacee() {
        // Coller ces octets au fragment fabriquerait un fichier dont le milieu
        // manque, et rien ne le signalerait avant l ouverture du chapitre.
        let accueil = RepriseDeTelechargement.accueil(
            code: 206,
            contentRange: "bytes 0-8191/8192",
            attendu: 4096
        )

        #expect(accueil == .refusee)
    }

    @Test("Un 206 sans entete de tranche est refuse")
    func trancheSansEntete() {
        #expect(RepriseDeTelechargement.accueil(code: 206, contentRange: nil, attendu: 4096) == .refusee)
    }

    @Test("Une page qui n a rien demande recoit forcement le fichier entier")
    func aucuneDemandeAucuneTranche() {
        #expect(RepriseDeTelechargement.accueil(code: 200, contentRange: nil, attendu: 0) == .fichierEntier)
    }

    @Test("Le premier octet se lit dans les formes que les serveurs emploient")
    func lectureDuContentRange() {
        #expect(RepriseDeTelechargement.premierOctet(de: "bytes 200-1023/1024") == 200)
        #expect(RepriseDeTelechargement.premierOctet(de: "bytes 0-0/1") == 0)
        #expect(RepriseDeTelechargement.premierOctet(de: "octets 200-1023/1024") == nil)
        #expect(RepriseDeTelechargement.premierOctet(de: "bytes */1024") == nil)
        #expect(RepriseDeTelechargement.premierOctet(de: nil) == nil)
    }
}
