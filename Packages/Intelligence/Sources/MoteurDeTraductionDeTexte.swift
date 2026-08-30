import Core

//
// MoteurDeTraductionDeTexte
//
// Ce qui traduit un texte deja lu, et l endroit ou ce travail se fait.
//
// Le protocole separe deux choses que le produit doit distinguer partout :
// traduire, et faire sortir une donnee de l appareil. La section 8 du cahier de
// developpement pose la regle en une phrase, tout tourne sur l appareil, aucune
// image ne le quitte sauf si l utilisateur choisit explicitement le moteur dans
// le nuage. Un moteur qui declarerait seulement savoir traduire ne permettrait
// pas de tenir cette regle : l acteur doit pouvoir refuser de l appeler avant de
// lui avoir passe le premier caractere.
//
// `emplacement` est donc une propriete du moteur et non un parametre d appel.
// Un moteur ne peut pas mentir sur l endroit ou il travaille au coup par coup,
// et l acteur decide au vu de cette seule valeur, sans avoir a connaitre
// l implantation.
//
// Le moteur recoit des textes et rend des textes, jamais des pixels. La
// consequence compte pour le moteur distant : ce qui sort de l appareil est le
// texte lu par la detection locale, pas la planche. C est le minimum
// necessaire pour que le service reponde, et c est deja assez pour justifier
// l accord explicite que `ReglagesDeTraduction` exige.
//

/// Endroit ou un moteur de traduction fait son travail.
public enum EmplacementDuMoteur: String, Sendable, Hashable, CaseIterable {
    /// Le travail se fait sur l appareil, sans reseau.
    case surLAppareil

    /// Le travail se fait sur un service distant.
    case dansLeNuage

    /// Choix de reglage qui designe cet emplacement.
    public var choix: ChoixDeMoteurDeTraduction {
        switch self {
        case .surLAppareil: .surLAppareil
        case .dansLeNuage: .dansLeNuage
        }
    }

    /// Vrai quand le moteur ne peut pas travailler sans reseau.
    public var exigeLeReseau: Bool {
        self == .dansLeNuage
    }
}

/// Moteur qui traduit des textes deja lus dans la planche.
public protocol MoteurDeTraductionDeTexte: Sendable {
    /// Nom du moteur, qui entre dans les cles de cache.
    var identifiant: String { get }

    /// Endroit ou ce moteur travaille.
    var emplacement: EmplacementDuMoteur { get }

    /// Traduit une suite de textes vers une langue.
    ///
    /// - Parameters:
    ///   - textes: textes lus dans les bulles, dans l ordre ou ils ont ete lus.
    ///   - langue: langue cible choisie dans les reglages.
    /// - Returns: autant de textes qu il en a recus, dans le meme ordre. Un
    ///   texte que le moteur ne sait pas traduire ressort tel quel plutot que
    ///   vide, pour que la bulle reste lisible.
    /// - Throws: `ErreurDeTraduction` quand le moteur ne peut pas repondre.
    func traduire(_ textes: [String], vers langue: ChoixDeLangue) throws -> [String]
}

/// Moteur local, construit autour d une traduction fournie a l installation.
///
/// Le projet ne livre pas la traduction elle meme, exactement comme il ne livre
/// pas les fichiers de modele des trois autres traitements de la section 8. La
/// couche qui installe la fonction branche ici le traducteur du systeme, et ce
/// type garantit ce que le reste du code a besoin de savoir : ce moteur travaille
/// sur l appareil, il n a donc aucune raison de toucher au reseau, et l acteur
/// ne lui demandera jamais s il est joignable.
public struct MoteurDeTraductionLocal: MoteurDeTraductionDeTexte {
    public let identifiant: String

    public let emplacement = EmplacementDuMoteur.surLAppareil

    private let traduction: @Sendable ([String], ChoixDeLangue) throws -> [String]

    /// Prepare un moteur local.
    ///
    /// - Parameters:
    ///   - identifiant: nom retenu dans les cles de cache. Il doit changer des
    ///     que la traduction installee change.
    ///   - traduction: traducteur du systeme, qui ne sort pas de l appareil.
    public init(
        identifiant: String,
        traduction: @escaping @Sendable ([String], ChoixDeLangue) throws -> [String]
    ) {
        self.identifiant = identifiant
        self.traduction = traduction
    }

    public func traduire(_ textes: [String], vers langue: ChoixDeLangue) throws -> [String] {
        try traduction(textes, langue)
    }
}
