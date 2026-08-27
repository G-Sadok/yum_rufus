import Foundation
import Testing
@testable import DesignSystem

//
// Couvre l intercalaire de chapitre et l ecran de fin de serie, sections 5.8 et
// 7.4.
//
// Les quatre valeurs de l intercalaire sont comparees a la ligne du document
// elle meme, jamais a une copie. Une modification du separateur dans
// DESIGN-SPEC.md qui n arriverait pas jusqu au code fait alors virer la suite au
// rouge, ce qui est le but.
//

struct EnchainementDeChapitresDansLaVueTests {
    private let libellesDeFin = LibellesDeFinDeSerie(
        titre: "Vous avez fini cette serie",
        phrase: "Le chapitre %@ etait le dernier publie. Revenez a la fiche pour suivre la serie.",
        phraseSansNumero: "Vous avez lu le dernier chapitre publie. Revenez a la fiche pour suivre la serie.",
        revenirALaFiche: "Revenir a la fiche"
    )

    private let libellesDeChapitre = LibellesDeChapitre(
        chapitreNumerote: "Chapitre %@",
        lu: "Lu",
        nombreDePages: "%lld pages",
        pageSurTotal: "page %1$lld sur %2$lld",
        telecharge: "Telecharge",
        etiquetteDeTelechargement: "Telecharge"
    )

    // MARK: Intercalaire

    @Test("Le separateur de chapitre porte les valeurs du document")
    func valeursDuSeparateur() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Separateur de chapitre")
        )

        #expect(ligne.contains("1 px"))
        #expect(ligne.contains("30 pour cent"))
        #expect(ligne.contains("footnote"))
        #expect(ligne.contains("text.tertiary"))
        #expect(ligne.contains("32"))

        #expect(Jetons.Enchainement.epaisseurDuFilet == 1)
        #expect(Jetons.Enchainement.opaciteDuFilet == 0.3)
        #expect(Jetons.Enchainement.margeVerticale == 32)
        #expect(Jetons.Enchainement.numero == Jetons.Typo.footnote)
    }

    @Test("La hauteur de l intercalaire est celle de ses deux marges et de sa ligne")
    func hauteurDeLIntercalaire() {
        #expect(
            Jetons.Enchainement.hauteurDeLIntercalaire
                == 2 * Jetons.Enchainement.margeVerticale + Jetons.Typo.footnote.interlignage
        )
    }

    @Test("La marge verticale du separateur vient de l echelle d espacement")
    func margeDansLEchelle() {
        #expect(Jetons.Espace.echelle.contains(Jetons.Enchainement.margeVerticale))
    }

    @Test("L intercalaire annonce le chapitre entrant, numero compris")
    func titreDeLIntercalaire() {
        let entier = String(format: libellesDeChapitre.chapitreNumerote, TexteDeChapitre.numero(118))
        let bonus = String(format: libellesDeChapitre.chapitreNumerote, TexteDeChapitre.numero(10.5))

        #expect(entier == "Chapitre 118")
        #expect(bonus.hasPrefix("Chapitre 10"))
        #expect(bonus != "Chapitre 10")
    }

    // MARK: Fin de serie

    @Test("La phrase de fin de serie nomme le dernier chapitre lu")
    func phraseAvecNumero() {
        let phrase = TexteDeFinDeSerie.phrase(dernierChapitre: 118, libelles: libellesDeFin)

        #expect(phrase == "Le chapitre 118 etait le dernier publie. Revenez a la fiche pour suivre la serie.")
    }

    @Test("Une fin de serie sans numero connu ne laisse pas de trou dans la phrase")
    func phraseSansNumero() {
        let phrase = TexteDeFinDeSerie.phrase(dernierChapitre: nil, libelles: libellesDeFin)

        #expect(phrase == libellesDeFin.phraseSansNumero)
        #expect(phrase.contains("%") == false)
    }

    @Test("Les textes de fin de serie suivent les regles d ecriture de la section 6")
    func reglesDEcriture() {
        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")
        let textes = [
            libellesDeFin.titre,
            libellesDeFin.phrase,
            libellesDeFin.phraseSansNumero,
            libellesDeFin.revenirALaFiche,
        ]

        for texte in textes {
            #expect(texte.contains("!") == false)
            #expect(texte.contains(tiretCadratin) == false)
        }
    }

    @Test("Le retour propose est celui que le document emploie deja dans le lecteur")
    func memeMotQueLeDocument() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Le defilement s est arrete a 38 pour cent")
        )

        #expect(ligne.contains(libellesDeFin.revenirALaFiche))
    }

    @Test("L ecran de fin de serie n emprunte ni le glyphe ni le ton d une erreur")
    func aucunTonDErreur() {
        #expect(Jetons.Enchainement.glypheDeFinDeSerie != Jetons.Icone.erreurDeContenu)
        #expect(libellesDeFin.revenirALaFiche.isEmpty == false)
    }
}
