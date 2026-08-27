//
// MatriceDeVerrouillage
//
// La matrice de la section 10 du cahier de developpement, ecrite une seule fois
// et consultee partout.
//
// Le document donne deux listes de mots. Le code en fait une enumeration dont
// chaque cas porte le nom exact du document, et la suite de tests confronte les
// deux plutot que de recopier la liste a cote. Une fonction deplacee d une
// colonne a l autre change alors le document et le code ensemble, ou fait virer
// la suite au rouge.
//
// Le point important n est pas l enumeration, c est l unicite. Avant elle,
// chaque ecran decidait seul si sa fonction etait payante, et le tableau de la
// section 5.5 de DESIGN-SPEC.md ne marquait d une couronne que deux lignes sur
// les dix sept que la section 10 place derriere l abonnement. Un ecran qui
// oublie de poser la question laisse une fonction premium ouverte, et personne
// ne s en apercoit avant la premiere facture manquante. Il n existe desormais
// qu un seul endroit ou la question se pose.
//
// Arbitrage entre les deux documents, regle 0.1 de DESIGN-SPEC.md : le texte du
// cahier des charges est normatif. La section 10 decide donc de ce qui est
// verrouille, la section 5.5 decide de la forme que prend une ligne verrouillee.
//

/// Une fonction du produit, telle que la matrice de la section 10 la nomme.
///
/// Les deux colonnes du document vivent dans la meme enumeration, et non dans
/// deux listes separees. Une fonction absente des deux colonnes n existe donc
/// pas ici, ce que la suite de tests verifie dans les deux sens.
public enum FonctionDeLApplication: String, Sendable, CaseIterable, Hashable, Identifiable {
    // Colonne gratuite.

    /// Dossiers et receptions poses sur l appareil.
    case sourcesLocales

    /// Dossier iCloud Drive de l utilisateur.
    case iCloudDrive

    /// Partage SMB.
    case smb

    /// Partage NFS.
    case nfs

    /// Serveur WebDAV.
    case webdav

    /// Extensions declaratives et leur depot.
    case extensions

    /// Lecteur pagine et webtoon, sans restriction.
    case lecteurComplet

    /// Les cinq curseurs et la reduction de bruit du panneau de filtres.
    case filtresNonIA

    /// Categories de la bibliotheque.
    case categories

    /// Historique de lecture.
    case historique

    /// Signets de page.
    case signets

    /// Statistiques de lecture.
    case statistiques

    /// Prereglages de lecture.
    case prereglages

    // Colonne premium.

    /// Traduction des bulles, et ses reglages.
    case traduction

    /// Amelioration de la planche par IA.
    case ameliorationIA

    /// Colorisation par IA.
    case colorisationIA

    /// Serveur Komga.
    case serveurKomga

    /// Serveur Kavita.
    case serveurKavita

    /// Serveur Jellyfin.
    case serveurJellyfin

    /// Catalogue OPDS.
    case serveurOpds

    /// Services de suivi de lecture.
    case suivis

    /// Telechargements hors ligne.
    case telechargements

    /// Sauvegarde et restauration.
    case sauvegardeEtRestauration

    /// Synchronisation iCloud.
    case synchronisationICloud

    /// Gestion du stockage.
    case gestionDuStockage

    /// Mode incognito.
    case incognito

    public var id: String {
        rawValue
    }

    /// Nom de la fonction tel que la section 10 l ecrit.
    ///
    /// Il ne s affiche jamais. Il existe pour que la suite de tests compare la
    /// matrice du code a celle du document sans la recopier.
    public var nomDuDocument: String {
        switch self {
        case .sourcesLocales: "sources locales"
        case .iCloudDrive: "iCloud Drive"
        case .smb: "SMB"
        case .nfs: "NFS"
        case .webdav: "WebDAV"
        case .extensions: "extensions"
        case .lecteurComplet: "lecteur complet"
        case .filtresNonIA: "filtres non IA"
        case .categories: "categories"
        case .historique: "historique"
        case .signets: "signets"
        case .statistiques: "statistiques"
        case .prereglages: "prereglages"
        case .traduction: "traduction"
        case .ameliorationIA: "amelioration IA"
        case .colorisationIA: "colorisation IA"
        case .serveurKomga: "serveurs Komga"
        case .serveurKavita: "Kavita"
        case .serveurJellyfin: "Jellyfin"
        case .serveurOpds: "OPDS"
        case .suivis: "tous les suivis"
        case .telechargements: "telechargements"
        case .sauvegardeEtRestauration: "sauvegarde et restauration"
        case .synchronisationICloud: "synchronisation iCloud"
        case .gestionDuStockage: "gestion du stockage"
        case .incognito: "incognito"
        }
    }

    /// Vrai quand la fonction figure dans la colonne premium de la section 10.
    public var estPremium: Bool {
        switch self {
        case .sourcesLocales, .iCloudDrive, .smb, .nfs, .webdav, .extensions,
             .lecteurComplet, .filtresNonIA, .categories, .historique, .signets,
             .statistiques, .prereglages:
            false

        case .traduction, .ameliorationIA, .colorisationIA, .serveurKomga,
             .serveurKavita, .serveurJellyfin, .serveurOpds, .suivis,
             .telechargements, .sauvegardeEtRestauration, .synchronisationICloud,
             .gestionDuStockage, .incognito:
            true
        }
    }

    /// Les fonctions de la colonne premium, dans l ordre du document.
    public static var premium: [FonctionDeLApplication] {
        allCases.filter(\.estPremium)
    }

    /// Les fonctions de la colonne gratuite, dans l ordre du document.
    public static var gratuites: [FonctionDeLApplication] {
        allCases.filter { $0.estPremium == false }
    }

    /// Fonction portant ce nom au document, nulle si le document ne le liste
    /// pas.
    public static func portant(leNomDuDocument nom: String) -> FonctionDeLApplication? {
        allCases.first { $0.nomDuDocument == nom }
    }
}

/// Ce que la matrice repond sur une fonction.
public enum AccesAUneFonction: String, Sendable, Equatable, CaseIterable {
    /// La fonction est utilisable.
    case ouvert

    /// La fonction demande un abonnement que l utilisateur n a pas.
    case verrouille

    /// Vrai quand la fonction est utilisable.
    public var estOuvert: Bool {
        self == .ouvert
    }
}

/// Application de la matrice de la section 10.
public enum MatriceDeVerrouillage {
    /// Acces a une fonction dans un etat d abonnement donne.
    ///
    /// - Parameters:
    ///   - fonction: fonction consultee.
    ///   - etat: etat de l abonnement au moment de la question.
    public static func acces(
        a fonction: FonctionDeLApplication,
        selon etat: EtatDePremium
    ) -> AccesAUneFonction {
        guard fonction.estPremium else {
            return .ouvert
        }

        return etat.donneAccesAuxFonctionsPremium ? .ouvert : .verrouille
    }

    /// Fonctions fermees dans cet etat.
    ///
    /// L ensemble est vide des que l abonnement court, et vaut toute la colonne
    /// premium sinon. L expiration ne ferme donc ni plus ni moins qu une
    /// installation qui n a jamais rien achete : ce qui change entre les deux,
    /// c est ce que l ecran dit, pas ce qu il ouvre.
    public static func fonctionsVerrouillees(
        selon etat: EtatDePremium
    ) -> Set<FonctionDeLApplication> {
        Set(FonctionDeLApplication.premium.filter { acces(a: $0, selon: etat) == .verrouille })
    }

    // MARK: Sources

    /// Fonction de la matrice a laquelle ce type de source appartient.
    ///
    /// Le mapping est total : toute source du produit figure dans une des deux
    /// colonnes de la section 10. Le depot d extensions et le transfert Wi-Fi
    /// n y sont pas nommes un a un, ils suivent la famille que le document
    /// nomme, `extensions` pour le premier et `sources locales` pour le second.
    public static func fonction(de type: TypeDeSource) -> FonctionDeLApplication {
        switch type {
        case .fichiersLocaux, .transfertWiFi: .sourcesLocales
        case .iCloudDrive: .iCloudDrive
        case .smb: .smb
        case .nfs: .nfs
        case .webdav: .webdav
        case .extensionDeclarative, .depotExtensions: .extensions
        case .komga: .serveurKomga
        case .kavita: .serveurKavita
        case .jellyfin: .serveurJellyfin
        case .opds: .serveurOpds
        }
    }

    /// Acces a une source dans un etat d abonnement donne.
    public static func acces(
        aLaSourceDeType type: TypeDeSource,
        selon etat: EtatDePremium
    ) -> AccesAUneFonction {
        acces(a: fonction(de: type), selon: etat)
    }

    // MARK: Traitements d image

    /// Fonction de la matrice a laquelle ce traitement appartient.
    public static func fonction(de traitement: TraitementDImage) -> FonctionDeLApplication {
        switch traitement {
        case .reductionDuBruit: .filtresNonIA
        case .ameliorationIA: .ameliorationIA
        case .colorisationIA: .colorisationIA
        }
    }

    /// Acces a un traitement du panneau de filtres.
    public static func acces(
        a traitement: TraitementDImage,
        selon etat: EtatDePremium
    ) -> AccesAUneFonction {
        acces(a: fonction(de: traitement), selon: etat)
    }

    // MARK: Lignes de reglages

    /// Fonction de la matrice qu une ligne de reglage arme, nulle quand la
    /// ligne n en arme aucune.
    ///
    /// Trois familles de lignes rendent `nil`, et chacune pour une raison qui
    /// lui est propre.
    ///
    /// Une ligne qui n offre aucun controle ne se verrouille pas. `Dernier
    /// envoi` et `Version` affichent un etat, la couronne y remplacerait un
    /// controle qui n existe pas, et la section 4.1 ne dessine la variante
    /// premium que sur une ligne qui commande quelque chose.
    ///
    /// Les deux commandes de purge de la section Stockage restent ouvertes.
    /// La section 10 place bien la gestion du stockage derriere l abonnement,
    /// et l ecran de detail y passe. Mais vider le cache d images et supprimer
    /// tous les telechargements sont les seules sorties d un disque plein.
    /// Les fermer transformerait la degradation en prise d otage, alors que la
    /// meme section exige au contraire que l expiration ne coute rien a
    /// l utilisateur. La gestion fine reste payante, la liberation d espace non.
    ///
    /// La section Abonnement elle meme n est jamais fermee. Verrouiller la
    /// porte de l achat derriere l achat n aurait aucun sens.
    public static func fonction(de identifiant: IdentifiantDeReglage) -> FonctionDeLApplication? {
        fonctionParLigne[identifiant]
    }

    /// Lignes classees dans la matrice, fonction par fonction.
    ///
    /// La table est ecrite en groupes plutot qu en un long aiguillage, parce que
    /// l aiguillage disait la meme chose en douze branches, et qu une fonction a
    /// douze branches se relit mal la ou une table se lit d un coup d oeil.
    ///
    /// Le compilateur ne verifie donc plus que chaque ligne du catalogue est
    /// classee. La suite de tests le fait a sa place : elle exige que la table
    /// et `lignesSansFonction` se partagent exactement `IdentifiantDeReglage`,
    /// sans trou ni recouvrement.
    static let fonctionParLigne: [IdentifiantDeReglage: FonctionDeLApplication] = compose([
        (.incognito, [.incognito]),
        (.traduction, [.traduireLesBulles, .langueCible, .policeDeRemplacement]),
        (.suivis, [.servicesDeSuivi, .envoyerLaProgression, .confirmerAvantDEnvoyer]),
        (
            .telechargements,
            [
                .qualiteDeTelechargement, .enWiFiSeulement, .chapitresALAvance,
                .emplacementDesTelechargements,
            ]
        ),
        (
            .sauvegardeEtRestauration,
            [.sauvegarderMaintenant, .sauvegardeAutomatique, .restaurerDepuisUnFichier]
        ),
        (.synchronisationICloud, [.synchroniserLaProgression, .synchroniserLaBibliotheque]),
        (.gestionDuStockage, [.detailDuStockage]),
        (.prereglages, [.prereglages, .appliquerAuChapitreSuivant]),
        (.statistiques, [.statistiquesDeLecture]),
        (.categories, [.grouperParCategorie]),
        (
            .lecteurComplet,
            [
                .sensDeLecture, .miseEnPage, .fondDuLecteur, .rognerLesBords,
                .tourneDePageAnimee, .garderLEcranAllume, .tournerAvecLesTouchesDeVolume,
                .pagesGardeesEnMemoire, .luminositeDuLecteur, .zonesDeToucher,
                .inverserLesZones,
            ]
        ),
    ])

    /// Lignes qui n arment aucune fonction de la matrice.
    ///
    /// La liste est explicite et non deduite par soustraction. Une ligne
    /// ajoutee au catalogue et oubliee ici fait virer la suite au rouge, ce
    /// qu une soustraction aurait silencieusement absorbe.
    static let lignesSansFonction: Set<IdentifiantDeReglage> = [
        .passerAPremium, .restaurerLesAchats, .verrouillageDeLApp, .langue,
        .apparence, .theme, .notificationsDeNouveauxChapitres, .trierPar,
        .ordreDeTri, .marquerLuALaDernierePage, .supprimerApresLecture,
        .mettreAJourAuLancement, .extensionSafari, .ouvrirLesLiensDansLApplication,
        .dernierEnvoi, .viderLeCacheDImages, .supprimerTousLesTelechargements,
        .aide, .signalerUnBug, .version, .nouveautes, .mentionsLegales,
    ]

    /// Retourne la table plate a partir des groupes.
    private static func compose(
        _ groupes: [(FonctionDeLApplication, [IdentifiantDeReglage])]
    ) -> [IdentifiantDeReglage: FonctionDeLApplication] {
        Dictionary(
            groupes.flatMap { fonction, lignes in lignes.map { ($0, fonction) } },
            uniquingKeysWith: { premiere, _ in premiere }
        )
    }

    /// Vrai quand cette ligne demande un abonnement que l utilisateur n a pas.
    public static func estVerrouillee(
        _ identifiant: IdentifiantDeReglage,
        selon etat: EtatDePremium
    ) -> Bool {
        guard let fonction = fonction(de: identifiant) else {
            return false
        }

        return acces(a: fonction, selon: etat) == .verrouille
    }

    /// Forme premium a poser sur une ligne, nulle quand elle n en porte aucune.
    ///
    /// L appel a l abonnement garde sa forme dans tous les etats : il mene au
    /// mur quand rien n est achete, a la gestion de l abonnement ensuite, et
    /// c est la meme ligne. Une fonction verrouillee, elle, cesse de l etre des
    /// que l abonnement court.
    public static func formePremium(
        de ligne: LigneDeReglage,
        selon etat: EtatDePremium
    ) -> FormeDeLignePremium? {
        if ligne.premium == .appelALAbonnement {
            return .appelALAbonnement
        }

        return estVerrouillee(ligne.id, selon: etat) ? .fonctionVerrouillee : nil
    }
}
