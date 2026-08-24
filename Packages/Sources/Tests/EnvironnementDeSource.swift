import Core
import Foundation
import Sources

//
// EnvironnementDeSource
//
// Un dossier de contenu, un magasin de signets range ailleurs, et de quoi
// fabriquer la source avant et apres un redemarrage.
//
// Le magasin vit dans un dossier separe du contenu, exactement comme dans
// l application : les signets sont dans l espace applicatif, le contenu est
// chez l utilisateur. Sans cette separation, supprimer le dossier de contenu
// emporterait le signet et le test ne prouverait plus rien.
//

/// Ce qu il faut pour interroger une source de fichiers locaux dans un test.
final class EnvironnementDeSource {
    static let nomDeLaSource = "Dossier de test"

    let arbre: ArbreDeTest
    let id = SourceID()

    private let espaceApplicatif: ArbreDeTest

    /// Emplacement du fichier de signets, partage par tous les magasins que le
    /// test fabrique.
    private let fichierDeSignets: URL

    init(arbre: ArbreDeTest) throws {
        self.arbre = arbre
        espaceApplicatif = try ArbreDeTest(nom: "espace-applicatif")
        fichierDeSignets = espaceApplicatif.racine.appending(path: "signets.json")
    }

    /// Un magasin neuf sur le meme fichier.
    ///
    /// Chaque appel rend une instance distincte : c est ce qui rend le
    /// redemarrage credible, puisque rien n est retenu en memoire d un appel a
    /// l autre.
    func magasin() -> MagasinDeSignetsFichier {
        MagasinDeSignetsFichier(fichier: fichierDeSignets)
    }

    /// Premiere configuration : l utilisateur choisit le dossier, le signet est
    /// enregistre.
    func sourcePremierLancement(
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut
    ) throws -> SourceFichiersLocaux {
        try SourceFichiersLocaux.enregistrant(
            dossier: arbre.racine,
            id: id,
            nom: Self.nomDeLaSource,
            magasin: magasin(),
            tailleDePage: tailleDePage
        )
    }

    /// Lancement suivant : la source est reconstruite a partir du seul signet,
    /// sans jamais revoir l URL du dossier.
    func sourceApresRedemarrage(
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut
    ) -> SourceFichiersLocaux {
        SourceFichiersLocaux.depuisLeSignet(
            id: id,
            nom: Self.nomDeLaSource,
            magasin: magasin(),
            tailleDePage: tailleDePage
        )
    }

    /// Source d un lancement suivant dont le signet n a jamais ete enregistre.
    func sourceSansSignet() -> SourceFichiersLocaux {
        SourceFichiersLocaux.depuisLeSignet(
            id: SourceID(),
            nom: Self.nomDeLaSource,
            magasin: magasin()
        )
    }
}

/// Arborescence de reference, utilisee par la plupart des tests.
///
///     Serie A/Chapitre 1.cbz, Chapitre 2.cbz, Chapitre 10.cbz
///     Serie B/Ch 01/, Ch 02/, Notes/
///     Serie C/page1.jpg, page2.jpg
///     Tome unique.cbz
///     Dossier vide/, notes.txt, parasites
enum BibliothequeDeTest {
    static func poser(dans arbre: ArbreDeTest) throws {
        try arbre.archive("Serie A/Chapitre 1.cbz", pages: ["page2.jpg", "page10.jpg", "page1.jpg"])
        try arbre.archive("Serie A/Chapitre 2.cbz", pages: ["01.png"])
        try arbre.archive("Serie A/Chapitre 10.cbz", pages: ["01.png"])

        try arbre.image("Serie B/Ch 01/page1.jpg")
        try arbre.image("Serie B/Ch 01/page2.jpg")
        try arbre.image("Serie B/Ch 02/page1.jpg")
        // Un dossier sans image n est pas un chapitre.
        try arbre.fichier("Serie B/Notes/lisezmoi.txt", contenu: Data("texte".utf8))

        // Une serie qui est son propre chapitre : des images posees a plat.
        try arbre.image("Serie C/page1.jpg")
        try arbre.image("Serie C/page2.jpg")

        // Une archive posee a la racine est une serie a un seul chapitre.
        try arbre.archive("Tome unique.cbz", pages: ["01.jpg"])

        // Ce qui doit disparaitre de l analyse.
        try arbre.fichier("Serie A/.DS_Store")
        try arbre.fichier("Serie A/__MACOSX/._Chapitre 1.cbz")
        try arbre.dossier("Dossier vide")
        try arbre.fichier("notes.txt", contenu: Data("texte".utf8))
    }
}
