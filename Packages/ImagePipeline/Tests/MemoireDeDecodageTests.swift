import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Mesure la memoire que le decodage consomme reellement.
///
/// Deux grandeurs sont mesurees, et il en faut deux.
///
/// La premiere est la matrice de pixels que le decodeur possede a la sortie,
/// `bytesPerRow` multiplie par la hauteur. Ce n est pas une estimation tiree
/// des dimensions : le decodeur redessine l image dans un contexte a lui, donc
/// ce nombre est la taille du tampon alloue, exactement.
///
/// La seconde est l empreinte physique du processus, celle que la section 12
/// plafonne a 400 Mo en lecture. Elle attrape ce que la premiere ne voit pas,
/// une copie oubliee ou un cache interne d Image I/O.
///
/// L empreinte sert de plafond, jamais de preuve d allocation. Mesure faite :
/// l allocateur ne rend pas au systeme les grandes regions qu on libere, il les
/// garde et les reutilise. Douze matrices de 11,9 Mo allouees d un coup n ont
/// donc fait bouger l empreinte que de 475 Ko. Une variation faible ne prouve
/// rien, et aucun test d ici n en tire argument. Ce que l empreinte prouve, en
/// revanche, c est un depassement : elle ne redescend pas.
///
/// La suite est serialisee. Deux mesures d empreinte prises en parallele se
/// contamineraient.
@Suite(.serialized)
struct MemoireDeDecodageTests {
    private let decodeur = DecodeurDePage()
    private let zoneDeLecture = TailleEnPixels(largeur: 1600, hauteur: 2400)

    @Test("La mesure d empreinte repond vraiment")
    func mesureDisponible() {
        // Un noyau qui refuserait task_info rendrait zero, et tous les plafonds
        // de cette suite passeraient sans rien prouver.
        #expect(MesureDeMemoire.octets() > 0)
    }

    @Test("La matrice d une page affichee pese moins de 12 Mo")
    func matriceDUnePageAffichee() throws {
        let page = try decodeur.decoder(PageDeTest.standard, nom: "mesure.jpg", dans: zoneDeLecture)

        #expect(page.octetsEnMemoire < 12_000_000)
        #expect(page.image.bytesPerRow * page.image.height == page.octetsEnMemoire)
    }

    @Test("Le modele de budget majore toujours l allocation reelle")
    func modeleMajoreLaRealite() throws {
        let zones = [
            TailleEnPixels(largeur: 800, hauteur: 1200),
            TailleEnPixels(largeur: 1133, hauteur: 1700),
            TailleEnPixels(largeur: 1600, hauteur: 2400),
            TailleEnPixels(largeur: 6000, hauteur: 9000),
        ]

        for zone in zones {
            let page = try decodeur.decoder(PageDeTest.standard, nom: "modele.jpg", dans: zone)
            let modele = BudgetDeDecodage.octetsOccupes(par: page.tailleDecodee)

            #expect(page.octetsEnMemoire <= modele, "Zone \(zone.largeur) par \(zone.hauteur)")
        }
    }

    @Test("La pleine resolution coute plus de quatre fois une page affichee")
    func coutCompareDuZoom() async throws {
        let affichee = try decodeur.decoder(PageDeTest.standard, nom: "affichee.jpg", dans: zoneDeLecture)

        let reserve = ReserveDeZoom()
        let entiere = try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")

        #expect(entiere.octetsEnMemoire == 54_000_000)
        #expect(await reserve.octetsRetenus == entiere.octetsEnMemoire)
        #expect(entiere.octetsEnMemoire > 4 * affichee.octetsEnMemoire)

        await reserve.terminer()

        #expect(await reserve.octetsRetenus == 0)
    }

    @Test("Douze pages simultanees restent sous le budget de lecture")
    func douzePagesSimultanees() throws {
        let donnees = try chauffer()

        var gardees: [ImageDePage] = []
        for index in 0..<12 {
            try gardees.append(decodeur.decoder(donnees, nom: "page-\(index).jpg", dans: zoneDeLecture))
        }

        #expect(gardees.count == 12)

        // Les douze matrices vivent en meme temps. Le cumul est la memoire que
        // le decodeur a reellement fait allouer, pas une estimation.
        let cumul = gardees.reduce(0) { $0 + $1.octetsEnMemoire }
        #expect(cumul < 12 * 12_000_000)

        // Les memes douze pages en pleine resolution peseraient 648 Mo. Le
        // cumul echouerait ci dessus, et l empreinte du processus ici, sur le
        // budget de lecture de la section 12.
        #expect(MesureDeMemoire.octets() < 400_000_000)
    }

    @Test("Decoder quarante pages a la suite ne fait pas gonfler le processus")
    func quarantePagesSansRetention() throws {
        let donnees = try chauffer()

        let variation = try MesureDeMemoire.variation {
            for index in 0..<40 {
                let page = try decodeur.decoder(donnees, nom: "page-\(index).jpg", dans: zoneDeLecture)
                #expect(page.octetsEnMemoire < 12_000_000)
            }
        }

        // Rien n est garde d une iteration a l autre. Ce qui reste a la fin est
        // du bruit d allocateur, pas des pages. Un decodeur qui garderait une
        // copie de chaque page ajouterait ici 475 Mo.
        #expect(variation < 60_000_000)
    }

    @Test("L empreinte du processus reste loin du budget de lecture pendant un zoom")
    func empreintePendantLeZoom() async throws {
        let donnees = try chauffer()
        let reserve = ReserveDeZoom()

        try await reserve.commencer(sur: donnees, nom: "zoom.jpg")
        let pendantLeGeste = MesureDeMemoire.octets()
        await reserve.terminer()

        // Budget memoire en lecture de la section 12.
        #expect(pendantLeGeste < 400_000_000)
    }

    /// Fabrique la page, decode une fois, et rend les octets.
    ///
    /// Le premier decodage alloue les tables internes d Image I/O et la page
    /// synthetique elle meme. Les compter dans la mesure reviendrait a mesurer
    /// le demarrage du systeme plutot que la chaine d images.
    private func chauffer() throws -> Data {
        let donnees = PageDeTest.standard
        #expect(donnees.isEmpty == false)

        _ = try decodeur.decoder(donnees, nom: "chauffe.jpg", dans: zoneDeLecture)

        return donnees
    }
}
