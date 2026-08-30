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

/// Jeu de donnees sur lequel un modele embarque a ete entraine.
///
/// La section 8 le demande nommement pour le detecteur de cases : verifier la
/// licence du jeu de donnees avant integration, la documenter dans le depot, et
/// porter la provenance dans la section A propos. La fiche est donc lue par
/// trois endroits qui ne doivent pas diverger, le chargeur, le document
/// `docs/LICENCES-MODELES.md` et la note de la section A propos.
///
/// La licence du jeu de donnees n est pas celle des poids, et c est tout le
/// sujet. Les jeux de donnees annotes de planches de manga sont pour la plupart
/// reserves a la recherche ou interdits d usage commercial, et un modele
/// entraine sur l un d eux ne peut pas etre distribue par une application
/// vendue. Le drapeau `redistributionDesPoids` porte cette distinction, et le
/// chargeur refuse le modele quand il est faux.
public struct FicheDeJeuDeDonnees: Sendable, Hashable {
    /// Nom du jeu de donnees, tel que le document du depot le nomme.
    public let nom: String

    /// Adresse ou le jeu de donnees est publie.
    public let provenance: String

    /// Identifiant SPDX de sa licence.
    public let licence: String

    /// Vrai quand cette licence permet de distribuer les poids entraines sur ce
    /// jeu de donnees dans une application vendue.
    public let redistributionDesPoids: Bool

    public init(nom: String, provenance: String, licence: String, redistributionDesPoids: Bool) {
        self.nom = nom
        self.provenance = provenance
        self.licence = licence
        self.redistributionDesPoids = redistributionDesPoids
    }
}

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

    /// Jeu de donnees d entrainement, nul quand le depot ne le documente pas.
    ///
    /// Nul pour les deux reseaux repris d un projet amont : leurs conditions
    /// d entrainement relevent de ce projet et le depot ne peut rien en dire
    /// qu il aurait verifie. La section 8 ne l exige que du detecteur de cases,
    /// et `TraitementIA.exigeUnJeuDeDonnees` porte cette exigence.
    public let jeuDeDonnees: FicheDeJeuDeDonnees?

    public init(
        identifiant: String,
        traitement: TraitementIA,
        provenance: String,
        licence: String,
        marqueurDeLicence: String,
        mentionAPropos: String,
        jeuDeDonnees: FicheDeJeuDeDonnees? = nil
    ) {
        self.identifiant = identifiant
        self.traitement = traitement
        self.provenance = provenance
        self.licence = licence
        self.marqueurDeLicence = marqueurDeLicence
        self.mentionAPropos = mentionAPropos
        self.jeuDeDonnees = jeuDeDonnees
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
        FicheDeModeleIA(
            identifiant: "detecteur-de-cases-domaine-public-v1",
            traitement: .detectionDeCases,
            provenance: "https://github.com/G-Sadok/yum_rufus",
            licence: "CC0-1.0",
            marqueurDeLicence: "CC0 1.0 Universal",
            mentionAPropos: """
            Detection de cases : detecteur du projet, entraine sur des planches du domaine \
            public du Digital Comic Museum, annotations du projet publiees sous licence \
            CC0 1.0.
            """,
            jeuDeDonnees: FicheDeJeuDeDonnees(
                nom: "Planches du domaine public du Digital Comic Museum",
                provenance: "https://digitalcomicmuseum.com",
                licence: "CC0-1.0",
                redistributionDesPoids: true
            )
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

    /// Mention de provenance du detecteur de cases.
    ///
    /// C est celle que la section 8 impose nommement, et que la section 9 place
    /// en note de fin de la section A propos. Elle est rendue a part parce que
    /// c est la seule que le document exige : les deux autres mentions
    /// documentent la licence des poids, celle ci documente la provenance des
    /// donnees d entrainement.
    public static var mentionDuDetecteurDeCases: String? {
        fiches.first { $0.traitement == .detectionDeCases }?.mentionAPropos
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
    ///   trois conditions manque, ou
    ///   `ErreurDeTraitementIA.jeuDeDonneesNonAutorise` quand le jeu de donnees
    ///   d entrainement manque ou ne permet pas de distribuer les poids.
    @discardableResult
    public static func verifierLaLicence(
        identifiant: String,
        traitement: TraitementIA,
        modele url: URL
    ) throws -> FicheDeModeleIA {
        guard let fiche = fiche(pour: identifiant), fiche.traitement == traitement else {
            throw ErreurDeTraitementIA.licenceNonDocumentee(identifiant: identifiant)
        }

        try verifierLeJeuDeDonnees(de: fiche)

        guard let texte = texteDeLicence(pres: url), fiche.reconnait(texte) else {
            throw ErreurDeTraitementIA.licenceNonDocumentee(identifiant: identifiant)
        }

        return fiche
    }

    /// Verifie que le jeu de donnees d entrainement est documente quand la
    /// section 8 l exige, et qu il autorise la distribution des poids.
    ///
    /// La verification vaut pour toutes les fiches et non pour le seul
    /// detecteur. Un jeu de donnees reserve a la recherche interdit de
    /// distribuer un modele entraine sur lui, quel que soit le traitement
    /// concerne, et le refus doit tomber au chargement plutot qu au premier
    /// courrier d avocat.
    static func verifierLeJeuDeDonnees(de fiche: FicheDeModeleIA) throws {
        if let jeu = fiche.jeuDeDonnees {
            guard jeu.redistributionDesPoids else {
                throw ErreurDeTraitementIA.jeuDeDonneesNonAutorise(identifiant: fiche.identifiant)
            }

            return
        }

        guard fiche.traitement.exigeUnJeuDeDonnees == false else {
            throw ErreurDeTraitementIA.jeuDeDonneesNonAutorise(identifiant: fiche.identifiant)
        }
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
