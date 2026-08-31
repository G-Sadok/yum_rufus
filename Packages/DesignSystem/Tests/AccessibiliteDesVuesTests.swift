import DesignSystem
import Foundation
import Testing

/// Audit d accessibilite des vues, section 7 de DESIGN-SPEC.md.
///
/// Ces tests lisent le code source des vues plutot que de monter chaque ecran.
/// C est volontaire. Les regles de la section 7 sont des invariants de tout le
/// produit, pas des proprietes d un ecran : une icone sans etiquette ajoutee
/// demain dans un dixieme ecran doit faire virer la suite au rouge sans qu on
/// ait pense a ecrire un test pour cet ecran la.
///
/// Le balayage couvre les deux seuls endroits ou vit de l interface, le paquet
/// `DesignSystem` et le dossier `App`, donc les dix ecrans de la section 5.
struct AccessibiliteDesVuesTests {
    /// Lignes qu on regarde apres un `Image` pour y trouver son etiquette.
    ///
    /// Une chaine de modificateurs plus longue que cela veut dire que l image
    /// porte deja beaucoup de mise en forme, et son etiquette doit alors etre
    /// posee explicitement plutot que devinee de loin.
    private static let porteeDUneChaineDeModificateurs = 12

    // MARK: Etiquettes des icones

    @Test("Chaque icone porte une etiquette d accessibilite ou est masquee")
    func iconesEtiquetees() throws {
        var manquantes: [String] = []

        for fichier in try Self.fichiersDInterface() {
            let lignes = try Self.lignes(de: fichier)

            for (index, ligne) in lignes.enumerated() where ligne.contains("Image(systemName:") {
                let fin = min(index + Self.porteeDUneChaineDeModificateurs, lignes.count)
                let chaine = lignes[index..<fin].joined(separator: "\n")

                guard chaine.contains("accessibilityLabel") == false,
                      chaine.contains("accessibilityHidden") == false
                else {
                    continue
                }

                manquantes.append("\(fichier.lastPathComponent):\(index + 1)")
            }
        }

        #expect(
            manquantes.isEmpty,
            """
            Section 7 : chaque icone sans libelle porte une etiquette \
            d accessibilite. Une icone qui double un texte voisin se masque \
            avec accessibilityHidden. Manquantes : \(manquantes.joined(separator: ", "))
            """
        )
    }

    @Test("Le balayage voit bien des icones, sinon il ne prouve rien")
    func balayageNonVide() throws {
        var icones = 0
        var fichiers = 0

        for fichier in try Self.fichiersDInterface() {
            fichiers += 1
            icones += try Self.lignes(de: fichier)
                .count { $0.contains("Image(systemName:") }
        }

        #expect(fichiers > 100, "Le balayage doit voir tout le code d interface")
        #expect(icones > 20, "Le balayage doit voir les icones du produit")
    }

    // MARK: Focus clavier

    @Test("Aucune vue ne coupe l effet de focus sans reposer le contour")
    func focusJamaisSupprime() throws {
        var fautives: [String] = []

        for fichier in try Self.fichiersDInterface() {
            let texte = try Self.lignes(de: fichier).joined(separator: "\n")

            guard texte.contains("focusEffectDisabled") else { continue }
            guard texte.contains("contourDeFocus") == false else { continue }
            // Une vue peut signaler le focus autrement, a condition de le dire
            // et de dire par quoi. Le champ de recherche est dans ce cas : son
            // contour de 2 en accent du tableau 4.9 tient lieu d anneau.
            guard texte.contains("focus-ok") == false else { continue }

            fautives.append(fichier.lastPathComponent)
        }

        #expect(
            fautives.isEmpty,
            """
            Section 7 : le contour de focus clavier n est jamais supprime. \
            Une vue qui appelle focusEffectDisabled repose le contour avec \
            contourDeFocus, ou justifie son remplacant avec focus-ok. \
            Fautives : \(fautives.joined(separator: ", "))
            """
        )
    }

    @Test("Le contour de focus n existe qu en un seul exemplaire")
    func contourNonDuplique() throws {
        // `focusRing` est le jeton de la section 1.3. Seuls sa definition, la
        // definition de la geometrie du contour et le composant qui le pose ont
        // le droit de le nommer. Toute autre mention est un contour recopie,
        // donc une geometrie qui divergera.
        let autorises = [
            "JetonsSemantiques.swift",
            "JetonsDeCoquille.swift",
            "ContourDeFocus.swift",
        ]
        var recopies: [String] = []

        for fichier in try Self.fichiersDInterface() {
            guard autorises.contains(fichier.lastPathComponent) == false else { continue }

            let texte = try Self.lignes(de: fichier).joined(separator: "\n")

            if texte.contains("focusRing") {
                recopies.append(fichier.lastPathComponent)
            }
        }

        #expect(
            recopies.isEmpty,
            """
            Le contour de focus vit dans ContourDeFocus.swift et nulle part \
            ailleurs. Recopies : \(recopies.joined(separator: ", "))
            """
        )
    }

    @Test("Le contour de focus reprend les valeurs de la section 7")
    func geometrieDuContour() throws {
        let lignes = try SpecificationDeDesign.lignes()

        #expect(
            lignes.contains {
                $0.contains("| Focus clavier | contour 2 en `accent`, decalage 2, jamais supprime |")
            },
            "Le document fixe un contour de 2 et un decalage de 2"
        )

        #expect(Jetons.Focus.epaisseur == 2)
        #expect(Jetons.Focus.decalage == 2)

        for apparence in Apparence.allCases {
            let palette = Palette.pour(theme: .midnight, apparence: apparence)
            #expect(
                palette.semantiques.focusRing == palette.semantiques.accent,
                "Le contour est en accent, section 1.3"
            )
        }
    }

    // MARK: Contraste des surfaces claires

    @Test("Toute vue qui pose du texte sur une surface claire passe par la derivation")
    func derivationSurLesSurfacesClaires() throws {
        // Ces trois surfaces sont plus claires que `surface.card` en variante
        // sombre. Les jetons de texte y tombent sous le seuil de la section 7,
        // voir ContrasteDesJetonsTests. Une vue qui les emploie derive donc ce
        // qu elle pose dessus, ou explique pourquoi elle n en a pas besoin.
        let surfacesClaires = ["surfaces.menu", "surfaces.selected", "surfaces.premium"]
        var fautives: [String] = []

        for fichier in try Self.fichiersDInterface() {
            let texte = try Self.lignes(de: fichier).joined(separator: "\n")

            guard surfacesClaires.contains(where: texte.contains) else { continue }
            guard texte.contains("palette.lisible(") == false else { continue }
            guard texte.contains("contraste-ok") == false else { continue }

            fautives.append(fichier.lastPathComponent)
        }

        #expect(
            fautives.isEmpty,
            """
            Section 7 : le texte pose sur surface.menu, surface.selected ou \
            surface.premium passe par palette.lisible, ou justifie son ecart \
            avec contraste-ok. Fautives : \(fautives.joined(separator: ", "))
            """
        )
    }

    // MARK: Aucune information par la couleur seule

    @Test("Le texte dit ce que la couleur montre, section 7")
    func aucuneInformationParLaCouleurSeule() throws {
        // La regle ne se lit pas dans une couleur, elle se lit dans le texte
        // qui l accompagne. Les deux cas que le document cite nommement sont
        // la pastille de non lus, qui porte un chiffre, et l etat d une source,
        // ecrit en clair dans son sous titre, tableau 4.4.
        let lignes = try SpecificationDeDesign.lignes()

        #expect(
            lignes.contains { $0.contains("Aucune information transmise par la couleur seule") },
            "La regle est bien celle du document"
        )

        // Etat d une source : le sous titre porte le mot, pas seulement la
        // pastille de couleur.
        let table = try SpecificationDeDesign.tableaux()
            .first { $0.entetes == ["Cas", "Sous titre"] }
        let sousTitres = try #require(table, "Le tableau 4.4 des sous titres de source").lignes

        #expect(
            sousTitres.allSatisfy { $0.count > 1 && $0[1].isEmpty == false },
            "Aucun sous titre de source n est vide, tableau 4.4"
        )
    }

    // MARK: Lecture du code source

    /// Racine du depot, resolue depuis l emplacement de ce fichier.
    private static var racine: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DesignSystem
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
    }

    /// Tout le code d interface du depot, dans un ordre stable.
    ///
    /// La regle 5 du projet limite l interface a ces deux emplacements, et le
    /// controle 7 de `verifications.sh` le verifie de son cote. Balayer les
    /// deux revient donc a balayer toutes les vues du produit.
    private static func fichiersDInterface() throws -> [URL] {
        var fichiers: [URL] = []

        for dossier in ["Packages/DesignSystem/Sources", "App"] {
            let base = racine.appendingPathComponent(dossier)

            guard let parcours = FileManager.default.enumerator(
                at: base,
                includingPropertiesForKeys: nil
            ) else {
                Issue.record("Dossier d interface introuvable : \(dossier)")
                continue
            }

            for cas in parcours {
                guard let url = cas as? URL, url.pathExtension == "swift" else { continue }
                fichiers.append(url)
            }
        }

        return fichiers.sorted { $0.path < $1.path }
    }

    private static func lignes(de fichier: URL) throws -> [String] {
        try String(contentsOf: fichier, encoding: .utf8).components(separatedBy: .newlines)
    }
}
