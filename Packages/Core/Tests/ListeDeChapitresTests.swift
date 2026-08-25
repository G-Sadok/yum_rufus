import Core
import Foundation
import Testing

/// Verifie le filtre, le tri et la selection multiple de la liste des chapitres,
/// sections 5.6 et 4.5 de DESIGN-SPEC.md.
struct ListeDeChapitresTests {
    // MARK: Filtre

    @Test("Le filtre par defaut ne retire rien")
    func filtreParDefaut() {
        let chapitres = ChapitresDeTest.lesQuatreEtats()
        let retenus = ReglageDeListeDeChapitres.defaut.appliquer(a: chapitres)

        #expect(retenus.count == chapitres.count)
        #expect(ReglageDeListeDeChapitres.defaut.filtre == .tous)
    }

    @Test("Le filtre Non lus garde aussi les chapitres commences")
    func filtreNonLus() {
        let chapitres = ChapitresDeTest.lesQuatreEtats()
        let reglage = ReglageDeListeDeChapitres(filtre: .nonLus)

        let etats = reglage.appliquer(a: chapitres).map(\.lecture)

        #expect(etats.allSatisfy { $0 != .lu })
        #expect(etats.contains(.enCours), "Un chapitre commence reste a lire")
        #expect(etats.contains(.nonLu))
    }

    @Test("Le filtre Lus ne garde que les chapitres termines")
    func filtreLus() {
        let retenus = ReglageDeListeDeChapitres(filtre: .lus)
            .appliquer(a: ChapitresDeTest.lesQuatreEtats())

        #expect(retenus.allSatisfy { $0.lecture == .lu })
        #expect(retenus.count == 1)
    }

    @Test("Le filtre Telecharges ne regarde pas l etat de lecture")
    func filtreTelecharges() {
        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, estTelecharge: true),
            ChapitresDeTest.chapitre(rang: 1, estLu: true, estTelecharge: true),
            ChapitresDeTest.chapitre(rang: 2),
        ]

        let retenus = ReglageDeListeDeChapitres(filtre: .telecharges).appliquer(a: chapitres)

        // La condition est evaluee avant l attente : la macro #expect refuse un
        // appel a allSatisfy avec un chemin de cle, qu elle voit comme
        // potentiellement lancant.
        let tousTelecharges = retenus.allSatisfy(\.estTelecharge)

        #expect(retenus.count == 2)
        #expect(tousTelecharges)
    }

    // MARK: Tri

    @Test("Le tri par defaut va du plus recent au plus ancien, comme le wireframe 04")
    func triParDefaut() {
        let chapitres = ChapitresDeTest.serie(de: 4)
        let ordonnes = ReglageDeListeDeChapitres.defaut.appliquer(a: chapitres)

        #expect(ordonnes.map(\.numero) == [4, 3, 2, 1])
        #expect(ReglageDeListeDeChapitres.defaut.ordre == .decroissant)
        #expect(ReglageDeListeDeChapitres.defaut.critere == .numero)
    }

    @Test("Le sens du tri s inverse sans changer le critere")
    func triCroissant() {
        let ordonnes = ReglageDeListeDeChapitres(ordre: .croissant)
            .appliquer(a: ChapitresDeTest.serie(de: 4))

        #expect(ordonnes.map(\.numero) == [1, 2, 3, 4])
    }

    @Test("Deux chapitres de meme numero gardent l ordre de la serie")
    func numerosEgaux() {
        let chapitres = [
            ChapitresDeTest.chapitre(rang: 1, numero: 10),
            ChapitresDeTest.chapitre(rang: 0, numero: 10),
        ]

        let ordonnes = ReglageDeListeDeChapitres(ordre: .croissant).appliquer(a: chapitres)

        #expect(ordonnes.map(\.ordreDansSerie) == [0, 1])
    }

    @Test("Le tri par date range les chapitres sans date en fin de liste")
    func triParDate() {
        let ancien = Date(timeIntervalSinceReferenceDate: 1000)
        let recent = Date(timeIntervalSinceReferenceDate: 2000)

        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, numero: 1, datePublication: ancien),
            ChapitresDeTest.chapitre(rang: 1, numero: 2),
            ChapitresDeTest.chapitre(rang: 2, numero: 3, datePublication: recent),
        ]

        let ordonnes = ReglageDeListeDeChapitres(critere: .datePublication)
            .appliquer(a: chapitres)

        #expect(ordonnes.map(\.numero) == [3, 1, 2])
    }

    @Test("Le tri est total, deux lectures rendent le meme ordre")
    func triStable() {
        let chapitres = ChapitresDeTest.serie(de: 12)
        let reglage = ReglageDeListeDeChapitres(critere: .datePublication)

        let premier = reglage.appliquer(a: chapitres).map(\.id)
        let second = reglage.appliquer(a: chapitres.shuffled()).map(\.id)

        #expect(premier == second)
    }

    // MARK: Selection multiple

    @Test("La barre d actions n existe pas tant que rien n est selectionne")
    func barreFermeeSansSelection() {
        let selection = SelectionDeChapitres()

        #expect(selection.estVide)
        #expect(selection.barreEstOuverte == false)
        #expect(selection.actionsDisponibles.isEmpty)
        #expect(selection.nombre == 0)
    }

    @Test("Un premier chapitre selectionne ouvre la barre et ses trois actions")
    func barreOuverteParUneSelection() throws {
        let chapitres = ChapitresDeTest.serie(de: 3)
        var selection = SelectionDeChapitres()

        try selection.basculer(#require(chapitres.first).id)

        #expect(selection.barreEstOuverte)
        #expect(selection.nombre == 1)
        #expect(
            selection.actionsDisponibles == [.marquerLu, .telecharger, .supprimer],
            "Les trois actions de la section 4.5, dans l ordre du document"
        )
    }

    @Test("Le second clic sur un chapitre le retire et referme la barre")
    func selectionVideeReferme() throws {
        let chapitre = try #require(ChapitresDeTest.serie(de: 1).first)
        var selection = SelectionDeChapitres()

        selection.basculer(chapitre.id)
        selection.basculer(chapitre.id)

        #expect(selection.estVide)
        #expect(selection.barreEstOuverte == false)
    }

    @Test("Maj clic etend la selection depuis l ancre, dans l ordre affiche")
    func extensionDepuisLAncre() {
        let chapitres = ChapitresDeTest.serie(de: 5)
        var selection = SelectionDeChapitres()

        selection.basculer(chapitres[1].id)
        selection.etendre(jusqua: chapitres[3].id, dans: chapitres)

        #expect(selection.nombre == 3)
        #expect(selection.contient(chapitres[2].id))
        #expect(selection.contient(chapitres[0].id) == false)
        #expect(selection.contient(chapitres[4].id) == false)
    }

    @Test("Une extension vers le haut retient la meme etendue")
    func extensionVersLeHaut() {
        let chapitres = ChapitresDeTest.serie(de: 5)
        var selection = SelectionDeChapitres()

        selection.basculer(chapitres[3].id)
        selection.etendre(jusqua: chapitres[1].id, dans: chapitres)

        #expect(selection.nombre == 3)
        #expect(selection.contient(chapitres[2].id))
    }

    @Test("Sans ancre, Maj clic vaut une selection simple")
    func extensionSansAncre() {
        let chapitres = ChapitresDeTest.serie(de: 3)
        var selection = SelectionDeChapitres()

        selection.etendre(jusqua: chapitres[2].id, dans: chapitres)

        #expect(selection.nombre == 1)
        #expect(selection.contient(chapitres[2].id))
    }

    @Test("Un changement de filtre ne laisse pas la barre ouverte sur du vide")
    func selectionRestreinteAuFiltre() {
        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, estLu: true),
            ChapitresDeTest.chapitre(rang: 1),
        ]

        var selection = SelectionDeChapitres()
        selection.toutSelectionner(chapitres)

        let apresFiltre = ReglageDeListeDeChapitres(filtre: .lus).appliquer(a: chapitres)
        selection.restreindre(a: apresFiltre)

        #expect(selection.nombre == 1)
        #expect(selection.contient(chapitres[0].id))
        #expect(selection.barreEstOuverte)
    }

    @Test("Un filtre qui ne laisse rien passer referme la barre")
    func selectionVideeParLeFiltre() {
        let chapitres = ChapitresDeTest.serie(de: 3)

        var selection = SelectionDeChapitres()
        selection.toutSelectionner(chapitres)
        selection.restreindre(a: ReglageDeListeDeChapitres(filtre: .lus).appliquer(a: chapitres))

        #expect(selection.barreEstOuverte == false)
        #expect(selection.ancre == nil)
    }

    @Test("Supprimer est la seule action destructive")
    func actionDestructive() {
        let destructives = SelectionDeChapitres.actions.filter(\.estDestructive)

        #expect(destructives == [.supprimer])
    }
}
