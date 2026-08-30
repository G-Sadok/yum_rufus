import Foundation
import Testing
@testable import Intelligence

/// Couvre le troisieme critere de la fonctionnalite : la licence du modele est
/// verifiee et documentee dans le depot.
///
/// Le critere porte sur deux objets qui peuvent diverger, un document destine a
/// la lecture humaine et un catalogue destine au chargement. Les tenir a la main
/// tous les deux garantit qu ils finiront par se contredire, et c est le
/// document qui perdra, puisque rien ne le lit. Le premier cas les compare donc
/// ligne par ligne.
///
/// Les cas suivants portent sur la verification elle meme. Elle doit refuser un
/// modele absent du catalogue, un modele livre sans son avis de licence, et un
/// modele livre sous une autre licence que celle documentee. Un dernier cas
/// prouve qu elle laisse passer le cas conforme, sans quoi les trois refus
/// pourraient venir d une verification qui refuse tout.
struct LicencesDeModelesTests {
    // MARK: Le document et le catalogue disent la meme chose

    @Test("Le registre du depot et le catalogue Swift concordent")
    func registreEtCatalogueConcordent() throws {
        let registre = try Self.registreDuDepot()

        #expect(registre.isEmpty == false)
        #expect(registre.count == CatalogueDesModelesIA.fiches.count)

        for fiche in CatalogueDesModelesIA.fiches {
            let ligne = try #require(
                registre.first { $0.identifiant == fiche.identifiant },
                "Le modele \(fiche.identifiant) n est pas au registre du depot"
            )

            #expect(ligne.traitement == fiche.traitement.rawValue)
            #expect(ligne.provenance == fiche.provenance)
            #expect(ligne.licence == fiche.licence)
            #expect(ligne.marqueur == fiche.marqueurDeLicence)
        }
    }

    @Test("Chaque fiche porte une provenance en HTTPS et une mention A propos")
    func fichesCompletes() {
        for fiche in CatalogueDesModelesIA.fiches {
            #expect(fiche.provenance.hasPrefix("https://"))
            #expect(fiche.licence.isEmpty == false)
            #expect(fiche.marqueurDeLicence.isEmpty == false)
            #expect(fiche.mentionAPropos.isEmpty == false)
        }

        #expect(CatalogueDesModelesIA.mentionsAPropos.count == CatalogueDesModelesIA.fiches.count)
        #expect(CatalogueDesModelesIA.fiche(pour: "modele-inconnu") == nil)
    }

    @Test("Les deux traitements de la section 8 ont chacun leur modele")
    func unModeleParTraitement() {
        let traitements = CatalogueDesModelesIA.fiches.map(\.traitement)

        #expect(traitements.contains(.amelioration))
        #expect(traitements.contains(.colorisation))
    }

    // MARK: La verification refuse ce qu elle doit refuser

    @Test("Un modele absent du catalogue ne se charge pas")
    func modeleHorsCatalogueRefuse() throws {
        let dossier = try Self.dossierDeModele(licence: Self.texteMit)

        #expect(throws: ErreurDeTraitementIA.licenceNonDocumentee(identifiant: "reseau-inconnu")) {
            try CatalogueDesModelesIA.verifierLaLicence(
                identifiant: "reseau-inconnu",
                traitement: .colorisation,
                modele: dossier.appendingPathComponent("modele.mlmodelc")
            )
        }
    }

    @Test("Un modele livre sans avis de licence ne se charge pas")
    func modeleSansLicenceRefuse() throws {
        let dossier = try Self.dossierDeModele(licence: nil)

        #expect(throws: ErreurDeTraitementIA.self) {
            try CatalogueDesModelesIA.verifierLaLicence(
                identifiant: Self.modeleDeColorisation,
                traitement: .colorisation,
                modele: dossier.appendingPathComponent("modele.mlmodelc")
            )
        }
    }

    @Test("Un modele livre sous une autre licence que celle documentee est refuse")
    func licenceQuiNeCorrespondPasRefusee() throws {
        let dossier = try Self.dossierDeModele(licence: Self.texteProprietaire)

        #expect(throws: ErreurDeTraitementIA.self) {
            try CatalogueDesModelesIA.verifierLaLicence(
                identifiant: Self.modeleDeColorisation,
                traitement: .colorisation,
                modele: dossier.appendingPathComponent("modele.mlmodelc")
            )
        }
    }

    @Test("Un modele de colorisation ne passe pas pour un modele d amelioration")
    func traitementQuiNeCorrespondPasRefuse() throws {
        let dossier = try Self.dossierDeModele(licence: Self.texteMit)

        #expect(throws: ErreurDeTraitementIA.self) {
            try CatalogueDesModelesIA.verifierLaLicence(
                identifiant: Self.modeleDeColorisation,
                traitement: .amelioration,
                modele: dossier.appendingPathComponent("modele.mlmodelc")
            )
        }
    }

    // MARK: La verification laisse passer ce qui est conforme

    @Test("Un modele documente et accompagne de sa licence passe la verification")
    func modeleConformeAccepte() throws {
        let dossier = try Self.dossierDeModele(licence: Self.texteMit)
        let fiche = try CatalogueDesModelesIA.verifierLaLicence(
            identifiant: Self.modeleDeColorisation,
            traitement: .colorisation,
            modele: dossier.appendingPathComponent("modele.mlmodelc")
        )

        #expect(fiche.identifiant == Self.modeleDeColorisation)
        #expect(fiche.licence == "MIT")
    }

    /// Le chargeur Core ML verifie la licence avant d ouvrir le fichier. Le cas
    /// le prouve par l erreur qu il obtient : sur un modele conforme mais
    /// inexistant, l echec porte sur le fichier et non sur la licence, donc la
    /// barriere a bien ete franchie.
    @Test("Le chargeur verifie la licence avant le fichier de modele")
    func leChargeurVerifieAvantDOuvrir() throws {
        let sansLicence = try Self.dossierDeModele(licence: nil)
        let avecLicence = try Self.dossierDeModele(licence: Self.texteMit)

        #expect(throws: ErreurDeTraitementIA.licenceNonDocumentee(
            identifiant: Self.modeleDeColorisation
        )) {
            _ = try ModeleCoreMLDeColorisation(
                contenuDe: sansLicence.appendingPathComponent("modele.mlmodelc"),
                identifiant: Self.modeleDeColorisation
            )
        }

        let chemin = avecLicence.appendingPathComponent("modele.mlmodelc")

        #expect(throws: ErreurDeTraitementIA.modeleIllisible(chemin: chemin.path)) {
            _ = try ModeleCoreMLDeColorisation(
                contenuDe: chemin,
                identifiant: Self.modeleDeColorisation
            )
        }
    }

    // MARK: Materiel des cas

    private static let modeleDeColorisation = "manga-colorization-v2"

    private static let texteMit = """
    MIT License

    Copyright (c) 2021 le projet amont

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files, to deal in the Software
    without restriction.
    """

    private static let texteProprietaire = """
    Tous droits reserves. Aucune redistribution n est autorisee sans accord
    ecrit prealable.
    """

    /// Dossier temporaire jouant le role du dossier de modele livre.
    ///
    /// Le fichier de modele n est pas cree : les cas de licence n ont pas besoin
    /// d un `mlmodelc` valide, et en fabriquer un exigerait le compilateur Core
    /// ML, que la suite de tests n a pas a invoquer.
    private static func dossierDeModele(licence: String?) throws -> URL {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("licences-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        if let licence {
            try licence.write(
                to: dossier.appendingPathComponent("LICENSE"),
                atomically: true,
                encoding: .utf8
            )
        }

        return dossier
    }

    /// Une ligne du registre de `docs/LICENCES-MODELES.md`.
    private struct LigneDeRegistre {
        let identifiant: String
        let traitement: String
        let provenance: String
        let licence: String
        let marqueur: String
    }

    /// Lignes du tableau de `docs/LICENCES-MODELES.md`.
    ///
    /// Le document est lu depuis le depot et non copie en ressource : une copie
    /// serait figee a la compilation, et le test cesserait de voir les
    /// modifications du document qu il est justement charge de surveiller.
    private static func registreDuDepot() throws -> [LigneDeRegistre] {
        let racine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let document = racine.appendingPathComponent("docs/LICENCES-MODELES.md")
        let texte = try String(contentsOf: document, encoding: .utf8)

        return texte
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { ligne in
                let cellules = cellules(de: String(ligne))

                guard cellules.count == 5,
                      cellules[0] != "Identifiant",
                      cellules[0].hasPrefix("-") == false
                else {
                    return nil
                }

                return LigneDeRegistre(
                    identifiant: cellules[0],
                    traitement: cellules[1],
                    provenance: cellules[2],
                    licence: cellules[3],
                    marqueur: cellules[4]
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
}
