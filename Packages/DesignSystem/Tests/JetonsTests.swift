import DesignSystem
import Foundation
import Testing

/// Verifie que chaque jeton de la section 1 de DESIGN-SPEC.md existe dans le
/// code, avec la valeur exacte du document.
///
/// Les tests lisent le document sur disque. Aucune valeur du document n est
/// recopiee ici, sinon la suite validerait sa propre copie au lieu de valider
/// le code contre la source.
struct JetonsTests {
    // MARK: Couleurs

    @Test("Les douze surfaces des quatre themes existent dans les deux apparences")
    func surfacesDesQuatreThemes() throws {
        let tableaux = try SpecificationDeDesign.tableaux()
            .filter { $0.entetes.first == "Jeton" && $0.entetes.count == 5 }

        #expect(tableaux.count == 2, "Le tableau 1.1 doit compter deux moities")

        var couples = 0

        for tableau in tableaux {
            for colonne in 1..<tableau.entetes.count {
                let entete = tableau.entetes[colonne].components(separatedBy: " ")

                guard entete.count == 2,
                      let theme = ThemeDeSurface(rawValue: entete[0].lowercased()),
                      let apparence = Apparence(rawValue: entete[1].lowercased())
                else {
                    Issue.record("Colonne illisible dans le tableau 1.1 : \(tableau.entetes[colonne])")
                    continue
                }

                let surfaces = JetonsDeSurface.pour(theme: theme, apparence: apparence).parNom

                for ligne in tableau.lignes {
                    let jeton = ligne[0]
                    let attendue = ligne[colonne]

                    #expect(
                        surfaces[jeton]?.notation == attendue,
                        "\(jeton) en \(theme.rawValue) \(apparence.rawValue) vaut \(attendue) dans le document"
                    )
                    couples += 1
                }
            }
        }

        #expect(couples == 96, "Douze surfaces, quatre themes, deux apparences")
    }

    @Test("Les sept couleurs de texte existent dans les deux apparences")
    func couleursDeTexte() throws {
        let attendus = try jetonsDeCouleurParApparence(prefixe: "text.")

        #expect(attendus.count == 14, "Sept jetons de texte, deux apparences")

        for attendu in attendus {
            let code = JetonsDeTexte.pour(apparence: attendu.apparence).parNom
            #expect(
                code[attendu.nom]?.notation == attendu.valeur,
                "\(attendu.nom) en \(attendu.apparence.rawValue)"
            )
        }
    }

    @Test("Les dix jetons semantiques existent dans les deux apparences")
    func jetonsSemantiques() throws {
        let attendus = try jetonsDeCouleurParApparence(prefixe: nil)

        #expect(attendus.count == 20, "Dix jetons semantiques, deux apparences")

        for attendu in attendus {
            let code = JetonsSemantiques.pour(apparence: attendu.apparence).parNom
            #expect(
                code[attendu.nom]?.notation == attendu.valeur,
                "\(attendu.nom) en \(attendu.apparence.rawValue)"
            )
        }
    }

    @Test("Le code n expose ni jeton de couleur en trop ni jeton manquant")
    func aucunJetonDeCouleurEnTrop() throws {
        let tableaux = try SpecificationDeDesign.tableaux()

        let surfacesDuDocument = tableaux
            .filter { $0.entetes.first == "Jeton" && $0.entetes.count == 5 }
            .flatMap(\.lignes)
            .map { $0[0] }

        #expect(
            Set(surfacesDuDocument) == Set(JetonsDeSurface.nomsDeJetons),
            "Les noms de surface du code doivent etre ceux du tableau 1.1"
        )

        let jetonsParApparence = tableaux
            .filter { $0.entetes == ["Jeton", "Sombre", "Clair", "Usage"] }
            .flatMap(\.lignes)
            .map { $0[0] }

        let texte = jetonsParApparence.filter { $0.hasPrefix("text.") }
        let semantiques = jetonsParApparence.filter { $0.hasPrefix("text.") == false }

        #expect(Set(texte) == Set(JetonsDeTexte.nomsDeJetons))
        #expect(Set(semantiques) == Set(JetonsSemantiques.nomsDeJetons))
    }

    @Test("Les quatre fonds du lecteur existent")
    func fondsDuLecteur() throws {
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Valeur du reglage", "Fond"])

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.4 introuvable")
            return
        }

        #expect(tableau.lignes.count == FondDeLecteur.allCases.count)

        for ligne in tableau.lignes {
            let fond = FondDeLecteur.allCases.first { $0.valeurDuDocument == ligne[0] }

            guard let fond else {
                Issue.record("Fond de lecteur absent du code : \(ligne[0])")
                continue
            }

            #expect(fond.couleur.notation == ligne[1], "Fond \(ligne[0])")
        }
    }

    // MARK: Typographie

    @Test("L echelle typographique complete est exposee")
    func echelleTypographique() throws {
        let entete = ["Role", "Taille", "Graisse", "Interlignage", "Interlettrage", "Usage"]
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: entete)

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.5 introuvable")
            return
        }

        #expect(tableau.lignes.count == Jetons.Typo.parRole.count, "Huit roles typographiques")

        for ligne in tableau.lignes {
            let role = ligne[0]

            guard let style = Jetons.Typo.parRole[role] else {
                Issue.record("Role typographique absent du code : \(role)")
                continue
            }

            #expect(SpecificationDeDesign.nombre(ligne[1]) == style.taille, "Taille de \(role)")
            #expect(
                SpecificationDeDesign.nombre(ligne[2]) == Double(style.graisse.rawValue),
                "Graisse de \(role)"
            )
            #expect(
                SpecificationDeDesign.nombre(ligne[3]) == style.interlignage,
                "Interlignage de \(role)"
            )
            #expect(
                SpecificationDeDesign.nombre(ligne[4]) == style.interlettrageEnEm,
                "Interlettrage de \(role)"
            )
        }
    }

    // MARK: Geometrie

    @Test("Les rayons du document existent tous")
    func rayons() throws {
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Valeur", "Element"])

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.6 introuvable")
            return
        }

        var numeriques: [Double] = []

        for ligne in tableau.lignes {
            if let valeur = SpecificationDeDesign.nombre(ligne[0]) {
                numeriques.append(valeur)
                #expect(Jetons.Rayon.echelle.contains(valeur), "Rayon \(valeur) absent du code")
            } else {
                #expect(ligne[0] == "capsule", "Ligne de rayon illisible : \(ligne[0])")
                #expect(
                    ligne[1].contains("rayon \(Int(Jetons.Rayon.capsule))"),
                    "Le rayon de capsule du code ne suit pas le document"
                )
            }
        }

        #expect(Set(numeriques) == Set(Jetons.Rayon.echelle), "Rayon en trop ou manquant")
    }

    @Test("L echelle d espacement est celle du document")
    func espacements() throws {
        guard let ligne = try SpecificationDeDesign.ligne(contenant: "Valeurs autorisees") else {
            Issue.record("Section 1.7 introuvable")
            return
        }

        let morceaux = ligne.components(separatedBy: "**")

        guard morceaux.count >= 2 else {
            Issue.record("Echelle d espacement illisible")
            return
        }

        let valeurs = morceaux[1]
            .components(separatedBy: ",")
            .compactMap { SpecificationDeDesign.nombre($0.trimmingCharacters(in: .whitespaces)) }

        #expect(valeurs == Jetons.Espace.echelle, "L echelle de 4 doit etre reprise a l identique")
    }

    // MARK: Elevation et mouvement

    @Test("Les trois niveaux d elevation portent l ombre et le complement du document")
    func elevation() throws {
        let entete = ["Niveau", "Ombre", "Complement", "Usage"]
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: entete)

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.8 introuvable")
            return
        }

        #expect(tableau.lignes.count == NiveauDElevation.allCases.count)

        for ligne in tableau.lignes {
            guard let rang = SpecificationDeDesign.nombre(ligne[0]),
                  let niveau = NiveauDElevation(rawValue: Int(rang))
            else {
                Issue.record("Niveau d elevation illisible : \(ligne[0])")
                continue
            }

            if ligne[1] == "aucune" {
                #expect(niveau.ombre == nil, "Le niveau \(Int(rang)) ne porte aucune ombre")
            } else {
                #expect(niveau.ombre?.notation == ligne[1], "Ombre du niveau \(Int(rang))")
            }

            #expect(
                ligne[2].contains(niveau.complement.rawValue),
                "Complement du niveau \(Int(rang))"
            )
        }
    }

    @Test("Chaque transition du document a sa duree et sa courbe dans le code")
    func mouvement() throws {
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Transition", "Duree", "Courbe"])

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.9 introuvable")
            return
        }

        #expect(tableau.lignes.count == Jetons.Mouvement.parTransition.count, "Huit transitions")

        for ligne in tableau.lignes {
            guard let transition = Jetons.Mouvement.parTransition[ligne[0]] else {
                Issue.record("Transition absente du code : \(ligne[0])")
                continue
            }

            #expect(
                SpecificationDeDesign.nombre(ligne[1]) == transition.dureeEnMillisecondes,
                "Duree de la transition \(ligne[0])"
            )
            #expect(
                ligne[2].contains(transition.courbe.notation),
                "Courbe de la transition \(ligne[0]), le code annonce \(transition.courbe.notation)"
            )
        }
    }

    @Test("Reduire les animations ramene toute transition a un fondu de 100 ms")
    func animationsReduites() throws {
        guard let ligne = try SpecificationDeDesign.ligne(contenant: "Reduire les animations") else {
            Issue.record("Regle de reduction des animations introuvable")
            return
        }

        let reduite = Jetons.Mouvement.animationsReduites

        #expect(ligne.contains("\(Int(reduite.dureeEnMillisecondes)) ms"))
        #expect(reduite.courbe == .fondu)
        #expect(Jetons.Mouvement.survol.reduite == reduite)
    }

    // MARK: Iconographie

    @Test("Chaque symbole du tableau 1.10 existe dans le code")
    func iconographie() throws {
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Element", "Symbole"])

        guard let tableau = tableaux.first else {
            Issue.record("Tableau 1.10 introuvable")
            return
        }

        #expect(tableau.lignes.count == Jetons.Icone.parElement.count)

        for ligne in tableau.lignes {
            #expect(Jetons.Icone.parElement[ligne[0]] == ligne[1], "Symbole de \(ligne[0])")
        }
    }

    // MARK: Outillage

    /// Jetons du tableau 1.2 ou 1.3, associes a leur apparence et a leur valeur.
    ///
    /// - Parameter prefixe: `text.` pour le tableau 1.2, `nil` pour le 1.3.
    private func jetonsDeCouleurParApparence(prefixe: String?) throws -> [JetonAttendu] {
        let tableaux = try SpecificationDeDesign
            .tableaux(dontLEnteteEst: ["Jeton", "Sombre", "Clair", "Usage"])

        return tableaux
            .flatMap(\.lignes)
            .filter { ligne in
                guard let prefixe else { return ligne[0].hasPrefix("text.") == false }
                return ligne[0].hasPrefix(prefixe)
            }
            .flatMap { ligne in
                [
                    JetonAttendu(apparence: .sombre, nom: ligne[0], valeur: ligne[1]),
                    JetonAttendu(apparence: .clair, nom: ligne[0], valeur: ligne[2]),
                ]
            }
    }
}

/// Un jeton de couleur lu dans le tableau 1.2 ou 1.3, pour une apparence.
struct JetonAttendu {
    let apparence: Apparence
    let nom: String
    let valeur: String
}
