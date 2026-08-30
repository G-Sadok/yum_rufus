import Testing
@testable import Core

//
// Couvre le premier critere de la fonctionnalite : le texte traduit reste
// lisible et ne deborde pas de la bulle.
//
// Le critere se decoupe en trois affirmations verifiables, et chacune a ses
// tests ici.
//
// Ne pas deborder veut dire que toute ligne rendue tient dans la largeur utile
// et que le bloc entier tient dans la hauteur utile. C est verifie sur chaque
// composition produite, y compris celles que l algorithme a du couper, et sur
// des textes choisis pour attaquer les bords : un mot plus large que la bulle,
// un texte trois fois trop long, une bulle minuscule.
//
// Rester lisible veut dire que le corps rendu ne descend jamais sous le
// plancher du gabarit. C est la contrainte qui rend le debordement difficile a
// eviter, et c est pourquoi elle est testee en meme temps que lui plutot
// qu apres.
//
// Preferer le plus grand corps qui entre veut dire que l algorithme ne se
// contente pas du plancher. Sans ce troisieme point, un algorithme qui ecrirait
// tout en onze points passerait les deux premiers.
//

struct MiseEnPageDeBulleTests {
    let mesure = MesureAChasseFixe()
    let gabarit = GabaritDeBulle.deTest

    /// Verifie qu une composition ne sort pas de sa bulle, ligne par ligne.
    private func verifierQueRienNeDeborde(
        _ composition: TexteDeBulleMisEnPage,
        _ localisation: SourceLocation = #_sourceLocation
    ) {
        for ligne in composition.lignes {
            let largeur = mesure.largeur(de: ligne, corps: composition.corps)

            #expect(
                largeur <= composition.largeurUtile,
                "la ligne \(ligne) deborde en largeur",
                sourceLocation: localisation
            )
        }

        #expect(
            composition.hauteurDuBloc <= composition.hauteurUtile,
            "le bloc deborde en hauteur",
            sourceLocation: localisation
        )
    }

    // MARK: Le texte ne deborde jamais

    @Test("Un texte court tient sur une bulle large sans etre coupe")
    func leTexteCourtTientEnEntier() {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 200, hauteur: 100)
        let composition = MiseEnPageDeBulle.composer(
            "Je reviendrai demain",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.estTronque == false)
        #expect(composition.lignes.isEmpty == false)
        #expect(composition.texte.contains("reviendrai"))
        verifierQueRienNeDeborde(composition)
    }

    @Test("Un texte trop long pour la bulle est coupe plutot que deborde")
    func leTexteTropLongEstCoupe() {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 90, hauteur: 40)
        let long = String(repeating: "Ce que tu dis ne change rien a ce qui arrive. ", count: 6)
        let composition = MiseEnPageDeBulle.composer(
            long,
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.estTronque)
        #expect(composition.corps == gabarit.corpsMinimal)
        verifierQueRienNeDeborde(composition)
    }

    @Test("La marque de coupe elle meme ne fait pas deborder la derniere ligne")
    func laMarqueDeCoupeNeDebordePas() throws {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 80, hauteur: 30)
        let composition = MiseEnPageDeBulle.composer(
            "Il faut que je te parle de ce qui est arrive hier soir au pont",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        let derniere = try #require(composition.lignes.last)

        #expect(composition.estTronque)
        #expect(derniere.hasSuffix(gabarit.marqueDeTroncature))
        verifierQueRienNeDeborde(composition)
    }

    @Test("Un mot plus large que la bulle est coupe au caractere")
    func leMotTropLargeEstCoupeAuCaractere() {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 60, hauteur: 120)
        let composition = MiseEnPageDeBulle.composer(
            "Kraaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaboooooooooooooom",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.lignes.count > 1)
        verifierQueRienNeDeborde(composition)
    }

    @Test("Une bulle trop petite pour un seul caractere ne rend rien")
    func laBulleMinusculeNeRendRien() {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 9, hauteur: 9)
        let composition = MiseEnPageDeBulle.composer(
            "Non",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.estVide)
        #expect(composition.estTronque)
        verifierQueRienNeDeborde(composition)
    }

    @Test("Une bulle sans surface ne rend rien et ne plante pas")
    func laBulleSansSurfaceNeRendRien() {
        let cadre = CadreEnPoints(abscisse: 0.5, ordonnee: 0.5, largeur: 0, hauteur: 0)
        let composition = MiseEnPageDeBulle.composer(
            "Attention",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.estVide)
        #expect(composition.largeurUtile == 0)
    }

    // MARK: Le texte reste lisible

    @Test("Le corps rendu ne descend jamais sous le plancher du gabarit")
    func leCorpsResteAuDessusDuPlancher() {
        let tailles = [30.0, 60, 90, 140, 260]
        let textes = [
            "Oui",
            "Je ne te laisserai pas partir seul",
            String(repeating: "un mot de plus ", count: 20),
        ]

        for largeur in tailles {
            for texte in textes {
                let cadre = CadreEnPoints(
                    abscisse: 0,
                    ordonnee: 0,
                    largeur: largeur,
                    hauteur: largeur
                )
                let composition = MiseEnPageDeBulle.composer(
                    texte,
                    dans: cadre,
                    gabarit: gabarit,
                    mesure: mesure
                )

                #expect(composition.corps >= gabarit.corpsMinimal)
                #expect(composition.corps <= gabarit.corpsMaximal)
                verifierQueRienNeDeborde(composition)
            }
        }
    }

    // MARK: Le plus grand corps qui entre est retenu

    @Test("Une bulle spacieuse recoit le plus grand corps du gabarit")
    func laBulleSpacieuseRecoitLePlusGrandCorps() {
        let cadre = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 300, hauteur: 200)
        let composition = MiseEnPageDeBulle.composer(
            "Merci",
            dans: cadre,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(composition.corps == gabarit.corpsMaximal)
    }

    @Test("Une bulle serree descend d un cran plutot que de couper")
    func laBulleSerreeDescendAvantDeCouper() {
        let texte = "Reviens ici tout de suite"
        let large = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 300, hauteur: 200)
        let serree = CadreEnPoints(abscisse: 0, ordonnee: 0, largeur: 92, hauteur: 44)

        let auLarge = MiseEnPageDeBulle.composer(
            texte,
            dans: large,
            gabarit: gabarit,
            mesure: mesure
        )
        let auSerre = MiseEnPageDeBulle.composer(
            texte,
            dans: serree,
            gabarit: gabarit,
            mesure: mesure
        )

        #expect(auSerre.corps < auLarge.corps)
        #expect(auSerre.estTronque == false)
        verifierQueRienNeDeborde(auSerre)
    }

    @Test("Les corps essayes vont du plus grand au plancher, sans le franchir")
    func lesCorpsEssayesDescendentJusquAuPlancher() {
        let corps = gabarit.corpsEssayes

        #expect(corps.first == gabarit.corpsMaximal)
        #expect(corps.last == gabarit.corpsMinimal)
        #expect(corps.allSatisfy { $0 >= gabarit.corpsMinimal })
        #expect(corps == corps.sorted(by: >))
    }

    // MARK: Le repli des lignes

    @Test("Le repli coupe aux espaces et ne perd aucun mot")
    func leRepliNePerdAucunMot() {
        let texte = "un deux trois quatre cinq six sept huit"
        let lignes = MiseEnPageDeBulle.decouper(
            texte,
            largeur: 60,
            corps: 12,
            mesure: mesure
        )

        #expect(lignes.count > 1)
        #expect(lignes.joined(separator: " ") == texte)
    }
}
