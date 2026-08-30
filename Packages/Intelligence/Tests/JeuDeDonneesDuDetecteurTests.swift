import Foundation
import Testing
@testable import Intelligence

//
// Couvre les deuxieme et troisieme criteres de la fonctionnalite : la licence du
// jeu de donnees est verifiee et documentee, et la mention de provenance apparait
// dans la section A propos.
//
// Les deux criteres portent sur des objets qui peuvent diverger sans que rien ne
// le dise : un document destine a la lecture humaine, un catalogue Swift lu par
// le chargeur, et une chaine du catalogue de l application affichee a l ecran.
// Tenir les trois a la main garantit qu ils finiront par se contredire, et le
// perdant sera toujours celui que personne ne lit. Ce fichier les compare donc
// deux a deux.
//
// La partie executable du deuxieme critere est la plus importante. Une licence
// de jeu de donnees documentee dans un fichier ne protege de rien le jour ou
// quelqu un remplace le modele livre par un reseau entraine sur Manga109, dont
// l usage commercial demande un accord separe. Le refus doit donc tomber au
// chargement, et c est ce que les derniers cas verifient.
//

struct JeuDeDonneesDuDetecteurTests {
    // MARK: Le document et le catalogue disent la meme chose

    @Test("Le registre des jeux de donnees du depot et les fiches concordent")
    func leRegistreEtLesFichesConcordent() throws {
        let registre = try Self.registreDesJeuxDeDonnees()
        let documentees = CatalogueDesModelesIA.fiches.filter { $0.jeuDeDonnees != nil }

        #expect(registre.isEmpty == false)
        #expect(registre.count == documentees.count)

        for fiche in documentees {
            let jeu = try #require(fiche.jeuDeDonnees)
            let ligne = try #require(
                registre.first { $0.modele == fiche.identifiant },
                "Le modele \(fiche.identifiant) n est pas au registre des jeux de donnees"
            )

            #expect(ligne.jeuDeDonnees == jeu.nom)
            #expect(ligne.provenance == jeu.provenance)
            #expect(ligne.licence == jeu.licence)
        }
    }

    @Test("Le detecteur de cases documente son jeu de donnees, comme la section 8 l exige")
    func leDetecteurDocumenteSonJeuDeDonnees() throws {
        let fiche = try #require(
            CatalogueDesModelesIA.fiches.first { $0.traitement == .detectionDeCases }
        )
        let jeu = try #require(fiche.jeuDeDonnees)

        #expect(TraitementIA.detectionDeCases.exigeUnJeuDeDonnees)
        #expect(jeu.nom.isEmpty == false)
        #expect(jeu.provenance.hasPrefix("https://"))
        #expect(jeu.licence.isEmpty == false)
        #expect(jeu.redistributionDesPoids)
    }

    @Test("Aucune fiche du catalogue ne repose sur un jeu de donnees qui interdit la distribution")
    func aucuneFicheNeReposeSurUnJeuInterdit() {
        for fiche in CatalogueDesModelesIA.fiches {
            #expect(fiche.jeuDeDonnees?.redistributionDesPoids != false, "\(fiche.identifiant)")
        }
    }

    @Test("Les candidats ecartes sont documentes avec la raison de leur refus")
    func lesCandidatsEcartesSontDocumentes() throws {
        let texte = try Self.document()

        #expect(texte.contains("Manga109"))
        #expect(texte.contains("academique"))
        #expect(texte.contains("non commerciale"))
        #expect(texte.contains("redistributionDesPoids"))
    }

    // MARK: La mention de provenance dans la section A propos

    @Test("La note de la section A propos porte la provenance du jeu de donnees du detecteur")
    func laNoteDAProposPorteLaProvenance() throws {
        let catalogue = try Self.catalogueDeChaines()
        let note = try #require(catalogue["reglages.note"])
        let mention = try #require(CatalogueDesModelesIA.mentionDuDetecteurDeCases)
        let jeu = try #require(
            CatalogueDesModelesIA.fiches.first { $0.traitement == .detectionDeCases }?.jeuDeDonnees
        )

        #expect(note == mention)
        #expect(note.contains("Digital Comic Museum"))
        #expect(note.contains("CC0"))
        #expect(jeu.licence == "CC0-1.0")
    }

    @Test("La note dit la provenance et la licence, comme la section 9 du cahier le demande")
    func laNoteDitLaProvenanceEtLaLicence() throws {
        let catalogue = try Self.catalogueDeChaines()
        let note = try #require(catalogue["reglages.note"])
        let trouvee = try Self.ligneDuCahier(
            contenant: "mention de provenance du jeu de donnees du detecteur"
        )
        let exigence = try #require(trouvee)

        #expect(exigence.contains("licence"))
        #expect(note.contains("Detection de cases"))
        #expect(note.hasSuffix("."))
        #expect(note.isEmpty == false)
    }

    // MARK: La verification refuse ce qu elle doit refuser

    @Test("Un detecteur sans jeu de donnees documente ne se charge pas")
    func leDetecteurSansJeuDeDonneesEstRefuse() throws {
        let fiche = FicheDeModeleIA(
            identifiant: "detecteur-sans-jeu",
            traitement: .detectionDeCases,
            provenance: "https://exemple.test",
            licence: "MIT",
            marqueurDeLicence: "Permission is hereby granted",
            mentionAPropos: "Detection de cases : detecteur de test."
        )

        #expect(throws: ErreurDeTraitementIA.jeuDeDonneesNonAutorise(identifiant: fiche.identifiant)) {
            try CatalogueDesModelesIA.verifierLeJeuDeDonnees(de: fiche)
        }
    }

    @Test("Un modele entraine sur un jeu de donnees non commercial ne se charge pas")
    func leJeuDeDonneesNonCommercialEstRefuse() throws {
        let fiche = FicheDeModeleIA(
            identifiant: "detecteur-manga109",
            traitement: .detectionDeCases,
            provenance: "https://exemple.test",
            licence: "MIT",
            marqueurDeLicence: "Permission is hereby granted",
            mentionAPropos: "Detection de cases : detecteur de test.",
            jeuDeDonnees: FicheDeJeuDeDonnees(
                nom: "Jeu de donnees reserve a la recherche",
                provenance: "https://exemple.test/jeu",
                licence: "LicenseRef-Academic",
                redistributionDesPoids: false
            )
        )

        #expect(throws: ErreurDeTraitementIA.jeuDeDonneesNonAutorise(identifiant: fiche.identifiant)) {
            try CatalogueDesModelesIA.verifierLeJeuDeDonnees(de: fiche)
        }
    }

    @Test("Le jeu de donnees est verifie avant meme le fichier de licence du modele")
    func leJeuDeDonneesEstVerifieAvantLaLicence() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("jeu-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        // Le dossier ne porte aucun fichier de licence. Un detecteur inconnu du
        // catalogue echoue donc sur la licence, ce que le cas de reference
        // montre, alors que le detecteur du catalogue passe cette barriere.
        #expect(throws: ErreurDeTraitementIA.licenceNonDocumentee(identifiant: "detecteur-inconnu")) {
            try CatalogueDesModelesIA.verifierLaLicence(
                identifiant: "detecteur-inconnu",
                traitement: .detectionDeCases,
                modele: dossier.appendingPathComponent("modele.mlmodelc")
            )
        }
    }

    @Test("Un traitement sans exigence de jeu de donnees passe la verification sans en avoir")
    func lesAutresTraitementsPassentSansJeuDeDonnees() throws {
        for fiche in CatalogueDesModelesIA.fiches where fiche.traitement != .detectionDeCases {
            #expect(fiche.traitement.exigeUnJeuDeDonnees == false)
            #expect(throws: Never.self) {
                try CatalogueDesModelesIA.verifierLeJeuDeDonnees(de: fiche)
            }
        }
    }

    // MARK: Le message d erreur

    @Test("Le message d erreur nomme la fonction et n envoie pas chercher un reglage inexistant")
    func leMessageNEnvoiePasVersUnReglageInexistant() {
        let erreur = ErreurDeTraitementIA.modeleIllisible(chemin: "/aucun")
        let message = erreur.messageUtilisateur(pour: .detectionDeCases)

        #expect(TraitementIA.detectionDeCases.libelleDuReglage == nil)
        #expect(message.contains("Zoom automatique case par case") || message.contains("page par page"))
        #expect(message.contains("dans les reglages") == false)

        for traitement in [TraitementIA.amelioration, .colorisation] {
            #expect(
                erreur.messageUtilisateur(pour: traitement).contains("dans les reglages"),
                "\(traitement)"
            )
        }
    }

    // MARK: Materiel des cas

    /// Une ligne du registre des jeux de donnees de `docs/LICENCES-MODELES.md`.
    private struct LigneDeRegistre {
        let modele: String
        let jeuDeDonnees: String
        let provenance: String
        let licence: String
    }

    /// Racine du depot, resolue depuis l emplacement de ce fichier de test.
    private static var racine: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Intelligence
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
    }

    /// Texte du document des licences, lu depuis le depot.
    private static func document() throws -> String {
        try String(
            contentsOf: racine.appendingPathComponent("docs/LICENCES-MODELES.md"),
            encoding: .utf8
        )
    }

    /// Premiere ligne du cahier de developpement qui contient ce fragment.
    private static func ligneDuCahier(contenant fragment: String) throws -> String? {
        try String(
            contentsOf: racine.appendingPathComponent("docs/CAHIER-DES-CHARGES-DEV.md"),
            encoding: .utf8
        )
        .components(separatedBy: .newlines)
        .first { $0.contains(fragment) }
    }

    /// Lignes du tableau des jeux de donnees.
    ///
    /// Le tableau se reconnait a son nombre de colonnes, quatre, la ou celui des
    /// modeles en a cinq et celui des candidats ecartes trois. Le document est lu
    /// depuis le depot et non copie en ressource : une copie serait figee a la
    /// compilation, et le test cesserait de voir les modifications du document
    /// qu il est justement charge de surveiller.
    private static func registreDesJeuxDeDonnees() throws -> [LigneDeRegistre] {
        try document()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { ligne in
                let cellules = cellules(de: String(ligne))

                guard cellules.count == 4,
                      cellules[0] != "Modele",
                      cellules[0].hasPrefix("-") == false
                else {
                    return nil
                }

                return LigneDeRegistre(
                    modele: cellules[0],
                    jeuDeDonnees: cellules[1],
                    provenance: cellules[2],
                    licence: cellules[3]
                )
            }
    }

    /// Cellules d une ligne de tableau markdown, sans accents graves ni espaces.
    private static func cellules(de ligne: String) -> [String] {
        let nettoyee = ligne.trimmingCharacters(in: .whitespaces)

        guard nettoyee.hasPrefix("|"), nettoyee.hasSuffix("|") else { return [] }

        return nettoyee
            .dropFirst()
            .dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .map {
                $0.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            }
    }

    /// Valeurs du catalogue de chaines de l application, indexees par cle.
    ///
    /// Le catalogue vit dans la cible `App/Yum`, que Swift Package Manager ne
    /// compile pas. Le lire sur le disque est le seul moyen de verifier, dans la
    /// suite qui tourne a chaque commit, que la note affichee sous la carte
    /// A propos est bien celle que le catalogue des modeles documente.
    private static func catalogueDeChaines() throws -> [String: String] {
        let donnees = try Data(
            contentsOf: racine.appendingPathComponent("App/Yum/Ressources/Localizable.xcstrings")
        )
        let catalogue = try JSONDecoder().decode(CatalogueXCStrings.self, from: donnees)

        return catalogue.strings.compactMapValues { entree in
            entree.localizations?[catalogue.sourceLanguage]?.stringUnit.value
        }
    }
}

private struct CatalogueXCStrings: Decodable {
    let sourceLanguage: String
    let strings: [String: EntreeDeCatalogue]
}

private struct EntreeDeCatalogue: Decodable {
    let localizations: [String: LocalisationDeCatalogue]?
}

private struct LocalisationDeCatalogue: Decodable {
    let stringUnit: UniteDeChaine
}

private struct UniteDeChaine: Decodable {
    let value: String
}
