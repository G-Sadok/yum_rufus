//
// ActionsDeSource
//
// La traduction des capacites de la section 4.1 en actions offertes par
// l interface. La regle est ecrite ainsi : l interface ne propose que les
// actions correspondant aux capacites declarees, et une source sans capacite de
// recherche n affiche pas de champ de recherche.
//
// Ce tableau vit dans Core et non dans la couche vue, pour deux raisons. La
// vue en aurait fait une suite de conditions dispersees dans plusieurs ecrans,
// donc plusieurs endroits ou oublier une capacite. Et un tableau declaratif se
// teste sur les cent vingt huit combinaisons possibles, ce qu une suite de
// conditions dans une vue ne permet pas.
//

/// Une action que l interface peut offrir sur une source.
///
/// L enumeration couvre a la fois les actions conditionnees par une capacite et
/// celles que toute source rend, sans quoi la liste ne dirait pas ce que
/// l interface a le droit d afficher, seulement ce qu elle doit cacher.
public enum ActionDeSource: String, Sendable, Codable, CaseIterable, Hashable {
    /// Ouvrir le catalogue de la source sur une section.
    case parcourir

    /// Ouvrir la fiche d une serie du catalogue.
    case ouvrirUneSerie

    /// Afficher la liste des chapitres d une serie.
    case listerLesChapitres

    /// Ouvrir un chapitre dans le lecteur.
    case lireUnChapitre

    /// Afficher le champ de recherche.
    case rechercher

    /// Afficher les filtres de genre et de statut.
    case filtrer

    /// Charger la suite du catalogue au defilement.
    case chargerLaSuite

    /// Proposer le telechargement hors ligne.
    case telecharger

    /// Publier la progression de lecture vers le serveur.
    case publierLaProgression

    /// Proposer le choix de la langue.
    case choisirLaLangue

    /// Proposer la veille des nouveaux chapitres sur les series de cette
    /// source.
    case surveillerLesNouveautes

    /// Capacite sans laquelle l action ne doit pas etre offerte.
    ///
    /// Nul veut dire que l action est offerte par toute source. Ces quatre
    /// actions la sont parce que le protocole les impose a toutes les
    /// implementations : parcourir, ouvrir une serie, lister ses chapitres et
    /// lire un chapitre n ont aucune capacite associee dans la section 4.1.
    public var capaciteRequise: SourceCapacites? {
        switch self {
        case .parcourir, .ouvrirUneSerie, .listerLesChapitres, .lireUnChapitre: nil
        case .rechercher: .recherche
        case .filtrer: .filtres
        case .chargerLaSuite: .pagination
        case .telecharger: .telechargement
        case .publierLaProgression: .progressionDistante
        case .choisirLaLangue: .plusieursLangues
        case .surveillerLesNouveautes: .veilleDeNouveautes
        }
    }

    /// Vrai quand l action ecrit quelque part au lieu de se contenter de lire.
    ///
    /// La distinction sert la regle de degradation de la section 10 du cahier de
    /// developpement : une source premium dont l abonnement a expire passe en
    /// lecture seule, elle ne perd donc que ces deux actions la. Telecharger
    /// pose des fichiers sur le disque, publier une progression ecrit sur le
    /// serveur. Tout le reste ne fait que consulter ce qui existe deja, et rien
    /// n oblige a le fermer.
    public var estUneEcriture: Bool {
        switch self {
        case .telecharger, .publierLaProgression: true
        case .parcourir, .ouvrirUneSerie, .listerLesChapitres, .lireUnChapitre,
             .rechercher, .filtrer, .chargerLaSuite, .choisirLaLangue,
             .surveillerLesNouveautes: false
        }
    }

    /// Les actions que toute source rend, quelles que soient ses capacites.
    public static var inconditionnelles: [ActionDeSource] {
        allCases.filter { $0.capaciteRequise == nil }
    }
}

extension SourceCapacites {
    /// Les actions que l interface a le droit d offrir pour ces capacites.
    ///
    /// C est le seul point de decision. Un ecran qui veut savoir s il affiche
    /// un champ de recherche interroge cet ensemble, il ne teste pas la
    /// capacite lui meme : la difference se voit le jour ou une action demande
    /// deux capacites.
    public var actionsOffertes: Set<ActionDeSource> {
        Set(ActionDeSource.allCases.filter { action in
            guard let requise = action.capaciteRequise else {
                return true
            }

            return contains(requise)
        })
    }

    /// Vrai quand cette action peut etre offerte.
    public func offre(_ action: ActionDeSource) -> Bool {
        guard let requise = action.capaciteRequise else {
            return true
        }

        return contains(requise)
    }
}
