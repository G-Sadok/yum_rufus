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

/// Un des deux traitements par modele embarque de la section 8.
public enum TraitementIA: String, Sendable, Hashable, CaseIterable {
    /// Quatrieme etape de la chaine de la section 6.3.
    case amelioration

    /// Cinquieme etape de la chaine de la section 6.3.
    case colorisation

    /// Libelle exact du reglage de la section 9 qui arme ce traitement.
    public var libelleDuReglage: String {
        switch self {
        case .amelioration: "Amelioration IA en deux fois"
        case .colorisation: "Colorisation par IA"
        }
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
    /// du projet. La sortie est la meme dans tous les cas : la page reste
    /// lisible sans traitement, et l interrupteur se coupe dans les reglages.
    public func messageUtilisateur(pour traitement: TraitementIA) -> String {
        let reglage = traitement.libelleDuReglage

        switch self {
        case .modeleIllisible:
            return "Le modele n est pas installe. Desactivez \(reglage) dans les reglages."
        case .modeleSansImage, .facteurInattendu:
            return "Le modele installe n est pas celui que Yum attend pour \(reglage)."
        case .licenceNonDocumentee:
            return "La licence du modele installe n est pas documentee. \(reglage) reste indisponible."
        case .modeleEnEchec:
            return "\(reglage) a echoue sur cet appareil. La page reste lisible telle quelle."
        case .pageIllisible, .tuileRefusee, .tailleInattendue:
            return "Cette page n a pas pu passer par \(reglage). Elle reste lisible telle quelle."
        case .pageTropLourde:
            return "Cette page est trop grande pour \(reglage) sur cet appareil."
        }
    }
}
