import Core

//
// Textes du parcours de premiere ouverture, sections 5.10, 6.5 et 6.8 de
// DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
// sait lequel c est.
//
// Les libelles de source ne sont pas redemandes au catalogue : la deuxieme
// etape met en avant trois entrees du menu d ajout de la section 5.3, et elle
// les nomme comme le menu les nomme. Le meme mot pour la meme action d un bout
// a l autre du parcours.
//

/// Textes du parcours de premiere ouverture.
public struct LibellesDePremiereOuverture: Sendable, Equatable {
    /// Titre de chaque etape, indexe par sa representation persistee.
    public let titres: [String: String]

    /// Phrase posee sous le titre de chaque etape.
    public let phrases: [String: String]

    /// Libelle de chaque commande, tableau 6.5.
    public let commandes: [String: String]

    /// Libelle des deux sens de lecture, tableau 6.7.
    public let sens: [String: String]

    /// Libelle des trois sources mises en avant, section 5.3.
    public let sources: [String: String]

    /// Lien vers la liste complete des sources, section 5.10.
    public let voirToutesLesSources: String

    /// Mention posee a la deuxieme etape, tableau 6.8.
    public let mentionDeLaDeuxiemeEtape: String

    /// Sous ligne d une source en cours de connexion.
    public let connexionEnCours: String

    /// Sous ligne d une source connectee, avec le nombre de series.
    public let seriesTrouvees: String

    /// Sous ligne d une source injoignable, tableau 6.4.
    public let adresseInjoignable: String

    /// Etiquette d accessibilite des points de progression.
    public let progression: String

    /// Etiquette d accessibilite d un apercu de sens de lecture.
    public let apercuDuSens: String

    public init(
        titres: [String: String],
        phrases: [String: String],
        commandes: [String: String],
        sens: [String: String],
        sources: [String: String],
        voirToutesLesSources: String,
        mentionDeLaDeuxiemeEtape: String,
        connexionEnCours: String,
        seriesTrouvees: String,
        adresseInjoignable: String,
        progression: String,
        apercuDuSens: String
    ) {
        self.titres = titres
        self.phrases = phrases
        self.commandes = commandes
        self.sens = sens
        self.sources = sources
        self.voirToutesLesSources = voirToutesLesSources
        self.mentionDeLaDeuxiemeEtape = mentionDeLaDeuxiemeEtape
        self.connexionEnCours = connexionEnCours
        self.seriesTrouvees = seriesTrouvees
        self.adresseInjoignable = adresseInjoignable
        self.progression = progression
        self.apercuDuSens = apercuDuSens
    }

    /// Titre d une etape.
    ///
    /// Une etape sans titre retombe sur sa representation persistee. Le cas
    /// signale un trou dans le catalogue, et la suite de tests le detecte avant
    /// qu il n arrive a l ecran.
    public func titre(de etape: EtapeDePremiereOuverture) -> String {
        titres[etape.rawValue] ?? etape.rawValue
    }

    /// Phrase d une etape.
    public func phrase(de etape: EtapeDePremiereOuverture) -> String {
        phrases[etape.rawValue] ?? ""
    }

    /// Libelle d une commande, tableau 6.5.
    public func libelle(de commande: CommandeDePremiereOuverture) -> String {
        commandes[commande.rawValue] ?? commande.rawValue
    }

    /// Libelle d un sens de lecture, tableau 6.7.
    public func libelle(de sens: SensDeLecture) -> String {
        self.sens[sens.rawValue] ?? sens.rawValue
    }

    /// Libelle d une source mise en avant, section 5.3.
    public func libelle(de source: TypeDeSource) -> String {
        sources[source.rawValue] ?? source.rawValue
    }
}

/// Assemblage des textes du parcours de premiere ouverture.
public enum TexteDePremiereOuverture {
    /// Sens proposes par la premiere etape, dans l ordre de la section 5.10.
    ///
    /// Le document pose `Droite a gauche` a gauche de l ecran et
    /// `Gauche a droite` a droite. L ordre vient donc du document, il n est pas
    /// celui de l enumeration, et il ne suit pas non plus la direction de
    /// l interface : c est une illustration du sens de lecture d un manga, pas
    /// un element de navigation.
    public static let sensProposes: [SensDeLecture] = SensDeLecture.choixDuMenuDeReglages

    /// Sous ligne d une ligne de source, nulle quand la source n a rien a dire.
    public static func sousLigne(
        de etat: EtatDeLaSourceInitiale,
        pour source: TypeDeSource,
        libelles: LibellesDePremiereOuverture
    ) -> String? {
        guard etat.type == source else { return nil }

        switch etat {
        case .rien:
            return nil

        case .connexion:
            return libelles.connexionEnCours

        case let .connectee(_, series):
            return String(format: libelles.seriesTrouvees, series)

        case .injoignable:
            return libelles.adresseInjoignable
        }
    }

    /// Etiquette d accessibilite des points de progression.
    ///
    /// La section 7 interdit de transmettre une information par la seule
    /// couleur. Les points disent le rang en `accent`, l etiquette le dit en
    /// toutes lettres.
    public static func etiquetteDeProgression(
        de etape: EtapeDePremiereOuverture,
        libelles: LibellesDePremiereOuverture
    ) -> String {
        String(
            format: libelles.progression,
            etape.rang,
            EtapeDePremiereOuverture.allCases.count
        )
    }
}
