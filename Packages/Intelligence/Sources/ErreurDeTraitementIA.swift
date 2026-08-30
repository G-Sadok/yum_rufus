import Core

//
// ErreurDeTraitementIA
//
// Les echecs possibles d un traitement par modele embarque, pour la surelevation
// comme pour la colorisation.
//
// Un seul domaine d erreur pour les deux traitements, parce que les deux
// echouent aux memes endroits : un fichier de modele absent, un modele qui n a
// pas la forme annoncee, une tuile refusee, une page trop lourde. Deux
// enumerations jumelles auraient diverge au premier correctif, et le moteur
// partage n aurait su laquelle lever.
//
// Le message utilisateur, lui, ne peut pas etre commun. La regle d erreur du
// projet demande de nommer la cause et d indiquer la sortie, et la sortie est un
// reglage precis de la section 9 : Amelioration IA en deux fois ou Colorisation
// par IA. Le message prend donc le traitement en parametre au lieu d etre une
// propriete, ce qui rend impossible d afficher le mauvais libelle.
//

/// Un des traitements par modele embarque de la section 8.
public enum TraitementIA: String, Sendable, Hashable, CaseIterable {
    /// Quatrieme etape de la chaine de la section 6.3.
    case amelioration

    /// Cinquieme etape de la chaine de la section 6.3.
    case colorisation

    /// Detecteur de cases, qui sert au zoom automatique case par case.
    case detectionDeCases

    /// Nom de la fonction tel que l utilisateur la connait.
    public var libelleDeLaFonction: String {
        switch self {
        case .amelioration: "Amelioration IA en deux fois"
        case .colorisation: "Colorisation par IA"
        case .detectionDeCases: "Zoom automatique case par case"
        }
    }

    /// Libelle exact du reglage de la section 9 qui arme ce traitement, nil
    /// quand aucun reglage ne l arme.
    ///
    /// La detection de cases n en a pas. L inventaire des reglages de la
    /// section 9 ne lui donne aucune ligne : elle s arme par le geste de zoom,
    /// dans le lecteur, et un message qui inviterait a couper un interrupteur
    /// inexistant enverrait l utilisateur chercher en vain.
    public var libelleDuReglage: String? {
        switch self {
        case .amelioration, .colorisation: libelleDeLaFonction
        case .detectionDeCases: nil
        }
    }

    /// Vrai quand la section 8 exige la provenance du jeu de donnees
    /// d entrainement pour ce traitement.
    ///
    /// Elle le demande nommement pour le detecteur de cases, dont la mention
    /// ferme la section A propos.
    public var exigeUnJeuDeDonnees: Bool {
        self == .detectionDeCases
    }
}

/// Echec d un traitement par modele embarque.
public enum ErreurDeTraitementIA: Error, Sendable, Equatable {
    /// Le fichier de modele est absent ou illisible.
    case modeleIllisible(chemin: String)

    /// Le modele n expose pas une entree et une sortie en image.
    case modeleSansImage(identifiant: String)

    /// Le modele n a pas le facteur d agrandissement attendu.
    case facteurInattendu(identifiant: String, facteur: Int)

    /// Aucune fiche de licence ne couvre ce modele dans le depot.
    case licenceNonDocumentee(identifiant: String)

    /// Le jeu de donnees d entrainement n est pas documente, ou sa licence ne
    /// permet pas de distribuer les poids qui en sont tires.
    case jeuDeDonneesNonAutorise(identifiant: String)

    /// Le modele a refuse la tuile ou n a rien rendu d exploitable.
    case modeleEnEchec(identifiant: String)

    /// La page ne peut pas etre lue comme une matrice de pixels.
    case pageIllisible

    /// Une tuile n a pas pu etre prelevee dans la page.
    case tuileRefusee(index: Int)

    /// Le modele a rendu une tuile qui n est pas a la taille attendue.
    case tailleInattendue(attendue: TailleEnPixels, recue: TailleEnPixels)

    /// La page produite depasserait le plafond memoire du traitement.
    case pageTropLourde(octets: Int, plafond: Int)

    /// Message destine a l utilisateur, pour le traitement qui a echoue.
    ///
    /// Il nomme la cause et indique la sortie, comme l impose la regle d erreur
    /// du projet. La sortie depend de ce qui arme le traitement : un
    /// interrupteur des reglages pour les deux traitements de la chaine
    /// d images, le geste de zoom pour la detection de cases, qui n a pas de
    /// ligne dans l inventaire de la section 9.
    public func messageUtilisateur(pour traitement: TraitementIA) -> String {
        let fonction = traitement.libelleDeLaFonction

        switch self {
        case .modeleIllisible:
            return "Le modele n est pas installe. " + Self.sortie(de: traitement)
        case .modeleSansImage, .facteurInattendu:
            return "Le modele installe n est pas celui que Yum attend pour \(fonction)."
        case .licenceNonDocumentee:
            return "La licence du modele installe n est pas documentee. \(fonction) reste indisponible."
        case .jeuDeDonneesNonAutorise:
            return "Le jeu de donnees du modele installe n est pas documente. \(fonction) reste indisponible."
        case .modeleEnEchec:
            return "\(fonction) a echoue sur cet appareil. La page reste lisible telle quelle."
        case .pageIllisible, .tuileRefusee, .tailleInattendue:
            return "Cette page n a pas pu passer par \(fonction). Elle reste lisible telle quelle."
        case .pageTropLourde:
            return "Cette page est trop grande pour \(fonction) sur cet appareil."
        }
    }

    /// Ce que l utilisateur peut faire quand le modele manque.
    private static func sortie(de traitement: TraitementIA) -> String {
        guard let reglage = traitement.libelleDuReglage else {
            return "La lecture continue page par page."
        }

        return "Desactivez \(reglage) dans les reglages."
    }
}
