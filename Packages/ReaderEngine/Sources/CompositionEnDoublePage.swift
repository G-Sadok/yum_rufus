import Core

//
// CompositionEnDoublePage
//
// Regroupement des pages d un chapitre en paires affichees ensemble, mode
// double page de la section 7.1 du cahier de developpement.
//
// La composition est une valeur calculee une fois par chapitre, pas un etat
// recalcule a chaque tourne de page. Elle porte trois regles et rien d autre :
// le decalage de couverture ouvre la sequence, une page large occupe l ecran
// seule, et le sens de lecture decide seulement de l ordre a l ecran, jamais de
// la sequence elle meme.
//

/// Raison pour laquelle une page occupe l ecran sans voisine.
///
/// La raison est portee par la paire plutot que deduite par la vue : deux
/// causes differentes appellent deux traitements differents a l affichage, et
/// une vue qui les redeviner reinventerait la regle de composition.
public enum MotifDePageSeule: String, Sendable, CaseIterable, Hashable {
    /// Premiere page du chapitre, isolee par le decalage de couverture.
    case couverture

    /// Page plus large que haute, qui occupe l ecran a elle seule.
    case pageLarge

    /// Page dont la voisine est large, et qui ne peut donc pas etre appariee.
    case voisineLarge

    /// Derniere page d un chapitre dont le compte laisse une page orpheline.
    case finDuChapitre
}

/// Deux pages affichees ensemble, ou une page affichee seule.
public struct PaireDePages: Sendable, Equatable, Hashable {
    /// Pages de la paire, dans l ordre narratif. Une ou deux pages.
    public let pages: [Int]

    /// Sens de lecture qui gouverne leur disposition a l ecran.
    public let sens: SensDeLecture

    /// Raison de la page seule, nulle quand la paire porte deux pages.
    public let motifDeLaPageSeule: MotifDePageSeule?

    /// Pages dans l ordre ou elles occupent l ecran, du bord gauche vers le
    /// bord droit.
    ///
    /// En droite a gauche, la premiere page de la paire est a droite, donc la
    /// liste est renversee. La regle vit dans `OrdreDesPages`, elle n est pas
    /// reecrite ici.
    public var aLEcran: [Int] {
        OrdreDesPages.aLEcran(pages, sens: sens)
    }

    /// Vrai quand la paire n affiche qu une page.
    public var estSeule: Bool {
        pages.count == 1
    }

    /// Premiere page de la paire dans l ordre narratif.
    ///
    /// C est elle qui sert de position de reprise : la section 7.5 sauvegarde
    /// un index de page, et rouvrir sur la seconde page d une paire ferait
    /// disparaitre la premiere.
    public var premierePage: Int {
        pages[0]
    }

    /// Vrai quand la page appartient a cette paire.
    public func contient(_ page: Int) -> Bool {
        pages.contains(page)
    }
}

/// Paires d un chapitre lu deux pages a la fois.
public struct CompositionEnDoublePage: Sendable, Equatable {
    /// Nombre de pages du chapitre.
    public let nombreDePages: Int

    /// Sens de lecture resolu pour la serie.
    public let sens: SensDeLecture

    /// Decalage de couverture resolu pour la serie.
    public let decalage: DecalageDeCouverture

    /// Index des pages larges, celles qui occupent l ecran seules.
    public let pagesLarges: Set<Int>

    /// Paires du chapitre, dans l ordre narratif.
    public let paires: [PaireDePages]

    /// Compose les paires d un chapitre.
    ///
    /// - Parameters:
    ///   - nombreDePages: nombre de pages, ramene a zero s il est negatif.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - decalage: decalage de couverture resolu pour la serie.
    ///   - pagesLarges: index des pages larges. Les index hors du chapitre sont
    ///     ignores plutot que refuses : une detection en cours peut porter sur
    ///     un chapitre dont le compte de pages vient de changer.
    public init(
        nombreDePages: Int,
        sens: SensDeLecture,
        decalage: DecalageDeCouverture = .parDefaut,
        pagesLarges: Set<Int> = []
    ) {
        let total = max(0, nombreDePages)
        let larges = pagesLarges.filter { (0..<total).contains($0) }

        self.nombreDePages = total
        self.sens = sens
        self.decalage = decalage
        self.pagesLarges = larges
        paires = Self.composer(
            nombreDePages: total,
            sens: sens,
            decalage: decalage,
            pagesLarges: larges
        )
    }

    /// Nombre de paires du chapitre.
    public var nombreDePaires: Int {
        paires.count
    }

    /// Rang de la paire qui affiche cette page, nul quand la page est hors du
    /// chapitre.
    public func indexDePaire(contenantLaPage page: Int) -> Int? {
        paires.firstIndex { $0.contient(page) }
    }

    /// Paire qui affiche cette page, nulle quand la page est hors du chapitre.
    public func paire(contenantLaPage page: Int) -> PaireDePages? {
        guard let index = indexDePaire(contenantLaPage: page) else {
            return nil
        }

        return paires[index]
    }

    /// Parcourt le chapitre et forme les paires.
    ///
    /// Une page large interrompt l appariement des deux cotes : elle est seule,
    /// et la page qui la precede l est aussi puisqu il ne lui reste aucune
    /// voisine. C est ce double effet qui decale la suite du chapitre, et c est
    /// exactement ce que fait un livre imprime autour d une planche double.
    private static func composer(
        nombreDePages: Int,
        sens: SensDeLecture,
        decalage: DecalageDeCouverture,
        pagesLarges: Set<Int>
    ) -> [PaireDePages] {
        guard nombreDePages > 0 else {
            return []
        }

        var paires: [PaireDePages] = []
        var index = 0

        if decalage.pagesAvantLaPremierePaire > 0 {
            let motif: MotifDePageSeule = pagesLarges.contains(0) ? .pageLarge : .couverture
            paires.append(PaireDePages(pages: [0], sens: sens, motifDeLaPageSeule: motif))
            index = 1
        }

        while index < nombreDePages {
            let voisine = index + 1

            if pagesLarges.contains(index) {
                paires.append(PaireDePages(pages: [index], sens: sens, motifDeLaPageSeule: .pageLarge))
                index += 1
                continue
            }

            guard voisine < nombreDePages else {
                paires.append(PaireDePages(pages: [index], sens: sens, motifDeLaPageSeule: .finDuChapitre))
                index += 1
                continue
            }

            guard pagesLarges.contains(voisine) == false else {
                paires.append(PaireDePages(pages: [index], sens: sens, motifDeLaPageSeule: .voisineLarge))
                index += 1
                continue
            }

            paires.append(PaireDePages(pages: [index, voisine], sens: sens, motifDeLaPageSeule: nil))
            index += 2
        }

        return paires
    }
}
