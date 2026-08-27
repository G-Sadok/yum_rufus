import Foundation

//
// DegradationPremium
//
// Ce que devient le produit quand l abonnement s arrete, regle de degradation
// de la section 10 du cahier de developpement.
//
// La phrase du document est courte et elle engage beaucoup : si l abonnement
// expire, aucune donnee n est supprimee, les sources premium passent en lecture
// seule et affichent une banniere expliquant comment les reactiver.
//
// La garantie n est pas tenue par une promesse ecrite dans un commentaire, elle
// est tenue par le type des effets. Une transition d abonnement ne rend que des
// changements d acces, et `EffetDePremium` n a aucun cas destructeur : il
// n existe litteralement pas de valeur qui dise supprimer. Ajouter une purge a
// l expiration demanderait d ajouter un cas ici, ce qui se voit dans un diff,
// et ce que la suite de tests refuse.
//
// L inventaire n est pas la base de donnees. Il en est le denombrement, et il
// sert a une seule chose : traverser la transition pour verifier qu il en
// ressort intact. C est le seul moyen de faire du premier critere de la section
// 10 un test qui peut echouer.
//

/// Ce qu une transition d abonnement peut faire, et rien de plus.
///
/// Aucun cas ne supprime, n efface, ne purge ni ne desactive une donnee. Cette
/// absence est la forme executable de la regle de degradation.
public enum EffetDePremium: Sendable, Equatable, Hashable {
    /// Une fonction premium n est plus utilisable.
    case verrouillerLaFonction(FonctionDeLApplication)

    /// Une fonction premium redevient utilisable.
    case deverrouillerLaFonction(FonctionDeLApplication)

    /// Une source premium n accepte plus que la lecture.
    case passerLaSourceEnLectureSeule(TypeDeSource)

    /// Une source premium redevient completement utilisable.
    case rendreLaSourceComplete(TypeDeSource)

    /// La banniere de reactivation se pose sur l ecran des sources.
    case afficherLaBanniereDeReactivation

    /// La banniere de reactivation disparait.
    case retirerLaBanniereDeReactivation

    /// Vrai quand l effet modifie une donnee de l utilisateur.
    ///
    /// La reponse est toujours fausse, et c est le sujet. La propriete existe
    /// pour que la suite de tests puisse le verifier cas par cas plutot que de
    /// le supposer, et pour que l ajout d un cas destructeur ait a mentir
    /// explicitement ici avant de passer.
    public var toucheAuxDonnees: Bool {
        switch self {
        case .verrouillerLaFonction, .deverrouillerLaFonction,
             .passerLaSourceEnLectureSeule, .rendreLaSourceComplete,
             .afficherLaBanniereDeReactivation, .retirerLaBanniereDeReactivation:
            false
        }
    }

    /// Fonction que cet effet ferme, nulle pour les autres effets.
    public var fonctionVerrouillee: FonctionDeLApplication? {
        guard case let .verrouillerLaFonction(fonction) = self else {
            return nil
        }

        return fonction
    }

    /// Fonction que cet effet rouvre, nulle pour les autres effets.
    public var fonctionDeverrouillee: FonctionDeLApplication? {
        guard case let .deverrouillerLaFonction(fonction) = self else {
            return nil
        }

        return fonction
    }
}

/// Denombrement de ce que l utilisateur possede.
///
/// Il ne sert pas a afficher un ecran. Il sert a traverser une transition
/// d abonnement et a prouver qu il en ressort identique, ce qui rend le premier
/// critere de la section 10 mesurable au lieu d etre promis.
public struct InventaireDesDonnees: Sendable, Equatable, Hashable {
    /// Sources configurees, premium comprises.
    public let sourcesConfigurees: [TypeDeSource]

    /// Series presentes en bibliotheque.
    public let seriesEnBibliotheque: Int

    /// Chapitres poses sur le disque.
    public let chapitresTelecharges: Int

    /// Entrees d historique de lecture.
    public let entreesDHistorique: Int

    /// Signets de page.
    public let signets: Int

    /// Prereglages de lecture enregistres.
    public let prereglagesDeLecture: Int

    /// Sauvegardes deja produites.
    public let sauvegardes: Int

    /// Identifiants ranges dans le trousseau.
    public let identifiantsDansLeTrousseau: Int

    public init(
        sourcesConfigurees: [TypeDeSource] = [],
        seriesEnBibliotheque: Int = 0,
        chapitresTelecharges: Int = 0,
        entreesDHistorique: Int = 0,
        signets: Int = 0,
        prereglagesDeLecture: Int = 0,
        sauvegardes: Int = 0,
        identifiantsDansLeTrousseau: Int = 0
    ) {
        self.sourcesConfigurees = sourcesConfigurees
        self.seriesEnBibliotheque = seriesEnBibliotheque
        self.chapitresTelecharges = chapitresTelecharges
        self.entreesDHistorique = entreesDHistorique
        self.signets = signets
        self.prereglagesDeLecture = prereglagesDeLecture
        self.sauvegardes = sauvegardes
        self.identifiantsDansLeTrousseau = identifiantsDansLeTrousseau
    }
}

/// Passage d un etat d abonnement a un autre.
public struct TransitionDePremium: Sendable, Equatable {
    /// Etat avant le changement.
    public let avant: EtatDePremium

    /// Etat apres le changement.
    public let apres: EtatDePremium

    public init(avant: EtatDePremium, apres: EtatDePremium) {
        self.avant = avant
        self.apres = apres
    }

    /// Vrai quand la transition ferme un acces ouvert.
    public var ferme: Bool {
        avant.donneAccesAuxFonctionsPremium && apres.donneAccesAuxFonctionsPremium == false
    }

    /// Vrai quand la transition rouvre un acces ferme.
    public var ouvre: Bool {
        avant.donneAccesAuxFonctionsPremium == false && apres.donneAccesAuxFonctionsPremium
    }

    /// Effets de la transition sur les sources configurees.
    ///
    /// Un changement qui ne franchit pas la frontiere de l acces ne rend rien.
    /// Passer du mensuel a l annuel, ou d un essai a un abonnement, ne verrouille
    /// ni ne deverrouille quoi que ce soit, et l ecran n a alors rien a refaire.
    ///
    /// - Parameter sources: types des sources configurees par l utilisateur.
    public func effets(pour sources: [TypeDeSource]) -> [EffetDePremium] {
        let premium = sources.filter { MatriceDeVerrouillage.fonction(de: $0).estPremium }

        if ferme {
            return FonctionDeLApplication.premium.map(EffetDePremium.verrouillerLaFonction)
                + premium.map(EffetDePremium.passerLaSourceEnLectureSeule)
                + (premium.isEmpty ? [] : [.afficherLaBanniereDeReactivation])
        }

        if ouvre {
            return FonctionDeLApplication.premium.map(EffetDePremium.deverrouillerLaFonction)
                + premium.map(EffetDePremium.rendreLaSourceComplete)
                + [.retirerLaBanniereDeReactivation]
        }

        return []
    }

    /// Inventaire apres la transition.
    ///
    /// Il est rendu tel quel, et c est la regle de degradation elle meme. Une
    /// expiration change ce que les ecrans ouvrent, jamais ce que la
    /// bibliotheque contient. Le sens de cette fonction n est pas de calculer
    /// quelque chose, il est d etre le seul point ou une suppression pourrait
    /// s ecrire, et de ne pas en porter.
    public func appliquer(a inventaire: InventaireDesDonnees) -> InventaireDesDonnees {
        inventaire
    }
}

/// Pourquoi la banniere de reactivation se pose sur une source.
///
/// Les deux cas ne disent pas la meme chose a l utilisateur. Celui dont
/// l abonnement vient de finir a besoin d entendre que rien n a ete perdu, et
/// la date le lui prouve. Celui qui n a jamais rien pris a besoin d entendre ce
/// que l abonnement ouvrirait. Une phrase unique mentirait a l un des deux.
public enum MotifDeLaBanniereDeReactivation: Sendable, Equatable {
    /// L abonnement a couru puis s est arrete, avec sa date de fin.
    case abonnementExpire(le: Date)

    /// Aucun abonnement n a jamais ete pris.
    case aucunAbonnement
}

/// Ce qu une source laisse faire dans l etat d abonnement courant.
///
/// La lecture seule n est pas un ecran grise. La source garde son catalogue,
/// ses series, ses chapitres deja telecharges et son identifiant dans le
/// trousseau. Ce qu elle perd, ce sont les actions qui ecrivent quelque part :
/// telecharger de nouveaux chapitres, publier une progression vers le serveur,
/// et changer sa configuration.
///
/// La suppression reste offerte. Une source que l utilisateur ne pourrait plus
/// retirer parce que son abonnement a expire retiendrait ses donnees en otage,
/// ce que la meme section interdit dans l autre sens.
public struct AccesAUneSource: Sendable, Equatable {
    /// Type de la source consultee.
    public let type: TypeDeSource

    /// Etat de l abonnement au moment de la question.
    public let etat: EtatDePremium

    public init(type: TypeDeSource, selon etat: EtatDePremium) {
        self.type = type
        self.etat = etat
    }

    /// Vrai quand la source n accepte plus que la lecture.
    public var estEnLectureSeule: Bool {
        MatriceDeVerrouillage.acces(aLaSourceDeType: type, selon: etat) == .verrouille
    }

    /// Vrai quand l ecran pose la banniere de reactivation pour cette source.
    ///
    /// C est la meme condition que la lecture seule, et c est voulu : une
    /// source bridee sans explication est un bogue pour l utilisateur, qui
    /// verra un bouton disparu et cherchera la panne.
    public var porteLaBanniere: Bool {
        estEnLectureSeule
    }

    /// Motif de la banniere, nul quand la source n en porte aucune.
    public var motifDeLaBanniere: MotifDeLaBanniereDeReactivation? {
        guard porteLaBanniere else {
            return nil
        }

        if case let .expire(le: fin) = etat {
            return .abonnementExpire(le: fin)
        }

        return .aucunAbonnement
    }

    /// Vrai quand cette action reste offerte.
    public func autorise(_ action: ActionDeSource) -> Bool {
        estEnLectureSeule == false || action.estUneEcriture == false
    }

    /// Actions encore offertes parmi celles que les capacites permettent.
    public func actionsOffertes(pour capacites: SourceCapacites) -> Set<ActionDeSource> {
        capacites.actionsOffertes.filter(autorise)
    }

    /// Vrai quand la feuille de configuration peut encore enregistrer.
    public var autoriseLaModificationDeLaConfiguration: Bool {
        estEnLectureSeule == false
    }

    /// Vrai quand la source peut etre retiree.
    ///
    /// Toujours. L utilisateur reste maitre de ses donnees, abonne ou non.
    public var autoriseLaSuppression: Bool {
        true
    }
}
