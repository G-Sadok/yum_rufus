import Core
import CoreGraphics
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la lecture d un PDF : ouverture, enumeration, rendu a la taille cible,
/// budget memoire et documents proteges par mot de passe.
///
/// La suite est serialisee. Elle contient une mesure de temps d ouverture, que
/// des rendus concurrents fausseraient.
@Suite(.serialized)
struct DocumentPdfTests {
    private let zoneDeLecture = TailleEnPixels(largeur: 1600, hauteur: 2400)

    // MARK: Ouverture

    @Test("Un PDF de 400 pages s ouvre en moins de 350 ms")
    func ouvertureDeQuatreCentsPages() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, pages: 400)

        try chauffer(dans: dossier)

        var mesures: [Duration] = []
        for _ in 0..<5 {
            let debut = ContinuousClock.now
            let document = try DocumentPdf(contenuDe: emplacement)
            mesures.append(ContinuousClock.now - debut)

            #expect(document.nombrePages == 400)
        }

        for mesure in mesures {
            #expect(mesure < .milliseconds(350), "ouverture en \(mesure)")
        }
    }

    @Test("Enumerer les 400 references reste sous le budget d ouverture de chapitre")
    func enumerationDeQuatreCentsPages() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, pages: 400)

        try chauffer(dans: dossier)

        // C est ce que fait la source locale a l ouverture d un chapitre : elle
        // ouvre le document puis demande toutes ses references. Mesurer la seule
        // construction laisserait le cout reel se cacher dans l enumeration.
        let debut = ContinuousClock.now
        let references = try DocumentPdf(contenuDe: emplacement).toutesLesPages()
        let duree = ContinuousClock.now - debut

        #expect(references.count == 400)
        #expect(duree < .milliseconds(350), "ouverture et enumeration en \(duree)")
    }

    @Test("Les pages portent des noms ordonnes et uniques")
    func nomsDePages() throws {
        let document = try ouvrir(pages: 12)
        let noms = try document.toutesLesPages().map(\.nom)

        #expect(noms.first == "page-0001")
        #expect(noms.last == "page-0012")
        #expect(noms == noms.sorted())
        #expect(Set(noms).count == 12)
    }

    @Test("La taille annoncee d une page est celle de son rendu par defaut")
    func tailleAnnoncee() throws {
        let document = try ouvrir(pages: 3)
        let reference = try document.referencePage(0)
        let rendue = try document.rendre(reference, dans: DocumentPdf.zoneParDefaut)

        #expect(reference.tailleOctets >= rendue.octetsEnMemoire)
        #expect(reference.tailleOctets == BudgetDeDecodage.octetsOccupes(par: rendue.tailleDecodee))
    }

    // MARK: Rendu

    @Test("Le rendu tient dans la zone demandee et conserve le ratio")
    func renduAjusteALaZone() throws {
        let document = try ouvrir(pages: 2)
        let zone = TailleEnPixels(largeur: 800, hauteur: 1200)
        let rendue = try document.rendre(document.referencePage(0), dans: zone)

        #expect(rendue.tailleDecodee.largeur <= zone.largeur)
        #expect(rendue.tailleDecodee.hauteur <= zone.hauteur)

        // La page A4 est plus haute que large, elle bute donc sur la largeur.
        #expect(rendue.tailleDecodee.largeur == zone.largeur)

        let ratioDOrigine = ConstructeurDePdf.tailleA4.width / ConstructeurDePdf.tailleA4.height
        let ratioRendu = Double(rendue.tailleDecodee.largeur) / Double(rendue.tailleDecodee.hauteur)

        #expect(abs(ratioRendu - Double(ratioDOrigine)) < 0.01)
        #expect(rendue.image.width == rendue.tailleDecodee.largeur)
        #expect(rendue.image.height == rendue.tailleDecodee.hauteur)
    }

    @Test("Une zone plus grande que le budget est ramenee sous le budget")
    func renduBorneParLeBudget() throws {
        let document = try ouvrir(pages: 1, taille: CGSize(width: 5000, height: 7000))
        let zone = TailleEnPixels(largeur: 6000, hauteur: 9000)
        let rendue = try document.rendre(document.referencePage(0), dans: zone)

        // Ajustee a la zone sans budget, cette page ferait 6000 par 8400, soit
        // 201 Mo. C est exactement l erreur numero trois du cahier.
        #expect(rendue.octetsEnMemoire < BudgetDeDecodage.parDefaut.octetsParPage)
        #expect(rendue.tailleDecodee.largeur < zone.largeur)
        #expect(rendue.image.bytesPerRow * rendue.image.height == rendue.octetsEnMemoire)
    }

    @Test("Un budget resserre resserre le rendu d autant")
    func renduSuitLeBudget() throws {
        let document = try ouvrir(pages: 1)
        let large = try document.rendre(document.referencePage(0), dans: zoneDeLecture)
        let etroit = try document.rendre(
            document.referencePage(0),
            dans: zoneDeLecture,
            budget: BudgetDeDecodage(octetsParPage: 1_000_000)
        )

        #expect(etroit.octetsEnMemoire < 1_000_000)
        #expect(etroit.tailleDecodee.plusGrandCote < large.tailleDecodee.plusGrandCote)
    }

    @Test("Chaque rendu restitue la page demandee et pas une autre")
    func renduDeLaBonnePage() throws {
        let document = try ouvrir(pages: 5)
        let zone = TailleEnPixels(largeur: 200, hauteur: 300)

        let niveaux = try (0..<5).map { rang in
            let rendue = try document.rendre(document.referencePage(rang), dans: zone)

            return try #require(ConstructeurDePdf.grisAuCentre(rendue.image))
        }

        // Les pages sont remplies d un gris croissant avec leur rang. Un lecteur
        // qui rendrait toujours la premiere page, ou qui decalerait d un rang,
        // casserait cette suite.
        #expect(niveaux == niveaux.sorted())
        #expect(Set(niveaux).count == 5)
    }

    @Test("Une boite media dont l origine n est pas nulle est rendue quand meme")
    func origineNonNulle() throws {
        let document = try ouvrir(pages: 2, origine: CGPoint(x: 120, y: 240))
        let rendue = try document.rendre(document.referencePage(1), dans: zoneDeLecture)
        let gris = try #require(ConstructeurDePdf.grisAuCentre(rendue.image))

        // Un rendu qui ignorerait l origine dessinerait la page a cote de la
        // matrice, qui resterait blanche.
        #expect(gris < 250)
    }

    @Test("Les octets d une page forment une image que la chaine sait decoder")
    func octetsDecodables() throws {
        let document = try ouvrir(pages: 3)
        let reference = try document.referencePage(2)
        let octets = try document.donneesPage(reference)
        let decodee = try DecodeurDePage().decoder(octets, nom: reference.nom, dans: zoneDeLecture)

        #expect(octets.isEmpty == false)
        #expect(decodee.octetsEnMemoire < BudgetDeDecodage.parDefaut.octetsParPage)
        #expect(decodee.tailleDecodee.largeur > 0)
    }

    @Test("Un PDF ne porte pas de ComicInfo.xml")
    func aucuneMetadonneeComic() throws {
        #expect(try ouvrir(pages: 2).donneesDeMetadonnees() == nil)
    }

    // MARK: Mot de passe

    @Test("Un PDF protege refuse de s ouvrir sans mot de passe")
    func protegeSansMotDePasse() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, pages: 3, motDePasse: "kokoro")

        #expect(throws: ErreurDeDocument.conteneurChiffre(chemin: emplacement.path)) {
            try DocumentPdf(contenuDe: emplacement)
        }
    }

    @Test("Un mot de passe faux est nomme comme tel, et non comme une demande")
    func protegeAvecMauvaisMotDePasse() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, pages: 3, motDePasse: "kokoro")

        #expect(throws: ErreurDeDocument.motDePasseIncorrect(chemin: emplacement.path)) {
            try DocumentPdf(contenuDe: emplacement, motDePasse: "kokora")
        }
    }

    @Test("Le bon mot de passe ouvre le document et rend ses pages")
    func protegeAvecBonMotDePasse() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, pages: 3, motDePasse: "kokoro")
        let document = try DocumentPdf(contenuDe: emplacement, motDePasse: "kokoro")

        #expect(document.nombrePages == 3)
        #expect(document.estChiffre)

        let rendue = try document.rendre(document.referencePage(1), dans: zoneDeLecture)

        #expect(rendue.tailleDecodee.estVide == false)
    }

    @Test("Un PDF en clair n est pas annonce comme chiffre")
    func clairNonAnnonceChiffre() throws {
        #expect(try ouvrir(pages: 1).estChiffre == false)
    }

    // MARK: Bornes et conteneurs abimes

    @Test("Une position hors du document est refusee", arguments: [-1, 4, 900])
    func positionHorsBornes(_ position: Int) throws {
        let document = try ouvrir(pages: 4)

        #expect(throws: ErreurDeDocument.indexHorsBornes(demande: position, nombrePages: 4)) {
            try document.referencePage(position)
        }
    }

    @Test("Une reference etrangere au document est refusee")
    func referenceEtrangere() throws {
        let document = try ouvrir(pages: 4)
        let etrangere = ReferencePage(index: 0, nom: "page1.jpg", tailleOctets: 32)

        #expect(throws: ErreurDeDocument.entreeIntrouvable(nom: "page1.jpg")) {
            try document.donneesPage(etrangere)
        }
    }

    @Test("Un fichier qui n est pas un PDF est refuse")
    func fichierQuiNEstPasUnPdf() throws {
        let octets = Data(repeating: 7, count: 4096)

        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: "tome.pdf")) {
            try DocumentPdf(donnees: octets, nom: "tome.pdf")
        }
    }

    @Test("Un fichier absent est nomme comme absent, pas comme illisible")
    func fichierIntrouvable() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let emplacement = dossier.appending(path: "absent.pdf")

        #expect(throws: ErreurDeDocument.fichierIntrouvable(chemin: emplacement.path)) {
            try DocumentPdf(contenuDe: emplacement)
        }
    }

    @Test("Une zone pas encore mesuree ne produit pas une page d un pixel")
    func zoneNonMesuree() throws {
        let document = try ouvrir(pages: 1)
        let rendue = try document.rendre(document.referencePage(0), dans: .nulle)

        #expect(rendue.tailleDecodee.plusGrandCote > 100)
    }

    // MARK: Outils

    /// Ouvre un PDF fabrique en memoire, sans passer par le disque.
    private func ouvrir(
        pages: Int,
        taille: CGSize = ConstructeurDePdf.tailleA4,
        origine: CGPoint = .zero
    ) throws -> DocumentPdf {
        let octets = try #require(ConstructeurDePdf.donnees(pages: pages, taille: taille, origine: origine))

        return try DocumentPdf(donnees: octets, nom: "tome.pdf")
    }

    /// Ouvre un petit document avant la mesure.
    ///
    /// La premiere ouverture d un PDF dans le processus charge PDFKit et ses
    /// dependances. Compter ce chargement dans le budget d ouverture d un
    /// chapitre reviendrait a mesurer le demarrage du systeme, que la section 12
    /// plafonne ailleurs et autrement.
    private func chauffer(dans dossier: URL) throws {
        let emplacement = try ConstructeurDePdf.fichier(dans: dossier, nom: "chauffe.pdf", pages: 1)

        _ = try DocumentPdf(contenuDe: emplacement).toutesLesPages()
    }
}
