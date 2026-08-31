import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre le panneau de filtres du lecteur, section 5.7 de DESIGN-SPEC.md.
//
// Les valeurs sont comparees a la phrase du document elle meme, jamais a une
// copie. Une largeur changee dans DESIGN-SPEC.md qui n arriverait pas jusqu au
// code fait alors virer la suite au rouge, ce qui est le but.
//

/// La suite construit des vues, qui sont isolees au fil principal. Le
/// compilateur local le deduisait seul, celui de l integration continue exige
/// que ce soit ecrit, comme NavigationDeCoquilleTests le fait deja.
@MainActor
struct PanneauDeFiltresDansLaVueTests {
    /// Phrase du document qui decrit le panneau en entier.
    private func phraseDuPanneau() throws -> String {
        try #require(try SpecificationDeDesign.ligne(contenant: "Panneau de filtres"))
    }

    /// Libelles tels que le catalogue de l application les porte.
    private func libellesDuCatalogue() throws -> LibellesDePanneauDeFiltres {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDePanneauDeFiltres(
            titre: catalogue["filtres.titre"] ?? "",
            libellesDeFiltre: Dictionary(
                uniqueKeysWithValues: FiltreDImage.allCases.map {
                    ($0, catalogue["filtres.\($0.rawValue)"] ?? "")
                }
            ),
            libellesDeTraitement: Dictionary(
                uniqueKeysWithValues: TraitementDImage.allCases.map {
                    ($0, catalogue["filtres.\($0.rawValue)"] ?? "")
                }
            ),
            etiquetteDeLaCouronne: catalogue["reglages.couronne"] ?? ""
        )
    }

    // MARK: Jetons

    @Test("La geometrie du panneau est celle du document")
    func geometrieDuDocument() throws {
        let phrase = try phraseDuPanneau()

        #expect(phrase.contains("largeur 300"))
        #expect(phrase.contains("rayon 14"))
        #expect(phrase.contains("elevation 1"))

        #expect(Jetons.PanneauDeFiltres.largeur == 300)
        #expect(Jetons.PanneauDeFiltres.rayon == 14)
        #expect(Jetons.PanneauDeFiltres.elevation == .flottant)
        #expect(Jetons.PanneauDeFiltres.elevation.rawValue == 1)
    }

    @Test("Le panneau n emprunte aucune mesure hors des sections 1.6, 1.7 et 4.1")
    func mesuresEmpruntees() {
        #expect(Jetons.Rayon.echelle.contains(Jetons.PanneauDeFiltres.rayon))
        #expect(Jetons.Espace.echelle.contains(Jetons.PanneauDeFiltres.margeVerticale))
        #expect(Jetons.Espace.echelle.contains(Jetons.PanneauDeFiltres.ecartAvantLeControle))

        #expect(Jetons.PanneauDeFiltres.hauteurDInterrupteur == Jetons.LigneDeReglage.hauteur)
        #expect(
            Jetons.PanneauDeFiltres.hauteurDeCurseur == Jetons.LigneDeReglage.hauteurAvecDescription
        )
        #expect(Jetons.PanneauDeFiltres.margeLaterale == Jetons.LigneDeReglage.margeLaterale)
    }

    // MARK: Composition

    @Test("Le panneau range cinq curseurs puis trois interrupteurs, comme le document")
    func compositionDuDocument() throws {
        let phrase = try phraseDuPanneau()

        #expect(phrase.contains("Curseurs Luminosite, Chaleur, Nettete, Contraste, Gamma"))
        #expect(phrase.contains("Interrupteurs Reduction du bruit, Amelioration IA, Colorisation IA"))
        #expect(phrase.contains("Separateur"))

        #expect(FiltreDImage.ordreDuPanneau == [.luminosite, .chaleur, .nettete, .contraste, .gamma])
        #expect(TraitementDImage.ordreDuPanneau == [.reductionDuBruit, .ameliorationIA, .colorisationIA])
        #expect(FiltreDImage.ordreDuPanneau.count == FiltreDImage.allCases.count)
        #expect(TraitementDImage.ordreDuPanneau.count == TraitementDImage.allCases.count)
    }

    @Test("L ordre du panneau n est pas celui de la chaine de traitement")
    func ordreDistinctDeLaChaine() {
        // La section 5.7 met la luminosite en tete, la section 6.3 la place
        // neuvieme. Confondre les deux ordres appliquerait les filtres dans
        // l ordre du panneau, ce qui se voit sur la planche et ne leve rien.
        let ordreDuPanneau = FiltreDImage.ordreDuPanneau.map(\.etape)

        #expect(ordreDuPanneau != ordreDuPanneau.dansLOrdreDeLaChaine)
    }

    // MARK: Verrouillage premium

    @Test("Les deux traitements par IA portent une couronne sans abonnement")
    func couronneSansAbonnement() throws {
        let phrase = try phraseDuPanneau()

        #expect(phrase.contains("Colorisation IA est verrouillee premium"))
        #expect(phrase.contains("couronne"))

        let sansAbonnement = panneau(abonnement: .gratuit)

        #expect(sansAbonnement.estVerrouille(.colorisationIA))
        #expect(sansAbonnement.estVerrouille(.ameliorationIA))
        #expect(sansAbonnement.estVerrouille(.reductionDuBruit) == false)
    }

    @Test("L abonnement rend l interrupteur des traitements par IA")
    func couronneAvecAbonnement() {
        let avecAbonnement = panneau(abonnement: .definitif)

        for traitement in TraitementDImage.allCases {
            #expect(avecAbonnement.estVerrouille(traitement) == false, "\(traitement.rawValue)")
        }
    }

    @Test("Un abonnement expire reverrouille les traitements par IA")
    func couronneApresExpiration() {
        let expire = panneau(abonnement: .expire(le: .distantPast))

        #expect(expire.estVerrouille(.colorisationIA))
        #expect(expire.estVerrouille(.ameliorationIA))
        #expect(expire.estVerrouille(.reductionDuBruit) == false)
    }

    // MARK: Libelles

    @Test("Le catalogue porte les huit libelles nommes par la section 5.7")
    func libellesDuDocument() throws {
        let libelles = try libellesDuCatalogue()

        #expect(libelles.titre == "Filtres")
        #expect(libelles.libelle(de: .luminosite) == "Luminosite")
        #expect(libelles.libelle(de: .chaleur) == "Chaleur")
        #expect(libelles.libelle(de: .nettete) == "Nettete")
        #expect(libelles.libelle(de: .contraste) == "Contraste")
        #expect(libelles.libelle(de: .gamma) == "Gamma")
        #expect(libelles.libelle(de: .reductionDuBruit) == "Reduction du bruit")
        #expect(libelles.libelle(de: .ameliorationIA) == "Amelioration IA")
        #expect(libelles.libelle(de: .colorisationIA) == "Colorisation IA")
        #expect(libelles.etiquetteDeLaCouronne.isEmpty == false)
    }

    @Test("Le titre du panneau est le libelle de l action qui l ouvre")
    func titreRepriseDeLAction() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "| Barre du lecteur |"))

        // Le meme mot pour la meme action du debut a la fin d un parcours,
        // regle d ecriture de la section 6.
        #expect(ligne.contains(libelles.titre))
    }

    @Test("Les libelles du panneau suivent les regles d ecriture de la section 6")
    func reglesDEcriture() throws {
        let libelles = try libellesDuCatalogue()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        let textes = [libelles.titre, libelles.etiquetteDeLaCouronne]
            + FiltreDImage.allCases.map { libelles.libelle(de: $0) }
            + TraitementDImage.allCases.map { libelles.libelle(de: $0) }

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    // MARK: Materiel

    private func panneau(abonnement: EtatDePremium) -> VueDePanneauDeFiltres {
        VueDePanneauDeFiltres(
            reglages: .parDefaut,
            abonnement: abonnement,
            libelles: LibellesDePanneauDeFiltres(
                titre: "Filtres",
                libellesDeFiltre: [:],
                libellesDeTraitement: [:],
                etiquetteDeLaCouronne: "Fonction premium"
            ),
            commandes: .inertes
        )
    }
}
