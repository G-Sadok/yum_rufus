import Foundation

//
// FicheDeModeleIA
//
// La licence de chaque modele embarque, declaree dans le depot et verifiee au
// chargement.
//
// La section 8 le demande pour le detecteur de cases et la regle vaut pour tout
// reseau que l application embarque : verifier la licence avant integration et
// la documenter dans le depot. Une phrase dans un fichier de documentation ne
// suffit pourtant pas. Le poids d un modele l empeche de vivre ici, il arrive
// donc au moment de l empaquetage, par une main qui n aura pas relu la
// documentation, et le jour ou quelqu un remplace le fichier par un autre reseau
// il n y a plus rien pour s en apercevoir.
//
// La verification est donc executable, et elle porte sur trois choses a la fois.
//
// Le modele doit etre nomme dans le catalogue. L identifiant sert deja de cle de
// cache, il sert ici de cle de licence : un modele inconnu du catalogue ne se
// charge pas, et l application reste utilisable sans lui.
//
// La licence doit voyager avec le modele. Le chargeur cherche un fichier de
// licence dans le dossier du modele et refuse de continuer s il n en trouve
// aucun. C est aussi ce que la plupart des licences permissives exigent, la
// conservation de l avis, et l exigence devient ici une condition de demarrage
// au lieu d une bonne intention.
//
// Le texte livre doit etre celui que la fiche annonce. Le marqueur est une
// phrase caracteristique de la licence attendue, cherchee sans tenir compte de
// la casse. Un modele livre sous une autre licence que celle documentee ne se
// charge donc pas, et le desaccord se voit a la premiere execution plutot qu au
// premier courrier d avocat.
//
// La fiche est un contrat, pas un constat. Elle dit ce que le depot attend, et
// la verification echoue de maniere fermee : dans le doute, la fonction reste
// indisponible et la page reste lisible telle quelle.
//

/// Licence d un modele embarque, telle que le depot la documente.
public struct FicheDeModeleIA: Sendable, Hashable {
    /// Identifiant du modele, cle du catalogue et des cles de cache.
    public let identifiant: String

    /// Traitement de la section 8 que ce modele sert.
    public let traitement: TraitementIA

    /// Adresse du projet amont dont le reseau est issu.
    public let provenance: String

    /// Identifiant SPDX de la licence attendue.
    public let licence: String

    /// Phrase que le texte de licence livre doit contenir.
    public let marqueurDeLicence: String

    /// Mention a porter dans la section A propos.
    public let mentionAPropos: String

    public init(
        identifiant: String,
        traitement: TraitementIA,
        provenance: String,
        licence: String,
        marqueurDeLicence: String,
        mentionAPropos: String
    ) {
        self.identifiant = identifiant
        self.traitement = traitement
        self.provenance = provenance
        self.licence = licence
        self.marqueurDeLicence = marqueurDeLicence
        self.mentionAPropos = mentionAPropos
    }

    /// Vrai quand ce texte de licence est celui que la fiche attend.
    public func reconnait(_ texte: String) -> Bool {
        texte.range(of: marqueurDeLicence, options: .caseInsensitive) != nil
    }
}

/// Les modeles que l application accepte de charger, et leur licence.
public enum CatalogueDesModelesIA {
    /// Noms de fichier acceptes pour la licence livree avec un modele.
    ///
    /// Les quatre orthographes courantes, parce que le fichier vient du projet
    /// amont tel quel et qu aucune convention ne s impose entre elles.
    static let nomsDeFichierDeLicence = ["LICENSE", "LICENSE.txt", "LICENCE", "LICENCE.txt"]

    /// Toutes les fiches du depot.
    ///
    /// Elles sont tenues a jour avec `docs/LICENCES-MODELES.md`, et un test
    /// verifie que les deux disent la meme chose. Le document sert a la lecture
    /// humaine et a la mention A propos, le catalogue sert au chargement.
    public static let fiches: [FicheDeModeleIA] = [
        FicheDeModeleIA(
            identifiant: "real-esrgan-anime-x2",
            traitement: .amelioration,
            provenance: "https://github.com/xinntao/Real-ESRGAN",
            licence: "BSD-3-Clause",
            marqueurDeLicence: "Redistribution and use in source and binary forms",
            mentionAPropos: "Amelioration IA : Real ESRGAN, variante anime, licence BSD 3 clauses."
        ),
        FicheDeModeleIA(
            identifiant: "manga-colorization-v2",
            traitement: .colorisation,
            provenance: "https://github.com/qweasdd/manga-colorization-v2",
            licence: "MIT",
            marqueurDeLicence: "Permission is hereby granted, free of charge",
            mentionAPropos: "Colorisation IA : manga colorization v2, licence MIT."
        ),
    ]

    /// Fiche de ce modele, nil quand le depot n en documente aucune.
    public static func fiche(pour identifiant: String) -> FicheDeModeleIA? {
        fiches.first { $0.identifiant == identifiant }
    }

    /// Mentions a porter dans la section A propos, dans l ordre du catalogue.
    public static var mentionsAPropos: [String] {
        fiches.map(\.mentionAPropos)
    }

    /// Verifie qu un modele installe est couvert par une fiche et que la licence
    /// livree a cote de lui est celle que cette fiche annonce.
    ///
    /// - Parameters:
    ///   - identifiant: nom du modele, qui doit figurer au catalogue.
    ///   - traitement: traitement auquel ce modele est destine.
    ///   - url: dossier du modele compile.
    /// - Returns: la fiche qui couvre ce modele.
    /// - Throws: `ErreurDeTraitementIA.licenceNonDocumentee` des que l une des
    ///   trois conditions manque.
    @discardableResult
    public static func verifierLaLicence(
        identifiant: String,
        traitement: TraitementIA,
        modele url: URL
    ) throws -> FicheDeModeleIA {
        guard let fiche = fiche(pour: identifiant), fiche.traitement == traitement else {
            throw ErreurDeTraitementIA.licenceNonDocumentee(identifiant: identifiant)
        }

        guard let texte = texteDeLicence(pres: url), fiche.reconnait(texte) else {
            throw ErreurDeTraitementIA.licenceNonDocumentee(identifiant: identifiant)
        }

        return fiche
    }

    /// Texte du fichier de licence pose dans le dossier du modele.
    ///
    /// Le dossier du modele est celui qui contient le paquet compile, et non le
    /// paquet lui meme : un `mlmodelc` est un dossier produit par le
    /// compilateur, y deposer un fichier de licence le ferait disparaitre a la
    /// prochaine recompilation.
    private static func texteDeLicence(pres url: URL) -> String? {
        let dossier = url.deletingLastPathComponent()

        for nom in nomsDeFichierDeLicence {
            let chemin = dossier.appendingPathComponent(nom)

            if let texte = try? String(contentsOf: chemin, encoding: .utf8), texte.isEmpty == false {
                return texte
            }
        }

        return nil
    }
}
