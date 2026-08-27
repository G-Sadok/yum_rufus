import Core
import DesignSystem

//
// Libelles de la gestion des prereglages, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDePanneauDeFiltres.duCatalogue` : le paquet
// DesignSystem sait quel libelle va ou, l application sait lequel c est.
//
// La table des valeurs de menu couvre les trois enumerations que le resume
// d une ligne peut nommer. Le sens vertical y figure bien qu il ne soit pas au
// menu Sens de lecture : un prereglage en defilement continu applique ce sens
// la, et son resume doit pouvoir le dire.
//

extension LibellesDePrereglages {
    /// Textes de l ecran de gestion des prereglages.
    static var duCatalogue: LibellesDePrereglages {
        LibellesDePrereglages(
            titre: Chaines.Prereglages.titre,
            enregistrerLActuel: Chaines.Prereglages.enregistrerLActuel,
            description: Chaines.Prereglages.description,
            options: Chaines.Prereglages.options,
            appliquer: Chaines.Prereglages.appliquer,
            renommer: Chaines.Prereglages.renommer,
            remplacerParLActuel: Chaines.Prereglages.remplacerParLActuel,
            supprimer: Chaines.Prereglages.supprimer,
            videTitre: Chaines.Prereglages.videTitre,
            videPhrase: Chaines.Prereglages.videPhrase,
            valeursDeMenu: valeursDeMenu
        )
    }

    /// Libelle de chaque valeur qu un resume de ligne peut porter.
    private static var valeursDeMenu: [String: String] {
        let brutes = SensDeLecture.allCases.map(\.rawValue)
            + MiseEnPage.allCases.map(\.rawValue)
            + ChoixDeFondDuLecteur.allCases.map(\.rawValue)

        return brutes.reduce(into: [String: String]()) { table, brute in
            table[brute] = Chaines.Prereglages.valeur(brute)
        }
    }
}
