import Core

//
// ModeleParTuiles
//
// Ce que le moteur de traitement attend d un modele, et rien de plus.
//
// La section 8 nomme deux reseaux, un de surelevation et un de colorisation, et
// leur demande la meme architecture d execution. Cette phrase se traduit ici par
// un seul contrat : une fonction qui prend une tuile carree au cote annonce et
// rend la meme tuile, chaque cote multiplie par un facteur connu. Le tuilage, le
// fondu, la serialisation et le cache ne dependent que de ce contrat, et non de
// ce que le reseau fait des pixels.
//
// Un facteur de un est un facteur legitime. C est celui de la colorisation, qui
// change les couleurs sans changer les dimensions, et le moteur n a pas a
// distinguer ce cas : une multiplication par un est une multiplication.
//
// Le poids du modele ne rentre pas dans le depot. Un reseau converti pese
// plusieurs dizaines de megaoctets et se livre avec l application, pas avec le
// code. La couche qui l installe le passe ici.
//
// La geometrie devient verifiable. La suite de tests fait passer par ce contrat
// des modeles synthetiques dont on connait la sortie exacte, ce qui permet de
// prouver l absence de raccord au pixel pres. Aucune assertion de ce genre ne
// serait possible sur un reseau entraine, dont personne ne sait dire ce que
// devrait valoir un pixel.
//
// Le modele est synchrone. C est voulu : l acteur qui l appelle ne doit pas
// pouvoir suspendre au milieu d un traitement, sans quoi deux traitements
// s entrelaceraient sur le meme appareil, ce que la section 8 interdit.
//

/// Modele qui transforme une tuile carree et multiplie son cote par un facteur.
public protocol ModeleParTuiles: Sendable {
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

    /// Transforme une tuile.
    ///
    /// - Parameter tuile: tuile carree au cote attendu par le modele.
    /// - Returns: la meme tuile, chaque cote multiplie par le facteur.
    /// - Throws: `ErreurDeTraitementIA` quand le modele refuse l entree.
    func traiter(_ tuile: MatriceDePixels) throws -> MatriceDePixels
}

extension ModeleParTuiles {
    /// Taille que ce modele rend pour une entree de cette taille.
    public func tailleDeSortie(pour taille: TailleEnPixels) -> TailleEnPixels {
        TailleEnPixels(largeur: taille.largeur * facteur, hauteur: taille.hauteur * facteur)
    }

    /// Tuilage adapte a ce modele, au recouvrement de la section 8.
    ///
    /// Le cote vient du modele et non d une constante, parce que c est le modele
    /// converti qui impose la taille de son entree. Un reseau de colorisation
    /// qui attend des tuiles de 512 serait refuse tuile apres tuile si le
    /// tuilage restait a 256, alors que la geometrie du decoupage, elle, ne
    /// change pas.
    public var tuilage: TuilageDeTraitement {
        TuilageDeTraitement(cote: coteDeTuile, recouvrement: TuilageDeTraitement.recouvrementDeTuile)
    }
}
