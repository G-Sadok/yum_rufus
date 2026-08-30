import Core
import Testing
@testable import Intelligence

/// Couvre la traversee des pixels : la page entre en image, sort en image, et
/// passe entre les deux par la matrice puis par le tampon que Core ML attend.
///
/// Ce fichier existe pour les deux fautes qui ne se voient pas a la relecture et
/// qui abiment toute la planche : la permutation des canaux entre RGBX et BGRA,
/// et la longueur de ligne d un tampon Core Video, qui n est pas sa largeur. Les
/// motifs de test portent trois valeurs differentes par pixel precisement pour
/// qu une permutation ne puisse pas passer.
struct MatriceDePixelsTests {
    @Test("Une matrice passee en image et relue reste la meme")
    func allerRetourParUneImage() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 37, hauteur: 23))
        let image = try #require(matrice.image)
        let relue = try #require(MatriceDePixels(image))

        #expect(relue.taille == matrice.taille)
        #expect(EcartsDePixels.maximum(relue, matrice) == 0)
    }

    @Test("Une matrice passee par un tampon Core Video garde ses canaux")
    func allerRetourParUnTampon() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 70, hauteur: 40))
        let tampon = try #require(TamponDePixels.creer(matrice))
        let relue = try #require(TamponDePixels.matrice(de: tampon))

        #expect(relue.taille == matrice.taille)
        #expect(EcartsDePixels.maximum(relue, matrice) == 0)
    }

    @Test("Une portion demandee hors de la matrice est refusee")
    func portionHorsMatriceRefusee() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 32, hauteur: 32))

        #expect(matrice.extraire(
            origineX: 16,
            origineY: 0,
            taille: TailleEnPixels(largeur: 20, hauteur: 8)
        ) == nil)
        #expect(matrice.extraire(
            origineX: -1,
            origineY: 0,
            taille: TailleEnPixels(largeur: 8, hauteur: 8)
        ) == nil)
    }

    @Test("Une portion prise dans la matrice porte les bons pixels")
    func portionFidele() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 32, hauteur: 32))
        let portion = try #require(matrice.extraire(
            origineX: 8,
            origineY: 4,
            taille: TailleEnPixels(largeur: 12, hauteur: 6)
        ))

        #expect(portion.taille == TailleEnPixels(largeur: 12, hauteur: 6))

        for ligne in 0..<6 {
            for colonne in 0..<12 {
                #expect(
                    portion.canal(0, colonne: colonne, ligne: ligne)
                        == matrice.canal(0, colonne: colonne + 8, ligne: ligne + 4)
                )
            }
        }
    }

    @Test("Une matrice trop petite est completee par recopie du bord")
    func remplissageParRecopieDuBord() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 10, hauteur: 6))
        let remplie = matrice.remplie(jusqua: 16)

        #expect(remplie.taille == TailleEnPixels(largeur: 16, hauteur: 16))

        for ligne in 0..<16 {
            for colonne in 0..<16 {
                let attendue = matrice.canal(0, colonne: min(colonne, 9), ligne: min(ligne, 5))

                #expect(remplie.canal(0, colonne: colonne, ligne: ligne) == attendue)
            }
        }
    }

    @Test("Une matrice deja assez grande n est pas recopiee")
    func remplissageSansEffet() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 20, hauteur: 20))

        #expect(matrice.remplie(jusqua: 16) == matrice)
    }

    @Test("Le rognage rend le coin superieur gauche")
    func rognageAuCoin() throws {
        let matrice = try #require(PagesDeTest.damier(largeur: 20, hauteur: 20))
        let rognee = try #require(matrice.rognee(a: TailleEnPixels(largeur: 12, hauteur: 9)))

        #expect(rognee.taille == TailleEnPixels(largeur: 12, hauteur: 9))
        #expect(matrice.rognee(a: TailleEnPixels(largeur: 40, hauteur: 9)) == nil)
    }
}

/// Couvre les poids du fondu, dont depend l absence de raccord.
struct RampeDeFonduTests {
    @Test("Un bord de page ne recoit aucune rampe")
    func bordDePageSansRampe() {
        let poids = RampeDeFondu.poids(longueur: 64, fondu: 8, debutLibre: true, finLibre: true)

        #expect(poids.count == 64)
        #expect(poids.allSatisfy { $0 == 1 })
    }

    @Test("Un bord partage descend jusqu au bord sans jamais l atteindre")
    func bordPartageDescend() {
        let poids = RampeDeFondu.poids(longueur: 64, fondu: 8, debutLibre: false, finLibre: false)

        #expect(abs((poids.first ?? 0) - 1.0 / 9.0) < 0.0001)
        #expect(abs((poids.last ?? 0) - 1.0 / 9.0) < 0.0001)
        #expect(poids.allSatisfy { $0 > 0 })
        #expect(poids[32] == 1)

        for rang in 1...8 {
            #expect(poids[rang] > poids[rang - 1])
        }
    }

    @Test("Le fondu du projet fait deux fois le recouvrement en sortie")
    func fonduEnSortie() {
        let tuilage = TuilageDeTraitement.parDefaut
        let facteur = 2
        let poids = RampeDeFondu.poids(
            longueur: tuilage.cote * facteur,
            fondu: tuilage.recouvrement * facteur,
            debutLibre: false,
            finLibre: false
        )

        #expect(poids[32] == 1)
        #expect(poids[31] < 1)
    }
}
