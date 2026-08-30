import Core
import Foundation
import ImagePipeline
import Testing
@testable import Intelligence

//
// Couvre l acteur de detection de cases, section 8 du cahier de developpement.
//
// Le premier critere de la fonctionnalite se joue en deux endroits. L ordre de
// lecture lui meme est eprouve dans `CaseDePageTests`, cote modele, et le
// parcours dans `NavigationParCasesTests`, cote moteur. Ce fichier verifie le
// troisieme maillon, celui qu on oublie : que l acteur applique bien le sens
// qu on lui passe, et qu il l applique a la lecture du cache et non a son
// remplissage. Un cache indexe par sens relancerait le reseau sur toute la serie
// au premier changement de sens, ce qui est le genre de defaut qui ne se voit
// jamais en test manuel.
//
// Les trois regles de filtrage sont eprouvees separement du reseau, parce qu
// elles ne doivent dependre d aucun reseau : un modele qui rendrait des cadres
// doubles, ou une longue queue de detections faibles, ne doit pas ajouter
// d etapes de navigation qui ne menent nulle part.
//

struct DetecteurDeCasesTests {
    // MARK: L ordre rendu suit le sens de lecture

    @Test("Les cases sont rendues dans l ordre du sens demande")
    func lOrdreSuitLeSens() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 0)

        let droiteGauche = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        let gaucheDroite = try await detecteur.cases(de: planche, pour: cle, sens: .gaucheDroite)

        #expect(droiteGauche.count == 4)
        #expect(droiteGauche.first == CasesDeTest.hautDroite)
        #expect(gaucheDroite.first == CasesDeTest.hautGauche)
        #expect(droiteGauche != gaucheDroite)
        #expect(Set(droiteGauche) == Set(gaucheDroite))
    }

    @Test("Changer de sens rerange les cases sans relancer le reseau")
    func leChangementDeSensNeRelancePasLeReseau() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 3)

        for sens in SensDeLecture.allCases {
            _ = try await detecteur.cases(de: planche, pour: cle, sens: sens)
        }

        #expect(modele.nombreDAppels == 1)
        await #expect(detecteur.nombreDeDetections == 1)
    }

    // MARK: Le resultat n est jamais recalcule

    @Test("Une planche deja detectee ressort du cache")
    func laPlancheDejaDetecteeRessortDuCache() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 1)

        let premiere = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        let seconde = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)

        #expect(premiere == seconde)
        #expect(modele.nombreDAppels == 1)
        await #expect(detecteur.nombreDePlanchesRetenues == 1)
    }

    @Test("Deux planches differentes passent chacune par le reseau")
    func deuxPlanchesPassentChacuneUneFois() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let chapitre = UUID()

        for index in 0..<3 {
            _ = try await detecteur.cases(
                de: planche,
                pour: ClePage(chapitre: chapitre, index: index),
                sens: .droiteGauche
            )
        }

        #expect(modele.nombreDAppels == 3)
        await #expect(detecteur.nombreDePlanchesRetenues == 3)
    }

    @Test("Oublier une planche la fait repasser par le reseau, vider les fait toutes repasser")
    func lOubliRelanceLaDetection() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 2)

        _ = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        await detecteur.oublier(cle)
        _ = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)

        #expect(modele.nombreDAppels == 2)

        await detecteur.vider()

        await #expect(detecteur.nombreDePlanchesRetenues == 0)
    }

    @Test("Le cache ne retient jamais plus de planches que son plafond")
    func leCacheResteSousSonPlafond() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let detecteur = DetecteurDeCases(modele: modele, plafondDuCache: 2)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let chapitre = UUID()

        for index in 0..<5 {
            _ = try await detecteur.cases(
                de: planche,
                pour: ClePage(chapitre: chapitre, index: index),
                sens: .droiteGauche
            )
        }

        await #expect(detecteur.nombreDePlanchesRetenues == 2)
    }

    @Test("Une planche sans case detectee est retenue comme les autres")
    func laPlancheMuetteEstRetenue() async throws {
        let modele = DetecteurFige(rendues: [])
        let detecteur = DetecteurDeCases(modele: modele)
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 0)

        let premiere = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        let seconde = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)

        #expect(premiere.isEmpty)
        #expect(seconde.isEmpty)
        #expect(modele.nombreDAppels == 1)
    }

    // MARK: Les trois regles de filtrage

    @Test("Une detection sous le seuil de confiance est ecartee")
    func leSeuilEcarteLesCadresDouteux() throws {
        let sure = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: 0.9))
        let douteuse = try #require(
            CaseDePage(abscisse: 0.55, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4, confiance: 0.2)
        )

        let retenues = DetecteurDeCases.retenir(
            [sure, douteuse],
            seuil: 0.5,
            recouvrementMaximal: 0.5
        )

        #expect(retenues == [sure])
    }

    @Test("Deux cadres poses sur la meme case n en font qu un, le plus sur")
    func leRecouvrementFondLesDoublons() throws {
        let sure = try #require(CaseDePage(abscisse: 0.5, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: 0.95))
        let doublon = try #require(
            CaseDePage(abscisse: 0.51, ordonnee: 0.06, largeur: 0.4, hauteur: 0.4, confiance: 0.7)
        )
        let voisine = try #require(
            CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: 0.8)
        )

        let retenues = DetecteurDeCases.retenir(
            [doublon, voisine, sure],
            seuil: 0.5,
            recouvrementMaximal: 0.5
        )

        #expect(retenues.count == 2)
        #expect(retenues.contains(sure))
        #expect(retenues.contains(voisine))
        #expect(retenues.contains(doublon) == false)
    }

    @Test("Le filtrage ne depend pas de l ordre de sortie du reseau")
    func leFiltrageNeDependPasDeLOrdreDArrivee() {
        let cases = CasesDeTest.grille()
        let reference = DetecteurDeCases.retenir(cases, seuil: 0.5, recouvrementMaximal: 0.5)
        let inverse = DetecteurDeCases.retenir(
            cases.reversed(),
            seuil: 0.5,
            recouvrementMaximal: 0.5
        )

        #expect(reference.isEmpty == false)
        #expect(reference == inverse)
    }

    // MARK: Les echecs laissent la page lisible

    @Test("Une planche plus lourde que le budget est refusee avant le reseau")
    func laPlancheTropLourdeEstRefusee() async throws {
        let modele = DetecteurFige(rendues: CasesDeTest.grille())
        let budget = BudgetDeTraitementIA(octetsParPage: 512 * 512 * 4)
        let detecteur = DetecteurDeCases(modele: modele, budget: budget)
        let planche = try #require(PagesDeTest.decodee(largeur: 1024, hauteur: 1024))
        let cle = ClePage(chapitre: UUID(), index: 0)

        await #expect(throws: ErreurDeTraitementIA.self) {
            _ = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        }

        #expect(modele.nombreDAppels == 0)
    }

    @Test("Un reseau en echec ne fait pas tomber la lecture")
    func leReseauEnEchecNeFaitPasTomberLaLecture() async throws {
        let detecteur = DetecteurDeCases(modele: DetecteurEnEchec())
        let planche = try #require(PagesDeTest.decodee(largeur: 64, hauteur: 96))
        let cle = ClePage(chapitre: UUID(), index: 0)

        await #expect(throws: ErreurDeTraitementIA.self) {
            _ = try await detecteur.cases(de: planche, pour: cle, sens: .droiteGauche)
        }

        let repli = await detecteur.casesOuAucune(de: planche, pour: cle, sens: .droiteGauche)

        #expect(repli.isEmpty)
    }

    // MARK: La cle de cache

    @Test("La cle de cache porte le nom du modele, jamais le sens de lecture")
    func laCleDeCachePorteLeModele() {
        let modele = DetecteurFige(rendues: [])
        let page = ClePage(chapitre: UUID(), index: 4, variante: "l=1200")
        let cle = DetecteurDeCases.cle(pour: page, modele: modele)

        #expect(cle.chapitre == page.chapitre)
        #expect(cle.index == page.index)
        #expect(cle.variante.contains("l=1200"))
        #expect(cle.variante.contains(modele.identifiant))

        for sens in SensDeLecture.allCases {
            #expect(cle.variante.contains(sens.rawValue) == false, "\(sens)")
        }
    }

    @Test("Deux modeles differents ne se partagent pas le cache")
    func deuxModelesNeSePartagentPasLeCache() {
        let premier = DetecteurFige(identifiant: "detecteur-un", rendues: [])
        let second = DetecteurFige(identifiant: "detecteur-deux", rendues: [])
        let page = ClePage(chapitre: UUID(), index: 0)

        #expect(
            DetecteurDeCases.cle(pour: page, modele: premier)
                != DetecteurDeCases.cle(pour: page, modele: second)
        )
    }
}
