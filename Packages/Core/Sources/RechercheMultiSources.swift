import Foundation

//
// RechercheMultiSources
//
// L etat de l ecran Rechercher de la section 5.4 de DESIGN-SPEC.md : une rangee
// par source, chacune avec son propre etat.
//
// Le modele vit dans Core et non dans la vue pour une raison qui est aussi le
// premier critere de la fonctionnalite. Une rangee ne connait que son etat, et
// une reponse ne touche que sa rangee. Une source lente laisse donc la sienne en
// chargement pendant que les autres passent en resultats, et il n existe nulle
// part d etat commun ou son attente pourrait retenir les autres. C est une
// propriete du type, pas une precaution de la vue, et elle se teste sans rendu.
//

/// Une source que la recherche va interroger.
///
/// Le nom voyage a cote de l identifiant, comme dans `ResultatDeSource` et pour
/// la meme raison : la rangee affiche le nom de sa source sans avoir a demander
/// au registre une source qui vient peut etre d en etre retiree.
public struct SourceInterrogee: Sendable, Equatable, Identifiable {
    public let source: SourceID
    public let nom: String

    public init(source: SourceID, nom: String) {
        self.source = source
        self.nom = nom
    }

    public var id: SourceID {
        source
    }
}

/// Ce qu une rangee de l ecran Rechercher a a montrer.
public enum EtatDeGroupeDeRecherche: Sendable, Equatable {
    /// La source n a pas encore repondu.
    case chargement

    /// La source a repondu. Un tableau vide veut dire qu elle ne connait rien
    /// qui corresponde, ce qui n est pas une erreur.
    case chargee(resultats: [MangaDistant], ilResteDesPages: Bool)

    /// La source a echoue, et la rangee cede la place a une ligne discrete.
    case erreur(ErreurDeSource)
}

/// Une rangee de resultats, pour une source.
public struct GroupeDeRecherche: Sendable, Equatable, Identifiable {
    public let source: SourceID
    public let nom: String
    public let etat: EtatDeGroupeDeRecherche

    public init(source: SourceID, nom: String, etat: EtatDeGroupeDeRecherche = .chargement) {
        self.source = source
        self.nom = nom
        self.etat = etat
    }

    public var id: SourceID {
        source
    }

    /// Les series rendues par la source, vides tant qu elle n a pas repondu.
    public var resultats: [MangaDistant] {
        guard case let .chargee(resultats, _) = etat else {
            return []
        }

        return resultats
    }

    /// Nombre de resultats, nul tant que la source n a pas repondu.
    ///
    /// Nul et zero disent deux choses differentes, et la vue les affiche
    /// differemment : un compteur absent pendant le chargement, un compteur a
    /// zero quand la source a repondu qu elle ne connaissait rien.
    public var nombreDeResultats: Int? {
        guard case let .chargee(resultats, _) = etat else {
            return nil
        }

        return resultats.count
    }

    /// Vrai quand la source annonce d autres pages derriere celle ci.
    public var ilResteDesPages: Bool {
        guard case let .chargee(_, ilResteDesPages) = etat else {
            return false
        }

        return ilResteDesPages
    }

    public var erreur: ErreurDeSource? {
        guard case let .erreur(erreur) = etat else {
            return nil
        }

        return erreur
    }

    public var estEnChargement: Bool {
        if case .chargement = etat {
            return true
        }

        return false
    }

    /// Vrai quand la rangee a quelque chose a montrer.
    public var porteDesResultats: Bool {
        resultats.isEmpty == false
    }
}

/// Etat complet de l ecran Rechercher.
public struct ResultatsDeRecherche: Sendable, Equatable {
    /// Texte cherche, tel que l utilisateur l a tape.
    public let terme: String

    /// Une rangee par source interrogee, dans l ordre du registre.
    ///
    /// L ordre ne suit pas celui des reponses : une liste qui se reordonnerait
    /// selon la latence du reseau changerait de forme a chaque frappe.
    public private(set) var groupes: [GroupeDeRecherche]

    /// Source dont la liste complete est ouverte, lien Tout voir de la 5.4.
    public private(set) var sourceDepliee: SourceID?

    /// Prepare l ecran avant la premiere reponse.
    ///
    /// Toutes les rangees existent des le depart, en chargement. C est ce qui
    /// permet a la vue de poser ses squelettes aux bonnes dimensions et de ne
    /// plus bouger ensuite.
    public init(terme: String, sources: [SourceInterrogee]) {
        self.terme = terme
        groupes = sources.map { GroupeDeRecherche(source: $0.source, nom: $0.nom) }
    }

    // MARK: Arrivee des reponses

    /// Range une reponse dans sa rangee, sans toucher aux autres.
    ///
    /// Une reponse pour une source absente de l ecran est ignoree : elle vient
    /// d une recherche precedente ou d une source retiree entre temps, et
    /// l ajouter ferait apparaitre une rangee que rien n a annoncee.
    public mutating func appliquer(_ resultat: ResultatDeSource<PageResultats<MangaDistant>>) {
        remplacer(resultat.source) { groupe in
            GroupeDeRecherche(
                source: groupe.source,
                nom: groupe.nom,
                etat: Self.etat(de: resultat)
            )
        }
    }

    /// Remet une rangee en chargement, avant de relancer sa seule source.
    ///
    /// Le lien Reessayer de la ligne d erreur passe par la. Il ne relance rien
    /// des autres sources : elles ont deja repondu, et les interroger a nouveau
    /// ferait clignoter des rangees qui vont afficher la meme chose.
    public mutating func remettreEnChargement(_ source: SourceID) {
        remplacer(source) { groupe in
            GroupeDeRecherche(source: groupe.source, nom: groupe.nom, etat: .chargement)
        }
    }

    // MARK: Liste complete d une source

    /// Ouvre la liste complete d une source, lien Tout voir de la section 5.4.
    ///
    /// Rend vrai quand la liste s ouvre. Une source qui n a rien rendu, qui est
    /// en echec ou qui n existe pas sur cet ecran n ouvre rien : le lien n est
    /// affiche que sur une rangee qui porte des resultats, et une action
    /// declenchee malgre tout ne doit pas ouvrir une liste vide.
    @discardableResult
    public mutating func deplier(_ source: SourceID) -> Bool {
        guard let groupe = groupe(source), groupe.porteDesResultats else {
            return false
        }

        sourceDepliee = source

        return true
    }

    /// Referme la liste complete et revient aux rangees.
    public mutating func replier() {
        sourceDepliee = nil
    }

    /// La rangee dont la liste complete est ouverte.
    public var groupeDeplie: GroupeDeRecherche? {
        sourceDepliee.flatMap(groupe)
    }

    public func groupe(_ source: SourceID) -> GroupeDeRecherche? {
        groupes.first { $0.source == source }
    }

    // MARK: Lecture d ensemble

    /// Vrai quand aucune source ne sait chercher, ou qu aucune n est installee.
    public var aucuneSourceInterrogee: Bool {
        groupes.isEmpty
    }

    /// Vrai quand toutes les sources ont repondu, en resultats ou en echec.
    public var estTerminee: Bool {
        groupes.contains { $0.estEnChargement } == false
    }

    /// Rangees qui ont echoue, celles qui portent une ligne discrete.
    public var groupesEnEchec: [GroupeDeRecherche] {
        groupes.filter { $0.erreur != nil }
    }

    /// Vrai quand toutes les sources interrogees ont echoue, tableau 6.4.
    ///
    /// L ecran bascule alors sur son etat d erreur global, parce qu une page de
    /// lignes d erreur empilees n aide personne.
    public var toutesLesSourcesOntEchoue: Bool {
        aucuneSourceInterrogee == false && groupesEnEchec.count == groupes.count
    }

    /// Vrai quand toutes les sources ont repondu et qu aucune ne connait le
    /// terme cherche.
    public var aucunResultat: Bool {
        estTerminee
            && aucuneSourceInterrogee == false
            && toutesLesSourcesOntEchoue == false
            && groupes.contains { $0.porteDesResultats } == false
    }

    /// Nombre total de series rendues, toutes sources confondues.
    public var nombreTotalDeResultats: Int {
        groupes.reduce(0) { total, groupe in total + groupe.resultats.count }
    }

    // MARK: Interne

    private mutating func remplacer(
        _ source: SourceID,
        par transformation: (GroupeDeRecherche) -> GroupeDeRecherche
    ) {
        guard let position = groupes.firstIndex(where: { $0.source == source }) else {
            return
        }

        groupes[position] = transformation(groupes[position])

        if sourceDepliee == source, groupes[position].porteDesResultats == false {
            sourceDepliee = nil
        }
    }

    private static func etat(
        de resultat: ResultatDeSource<PageResultats<MangaDistant>>
    ) -> EtatDeGroupeDeRecherche {
        switch resultat.resultat {
        case let .success(page):
            .chargee(resultats: page.elements, ilResteDesPages: page.ilResteDesPages)
        case let .failure(erreur):
            .erreur(erreur)
        }
    }
}

// MARK: - Cause affichee par une ligne d erreur

/// Ce qu une ligne d erreur de la section 5.4 a a dire en une seule ligne.
///
/// L ecran ne peut pas y poser `ErreurDeSource.messageUtilisateur` : ce message
/// nomme la cause et la sortie en deux phrases, ce qui est juste dans un etat
/// d erreur plein ecran et illisible dans une ligne de 52. Cette enumeration
/// choisit laquelle des quatre formes courtes s applique, et la vue lui donne
/// le libelle du catalogue de chaines qui correspond.
public enum CauseDEchecDeSource: String, Sendable, CaseIterable, Hashable {
    /// La source n a rien rendu avant la fin du delai accorde.
    case delaiDepasse

    /// La source n a pas pu etre jointe du tout.
    case injoignable

    /// Le serveur a refuse les identifiants ou l acces.
    case accesRefuse

    /// Echec qu aucune des trois formes precedentes ne decrit.
    case echec
}

extension ErreurDeSource {
    /// Forme courte affichee par la ligne d erreur de la section 5.4.
    public var causeCourte: CauseDEchecDeSource {
        switch self {
        case let .reseau(reseau, _):
            Self.cause(de: reseau)
        case .sourceInjoignable, .accesAuDossierPerdu:
            .injoignable
        default:
            .echec
        }
    }

    private static func cause(de reseau: ErreurReseau) -> CauseDEchecDeSource {
        switch reseau {
        case .delaiDepasse:
            .delaiDepasse
        case .authentificationRefusee, .accesRefuse:
            .accesRefuse
        default:
            reseau.etatDeConnexion == .injoignable ? .injoignable : .echec
        }
    }
}
