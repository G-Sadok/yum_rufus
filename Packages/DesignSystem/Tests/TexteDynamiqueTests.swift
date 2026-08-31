import DesignSystem
import SwiftUI
import Testing

/// Verifie les deux regles de texte dynamique, sections 4.1 et 7 de
/// DESIGN-SPEC.md.
struct TexteDynamiqueTests {
    @Test("Le document borne la prise en charge a accessibilite extra extra large")
    func borneDuDocument() throws {
        let lignes = try SpecificationDeDesign.lignes()

        #expect(
            lignes.contains {
                $0.contains("| Texte dynamique | pris en charge jusqu a accessibilite extra extra large |")
            },
            "La section 7 fixe la borne"
        )

        // Cote systeme, accessibilite extra extra large est `accessibility4` :
        // les cinq crans d accessibilite montent de medium a extra extra extra
        // large, le quatrieme est donc extra extra large.
        #expect(Jetons.TexteDynamique.tailleMaximale == .accessibility4)
        #expect(Jetons.TexteDynamique.tailleMaximale < .accessibility5)
    }

    @Test("La coquille borne l environnement a la taille maximale")
    func coquilleBornee() throws {
        let source = try LectureDuCode.fichier("Packages/DesignSystem/Sources/VueDeCoquille.swift")

        #expect(
            source.contains(".dynamicTypeSize(...Jetons.TexteDynamique.tailleMaximale)"),
            "La coquille pose la borne pour toute l application"
        )
    }

    @Test("Les lignes de reglages passent en pile au dela de large")
    func basculeEnPile() throws {
        let lignes = try SpecificationDeDesign.lignes()

        #expect(
            lignes.contains {
                $0.contains("Au dela de la taille de texte `large`, les lignes de reglages")
                    && $0.contains("disposition verticale")
            },
            "La section 7 fixe le point de bascule"
        )

        #expect(Jetons.TexteDynamique.derniereTailleEnLigne == .large)

        for taille in DynamicTypeSize.allCases where taille <= .large {
            #expect(
                Jetons.TexteDynamique.passeEnPile(taille) == false,
                "\(taille) garde la disposition horizontale"
            )
        }

        for taille in DynamicTypeSize.allCases where taille > .large {
            #expect(
                Jetons.TexteDynamique.passeEnPile(taille),
                "\(taille) impose la disposition verticale"
            )
        }
    }

    @Test("La ligne de reglage applique la regle plutot que de la reecrire")
    func ligneDeReglageUtiliseLaRegle() throws {
        let source = try LectureDuCode.fichier(
            "Packages/DesignSystem/Sources/VueDeLigneDeReglage.swift"
        )

        #expect(
            source.contains("Jetons.TexteDynamique.passeEnPile(tailleDeTexte)"),
            "La ligne de reglage lit la regle du systeme de design"
        )
        #expect(
            source.contains("tailleDeTexte > .large") == false,
            "Le seuil ne se recopie pas dans la vue"
        )
    }

    @Test("Toutes les tailles d accessibilite passent en pile")
    func taillesDAccessibilite() {
        let accessibilite: [DynamicTypeSize] = [
            .accessibility1,
            .accessibility2,
            .accessibility3,
            .accessibility4,
            .accessibility5,
        ]

        for taille in accessibilite {
            #expect(Jetons.TexteDynamique.passeEnPile(taille))
        }
    }
}

/// Lecture d un fichier du depot, pour les tests qui verifient qu une regle est
/// appliquee la ou elle doit l etre.
enum LectureDuCode {
    static func fichier(_ chemin: String) throws -> String {
        let racine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DesignSystem
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot

        return try String(
            contentsOf: racine.appendingPathComponent(chemin),
            encoding: .utf8
        )
    }
}
