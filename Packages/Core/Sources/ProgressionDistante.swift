import Foundation

//
// ProgressionDistante
//
// La progression de lecture telle qu un serveur la tient, et le contrat par
// lequel une source la lit et la publie.
//
// Le protocole de la section 4.1 ne porte aucune methode de progression : la
// plupart des sources n en tiennent aucune, et un dossier local encore moins.
// La capacite `SourceCapacites.progressionDistante` existait donc sans surface
// correspondante. C est ce protocole separe qui la lui donne, sans obliger les
// dix autres implementations a ecrire trois methodes qui leveraient toujours.
//
// La page atteinte est indexee a partir de zero, comme `PositionDeLecture`.
// Les serveurs ne sont pas d accord entre eux sur ce point, Komga compte a
// partir de un, et c est exactement le genre d ecart d une page qui ne se voit
// pas a la lecture mais deplace la reprise a chaque chapitre. La conversion se
// fait donc une fois, a la frontiere de chaque source, jamais dans le modele.
//

/// Avancement d un chapitre tel que le serveur le connait.
public struct ProgressionDistante: Sendable, Hashable {
    /// Identifiant du chapitre chez la source.
    public let identifiantChapitre: String

    /// Page atteinte, indexee a partir de zero.
    public let pageAtteinte: Int

    /// Nombre de pages du chapitre, zero quand la source ne le dit pas.
    public let nombreDePages: Int

    /// Vrai quand le serveur considere le chapitre comme lu.
    ///
    /// La valeur vient du serveur et n est jamais deduite de la page atteinte :
    /// un chapitre marque lu a la main depuis une autre application est lu,
    /// meme si sa derniere page n a jamais ete affichee.
    public let estLu: Bool

    /// Date de la derniere lecture, quand le serveur la publie.
    public let dateDeLecture: Date?

    public init(
        identifiantChapitre: String,
        pageAtteinte: Int,
        nombreDePages: Int = 0,
        estLu: Bool = false,
        dateDeLecture: Date? = nil
    ) {
        self.identifiantChapitre = identifiantChapitre
        self.pageAtteinte = max(0, pageAtteinte)
        self.nombreDePages = max(0, nombreDePages)
        self.estLu = estLu
        self.dateDeLecture = dateDeLecture
    }

    /// Part du chapitre deja lue, entre zero et un.
    ///
    /// Un chapitre que le serveur declare lu rend un, meme quand la page
    /// atteinte dit autre chose : c est le serveur qui fait autorite sur ce
    /// qu il a marque, et la barre affichee doit dire la meme chose que la
    /// pastille de la liste des chapitres.
    public var part: Double {
        guard estLu == false else {
            return 1
        }

        return ProgressionDeChapitre.part(pageAtteinte: pageAtteinte, nombreDePages: nombreDePages)
    }
}

/// Une source qui tient la progression de lecture cote serveur.
///
/// Le protocole complete `SourceProvider` au lieu de l elargir : seules les
/// sources qui declarent `SourceCapacites.progressionDistante` le conforment,
/// et l appelant les reconnait par un `as?` plutot que par une capacite qu il
/// aurait a tester avant chaque appel.
public protocol SourceAProgressionDistante: SourceProvider {
    /// Lit la progression que le serveur tient pour ce chapitre.
    ///
    /// Rend nul quand le serveur n en tient aucune, ce qui est le cas normal
    /// d un chapitre jamais ouvert, et non une erreur.
    func progression(pour chapitre: String) async throws -> ProgressionDistante?

    /// Publie une progression vers le serveur.
    func publier(_ progression: ProgressionDistante) async throws

    /// Efface la progression que le serveur tient pour ce chapitre.
    ///
    /// C est ce que fait le marquage comme non lu. La suppression est
    /// idempotente : effacer une progression qui n existait pas ne leve pas.
    func effacerLaProgression(pour chapitre: String) async throws
}
