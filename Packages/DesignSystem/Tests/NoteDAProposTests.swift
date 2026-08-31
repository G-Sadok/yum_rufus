import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre le troisieme critere de la fonctionnalite : la mention de provenance
// apparait dans la section A propos.
//
// La mention traverse trois objets avant d atteindre l ecran. Le catalogue des
// modeles la produit, dans le paquet Intelligence. Le catalogue de chaines de
// l application la porte, sous la cle `reglages.note`. La vue la pose, sous la
// derniere carte de la colonne. Chacun de ces objets est verifie chez lui : le
// paquet Intelligence compare la chaine du catalogue a sa fiche, ce fichier
// verifie qu elle arrive bien sous la carte A propos et nulle part ailleurs.
//
// Le point qui merite un test plutot qu une relecture est la place. La note
// n appartient a aucune ligne et a aucune section : la vue la pose apres la
// derniere carte de la colonne. Elle ne ferme donc la section A propos que
// parce que A propos est la derniere section du tableau de la section 5.5. Le
// jour ou une dix huitieme section arrive, la note se retrouve sous elle, et
// c est ce cas la que le premier test attrape.
//

struct NoteDAProposTests {
    // MARK: La note ferme bien la section A propos

    @Test("A propos est la derniere section, donc la note posee apres les cartes la ferme")
    func laNoteFermeLaSectionAPropos() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "La section A propos se termine par une note")
        )

        #expect(ligne.contains("sous la carte"))
        #expect(SectionDeReglages.allCases.last == .aPropos)
        #expect(SectionDeReglages.aPropos.rang == SectionDeReglages.allCases.count)
    }

    @Test("La note est en caption, comme le document l ecrit")
    func laNoteEstEnCaption() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "La section A propos se termine par une note")
        )

        #expect(ligne.contains("`caption`"))
        #expect(ligne.contains("`text.quaternary`"))
        #expect(Jetons.CarteDeReglages.note == Jetons.Typo.caption)
    }

    // MARK: La note porte la provenance du jeu de donnees

    @Test("La note affichee est celle du catalogue de chaines, sous la cle reglages.note")
    func laNoteVientDuCatalogue() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let note = try #require(catalogue["reglages.note"])
        let libelles = try Self.libellesDuCatalogue()

        #expect(libelles.noteDeFin == note)
        #expect(libelles.noteDeFin.isEmpty == false)
    }

    @Test("La note dit la provenance du jeu de donnees du detecteur de cases et sa licence")
    func laNoteDitLaProvenanceEtLaLicence() throws {
        let libelles = try Self.libellesDuCatalogue()

        #expect(libelles.noteDeFin.contains("Detection de cases"))
        #expect(libelles.noteDeFin.contains("Digital Comic Museum"))
        #expect(libelles.noteDeFin.contains("CC0"))
    }

    /// La note et la description de la section sont deux textes distincts, et
    /// aucun des deux ne doit chasser l autre. Le tableau 6.8 donne la
    /// description, sur la responsabilite des sources, la section 9 du cahier de
    /// developpement donne la note, sur la provenance du jeu de donnees.
    @Test("La note ne remplace pas la description de la carte A propos")
    func laNoteNeRemplacePasLaDescription() throws {
        let libelles = try Self.libellesDuCatalogue()
        let description = try #require(libelles.description(de: .aPropos))
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Sous la carte A propos")
        )

        #expect(ligne.contains(description))
        #expect(description != libelles.noteDeFin)
        #expect(description.contains("Digital Comic Museum") == false)
    }

    @Test("La note suit les regles d ecriture de la section 6")
    func laNoteSuitLesReglesDEcriture() throws {
        let libelles = try Self.libellesDuCatalogue()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        #expect(libelles.noteDeFin.contains("!") == false)
        #expect(libelles.noteDeFin.contains(tiretCadratin) == false)
        #expect(libelles.noteDeFin.hasSuffix("."))
    }

    // MARK: Materiel des cas

    /// Libelles de l ecran Reglages tels que le catalogue les porte.
    ///
    /// Seules les entrees que ce fichier eprouve sont remplies. Les autres
    /// restent vides : les completer ici les figerait une seconde fois, et
    /// c est la suite des reglages qui a la charge de les comparer au tableau
    /// de la section 5.5.
    private static func libellesDuCatalogue() throws -> LibellesDeReglages {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDeReglages(
            titresDeSection: [.aPropos: catalogue["reglages.section.aPropos"] ?? ""],
            libellesDeLigne: [:],
            descriptionsDeSection: [.aPropos: catalogue["reglages.description.aPropos"] ?? ""],
            valeursDeMenu: [:],
            noteDeFin: catalogue["reglages.note"] ?? "",
            augmenter: "",
            diminuer: ""
        )
    }
}
