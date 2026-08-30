import Core
import Testing

//
// Couvre le dernier critere de F064 : l architecture n empeche pas l ajout
// ulterieur d une langue de droite a gauche.
//
// Un critere de ce genre ne se verifie pas en relisant le code, il se verifie
// en montrant que le seul geste demande par l ajout est l ajout lui meme. Les
// tests ci dessous tiennent ce raisonnement en deux temps. D abord la direction
// ne s ecrit nulle part a la main, elle se deduit du code de langue. Ensuite la
// deduction est deja juste pour des langues que le projet ne livre pas, l arabe
// en tete, ce qui veut dire qu aucune condition ne reste a ecrire le jour ou
// l une d elles entrera dans l enumeration.
//

struct LangueDeLInterfaceTests {
    // MARK: Les quatre langues de la version un

    @Test("Le projet livre les quatre langues de la section 13 du cahier")
    func quatreLangues() {
        #expect(LangueDeLInterface.allCases.map(\.codeBCP47) == ["fr", "en", "es", "ja"])
    }

    @Test("Le francais est la langue source du catalogue")
    func langueSource() {
        #expect(LangueDeLInterface.source == .francais)
        #expect(LangueDeLInterface.source.codeBCP47 == "fr")
    }

    // MARK: Direction de l interface

    @Test(
        "Aucune des quatre langues livrees ne dispose l interface de droite a gauche",
        arguments: LangueDeLInterface.allCases
    )
    func directionDesLanguesLivrees(langue: LangueDeLInterface) {
        #expect(langue.directionDInterface == .gaucheDroite)
    }

    @Test(
        "La direction se deduit du code de langue, y compris pour une langue non livree",
        arguments: ["ar", "he", "fa", "ur", "ar-EG", "he_IL"]
    )
    func directionDUneLangueNonLivree(code: String) {
        #expect(DirectionDInterface.pourLangue(code) == .droiteGauche)
    }

    @Test(
        "Le jour ou une langue de droite a gauche est ajoutee, elle repond sans autre changement"
    )
    func ajoutDUneLangueDeDroiteAGauche() {
        // On ne peut pas ajouter un cas a une enumeration depuis un test. On
        // verifie donc ce dont l ajout dependrait : que la direction d une
        // langue se calcule a partir de son seul code BCP 47, exactement comme
        // `LangueDeLInterface.directionDInterface` le fait pour les quatre
        // langues livrees. Ecrire `case arabe = "ar"` suffirait alors.
        let codeQuUneLangueArabePorterait = "ar"

        #expect(
            DirectionDInterface.pourLangue(codeQuUneLangueArabePorterait) == .droiteGauche
        )
        #expect(
            LangueDeLInterface.francais.directionDInterface
                == DirectionDInterface.pourLangue(LangueDeLInterface.francais.codeBCP47)
        )
    }

    // MARK: Le menu Langue est plus large que les langues livrees

    @Test("Chaque langue livree est atteignable depuis le menu Langue du tableau 6.7")
    func menuCouvreLesLanguesLivrees() {
        let atteignables = Set(ChoixDeLangue.allCases.compactMap(\.langueDeLInterface))

        #expect(atteignables == Set(LangueDeLInterface.allCases))
    }

    @Test("Les deux entrees de menu sans catalogue le disent au lieu de le taire")
    func entreesSansCatalogue() {
        // Systeme delegue le choix a l appareil, Deutsch n est qu une langue
        // cible de traduction. Ni l une ni l autre ne designe un catalogue.
        #expect(ChoixDeLangue.systeme.langueDeLInterface == nil)
        #expect(ChoixDeLangue.deutsch.langueDeLInterface == nil)
    }
}
