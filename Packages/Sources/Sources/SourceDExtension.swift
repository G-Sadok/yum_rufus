import Core
import Foundation

//
// SourceDExtension
//
// L implementation de `SourceProvider` pilotee par un manifeste declaratif.
//
// Elle ne contient aucune connaissance d un catalogue particulier. Elle sait
// quelle regle repond a quelle question du protocole, elle demande l adresse a
// l interprete, elle passe la requete au transport, et elle rend l analyse de
// l interprete. Tout ce qui varie d un catalogue a l autre vit dans le
// manifeste, et rien de ce qui vit dans le manifeste n est autre chose qu une
// valeur.
//
// Le transport est toujours un `TransportDExtension`, jamais le transport brut.
// La construction ne laisse pas le choix : la source se construit depuis une
// extension installee et un transport interne, et pose la barriere elle meme.
// C est ce qui garantit qu aucun chemin de ce fichier ne peut atteindre le
// reseau sans passer par la liste blanche et par le delai.
//

/// Une source de contenu pilotee par une extension declarative.
public struct SourceDExtension: SourceProvider {
    public let id: SourceID

    private let manifeste: ManifesteDExtension
    private let interprete: InterpreteDExtension
    private let transport: TransportDExtension

    /// Construit la source d une extension installee.
    ///
    /// - Parameters:
    ///   - installee: l extension, avec la confirmation qui l a autorisee.
    ///   - transportInterne: le transport reel, qui ne doit suivre aucune
    ///     redirection. Voir `TransportURLSessionSansRedirection`.
    ///   - journal: ou sont consignes les refus opposes a l extension.
    ///   - id: identite de la source configuree.
    public init(
        installee: ExtensionInstallee,
        transportInterne: any TransportHttp,
        journal: any JournalDExtensions,
        delaiMaximal: Duration = TransportDExtension.delaiParDefaut,
        id: SourceID = SourceID()
    ) {
        self.id = id
        manifeste = installee.manifeste
        interprete = InterpreteDExtension(regles: installee.manifeste.regles)
        transport = TransportDExtension(
            interne: transportInterne,
            extensionInstallee: installee,
            journal: journal,
            delaiMaximal: delaiMaximal
        )
    }

    public var nom: String {
        manifeste.nom
    }

    public var capacites: SourceCapacites {
        manifeste.capacites
    }

    /// Sous titre de la ligne de source, tableau 4.4 de DESIGN-SPEC.md.
    ///
    /// Le document ecrit `v1.4  multilingue` pour une extension de catalogue.
    /// Le second element est la langue declaree, ou la mention multilingue
    /// quand l extension sert plusieurs langues.
    public var version: VersionDExtension {
        manifeste.version
    }

    /// Langue du catalogue, au format BCP 47.
    public var langue: String {
        manifeste.langue
    }

    // MARK: Protocole

    /// Verifie que le catalogue repond.
    ///
    /// La verification passe par la premiere regle declaree, quelle qu elle
    /// soit. Une extension sans aucune regle de liste ne se verifie pas : elle
    /// rend `nonVerifie` plutot qu un etat invente.
    public func verifierConnexion() async -> EtatConnexion {
        guard let regle = manifeste.regles.sections.first?.regle ?? manifeste.regles.recherche else {
            return .nonVerifie
        }

        do {
            _ = try await lire(regle.requete, contexte: contexte())

            return .connecte
        } catch let erreur {
            return ErreurDeSource.depuis(erreur, source: nom).etatDeConnexion
        }
    }

    public func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
        try exiger(.recherche)

        if requete.filtres.estVide == false {
            try exiger(.filtres)
        }
        if requete.langue != nil {
            try exiger(.plusieursLangues)
        }
        if requete.page > 0 {
            try exiger(.pagination)
        }

        let regle = try regleObligatoire(manifeste.regles.recherche, capacite: .recherche)
        let contexte = contexte(texte: requete.texte, page: requete.page, langue: requete.langue)

        return try await interprete.series(
            depuis: lire(regle.requete, contexte: contexte),
            regle: regle,
            page: requete.page
        )
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }

        guard let regle = manifeste.regles.regle(pour: section) else {
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }

        return try await interprete.series(
            depuis: lire(regle.requete, contexte: contexte(page: page)),
            regle: regle,
            page: page
        )
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        guard let regle = manifeste.regles.details else {
            throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        }

        return try await interprete.detail(
            depuis: lire(regle.requete, contexte: contexte(serie: identifiant)),
            regle: regle,
            identifiant: identifiant
        )
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        let regle = manifeste.regles.chapitres

        return try await interprete.chapitres(
            depuis: lire(regle.requete, contexte: contexte(serie: identifiant)),
            regle: regle,
            identifiantManga: identifiant
        )
    }

    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        let regle = manifeste.regles.pages

        return try await interprete.pages(
            depuis: lire(regle.requete, contexte: contexte(chapitre: chapitre)),
            regle: regle,
            identifiantChapitre: chapitre
        )
    }

    /// La requete qui rapporte les octets d une page.
    ///
    /// L adresse est verifiee contre la liste blanche avant d etre rendue, et
    /// pas seulement au moment ou la chaine d images l enverra. Une page
    /// pointant hors liste est le chemin le plus discret pour faire joindre un
    /// tiers par l application : la couche qui telecharge l image ne connait ni
    /// l extension ni ses domaines.
    ///
    /// - Throws: `ErreurReseau.domaineNonAutorise` quand l adresse sort de la
    ///   liste blanche de l extension.
    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        guard manifeste.listeBlanche.autorise(page.emplacement) else {
            throw ErreurReseau.domaineNonAutorise(
                domaine: ListeBlancheDeDomaines.hote(de: page.emplacement) ?? ""
            )
        }

        var requete = URLRequest(url: page.emplacement)
        requete.httpMethod = MethodeHttp.get.rawValue

        return requete
    }

    // MARK: Requetes

    /// Demande un document au catalogue, a travers la barriere.
    private func lire(_ regle: RegleDeRequete, contexte: ContexteDeGabarit) async throws -> Data {
        var requete = try URLRequest(url: interprete.adresse(pour: regle, contexte: contexte))
        requete.httpMethod = MethodeHttp.get.rawValue
        requete.setValue(regle.format == .json ? "application/json" : "text/html", forHTTPHeaderField: "Accept")

        let reponse = try await transport.executer(requete)

        if let erreur = ErreurReseau.depuis(codeHttp: reponse.code) {
            throw erreur
        }

        return reponse.corps
    }

    /// Le contexte que les gabarits remplissent.
    ///
    /// La langue du manifeste sert de valeur par defaut : une extension qui
    /// cite `{langue}` sans que l appelant en demande une doit interroger son
    /// catalogue dans la langue qu elle declare, pas dans une chaine vide.
    private func contexte(
        texte: String = "",
        page: Int = 0,
        langue: String? = nil,
        serie: String = "",
        chapitre: String = ""
    ) -> ContexteDeGabarit {
        ContexteDeGabarit(
            texteRecherche: texte,
            page: page,
            langue: langue ?? manifeste.langue,
            identifiantSerie: serie,
            identifiantChapitre: chapitre
        )
    }

    /// La regle demandee, ou le refus qui dit laquelle manque.
    private func regleObligatoire<Regle>(_ regle: Regle?, capacite: SourceCapacites) throws -> Regle {
        guard let regle else {
            throw ErreurDeSource.declarative(.regleAbsente(capacite: capacite), source: nom)
        }

        return regle
    }
}
