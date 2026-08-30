import Core

//
// NavigationParCases
//
// Le parcours case par case d une planche, et le moment ou il rend la main a la
// tourne de page, section 8 du cahier de developpement.
//
// Le sens de lecture gouverne ce parcours deux fois, et les deux fois comptent.
// Il range d abord les cases, par `SensDeLecture.ordonner`, ce qui decide de la
// case qui vient apres celle que le lecteur regarde. Il traduit ensuite le geste
// ou la touche en intention, par `NavigationDeLecture`, ce qui decide du geste
// qui avance. Se tromper sur l un des deux donne une lecture a l envers, se
// tromper sur les deux la remet a l endroit par accident, et le jour ou l un des
// deux est corrige la navigation casse sans que personne comprenne pourquoi.
// Les deux passent donc par le meme sens, celui du modele, et aucune fonction de
// ce fichier ne recoit la direction de l interface.
//
// Le parcours ne connait pas le chapitre. Il dit qu il a fini la planche et rend
// une intention de tourne de page, que la couche appelante execute avec ce qu
// elle sait des pages voisines et de l enchainement des chapitres. C est ce qui
// permet de le tester en entier sans monter un chapitre, et c est aussi ce qui
// evite de dupliquer ici la fin de chapitre, deja traitee par
// `EnchainementDeChapitres`.
//
// Une planche sans case detectee n est pas un cas d erreur. Le detecteur echoue
// sur une planche muette, sur une page de titre, ou parce qu aucun modele n est
// installe, et la lecture doit continuer. Le parcours prend alors la planche
// entiere pour seule case : la premiere avance tourne la page, ce qui est
// exactement le comportement de la navigation par pages.
//

/// Bord par lequel la lecture entre dans une planche.
public enum EntreeDansLaPlanche: String, Sendable, CaseIterable, Hashable {
    /// La lecture arrive de la planche precedente et commence par la premiere
    /// case.
    case parLeDebut

    /// La lecture revient de la planche suivante et reprend par la derniere
    /// case, celle qu elle avait quittee.
    case parLaFin

    /// Bord d entree d une planche atteinte par cette intention.
    public static func apres(_ intention: IntentionDeNavigation) -> EntreeDansLaPlanche {
        intention == .pagePrecedente ? .parLaFin : .parLeDebut
    }
}

/// Ce qu une intention produit pendant une lecture case par case.
public enum EtapeDeNavigationParCases: Sendable, Equatable {
    /// Le zoom passe a une autre case de la meme planche.
    case caseVisee(NavigationParCases)

    /// La planche est finie de ce cote, la page tourne.
    case changementDePage(IntentionDeNavigation)

    /// Le geste ne navigue pas. Il appartient a une autre couche.
    case aucune
}

/// Position de la lecture dans les cases d une planche.
public struct NavigationParCases: Sendable, Equatable {
    /// Marge ajoutee autour d une case pendant le zoom, en part de la planche.
    ///
    /// Une case cadree au trait pres colle son cadre au bord de l ecran, et le
    /// lecteur perd le reperage qui lui dit ou il en est dans la planche. Deux
    /// pour cent laissent voir la gouttiere sans montrer la case voisine.
    public static let margeDeCadrage = 0.02

    /// Sens qui gouverne l ordre des cases et la lecture des gestes.
    public let sens: SensDeLecture

    /// Cases de la planche, dans l ordre ou elles se lisent.
    public let cases: [CaseDePage]

    /// Position de la case regardee dans cette suite.
    public let indice: Int

    /// Ouvre une planche et se place sur sa premiere case dans ce sens.
    ///
    /// - Parameters:
    ///   - cases: cases detectees, dans n importe quel ordre.
    ///   - sens: sens de lecture de la serie, jamais celui de l interface.
    ///   - entree: bord par lequel la lecture entre dans la planche.
    public init(
        cases: [CaseDePage],
        sens: SensDeLecture,
        entree: EntreeDansLaPlanche = .parLeDebut
    ) {
        let rangees = sens.ordonner(cases)
        let suite = rangees.isEmpty ? [CaseDePage.plancheEntiere] : rangees

        self.sens = sens
        self.cases = suite
        indice = entree == .parLaFin ? suite.count - 1 : 0
    }

    /// Recopie ce parcours a une autre position de la meme planche.
    private init(sens: SensDeLecture, cases: [CaseDePage], indice: Int) {
        self.sens = sens
        self.cases = cases
        self.indice = indice
    }

    /// Case que le lecteur regarde.
    ///
    /// La suite n est jamais vide et l indice est toujours dans ses bornes, mais
    /// le dire au compilateur couterait une force unwrap. Le repli sur la
    /// planche entiere dit la meme chose sans mentir sur l invariant.
    public var caseCourante: CaseDePage {
        guard indice >= 0, indice < cases.count else { return .plancheEntiere }

        return cases[indice]
    }

    /// Cadrage du zoom sur la case regardee, marge comprise.
    public func cadrage(marge: Double = margeDeCadrage) -> CaseDePage {
        caseCourante.elargie(de: marge)
    }

    /// Vrai quand la lecture est sur la premiere case de la planche.
    public var estALaPremiereCase: Bool {
        indice <= 0
    }

    /// Vrai quand la lecture est sur la derniere case de la planche.
    public var estALaDerniereCase: Bool {
        indice >= cases.count - 1
    }

    /// Etape produite par une intention deja interpretee.
    public func apres(_ intention: IntentionDeNavigation) -> EtapeDeNavigationParCases {
        switch intention {
        case .pageSuivante:
            if estALaDerniereCase {
                return .changementDePage(.pageSuivante)
            }

            return .caseVisee(deplacee(de: 1))

        case .pagePrecedente:
            if estALaPremiereCase {
                return .changementDePage(.pagePrecedente)
            }

            return .caseVisee(deplacee(de: -1))

        case .aucune:
            return .aucune
        }
    }

    /// Etape produite par un balayage, lu dans le sens de la serie.
    public func apres(balayage: BalayageDeNavigation) -> EtapeDeNavigationParCases {
        apres(NavigationDeLecture.intention(pourBalayage: balayage, sens: sens))
    }

    /// Etape produite par une touche du clavier, lue dans le sens de la serie.
    public func apres(touche: ToucheDeNavigation) -> EtapeDeNavigationParCases {
        apres(NavigationDeLecture.intention(pourTouche: touche, sens: sens))
    }

    /// Le meme parcours, decale de ce nombre de cases dans la planche.
    private func deplacee(de pas: Int) -> NavigationParCases {
        let vise = min(max(0, indice + pas), cases.count - 1)

        return NavigationParCases(sens: sens, cases: cases, indice: vise)
    }
}
