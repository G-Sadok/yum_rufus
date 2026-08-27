import Core
import Foundation
import Testing

//
// Couvre les trois regles de domaine de la gestion du stockage.
//
// Deux des trois criteres d acceptation se jouent ici, et le troisieme pour
// moitie.
//
// Le second, la suppression automatique respecte le reglage, est une fonction
// pure : les quatre valeurs du tableau 6.7 entrent, une liste de chapitres sort,
// et rien d autre n intervient. Un test qui la couvre couvre la regle elle meme,
// pas une observation de son effet.
//
// Le troisieme, aucune suppression sans confirmation, tient a la garde. Elle ne
// rend une cible que si la demande a ete posee, ce qui ferme le chemin d une
// confirmation qui arriverait seule.
//

struct AssemblageDesPostesTests {
    private func chapitre(_ titre: String, numero: Double, estLu: Bool = false) -> ContenuDePoste {
        .chapitre(
            ChapitreDeStockage(
                chapitreId: UUID(),
                titreDeLaSerie: titre,
                numeroDeChapitre: numero,
                estLu: estLu
            )
        )
    }

    @Test("Un pesage nomme devient un poste qui porte son poids et son element")
    func unPesageNommeDevientUnPoste() {
        let postes = AssemblageDesPostes.postes(
            depuis: [PesageSurDisque(nom: "alpha", octets: 32_000_000)]
        ) { _ in chapitre("Serie", numero: 43) }

        #expect(postes.count == 1)
        #expect(postes[0].id == "alpha")
        #expect(postes[0].octets == 32_000_000)
        #expect(postes[0].elements == ["alpha"])
    }

    @Test("Les elements que rien ne nomme forment un poste unique qui les compte")
    func lesAnonymesFormentUnPosteUnique() {
        let postes = AssemblageDesPostes.postes(
            depuis: [
                PesageSurDisque(nom: "a1b2", octets: 300),
                PesageSurDisque(nom: "c3d4", octets: 700),
            ]
        ) { _ in nil }

        #expect(postes.count == 1)
        #expect(postes[0].id == AssemblageDesPostes.clesDesAnonymes)
        #expect(postes[0].contenu == .elementsAnonymes(nombre: 2))
        #expect(postes[0].octets == 1000)
        #expect(postes[0].elements == ["a1b2", "c3d4"])
    }

    @Test("Un element que la base ne connait plus garde son poids au lieu de disparaitre")
    func lInconnuNEstJamaisPerdu() {
        let pesages = [
            PesageSurDisque(nom: "connu", octets: 100),
            PesageSurDisque(nom: "inconnu", octets: 900),
        ]

        let postes = AssemblageDesPostes.postes(depuis: pesages) { nom in
            nom == "connu" ? chapitre("Serie", numero: 1) : nil
        }

        #expect(postes.reduce(0) { $0 + $1.octets } == 1000)
        #expect(postes.contains { $0.id == AssemblageDesPostes.clesDesAnonymes })
    }

    @Test("Les postes sont ranges du plus lourd au plus leger")
    func lOrdreVaDuPlusLourdAuPlusLeger() {
        let pesages = [
            PesageSurDisque(nom: "petit", octets: 10),
            PesageSurDisque(nom: "gros", octets: 1000),
            PesageSurDisque(nom: "moyen", octets: 500),
        ]

        let postes = AssemblageDesPostes.postes(depuis: pesages) { _ in .source(nom: "Serveur") }

        #expect(postes.map(\.id) == ["gros", "moyen", "petit"])
    }

    @Test("Deux postes de meme poids gardent un ordre total, jamais tire au sort")
    func lOrdreResteTotal() {
        let pesages = [
            PesageSurDisque(nom: "b", octets: 10),
            PesageSurDisque(nom: "a", octets: 10),
        ]

        let premiers = AssemblageDesPostes.postes(depuis: pesages) { _ in .source(nom: "Serveur") }
        let seconds = AssemblageDesPostes.postes(depuis: pesages.reversed()) { _ in
            .source(nom: "Serveur")
        }

        #expect(premiers.map(\.id) == ["a", "b"])
        #expect(premiers.map(\.id) == seconds.map(\.id))
    }

    @Test("Un inventaire neuf porte les trois categories a zero, jamais un ecran vide")
    func lInventaireNeufPorteLesTroisCategories() {
        for categorie in CategorieDeStockage.allCases {
            #expect(InventaireDuStockage.vide.octets(de: categorie) == 0)
        }

        #expect(InventaireDuStockage.vide.octetsTotal == 0)
        #expect(CategorieDeStockage.allCases.count == 3)
    }

    @Test("Le total d un detail est la somme de ses postes")
    func leTotalEstLaSommeDesPostes() {
        let detail = DetailDuStockage(
            categorie: .chapitresTelecharges,
            postes: [
                PosteDeStockage(id: "a", contenu: .source(nom: "A"), octets: 12, elements: ["a"]),
                PosteDeStockage(id: "b", contenu: .source(nom: "B"), octets: 30, elements: ["b"]),
            ]
        )

        #expect(detail.octets == 42)
        #expect(detail.elements == ["a", "b"])
    }
}

/// Couvre le second critere : la suppression automatique respecte le reglage.
struct SuppressionAutomatiqueDesTelechargementsTests {
    private let maintenant = Date(timeIntervalSince1970: 1_700_000_000)

    private func lu(ilYA secondes: TimeInterval) -> TelechargementLu {
        TelechargementLu(
            chapitreId: UUID(),
            dateLecture: maintenant.addingTimeInterval(-secondes)
        )
    }

    private var jour: TimeInterval {
        24 * 60 * 60
    }

    @Test("Les quatre valeurs du tableau 6.7 sont couvertes, une seule ne supprime rien")
    func lesQuatreValeursDuTableau() {
        #expect(SuppressionApresLecture.allCases.count == 4)
        #expect(SuppressionApresLecture.jamais.delaiApresLecture == nil)
        #expect(SuppressionApresLecture.immediatement.delaiApresLecture == 0)
        #expect(SuppressionApresLecture.apres1Jour.delaiApresLecture == jour)
        #expect(SuppressionApresLecture.apres7Jours.delaiApresLecture == 7 * jour)
    }

    @Test("Jamais ne supprime rien, quelle que soit l anciennete de la lecture")
    func jamaisNeSupprimeRien() {
        let lus = [lu(ilYA: 0), lu(ilYA: 365 * jour)]

        let vises = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: lus,
            reglage: .jamais,
            maintenant: maintenant
        )

        #expect(vises.isEmpty)
    }

    @Test("Immediatement supprime tout ce qui est lu, date connue ou non")
    func immediatementSupprimeTout() {
        let sansDate = TelechargementLu(chapitreId: UUID(), dateLecture: nil)
        let lus = [lu(ilYA: 0), sansDate]

        let vises = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: lus,
            reglage: .immediatement,
            maintenant: maintenant
        )

        #expect(vises.count == 2)
    }

    @Test("Apres 1 jour ne prend que ce qui a passe la journee entiere")
    func apresUnJourAttendLeDelai() {
        let recent = lu(ilYA: jour - 1)
        let echu = lu(ilYA: jour)
        let ancien = lu(ilYA: 3 * jour)

        let vises = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: [recent, echu, ancien],
            reglage: .apres1Jour,
            maintenant: maintenant
        )

        #expect(vises == [echu.chapitreId, ancien.chapitreId])
    }

    @Test("Apres 7 jours garde ce qu Apres 1 jour aurait deja supprime")
    func lesDeuxDelaisNeSeConfondentPas() {
        let lus = [lu(ilYA: 2 * jour)]

        let unJour = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: lus,
            reglage: .apres1Jour,
            maintenant: maintenant
        )
        let septJours = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: lus,
            reglage: .apres7Jours,
            maintenant: maintenant
        )

        #expect(unJour.count == 1)
        #expect(septJours.isEmpty)
    }

    @Test("Un chapitre lu sans date n est jamais efface par un reglage a delai")
    func laDateInconnueNeVautPasUneDateAncienne() {
        let sansDate = TelechargementLu(chapitreId: UUID(), dateLecture: nil)

        for reglage in [SuppressionApresLecture.apres1Jour, .apres7Jours] {
            let vises = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
                parmi: [sansDate],
                reglage: reglage,
                maintenant: maintenant
            )

            #expect(vises.isEmpty, "\(reglage)")
        }
    }
}

/// Couvre le troisieme critere : aucune suppression n est possible sans
/// confirmation.
struct GardeDeSuppressionTests {
    private func demande(_ nombre: Int = 2) -> DemandeDeSuppression {
        DemandeDeSuppression(
            categorie: .chapitresTelecharges,
            elements: (0..<nombre).map { "element-\($0)" },
            octets: 1000,
            nombreDePostes: nombre
        )
    }

    @Test("Une garde neuve ne demande rien et ne rend rien")
    func uneGardeNeuveNeRendRien() {
        var garde = GardeDeSuppression()

        #expect(garde.estDemandee == false)
        #expect(garde.confirmer() == nil)
    }

    @Test("Une confirmation qui arrive sans demande ne supprime rien")
    func laConfirmationSeuleNeSupprimeRien() {
        var garde = GardeDeSuppression()

        #expect(garde.confirmer() == nil)
        #expect(garde.confirmer() == nil)
    }

    @Test("La demande ouvre la modale et la confirmation rend exactement ce qui a ete demande")
    func laDemandeVoyageAvecLaConfirmation() {
        var garde = GardeDeSuppression()
        let posee = demande()

        garde.demander(posee)

        #expect(garde.estDemandee)
        #expect(garde.confirmer() == posee)
    }

    @Test("Une confirmation ne vaut qu une fois, un second appel ne supprime rien")
    func laConfirmationNeVautQuUneFois() {
        var garde = GardeDeSuppression()

        garde.demander(demande())

        #expect(garde.confirmer() != nil)
        #expect(garde.confirmer() == nil)
    }

    @Test("Annuler referme la demande sans rien rendre")
    func annulerNeRendRien() {
        var garde = GardeDeSuppression()

        garde.demander(demande())
        garde.annuler()

        #expect(garde.estDemandee == false)
        #expect(garde.confirmer() == nil)
    }

    @Test("Une demande vide n ouvre aucune modale")
    func laDemandeVideNOuvreRien() {
        var garde = GardeDeSuppression()

        garde.demander(DemandeDeSuppression(categorie: .cacheDImages, postes: []))

        #expect(garde.estDemandee == false)
        #expect(garde.confirmer() == nil)
    }

    @Test("Une demande deplie les postes en noms de disque au moment ou elle est posee")
    func laDemandeDeplieLesPostes() {
        let postes = [
            PosteDeStockage(
                id: "groupe",
                contenu: .elementsAnonymes(nombre: 2),
                octets: 300,
                elements: ["a", "b"]
            ),
            PosteDeStockage(id: "c", contenu: .source(nom: "Serveur"), octets: 700, elements: ["c"]),
        ]

        let demande = DemandeDeSuppression(categorie: .cacheDImages, postes: postes)

        #expect(demande.elements == ["a", "b", "c"])
        #expect(demande.octets == 1000)
        #expect(demande.nombreDePostes == 2)
    }
}

/// Selection multiple d un ecran de detail, section 4.5.
struct SelectionDePostesTests {
    private func postes(_ cles: [String]) -> [PosteDeStockage] {
        cles.map {
            PosteDeStockage(id: $0, contenu: .source(nom: $0), octets: 10, elements: [$0])
        }
    }

    @Test("La barre n existe pas tant que la selection est vide")
    func laBarreSuitLaSelection() {
        var selection = SelectionDePostes()

        #expect(selection.barreEstOuverte == false)

        selection.basculer("a")

        #expect(selection.barreEstOuverte)
        #expect(selection.nombre == 1)
    }

    @Test("Un second appui retire le poste de la selection")
    func basculerRetireAussi() {
        var selection = SelectionDePostes()

        selection.basculer("a")
        selection.basculer("a")

        #expect(selection.estVide)
    }

    @Test("Une suppression qui aboutit referme la barre au lieu de la laisser ouverte")
    func laSelectionSeResserreSurCeQuiReste() {
        var selection = SelectionDePostes()

        selection.toutSelectionner(postes(["a", "b"]))
        selection.restreindre(a: postes(["b"]))

        #expect(selection.nombre == 1)
        #expect(selection.contient("b"))

        selection.restreindre(a: [])

        #expect(selection.barreEstOuverte == false)
    }

    @Test("Les postes retenus sortent dans l ordre de la liste affichee")
    func lOrdreVientDeLaListe() {
        var selection = SelectionDePostes()
        let affiches = postes(["gros", "moyen", "petit"])

        selection.basculer("petit")
        selection.basculer("gros")

        #expect(selection.postesRetenus(dans: affiches).map(\.id) == ["gros", "petit"])
    }
}
