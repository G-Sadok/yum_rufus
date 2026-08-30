import Foundation
@testable import Intelligence

//
// ModelesDeColorisationDeTest
//
// Modeles de colorisation synthetiques, dont la sortie exacte est connue.
//
// Meme raison d etre que les modeles de surelevation du fichier voisin : aucune
// assertion utile ne peut porter sur un reseau entraine, et les proprietes que
// la fonctionnalite promet ne portent pas sur le reseau. Elles portent sur ce
// qui l entoure, le tuilage, la refonte, la serialisation, le cache et la
// preservation des dimensions.
//
// La teinte est calculee pixel par pixel, sans regarder les voisins. Un tel
// modele rend exactement la meme chose qu il voie la page entiere ou une tuile,
// ce qui permet d exiger l egalite au pixel pres entre la page tuilee et la page
// colorisee d un seul tenant. Toute erreur propre a la recomposition apparait
// alors comme un ecart.
//
// La teinte choisie n est pas decorative. Elle ecarte les trois canaux les uns
// des autres des que le pixel n est pas noir, ce qui rend la mise en couleurs
// mesurable : une page dont les trois canaux etaient egaux ne l est plus, et le
// test le compte au lieu de le regarder.
//

/// Colorisation par teinte fixe, calculee pixel par pixel.
struct ModeleDeTeinte: ModeleDeColorisation {
    let identifiant: String
    let coteDeTuile: Int

    init(
        identifiant: String = "teinte",
        coteDeTuile: Int = TuilageDeTraitement.coteDeTuile
    ) {
        self.identifiant = identifiant
        self.coteDeTuile = coteDeTuile
    }

    func coloriser(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        guard let teintee = OperationsDeTest.teinter(tuile) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        return teintee
    }
}

/// Colorisation qui change les dimensions, ce que le protocole interdit.
///
/// Elle existe pour prouver que la garde de `ColoriseurIA` sait echouer. Sans
/// elle, l assertion qui exige des dimensions inchangees passerait aussi sur un
/// acteur qui ne verifierait rien.
struct ModeleDeColorisationQuiAgrandit: ModeleDeColorisation {
    let identifiant = "colorisation-qui-agrandit"
    let coteDeTuile = TuilageDeTraitement.coteDeTuile
    let facteur = 2

    func coloriser(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        guard let teintee = OperationsDeTest.teinter(tuile),
              let agrandie = OperationsDeTest.agrandir(teintee, facteur: facteur)
        else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        return agrandie
    }
}

/// Modele de colorisation qui journalise ses appels et peut prendre son temps.
struct ModeleDeColorisationSurveille: ModeleDeColorisation {
    let base: any ModeleDeColorisation
    let journal: JournalDeModele

    /// Duree tenue par chaque tuile, pour laisser le temps a deux traitements
    /// de se chevaucher si rien ne les en empeche.
    let attente: TimeInterval

    init(
        base: any ModeleDeColorisation = ModeleDeTeinte(),
        journal: JournalDeModele,
        attente: TimeInterval = 0
    ) {
        self.base = base
        self.journal = journal
        self.attente = attente
    }

    var identifiant: String {
        base.identifiant
    }

    var coteDeTuile: Int {
        base.coteDeTuile
    }

    func coloriser(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        journal.entrer(largeur: tuile.largeur, hauteur: tuile.hauteur)

        defer { journal.sortir() }

        if attente > 0 {
            Thread.sleep(forTimeInterval: attente)
        }

        return try base.coloriser(tuile)
    }
}

extension OperationsDeTest {
    /// Ecarte les trois canaux a partir du seul ton du pixel.
    ///
    /// Le rouge garde le ton, le vert en perd un quart, le bleu la moitie. Un
    /// pixel noir reste noir, tous les autres deviennent colores, et la
    /// transformation est inversible, ce qui permet de comparer deux sorties
    /// sans avoir a decrire une palette.
    static func teinter(_ matrice: MatriceDePixels) -> MatriceDePixels? {
        let parPixel = MatriceDePixels.octetsParPixel
        var octets = matrice.octets

        for ligne in 0..<matrice.hauteur {
            for colonne in 0..<matrice.largeur {
                let depart = (ligne * matrice.largeur + colonne) * parPixel
                let ton = Int(matrice.canal(0, colonne: colonne, ligne: ligne))

                octets[depart] = UInt8(ton)
                octets[depart + 1] = UInt8(ton * 3 / 4)
                octets[depart + 2] = UInt8(ton / 2)
            }
        }

        return MatriceDePixels(largeur: matrice.largeur, hauteur: matrice.hauteur, octets: octets)
    }
}
