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

    /// Part du budget de la section 12 qui revient a la lecture elle meme.
    ///
    /// C est la difference entre les deux budgets memoire du tableau : 400 Mo
    /// en lecture, moins 200 Mo au repos avec une bibliotheque de 5000 series.
    /// Ce qui reste est ce qu un chapitre ouvert, son cache et un geste de zoom
    /// ont le droit d ajouter.
    ///
    /// La borne est derivee du cahier et non choisie ici. Un seuil invente pour
    /// qu une mesure passe serait un budget elargi sous un autre nom.
    private let partDeLecture = 200_000_000

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

    @Test("Douze pages simultanees restent sous la part de lecture du budget")
    func douzePagesSimultanees() throws {
        let donnees = try chauffer()
        var gardees: [ImageDePage] = []

        let variation = try MesureDeMemoire.variation {
            for index in 0..<12 {
                try gardees.append(decodeur.decoder(donnees, nom: "page-\(index).jpg", dans: zoneDeLecture))
            }
        }

        #expect(gardees.count == 12)

        // Les douze matrices vivent en meme temps. Le cumul est la memoire que
        // le decodeur a reellement fait allouer, pas une estimation.
        let cumul = gardees.reduce(0) { $0 + $1.octetsEnMemoire }
        #expect(cumul < 12 * 12_000_000)

        // Ce qui est plafonne ici est la memoire imputable a la lecture, et non
        // l empreinte absolue du processus.
        //
        // La version precedente comparait `MesureDeMemoire.octets()` aux 400 Mo
        // de la section 12. Cette mesure la est l empreinte du processus de
        // test entier, qui a execute deux mille cinq cents autres tests avant
        // d arriver ici et dont l allocateur ne rend pas au systeme les regions
        // liberees. Elle passait a 399 Mo et echouait a 429 des qu une suite
        // s ajoutait ailleurs dans le paquet, sans que la chaine d images ait
        // bouge d un octet. Un plafond qui depend de ce que les autres suites
        // ont fait avant ne mesure pas la chaine d images.
        //
        // La borne retenue est `partDeLecture`, derivee des deux budgets
        // memoire du cahier. Les memes douze pages en pleine resolution
        // peseraient 648 Mo et feraient echouer les deux verifications.
        //
        // Le plafond absolu des 400 Mo n a pas disparu, il a change d endroit :
        // `mesurer-budgets` le mesure sur le corpus complet, dans un processus
        // qui ne fait que lire un chapitre, et l integration continue echoue
        // s il est franchi.
        #expect(variation < partDeLecture)
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

    @Test("Un zoom coute une page entiere et rien de plus")
    func empreintePendantLeZoom() async throws {
        let donnees = try chauffer()
        let reserve = ReserveDeZoom()

        let avant = MesureDeMemoire.octets()
        try await reserve.commencer(sur: donnees, nom: "zoom.jpg")
        let pendantLeGeste = MesureDeMemoire.octets() - avant
        await reserve.terminer()

        // Comme pour les douze pages, ce qui est plafonne est la memoire que le
        // geste ajoute, pas l empreinte absolue d un processus de test qui a
        // deja tout fait avant.
        //
        // Que la reserve ne retienne qu une seule page entiere est verifie
        // ailleurs, a l octet pres, par `coutCompareDuZoom`. Ce plafond ci est
        // un garde fou de second rideau : il attrape ce que la matrice ne voit
        // pas, un tampon intermediaire d Image I/O qui resterait alloue.
        #expect(pendantLeGeste < partDeLecture)
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
