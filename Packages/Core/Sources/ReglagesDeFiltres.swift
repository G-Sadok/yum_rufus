//
// ReglagesDeFiltres
//
// Etat du panneau de filtres du lecteur, section 5.7 de DESIGN-SPEC.md.
//
// Le panneau porte cinq curseurs et trois interrupteurs. Ces huit valeurs sont
// aussi des etapes de la chaine de traitement de la section 6.3, et c est la
// leur seul lien : le panneau decide de ce qui est actif, la chaine decide de
// l ordre. Aucun des deux ne connait l ordre de l autre. Le panneau range ses
// lignes comme la section 5.7 les dessine, la chaine range ses etapes comme la
// section 6.3 les numerote, et les deux ordres different.
//
// Les valeurs vont de zero a cent, comme tous les curseurs du produit. La valeur
// par defaut n est pas toujours le minimum : la luminosite part de cent, le
// contraste et le gamma partent du milieu. Un curseur pose sur sa valeur par
// defaut est neutre, il n ajoute aucune etape a la chaine, et c est ce qui
// garantit qu une installation neuve n applique aucun filtre.
//

/// Un des cinq curseurs du panneau de filtres, section 5.7.
public enum FiltreDImage: String, Sendable, CaseIterable, Hashable {
    case luminosite
    case chaleur
    case nettete
    case contraste
    case gamma

    /// Les cinq curseurs dans l ordre ou la section 5.7 les dessine.
    ///
    /// Cet ordre n est pas celui de la chaine de la section 6.3. Le panneau met
    /// en tete ce que l utilisateur change le plus souvent, la chaine met en
    /// tete ce qui doit s appliquer en premier.
    public static let ordreDuPanneau: [FiltreDImage] = [
        .luminosite,
        .chaleur,
        .nettete,
        .contraste,
        .gamma,
    ]

    /// Etape de la chaine de traitement que ce curseur commande.
    public var etape: EtapeDeTraitement {
        switch self {
        case .luminosite: .luminosite
        case .chaleur: .chaleur
        case .nettete: .nettete
        case .contraste: .contraste
        case .gamma: .gamma
        }
    }

    /// Valeur livree par defaut, inventaire de la section 9 du cahier de
    /// developpement.
    public var valeurParDefaut: Double {
        switch self {
        case .luminosite: 100
        case .chaleur: 0
        case .nettete: 0
        case .contraste: 50
        case .gamma: 50
        }
    }

    /// Bornes du curseur, celles de tous les curseurs du produit.
    public var bornes: BornesDeReglage {
        .pourcentage
    }
}

/// Un des trois interrupteurs du panneau de filtres, section 5.7.
public enum TraitementDImage: String, Sendable, CaseIterable, Hashable {
    case reductionDuBruit
    case ameliorationIA
    case colorisationIA

    /// Les trois interrupteurs dans l ordre ou la section 5.7 les dessine.
    public static let ordreDuPanneau: [TraitementDImage] = [
        .reductionDuBruit,
        .ameliorationIA,
        .colorisationIA,
    ]

    /// Etape de la chaine de traitement que cet interrupteur commande.
    public var etape: EtapeDeTraitement {
        switch self {
        case .reductionDuBruit: .reductionDuBruit
        case .ameliorationIA: .ameliorationIA
        case .colorisationIA: .colorisationIA
        }
    }

    /// Etat livre par defaut, inventaire de la section 9.
    ///
    /// Les trois partent inactifs. Un traitement qui modifie la planche ne
    /// s arme jamais sans que l utilisateur l ait demande.
    public var actifParDefaut: Bool {
        false
    }

    /// Vrai quand la fonction est reservee a l abonnement, matrice de la
    /// section 10 : les filtres non IA sont gratuits, les deux traitements par
    /// IA ne le sont pas.
    public var estReserveAuPremium: Bool {
        switch self {
        case .reductionDuBruit: false
        case .ameliorationIA, .colorisationIA: true
        }
    }
}

/// Valeurs des cinq curseurs et des trois interrupteurs du panneau de filtres.
public struct ReglagesDeFiltres: Sendable, Equatable, Hashable {
    private var curseurs: [FiltreDImage: Double]
    private var traitements: Set<TraitementDImage>

    /// Construit un etat a partir des seules valeurs changees.
    ///
    /// Ce qui manque vient de la valeur par defaut du curseur, comme
    /// `ReglagesDeLApplication` le fait pour les lignes de reglages. Une valeur
    /// lue est donc toujours definie et toujours dans ses bornes.
    public init(
        curseurs: [FiltreDImage: Double] = [:],
        traitements: Set<TraitementDImage> = []
    ) {
        self.curseurs = curseurs
        self.traitements = traitements
    }

    /// Etat d une installation neuve, ou rien n a jamais ete change.
    public static let parDefaut = ReglagesDeFiltres()

    /// Etat initial du panneau, luminosite reprise du reglage du meme nom.
    ///
    /// La section 5.5 de DESIGN-SPEC.md pose une ligne `Luminosite du lecteur`
    /// dans les reglages, et la section 5.7 pose un curseur `Luminosite` dans le
    /// panneau. Ce sont deux surfaces pour la meme grandeur, pas deux grandeurs.
    /// Les faire diverger donnerait deux luminosites contradictoires selon
    /// l ecran ouvert. Les quatre autres curseurs n ont pas de ligne dans le
    /// tableau de la section 5.5 et partent donc de leur valeur par defaut.
    public static func depuis(_ reglages: ReglagesDeLApplication) -> ReglagesDeFiltres {
        ReglagesDeFiltres(curseurs: [.luminosite: reglages.curseur(.luminositeDuLecteur)])
    }

    /// Valeur d un curseur, celle par defaut tant que rien ne l a remplacee.
    public func valeur(_ filtre: FiltreDImage) -> Double {
        guard let valeur = curseurs[filtre] else {
            return filtre.valeurParDefaut
        }

        return filtre.bornes.contraindre(valeur)
    }

    /// Etat d un interrupteur.
    public func estActif(_ traitement: TraitementDImage) -> Bool {
        traitements.contains(traitement)
    }

    /// Deplace un curseur, la valeur etant ramenee dans ses bornes.
    public mutating func regler(_ filtre: FiltreDImage, a valeur: Double) {
        curseurs[filtre] = filtre.bornes.contraindre(valeur)
    }

    /// Arme ou desarme un interrupteur.
    public mutating func basculer(_ traitement: TraitementDImage, _ actif: Bool) {
        if actif {
            traitements.insert(traitement)
        } else {
            traitements.remove(traitement)
        }
    }

    /// Vrai quand ce curseur est pose sur sa valeur par defaut.
    ///
    /// Un curseur neutre n ajoute aucune etape a la chaine. La comparaison se
    /// fait a moins d une unite, parce qu un curseur rend un flottant et que
    /// l ecart d un millieme entre 50 et 50,0001 ne se voit sur aucune planche
    /// mais couterait une passe de rendu a chaque page.
    public func estNeutre(_ filtre: FiltreDImage) -> Bool {
        abs(valeur(filtre) - filtre.valeurParDefaut) < 1
    }

    /// Vrai quand aucun curseur ni aucun interrupteur ne modifie la page.
    public var estNeutre: Bool {
        etapesDemandees.isEmpty
    }

    /// Etapes que ces reglages demandent, dans l ordre de la section 6.3.
    ///
    /// C est le seul point du code qui traduit un etat de panneau en chaine de
    /// traitement, et il rend toujours l ordre du document, jamais celui du
    /// panneau ni celui d un dictionnaire.
    public var etapesDemandees: [EtapeDeTraitement] {
        let curseursActifs = FiltreDImage.allCases
            .filter { estNeutre($0) == false }
            .map(\.etape)

        let traitementsActifs = traitements.map(\.etape)

        return (curseursActifs + traitementsActifs).dansLOrdreDeLaChaine
    }

    /// Empreinte des valeurs, destinee aux cles de cache.
    ///
    /// Deux etats qui produisent la meme page portent la meme empreinte, et deux
    /// etats qui produisent des pages differentes en portent deux. Un curseur
    /// neutre n y figure pas : le faire entrer multiplierait les entrees de
    /// cache pour des pages identiques.
    public var empreinte: String {
        let morceaux = FiltreDImage.ordreDuPanneau
            .filter { estNeutre($0) == false }
            .map { "\($0.rawValue)=\(Int(valeur($0).rounded()))" }

        let armes = TraitementDImage.ordreDuPanneau
            .filter(estActif)
            .map(\.rawValue)

        guard morceaux.isEmpty == false || armes.isEmpty == false else {
            return "filtres=0"
        }

        return (["filtres=1"] + morceaux + armes).joined(separator: ";")
    }
}
