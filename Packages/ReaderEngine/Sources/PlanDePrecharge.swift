//
// PlanDePrecharge
//
// Quelles pages precharger autour de la page lue, et dans quel ordre.
//
// La section 6.2 fixe la fenetre : deux pages en avant, une en arriere. L ordre
// de la liste est un ordre de priorite, pas un ordre d affichage. La page
// suivante arrive en tete parce que c est celle que l utilisateur atteindra
// dans la seconde qui vient, la page precedente ferme la marche parce qu un
// retour en arriere est plus rare et moins urgent.
//
// Le sens de lecture n entre pas dans ce calcul, et ce n est pas un oubli.
// Un chapitre est numerote dans son ordre narratif, celui que rend
// `OrdreDesPages.ordreNarratif`, et le sens de lecture ne renumerote rien : il
// decide de quel cote de l ecran une page se pose, pas de celle qui vient
// apres. En avant veut donc dire index croissant dans les trois sens, y compris
// en droite a gauche ou la page suivante entre par la gauche.
//

/// Fenetre de precharge autour de la page lue.
public struct PlanDePrecharge: Sendable, Hashable {
    /// Nombre de pages prechargees devant la page lue.
    public let enAvant: Int

    /// Nombre de pages prechargees derriere la page lue.
    public let enArriere: Int

    /// Construit une fenetre, en refusant une profondeur negative.
    public init(enAvant: Int, enArriere: Int) {
        self.enAvant = max(0, enAvant)
        self.enArriere = max(0, enArriere)
    }

    /// Fenetre de la section 6.2 : deux pages en avant, une en arriere.
    public static let parDefaut = PlanDePrecharge(enAvant: 2, enArriere: 1)

    /// Pages a precharger autour d une page lue, de la plus utile a la moins utile.
    ///
    /// - Parameters:
    ///   - index: page que l utilisateur regarde, indexee a partir de zero.
    ///   - nombreDePages: nombre de pages du chapitre.
    /// - Returns: les index voisins, bornes au chapitre, sans la page lue.
    public func voisines(de index: Int, nombreDePages: Int) -> [Int] {
        guard nombreDePages > 0, index >= 0, index < nombreDePages else {
            return []
        }

        var voisines: [Int] = []

        for pas in stride(from: 1, through: enAvant, by: 1) where index + pas < nombreDePages {
            voisines.append(index + pas)
        }

        for pas in stride(from: 1, through: enArriere, by: 1) where index - pas >= 0 {
            voisines.append(index - pas)
        }

        return voisines
    }
}
