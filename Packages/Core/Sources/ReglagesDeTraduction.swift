//
// ReglagesDeTraduction
//
// Parametres de la traduction des bulles, section 8 du cahier de developpement
// et section Traduction de l inventaire des reglages de la section 9.
//
// Trois valeurs commandent la fonction, et une quatrieme la retient.
//
// L interrupteur `Traduire les bulles` l arme. La langue cible dit vers quoi
// traduire. Le moteur dit ou le travail se fait. Le consentement, lui, n est pas
// une preference : c est la trace d un accord donne une fois, explicitement,
// pour que du texte sorte de l appareil.
//
// La regle qui justifie ce quatrieme champ est celle de la section 8 : tout
// tourne sur l appareil, aucune image ne le quitte sauf si l utilisateur choisit
// explicitement le moteur dans le nuage. Un choix de menu n est pas un choix
// explicite au sens ou l entend cette phrase. Un menu se touche par erreur, et
// l erreur couterait ici une sortie de donnees que rien ne rattrape. Le moteur
// distant ne prend donc effet qu une fois les deux conditions reunies, le choix
// et l accord, et il retombe sur le moteur local le reste du temps.
//
// `moteurEffectif` est la seule valeur que le reste du code doit lire. Lire
// `moteur` directement reviendrait a decider sans savoir si l accord existe, et
// c est exactement le defaut que ce type existe pour rendre impossible.
//

/// Parametres de la traduction des bulles d une page.
public struct ReglagesDeTraduction: Sendable, Hashable, Codable {
    /// Vrai quand l interrupteur `Traduire les bulles` est arme.
    public let actif: Bool

    /// Langue vers laquelle les bulles sont traduites.
    public let langueCible: ChoixDeLangue

    /// Moteur choisi dans le menu des reglages.
    public let moteur: ChoixDeMoteurDeTraduction

    /// Accord donne pour que du texte sorte de l appareil.
    ///
    /// Faux tant que l utilisateur n a pas explicitement accepte. Le champ est
    /// distinct du moteur pour que revenir au moteur local puis y retourner ne
    /// redemande pas l accord, et pour que retirer l accord suffise a fermer la
    /// sortie sans toucher au reste des reglages.
    public let consentementAuNuage: Bool

    public init(
        actif: Bool,
        langueCible: ChoixDeLangue = .parDefaut,
        moteur: ChoixDeMoteurDeTraduction = .parDefaut,
        consentementAuNuage: Bool = false
    ) {
        self.actif = actif
        self.langueCible = langueCible
        self.moteur = moteur
        self.consentementAuNuage = consentementAuNuage
    }

    /// Reglages livres par defaut : interrupteur inactif, moteur local, aucun
    /// accord donne.
    public static let parDefaut = ReglagesDeTraduction(actif: false)

    /// Reglages une fois l interrupteur arme, moteur local.
    public static let arme = ReglagesDeTraduction(actif: true)

    /// Moteur reellement employe, une fois l accord verifie.
    ///
    /// Le moteur distant sans accord retombe sur le moteur local. Ce n est pas
    /// une degradation silencieuse : la ligne de reglages ne montre le moteur
    /// distant comme choisi qu apres l accord, et `attendUnConsentement` dit a
    /// l interface qu il reste a demander.
    public var moteurEffectif: ChoixDeMoteurDeTraduction {
        guard moteur.exigeUnConsentement else { return moteur }

        return consentementAuNuage ? moteur : .surLAppareil
    }

    /// Vrai quand le moteur choisi attend encore l accord de l utilisateur.
    public var attendUnConsentement: Bool {
        moteur.exigeUnConsentement && consentementAuNuage == false
    }

    /// Vrai quand du texte sort reellement de l appareil.
    ///
    /// C est la question a laquelle l interface doit repondre pour decider
    /// d afficher ou non la mention permanente. Elle ne se deduit ni du moteur
    /// seul, ni du consentement seul.
    public var sortDeLAppareil: Bool {
        actif && moteurEffectif.estDansLeNuage
    }

    /// Vrai quand la traduction a besoin du reseau pour aboutir.
    public var exigeLeReseau: Bool {
        sortDeLAppareil
    }

    /// Les memes reglages, avec l accord donne.
    public func avecConsentement() -> ReglagesDeTraduction {
        ReglagesDeTraduction(
            actif: actif,
            langueCible: langueCible,
            moteur: moteur,
            consentementAuNuage: true
        )
    }

    /// Les memes reglages, avec l accord retire.
    ///
    /// Retirer l accord suffit a fermer la sortie. Le moteur choisi reste ce
    /// qu il est, et la fonction repart sur l appareil.
    public func sansConsentement() -> ReglagesDeTraduction {
        ReglagesDeTraduction(
            actif: actif,
            langueCible: langueCible,
            moteur: moteur,
            consentementAuNuage: false
        )
    }

    /// Empreinte des parametres, destinee aux cles de cache.
    ///
    /// Elle porte le moteur effectif et non le moteur choisi. Deux lectures de
    /// la meme page, l une avant l accord et l autre apres, n ont pas ete
    /// traduites par le meme moteur : les confondre sous une meme cle ferait
    /// ressortir la traduction locale la ou l utilisateur vient de payer la
    /// traduction distante.
    public var empreinte: String {
        "tr=\(actif ? 1 : 0);lc=\(langueCible.rawValue);mt=\(moteurEffectif.rawValue)"
    }
}
