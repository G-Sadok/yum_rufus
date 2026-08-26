import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la section 7.3 du cahier de developpement : une bande de vingt mille
/// pixels de haut est decoupee en tuiles de 2048 au plus, ces tuiles couvrent la
/// bande exactement, et chacune tient dans une texture.
///
/// Le critere de la fonctionnalite parle d un affichage sans echec de rendu. Un
/// test ne peut pas creer de texture Metal, mais l echec de rendu a une cause
/// unique et mesurable : une image dont un cote depasse 16384 pixels. Ce que ces
/// tests verifient est donc que rien de ce que la chaine d images propose a la
/// vue ne depasse cette limite, et que la bande entiere, elle, la depasse bien,
/// faute de quoi le test passerait aussi sur une chaine qui n a rien tuile.
struct TuilageDImageLongueTests {
    private let tuilage = TuilageDImageLongue.parDefaut

    /// Bande du critere, vingt mille pixels de haut.
    private let bandeDuCritere = TailleEnPixels(largeur: 800, hauteur: 20000)

    // MARK: Geometrie

    @Test("Une bande de 20000 pixels donne dix tuiles de 2048 au plus")
    func bandeDuCritereDecoupee() {
        let decoupes = tuilage.decoupes(de: bandeDuCritere)

        #expect(decoupes.count == 10)
        #expect(tuilage.nombreDeTuiles(pour: bandeDuCritere) == 10)
        #expect(decoupes.allSatisfy { $0.taille.hauteur <= TuilageDImageLongue.hauteurMaximaleDeTuile })
        #expect(decoupes.last?.taille.hauteur == 20000 - 9 * 2048)
    }

    @Test("Aucune tuile de la bande du critere ne depasse la limite de texture")
    func tuilesSousLaLimiteDeTexture() {
        let decoupes = tuilage.decoupes(de: bandeDuCritere)

        #expect(decoupes.isEmpty == false)
        #expect(decoupes.allSatisfy { TuilageDImageLongue.tientDansUneTexture($0.taille) })
    }

    @Test("La bande entiere, elle, depasse la limite de texture")
    func bandeEntiereAuDessusDeLaLimite() {
        #expect(TuilageDImageLongue.tientDansUneTexture(bandeDuCritere) == false)
        #expect(tuilage.doitTuiler(bandeDuCritere))
    }

    @Test("Les tuiles couvrent la bande exactement, sans trou ni recouvrement")
    func couvertureExacte() {
        for hauteur in [2049, 4096, 12345, 16384, 20000, 32768] {
            let taille = TailleEnPixels(largeur: 720, hauteur: hauteur)
            let decoupes = tuilage.decoupes(de: taille)

            #expect(decoupes.first?.origineY == 0)
            #expect(decoupes.last?.lignes.upperBound == hauteur)
            #expect(decoupes.reduce(0) { $0 + $1.taille.hauteur } == hauteur)

            for (rang, decoupe) in decoupes.enumerated() {
                #expect(decoupe.index == rang)
                #expect(decoupe.taille.largeur == 720)

                if rang > 0 {
                    #expect(decoupe.origineY == decoupes[rang - 1].lignes.upperBound)
                }
            }
        }
    }

    @Test("Une page assez courte rend une tuile unique qui la couvre entierement")
    func pageCourteEnUneTuile() {
        let page = TailleEnPixels(largeur: 1200, hauteur: 1800)
        let decoupes = tuilage.decoupes(de: page)

        #expect(tuilage.doitTuiler(page) == false)
        #expect(decoupes.count == 1)
        #expect(decoupes.first?.taille == page)
    }

    @Test("Une taille nulle ne rend aucune tuile")
    func tailleNulleSansTuile() {
        #expect(tuilage.decoupes(de: .nulle).isEmpty)
        #expect(tuilage.nombreDeTuiles(pour: .nulle) == 0)
        #expect(tuilage.doitTuiler(.nulle) == false)
        #expect(TuilageDImageLongue.tientDansUneTexture(.nulle) == false)
    }

    @Test("Une hauteur de tuile plus haute que la regle est ramenee a 2048")
    func hauteurDeTuilePlafonnee() {
        #expect(TuilageDImageLongue(hauteurDeTuile: 8000).hauteurDeTuile == 2048)
        #expect(TuilageDImageLongue(hauteurDeTuile: 0).hauteurDeTuile == 1)
        #expect(TuilageDImageLongue(hauteurDeTuile: 512).hauteurDeTuile == 512)
    }

    // MARK: Extraction

    @Test("Chaque tuile porte les lignes de la bande, dans l ordre du haut vers le bas")
    func tuilesFidelesALaBande() throws {
        let taille = TailleEnPixels(largeur: 32, hauteur: 5000)
        let bande = try #require(BandeLongue.page(taille: taille))
        let tuiles = tuilage.tuiles(de: bande)
        let decoupes = tuilage.decoupes(de: taille)

        #expect(tuiles.count == 3)

        for (rang, tuile) in tuiles.enumerated() {
            let matrice = try #require(MatriceDeGris(tuile.image))

            #expect(matrice.hauteur == decoupes[rang].taille.hauteur)
            #expect(BandeLongue.lignesFausses(dans: matrice, origineY: decoupes[rang].origineY) == 0)
        }
    }

    @Test("Une tuile lue par son rang est celle de la decoupe du meme rang")
    func tuileParRang() throws {
        let taille = TailleEnPixels(largeur: 32, hauteur: 5000)
        let bande = try #require(BandeLongue.page(taille: taille))

        let deuxieme = try #require(tuilage.tuile(1, de: bande))
        let matrice = try #require(MatriceDeGris(deuxieme.image))

        #expect(matrice.hauteur == 2048)
        #expect(BandeLongue.lignesFausses(dans: matrice, origineY: 2048) == 0)
        #expect(tuilage.tuile(3, de: bande) == nil)
        #expect(tuilage.tuile(-1, de: bande) == nil)
    }

    @Test("Une tuile pese sa propre matrice et non celle de la bande")
    func tuileDetacheeDeLaBande() throws {
        let taille = TailleEnPixels(largeur: 256, hauteur: 5000)
        let bande = try #require(BandeLongue.page(taille: taille))
        let tuile = try #require(tuilage.tuile(0, de: bande))

        // Une tuile qui garderait la bande vivante derriere elle rendrait le
        // budget de tuiles vivantes purement decoratif.
        #expect(tuile.octetsEnMemoire < bande.octetsEnMemoire / 2)
        #expect(tuile.image.height == 2048)
    }

    // MARK: Decodage a la largeur de colonne

    @Test("Une bande de 20000 pixels se decode en tuiles toutes affichables")
    func decodageDeLaBandeDuCritere() throws {
        let octets = BandeLongue.octets(taille: TailleEnPixels(largeur: 300, hauteur: 20000))

        #expect(octets.isEmpty == false)

        let bande = try DecodeurDePage().decoderEnTuiles(octets, nom: "bande.png", largeurDeColonne: 300)

        #expect(bande.tailleDOrigine == TailleEnPixels(largeur: 300, hauteur: 20000))
        #expect(bande.tailleDecodee == TailleEnPixels(largeur: 300, hauteur: 20000))
        #expect(bande.nombreDeTuiles == 10)
        #expect(bande.tuilesAffichables)
        #expect(TuilageDImageLongue.tientDansUneTexture(bande.tailleDecodee) == false)
        #expect(bande.decoupes.reduce(0) { $0 + $1.taille.hauteur } == 20000)
    }

    @Test("Les tuiles servies par la bande decodee portent les bonnes lignes")
    func tuilesDeLaBandeDecodee() throws {
        let octets = BandeLongue.octets(taille: TailleEnPixels(largeur: 64, hauteur: 5000))

        #expect(octets.isEmpty == false)

        let bande = try DecodeurDePage().decoderEnTuiles(octets, nom: "bande.png", largeurDeColonne: 64)
        let derniere = try #require(bande.tuile(bande.nombreDeTuiles - 1))
        let matrice = try #require(MatriceDeGris(derniere.image))

        #expect(bande.nombreDeTuiles == 3)
        #expect(matrice.hauteur == 5000 - 2 * 2048)
        #expect(BandeLongue.lignesFausses(dans: matrice, origineY: 2 * 2048) == 0)
        #expect(bande.tuile(bande.nombreDeTuiles) == nil)
    }

    @Test("La bande est decodee a la largeur de la colonne, pas a son plus grand cote")
    func bandeDecodeeALaColonne() throws {
        let octets = BandeLongue.octets(taille: TailleEnPixels(largeur: 1200, hauteur: 9000))

        #expect(octets.isEmpty == false)

        let bande = try DecodeurDePage().decoderEnTuiles(octets, nom: "bande.png", largeurDeColonne: 600)

        #expect(bande.tailleDecodee.largeur == 600)
        #expect(bande.tailleDecodee.hauteur == 4500)
        #expect(bande.nombreDeTuiles == 3)
    }

    @Test("Le decodage n agrandit jamais une bande plus etroite que la colonne")
    func bandeJamaisAgrandie() throws {
        let octets = BandeLongue.octets(taille: TailleEnPixels(largeur: 200, hauteur: 3000))

        #expect(octets.isEmpty == false)

        let bande = try DecodeurDePage().decoderEnTuiles(octets, nom: "bande.png", largeurDeColonne: 900)

        #expect(bande.tailleDecodee == TailleEnPixels(largeur: 200, hauteur: 3000))
    }

    @Test("La largeur demandee au decodeur est bornee par la limite de texture")
    func colonneBorneeParLaLimiteDeTexture() {
        #expect(DecodeurDePage.colonneRetenue(40000) == TuilageDImageLongue.limiteDeTexture)
        #expect(DecodeurDePage.colonneRetenue(0) == 1)
        #expect(DecodeurDePage.colonneRetenue(800) == 800)
    }

    @Test("Une bande trop lourde pour le budget est sous echantillonnee, jamais refusee")
    func bandeAuDessusDuBudget() {
        let bande = TailleEnPixels(largeur: 2000, hauteur: 40000)
        let etroit = BudgetDeDecodage(octetsParPage: 8_000_000)

        let cote = DecodeurDePage.coteADecoder(pour: bande, colonne: 2000, budget: etroit)
        let reduite = BudgetDeDecodage.reduction(de: bande, vers: cote)

        #expect(cote < bande.hauteur)
        #expect(BudgetDeDecodage.octetsOccupes(par: reduite) < etroit.octetsParPage)
    }

    @Test("Le budget de bande laisse passer la bande du critere sans la reduire")
    func budgetDeBandeSuffisant() {
        let cote = DecodeurDePage.coteADecoder(
            pour: bandeDuCritere,
            colonne: bandeDuCritere.largeur,
            budget: .bandeDeWebtoon
        )

        #expect(cote == bandeDuCritere.hauteur)
    }
}
