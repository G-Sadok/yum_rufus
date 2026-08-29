import Core

//
// ModeleDeSurelevation
//
// Ce que la surelevation attend d un modele, et rien de plus.
//
// La section 8 nomme un modele precis, Real ESRGAN converti en Core ML dans sa
// variante anime. Le tuilage, le fondu, la serialisation et le cache n en
// dependent pourtant pas : ils dependent d une fonction qui prend une tuile et
// rend la meme tuile agrandie d un facteur connu. Le protocole isole cette
// fonction, ce qui a deux effets.
//
// Le poids du modele ne rentre pas dans le depot. Un reseau converti pese
// plusieurs dizaines de megaoctets et se livre avec l application, pas avec le
// code. La couche qui l installe le passe ici.
//
// La geometrie devient verifiable. La suite de tests fait passer par ce
// protocole des modeles synthetiques dont on connait la sortie exacte, ce qui
// permet de prouver l absence de raccord au pixel pres. Aucune assertion de ce
// genre ne serait possible sur un reseau entraine, dont personne ne sait dire ce
// que devrait valoir un pixel.
//
// Le modele est synchrone. C est voulu : l acteur qui l appelle ne doit pas
// pouvoir suspendre au milieu d un traitement, sans quoi deux traitements
// s entrelaceraient sur le meme appareil, ce que la section 8 interdit.
//

/// Echec d une amelioration par IA.
public enum ErreurDAmelioration: Error, Sendable, Equatable {
    /// Le fichier de modele est absent ou illisible.
    case modeleIllisible(chemin: String)

    /// Le modele n expose pas une entree et une sortie en image.
    case modeleSansImage(identifiant: String)

    /// Le modele n agrandit pas, ou pas d un facteur entier.
    case facteurInattendu(identifiant: String, facteur: Int)

    /// Le modele a refuse la tuile ou n a rien rendu d exploitable.
    case modeleEnEchec(identifiant: String)

    /// La page ne peut pas etre lue comme une matrice de pixels.
    case pageIllisible

    /// Une tuile n a pas pu etre prelevee dans la page.
    case tuileRefusee(index: Int)

    /// Le modele a rendu une tuile qui n est pas a la taille attendue.
    case tailleInattendue(attendue: TailleEnPixels, recue: TailleEnPixels)

    /// La page surelevee depasserait le plafond memoire du traitement.
    case pageTropLourde(octets: Int, plafond: Int)

    /// Message destine a l utilisateur.
    ///
    /// Il nomme la cause et indique la sortie, comme l impose la regle d erreur
    /// du projet. La sortie est la meme dans tous les cas : la page reste
    /// lisible sans amelioration, et l interrupteur se coupe dans les reglages.
    public var messageUtilisateur: String {
        switch self {
        case .modeleIllisible:
            "Le modele d amelioration n est pas installe. Desactivez Amelioration IA dans les reglages."
        case .modeleSansImage, .facteurInattendu:
            "Le modele d amelioration installe n est pas celui que Yum attend."
        case .modeleEnEchec:
            "L amelioration a echoue sur cet appareil. La page reste lisible telle quelle."
        case .pageIllisible, .tuileRefusee, .tailleInattendue:
            "Cette page n a pas pu etre amelioree. Elle reste lisible telle quelle."
        case .pageTropLourde:
            "Cette page est trop grande pour etre amelioree sur cet appareil."
        }
    }
}

/// Modele qui agrandit une tuile d un facteur entier.
public protocol ModeleDeSurelevation: Sendable {
    /// Nom du modele, repris dans les cles de cache.
    ///
    /// Deux modeles differents ne donnent pas le meme resultat sur la meme
    /// page. Sans cet identifiant dans la cle, un changement de modele ferait
    /// ressortir du cache des pages produites par l ancien.
    var identifiant: String { get }

    /// Nombre par lequel le modele multiplie chaque cote.
    var facteur: Int { get }

    /// Cote de la tuile carree que le modele attend en entree.
    var coteDeTuile: Int { get }

    /// Agrandit une tuile.
    ///
    /// - Parameter tuile: tuile carree au cote attendu par le modele.
    /// - Returns: la meme tuile, chaque cote multiplie par le facteur.
    /// - Throws: `ErreurDAmelioration` quand le modele refuse l entree.
    func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels
}

extension ModeleDeSurelevation {
    /// Taille que ce modele rend pour une entree de cette taille.
    public func tailleDeSortie(pour taille: TailleEnPixels) -> TailleEnPixels {
        TailleEnPixels(largeur: taille.largeur * facteur, hauteur: taille.hauteur * facteur)
    }
}
