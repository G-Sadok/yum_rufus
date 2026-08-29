import Foundation
import Testing
@testable import Core

//
// Couvre le rapprochement d une serie locale avec le catalogue d un service,
// deuxieme critere de la fonctionnalite.
//
// Les cas retenus sont ceux qui ont produit des liaisons fausses dans les
// lecteurs existants : le sous titre absent d un cote, la suite qui porte le
// nom de l original, le remake publie vingt ans plus tard, et le titre traduit
// que le service ne connait que dans sa langue d origine.
//

@Suite("Correspondance avec un service de suivi")
struct CorrespondanceDeSuiviTests {
    @Test("Un titre identique au caractere pres se pose sans confirmation")
    func titreIdentique() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Le Voyage du Heros",
            parmi: [
                SerieDeSuivi(id: "1", titre: "Le Voyage du Heros"),
                SerieDeSuivi(id: "2", titre: "Chroniques du Sud"),
            ]
        )

        #expect(proposition.meilleur?.serie.id == "1")
        #expect(proposition.estCertaine)
        #expect(proposition.demandeUnChoix == false)
    }

    @Test("La casse, les accents et la ponctuation ne changent rien")
    func normalisationDesTitres() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "L Ete a Kyoto",
            parmi: [SerieDeSuivi(id: "42", titre: "L'ete, a Kyoto !")]
        )

        #expect(proposition.meilleur?.serie.id == "42")
        #expect(proposition.estCertaine)
    }

    @Test("Une suite est proposee derriere l original, jamais devant")
    func suiteEtOriginal() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Le Voyage du Heros",
            parmi: [
                SerieDeSuivi(id: "2", titre: "Le Voyage du Heros II"),
                SerieDeSuivi(id: "1", titre: "Le Voyage du Heros"),
            ]
        )

        // Les deux sont proposees, l originale devant. Le titre local
        // correspond au caractere pres a l originale et la suite reste
        // nettement derriere : c est le seul cas ou la proposition se pose
        // seule, et la suite reste a un clic pour la corriger.
        #expect(proposition.candidats.map(\.serie.id) == ["1", "2"])
        #expect(proposition.estCertaine)
    }

    @Test("Deux candidats aussi proches l un que l autre demandent un choix")
    func candidatsExAequo() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Chroniques du Sud",
            parmi: [
                SerieDeSuivi(id: "publication-originale", titre: "Chroniques du Sud"),
                SerieDeSuivi(id: "edition-couleur", titre: "Chroniques du Sud"),
            ]
        )

        // Le service publie deux entrees pour la meme serie, ce qui arrive des
        // qu une edition couleur existe. Poser la premiere venue enverrait la
        // progression sur une entree que l utilisateur ne suit pas.
        #expect(proposition.candidats.count == 2)
        #expect(proposition.demandeUnChoix)
    }

    @Test("Un titre approchant sans egaler ne se pose pas seul")
    func titreApprochant() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Chroniques du Sud Tome Un",
            parmi: [
                SerieDeSuivi(id: "sud", titre: "Chroniques du Sud"),
                SerieDeSuivi(id: "nord", titre: "Chroniques du Nord Tome Un"),
            ]
        )

        #expect(proposition.meilleur?.serie.id == "sud")
        #expect(proposition.demandeUnChoix)
    }

    @Test("L annee departage une serie de son remake")
    func anneeDepartage() {
        let entrees = [
            SerieDeSuivi(id: "ancienne", titre: "Cite de Verre", annee: 1998),
            SerieDeSuivi(id: "remake", titre: "Cite de Verre", annee: 2021),
        ]

        let versLAncienne = CorrespondanceDeSuivi.proposer(
            pourTitre: "Cite de Verre",
            annee: 1998,
            parmi: entrees
        )
        let versLeRemake = CorrespondanceDeSuivi.proposer(
            pourTitre: "Cite de Verre",
            annee: 2021,
            parmi: entrees
        )

        #expect(versLAncienne.meilleur?.serie.id == "ancienne")
        #expect(versLeRemake.meilleur?.serie.id == "remake")
    }

    @Test("Un titre alternatif compte autant que le titre principal")
    func titreAlternatif() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Lame de Lune",
            parmi: [
                SerieDeSuivi(id: "7", titre: "Tsuki no Yaiba", titresAlternatifs: ["Lame de Lune"]),
            ]
        )

        #expect(proposition.meilleur?.serie.id == "7")
        #expect(proposition.estCertaine)
    }

    @Test("Une entree sans rapport n est pas proposee du tout")
    func entreeSansRapport() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Le Voyage du Heros",
            parmi: [SerieDeSuivi(id: "99", titre: "Recettes du dimanche")]
        )

        #expect(proposition.candidats.isEmpty)
        #expect(proposition.meilleur == nil)
        #expect(proposition.demandeUnChoix)
    }

    @Test("Le classement ne depend pas de l ordre d arrivee")
    func classementStable() {
        let entrees = [
            SerieDeSuivi(id: "b", titre: "Chroniques du Sud"),
            SerieDeSuivi(id: "a", titre: "Chroniques du Sud"),
        ]

        let premier = CorrespondanceDeSuivi.proposer(pourTitre: "Chroniques du Sud", parmi: entrees)
        let second = CorrespondanceDeSuivi.proposer(pourTitre: "Chroniques du Sud", parmi: entrees.reversed())

        #expect(premier.candidats.map(\.serie.id) == second.candidats.map(\.serie.id))
        #expect(premier.meilleur?.serie.id == "a")
    }

    @Test("Un titre entierement fait de mots vides reste comparable")
    func titreDeMotsVides() {
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "The End",
            parmi: [
                SerieDeSuivi(id: "fin", titre: "The End"),
                SerieDeSuivi(id: "autre", titre: "The Beginning"),
            ]
        )

        #expect(proposition.meilleur?.serie.id == "fin")
    }

    @Test("La correction manuelle pose la liaison sur l entree choisie")
    func correctionManuelle() {
        let manga = UUID()
        let proposition = CorrespondanceDeSuivi.proposer(
            pourTitre: "Le Voyage du Heros",
            parmi: [
                SerieDeSuivi(id: "1", titre: "Le Voyage du Heros"),
                SerieDeSuivi(id: "2", titre: "Le Voyage du Heros II"),
            ]
        )

        // L utilisateur retient la suite alors que la proposition classait
        // l originale en tete.
        let choix = SerieDeSuivi(id: "2", titre: "Le Voyage du Heros II")
        let liaison = CorrespondanceDeSuivi.liaison(pour: manga, service: .kitsu, vers: choix)

        #expect(proposition.meilleur?.serie.id == "1")
        #expect(liaison.identifiantDistant == "2")
        #expect(liaison.mangaId == manga)
        #expect(liaison.service == .kitsu)
        #expect(liaison.statut == .enLecture)
        #expect(liaison.chapitreVu == 0)
    }

    @Test("Une entree absente de la proposition peut quand meme etre choisie")
    func choixHorsProposition() {
        let manga = UUID()
        let trouveeAlaMain = SerieDeSuivi(id: "301", titre: "Tsuki no Yaiba")
        let liaison = CorrespondanceDeSuivi.liaison(
            pour: manga,
            service: .aniList,
            vers: trouveeAlaMain,
            statut: .relecture,
            chapitreVu: 12
        )

        #expect(liaison.identifiantDistant == "301")
        #expect(liaison.statut == .relecture)
        #expect(liaison.chapitreVu == 12)
    }
}
