//
// ParcoursDePremiereOuverture
//
// Le parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md. Trois
// etapes au maximum, une seule decision par etape.
//
// La borne de trois etapes vit dans le modele et non dans la vue. Une quatrieme
// etape ajoutee a l ecran ne compilerait pas : les etapes sont les cas d une
// enumeration, la vue les parcourt, et la suite de tests compare leur nombre a
// la phrase du document. Un parcours d accueil grossit toujours par petites
// additions raisonnables, et c est ainsi qu il finit a sept ecrans.
//
// Le drapeau deja fait est une donnee persistee, comme celui du tutoriel des
// zones de toucher. `MagasinDuParcoursDePremiereOuverture` le relit au
// demarrage et l ecrit une fois. Le rejeu demande depuis l ecran Reglages passe
// par `rejouer`, qui repart de la premiere etape sans effacer ce que
// l utilisateur a deja choisi.
//

/// Une etape du parcours de premiere ouverture, section 5.10.
public enum EtapeDePremiereOuverture: String, Sendable, Codable, CaseIterable, Hashable, Identifiable {
    /// Sens de lecture par defaut, deux cartes avec apercu.
    case sensDeLecture

    /// Premiere source, les trois choix les plus courants.
    case premiereSource

    /// Essai premium, avec Plus tard aussi visible que le bouton d essai.
    case essaiPremium

    public var id: String {
        rawValue
    }

    /// Rang de l etape, de 1 a 3, tel que la section 5.10 les numerote.
    public var rang: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    /// Nom de l etape tel que le document l ecrit, jamais affiche.
    ///
    /// Le libelle visible vient du catalogue de chaines. Ce nom rapproche le
    /// code du document sans recopier la section 5.10 dans un test.
    public var nomDuDocument: String {
        switch self {
        case .sensDeLecture: "Sens de lecture"
        case .premiereSource: "Premiere source"
        case .essaiPremium: "Essai premium"
        }
    }

    /// La seule question posee par l etape.
    ///
    /// La section 5.10 impose une decision par etape. Le lien est bijectif, et
    /// la suite de tests le verifie dans les deux sens : une etape qui poserait
    /// deux questions n aurait pas de decision a rendre ici, et une decision
    /// sans etape n aurait nulle part ou etre prise.
    public var decision: DecisionDePremiereOuverture {
        switch self {
        case .sensDeLecture: .sensParDefaut
        case .premiereSource: .premiereSource
        case .essaiPremium: .essaiPremium
        }
    }
}

/// La decision demandee par une etape, section 5.10.
public enum DecisionDePremiereOuverture: String, Sendable, CaseIterable, Hashable {
    /// Dans quel sens les pages s enchainent.
    case sensParDefaut

    /// Ou l application ira chercher les chapitres.
    case premiereSource

    /// Prendre l essai premium, ou continuer sans lui.
    case essaiPremium
}

/// Une commande offerte par une etape, tableau 6.5.
///
/// Le tableau donne quatre libelles pour cet ecran, et il n en existe pas un
/// cinquieme. Les commandes sont construites a partir de cette enumeration, la
/// vue ne pose donc aucun bouton que le document ne nomme pas.
public enum CommandeDePremiereOuverture: String, Sendable, CaseIterable, Hashable, Identifiable {
    /// Passe a l etape suivante en gardant ce qui vient d etre choisi.
    case continuer

    /// Passe a l etape suivante sans rien choisir.
    case passer

    /// Ouvre l essai premium de sept jours.
    case commencerLEssai

    /// Ferme le parcours sans prendre l essai.
    case plusTard

    public var id: String {
        rawValue
    }
}

/// Etat de la source ajoutee pendant la deuxieme etape, section 5.10.
///
/// Ce sont les quatre etats d une source, que le document nomme un a un : rien,
/// connexion en cours, connectee avec le nombre de series, adresse injoignable.
public enum EtatDeLaSourceInitiale: Sendable, Equatable {
    /// Aucune source choisie pour l instant.
    case rien

    /// Connexion en cours vers la source choisie.
    case connexion(TypeDeSource)

    /// Source connectee, avec le nombre de series qu elle expose.
    case connectee(TypeDeSource, series: Int)

    /// Adresse injoignable.
    case injoignable(TypeDeSource)

    /// Vrai quand une source repond et peut servir de point de depart.
    public var estConnectee: Bool {
        if case .connectee = self {
            return true
        }
        return false
    }

    /// Type de source concerne, nul tant que rien n est choisi.
    public var type: TypeDeSource? {
        switch self {
        case .rien: nil
        case let .connexion(type): type
        case let .connectee(type, _): type
        case let .injoignable(type): type
        }
    }
}

/// Etat du parcours de premiere ouverture, section 5.10.
public struct ParcoursDePremiereOuverture: Sendable, Equatable {
    /// Nombre d etapes que le parcours ne depasse jamais, section 5.10.
    public static let nombreMaximalDEtapes = 3

    /// Les trois sources mises en avant a la deuxieme etape.
    ///
    /// Les libelles ne sont pas reecrits : ce sont trois entrees du menu
    /// d ajout de la section 5.3, prises telles quelles. Le meme mot pour la
    /// meme action d un bout a l autre du parcours, et une entree renommee dans
    /// le menu se renomme ici aussi.
    public static let sourcesMisesEnAvant: [TypeDeSource] = [.fichiersLocaux, .komga, .opds]

    /// Entrees du menu d ajout correspondant aux trois sources mises en avant.
    public static var entreesMisesEnAvant: [EntreeDuMenuDAjout] {
        sourcesMisesEnAvant.compactMap(MenuDAjoutDeSource.entree(pour:))
    }

    /// Vrai quand le parcours a deja ete mene a son terme sur cette
    /// installation.
    public private(set) var dejaFait: Bool

    /// Etape affichee, nulle quand le parcours n est pas ouvert.
    public private(set) var etape: EtapeDePremiereOuverture?

    /// Sens de lecture retenu par la premiere etape.
    public private(set) var sens: SensDeLecture

    /// Etat de la source de la deuxieme etape.
    public private(set) var source: EtatDeLaSourceInitiale

    /// Vrai quand l utilisateur a demande l essai premium a la troisieme etape.
    public private(set) var essaiDemande: Bool

    /// - Parameter dejaFait: drapeau relu depuis la base. Vrai empeche le
    ///   parcours de s ouvrir au lancement, sans empecher son rejeu.
    public init(dejaFait: Bool = false) {
        self.dejaFait = dejaFait
        etape = nil
        sens = .parDefaut
        source = .rien
        essaiDemande = false
    }

    /// Vrai quand le parcours occupe l ecran.
    public var estOuvert: Bool {
        etape != nil
    }

    /// Ouvre le parcours au lancement de l application.
    ///
    /// - Returns: vrai quand le parcours vient de s ouvrir. Faux sur une
    ///   installation qui l a deja vu, ou quand il est deja a l ecran.
    @discardableResult
    public mutating func ouvrirAuLancement() -> Bool {
        guard dejaFait == false, estOuvert == false else { return false }

        etape = .sensDeLecture

        return true
    }

    /// Rejoue le parcours depuis la ligne de l ecran Reglages.
    ///
    /// Le rejeu repart de la premiere etape, et non de celle ou l utilisateur
    /// s etait arrete. Il n efface pas non plus ce qui a deja ete choisi : le
    /// sens de lecture retenu la premiere fois reste selectionne, pour que
    /// revoir le parcours ne coute pas un reglage perdu.
    public mutating func rejouer() {
        etape = .sensDeLecture
    }

    /// Retient le sens de lecture, decision de la premiere etape.
    ///
    /// Choisir ne fait pas avancer : la section 5.10 pose deux cartes et un
    /// bouton Continuer, pour qu un clic sur la mauvaise carte se corrige.
    public mutating func choisirLeSens(_ sens: SensDeLecture) {
        self.sens = sens
    }

    /// Retient l etat de la source, decision de la deuxieme etape.
    public mutating func noterLaSource(_ etat: EtatDeLaSourceInitiale) {
        source = etat
    }

    /// Commandes offertes par l etape affichee, tableau 6.5.
    ///
    /// La deuxieme etape offre `Continuer` une fois la source connectee, et
    /// `Passer` tant qu elle ne l est pas. Un bouton `Continuer` pose sur une
    /// etape ou rien n a ete ajoute mentirait sur ce qui vient de se passer.
    public var commandes: [CommandeDePremiereOuverture] {
        guard let etape else { return [] }

        return Self.commandes(de: etape, source: source)
    }

    /// Commandes offertes par une etape, selon l etat de sa source.
    public static func commandes(
        de etape: EtapeDePremiereOuverture,
        source: EtatDeLaSourceInitiale = .rien
    ) -> [CommandeDePremiereOuverture] {
        switch etape {
        case .sensDeLecture: [.continuer]
        case .premiereSource: source.estConnectee ? [.continuer] : [.passer]
        case .essaiPremium: [.commencerLEssai, .plusTard]
        }
    }

    /// Execute une commande de l etape affichee.
    ///
    /// Une commande que l etape n offre pas est refusee plutot qu appliquee.
    /// C est ce qui empeche un raccourci clavier de sauter une etape, ou de
    /// prendre l essai depuis un ecran qui ne le propose pas.
    ///
    /// - Returns: vrai quand la commande a ete appliquee.
    @discardableResult
    public mutating func executer(_ commande: CommandeDePremiereOuverture) -> Bool {
        guard let etape, commandes.contains(commande) else { return false }

        if commande == .commencerLEssai {
            essaiDemande = true
        }

        avancerDepuis(etape)

        return true
    }

    /// Passe a l etape suivante, ou termine le parcours.
    private mutating func avancerDepuis(_ courante: EtapeDePremiereOuverture) {
        let toutes = EtapeDePremiereOuverture.allCases
        let suivant = courante.rang

        guard suivant < toutes.count else {
            terminer()
            return
        }

        etape = toutes[suivant]
    }

    /// Ferme le parcours et note qu il a ete vu.
    private mutating func terminer() {
        etape = nil
        dejaFait = true
    }
}
