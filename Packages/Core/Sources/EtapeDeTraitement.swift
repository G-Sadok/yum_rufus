//
// EtapeDeTraitement
//
// Les dix etapes de la chaine de traitement des images, section 6.3 du cahier
// de developpement, dans l ordre exact ou elles s appliquent.
//
// L ordre n est pas un detail de mise en oeuvre, c est le contenu meme de la
// section. Rogner apres avoir divise couperait chaque moitie sur ses propres
// marges et decalerait le raccord. Accentuer apres avoir eclairci accentuerait
// du bruit deja amplifie. Chauffer avant de corriger le gamma teindrait la
// correction. Chaque interversion se voit sur la planche, et aucune ne leve
// d erreur.
//
// Le rang est porte par la valeur brute, de 1 a 10, et non par l ordre de
// declaration des cas. Un cas ajoute au milieu ne peut donc pas renumeroter la
// chaine en silence.
//
// La section 6.3 partage ces dix etapes en deux groupes. Les etapes 1 a 5 sont
// couteuses et leur resultat se met en cache sur disque sous une cle qui integre
// le hachage des parametres. Les etapes 6 a 10 sont des filtres Core Image
// appliques en temps reel sur le GPU. Les deux proprietes ci dessous nomment ce
// partage tel que le document l ecrit, et rien de plus : ce que la chaine sait
// reellement appliquer aujourd hui est declare par la chaine, pas ici.
//

/// Une etape de la chaine de traitement des images, section 6.3.
public enum EtapeDeTraitement: Int, Sendable, CaseIterable, Hashable {
    case rognageAutomatique = 1
    case divisionDesImagesLarges = 2
    case reductionDuBruit = 3
    case ameliorationIA = 4
    case colorisationIA = 5
    case nettete = 6
    case contraste = 7
    case gamma = 8
    case luminosite = 9
    case chaleur = 10

    /// Les dix etapes, dans l ordre impose par la section 6.3.
    public static let chaine: [EtapeDeTraitement] =
        allCases.sorted { $0.rawValue < $1.rawValue }

    /// Rang de l etape dans la chaine, de 1 a 10.
    public var rang: Int {
        rawValue
    }

    /// Vrai pour les etapes 6 a 10, que la section 6.3 declare appliquees en
    /// temps reel sur le GPU.
    public var estDeclareeEnTempsReel: Bool {
        rawValue >= 6
    }

    /// Vrai pour les etapes 1 a 5, que la section 6.3 declare couteuses et dont
    /// le resultat se met en cache sur disque.
    public var estDeclareeCouteuse: Bool {
        rawValue <= 5
    }

    /// Vrai quand cette etape s applique avant l autre dans la chaine.
    public func precede(_ autre: EtapeDeTraitement) -> Bool {
        rawValue < autre.rawValue
    }
}

/// Suite d etapes rangee dans l ordre de la section 6.3.
extension Collection<EtapeDeTraitement> {
    /// Les memes etapes, remises dans l ordre de la chaine.
    ///
    /// Un appelant qui compose une chaine a partir d un ensemble ou d un
    /// dictionnaire n a aucun ordre a lui, et l ordre est precisement ce que la
    /// section 6.3 impose. Passer par ici est le seul moyen de le retrouver.
    public var dansLOrdreDeLaChaine: [EtapeDeTraitement] {
        sorted { $0.rawValue < $1.rawValue }
    }
}
