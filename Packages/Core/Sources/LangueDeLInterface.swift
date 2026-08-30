//
// LangueDeLInterface
//
// Les langues dont le catalogue de chaines est livre. Section 13 du cahier de
// developpement.
//

/// Une langue dans laquelle l interface de l application est entierement
/// traduite.
///
/// La liste est la source de verite de la completude du catalogue : la suite de
/// tests exige que chaque cle de `Localizable.xcstrings` porte une valeur dans
/// chacun de ces cas, et refuse une langue presente dans le catalogue qui ne
/// figurerait pas ici. Ajouter une langue se fait donc en deux gestes, un cas
/// ici et les traductions la bas, et le test dit lequel des deux manque.
///
/// La direction de disposition n est pas ecrite cas par cas : elle se demande a
/// `DirectionDInterface.pourLangue`, qui la deduit du code BCP 47. Ajouter
/// l arabe reviendra donc a ecrire `case arabe = "ar"`, sans toucher a la
/// moindre vue ni a la moindre condition. C est ce que la section 13 demande
/// quand elle dit que l architecture ne doit pas empecher la disposition de
/// droite a gauche.
///
/// Cette enumeration ne dit rien du sens de lecture d une serie. Voir
/// `ContexteDePresentation` pour la raison.
public enum LangueDeLInterface: String, Sendable, Codable, CaseIterable, Hashable {
    /// Langue source du catalogue, celle dans laquelle les libelles sont ecrits.
    case francais = "fr"

    case anglais = "en"
    case espagnol = "es"
    case japonais = "ja"

    /// Langue dans laquelle les valeurs du catalogue sont redigees d abord.
    ///
    /// Le champ `sourceLanguage` du catalogue porte le meme code, et un test
    /// verifie que les deux ne divergent pas.
    public static let source = LangueDeLInterface.francais

    /// Code BCP 47 de la langue, tel qu il est ecrit dans le catalogue et dans
    /// `knownRegions` du projet Xcode.
    public var codeBCP47: String {
        rawValue
    }

    /// Direction de disposition de l interface quand cette langue est affichee.
    ///
    /// Deduite du code, jamais ecrite a la main. Une langue de droite a gauche
    /// ajoutee plus tard repondra correctement sans modification de ce fichier.
    public var directionDInterface: DirectionDInterface {
        DirectionDInterface.pourLangue(codeBCP47)
    }
}

extension ChoixDeLangue {
    /// Langue de l interface correspondante, nulle quand le catalogue ne la
    /// livre pas.
    ///
    /// Le menu Langue du tableau 6.7 est plus large que les langues livrees :
    /// il porte `Systeme`, qui delegue le choix a l appareil, et `Deutsch`, qui
    /// sert de langue cible a la traduction des bulles sans que l interface
    /// elle meme soit traduite en allemand. Rendre ce trou explicite vaut mieux
    /// que de laisser une vue choisir un catalogue qui n existe pas.
    public var langueDeLInterface: LangueDeLInterface? {
        switch self {
        case .systeme, .deutsch: nil
        case .francais: .francais
        case .english: .anglais
        case .espanol: .espagnol
        case .japonais: .japonais
        }
    }
}
