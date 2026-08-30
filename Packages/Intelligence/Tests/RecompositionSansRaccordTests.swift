import Core
import Testing
@testable import Intelligence

/// Couvre le deuxieme critere de la fonctionnalite : aucun raccord visible entre
/// les tuiles.
///
/// Un raccord ne se prouve pas a l oeil dans une suite de tests. Il se mesure par
/// rapport a la seule reference qui n en porte aucun : la meme page passee au
/// meme modele d un seul tenant, sans decoupage. Un raccord est alors un ecart
/// local entre la page tuilee et cette reference, et il se compte en niveaux.
///
/// Les cas sont batis pour pouvoir echouer. Le modele de flou extrapole a ses
/// bords exactement comme un reseau de convolution, et le meme traitement lance
/// sans recouvrement sert de temoin : il doit montrer le raccord que la version
/// avec recouvrement efface. Sans ce temoin, un test qui mesure un petit ecart
/// ne prouverait rien, puisqu il passerait aussi sur un modele sans bord.
struct RecompositionSansRaccordTests {
    /// Page assez large pour porter deux raccords, assez courte pour tenir en
    /// une seule ligne de tuiles.
    private let largeurDePage = 512
    private let hauteurDePage = 256

    /// Tuilage temoin, tuiles posees bord a bord.
    private let sansRecouvrement = TuilageDeTraitement(cote: 256, recouvrement: 0)

    // MARK: La recomposition n ajoute rien d elle meme

    @Test("Un modele sans voisinage rend exactement la meme page, tuilee ou non")
    func recompositionExacte() throws {
        let modele = ModeleDeRecopie()
        let page = try #require(PagesDeTest.damier(largeur: 700, hauteur: 300))
        let reference = try modele.surelever(page)
        let tuilee = try TraitementParTuiles().traiter(page, avec: modele)

        #expect(tuilee.taille == reference.taille)
        #expect(EcartsDePixels.maximum(tuilee, reference) == 0)
    }

    @Test("Une page plus petite qu une tuile ressort a la bonne taille")
    func pagePlusPetiteQuUneTuile() throws {
        let modele = ModeleDeRecopie()
        let page = try #require(PagesDeTest.rayures(largeur: 40, hauteur: 90))
        let reference = try modele.surelever(page)
        let tuilee = try TraitementParTuiles().traiter(page, avec: modele)

        #expect(tuilee.taille == TailleEnPixels(largeur: 80, hauteur: 180))
        #expect(EcartsDePixels.maximum(tuilee, reference) == 0)
    }

    // MARK: Le raccord d un modele qui extrapole a ses bords

    /// Les deux recompositions sont comparees dans un seul cas, parce que la
    /// mesure coute plusieurs secondes et qu elle est la meme pour les quatre
    /// assertions. La dedoubler ferait payer deux fois le meme flou.
    ///
    /// Les bornes viennent de la mesure et non d une intuition. Sur cette page
    /// de rayures, le temoin sans recouvrement s ecarte de 114 niveaux de la
    /// reference, et la recomposition avec recouvrement de 5. Les bornes sont
    /// posees a 64 et a 8, ce qui laisse de la marge aux deux sans rien laisser
    /// passer : un raccord de 114 niveaux est une ligne franche sur la planche,
    /// un ecart de 5 niveaux est sous le seuil de perception dans une zone
    /// contrastee.
    @Test("Le recouvrement efface le raccord qu un modele a bords laisse")
    func recouvrementEffaceLeRaccord() throws {
        let mesures = try mesurerLesEcarts()

        #expect(mesures.avecRecouvrement <= 8)
        #expect(mesures.sansRecouvrement >= 64)
        #expect(mesures.sansRecouvrement > 8 * mesures.avecRecouvrement)
        #expect(mesures.sansRecouvrementAuRaccord == mesures.sansRecouvrement)
        #expect(mesures.avecRecouvrementAuRaccord <= 8)
    }

    // MARK: Mesure commune

    /// Ecarts a la reference, avec et sans recouvrement.
    private struct Ecarts {
        let avecRecouvrement: Int
        let sansRecouvrement: Int
        let avecRecouvrementAuRaccord: Int
        let sansRecouvrementAuRaccord: Int
    }

    /// Compare les deux recompositions a la page traitee d un seul tenant.
    ///
    /// La colonne du raccord est celle ou le temoin pose deux tuiles bord a
    /// bord, soit le cote de tuile multiplie par le facteur du modele. Les
    /// colonnes voisines sont incluses parce que le flou etale l ecart sur son
    /// rayon.
    private func mesurerLesEcarts() throws -> Ecarts {
        let modele = ModeleDeFlou()
        let page = try #require(PagesDeTest.rayures(largeur: largeurDePage, hauteur: hauteurDePage))
        let reference = try modele.surelever(page)
        let avec = try TraitementParTuiles().traiter(page, avec: modele)
        let sans = try TraitementParTuiles(tuilage: sansRecouvrement).traiter(page, avec: modele)

        let raccord = sansRecouvrement.cote * modele.facteur
        let colonnes = (raccord - 8)..<(raccord + 8)

        return try Ecarts(
            avecRecouvrement: #require(EcartsDePixels.maximum(avec, reference)),
            sansRecouvrement: #require(EcartsDePixels.maximum(sans, reference)),
            avecRecouvrementAuRaccord: #require(
                EcartsDePixels.maximum(avec, reference, colonnes: colonnes)
            ),
            sansRecouvrementAuRaccord: #require(
                EcartsDePixels.maximum(sans, reference, colonnes: colonnes)
            )
        )
    }
}
