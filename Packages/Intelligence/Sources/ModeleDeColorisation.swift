//
// ModeleDeColorisation
//
// Ce que la colorisation attend d un modele, et rien de plus.
//
// La section 8 demande un modele de colorisation de manga converti en Core ML,
// avec la meme architecture d execution que la surelevation. La phrase se lit
// litteralement dans ce fichier : le protocole reprend `ModeleParTuiles`,
// n ajoute aucune exigence de geometrie, et fixe le seul point qui les
// distingue, le facteur, a un.
//
// Le facteur vaut un et ne se regle pas. Une colorisation qui changerait les
// dimensions de la planche ne serait pas une colorisation : la chaine de la
// section 6.3 la place cinquieme, apres l amelioration et avant les filtres, et
// chaque etape suivante suppose la geometrie de la precedente. Le facteur est
// donc une constante du protocole et non une propriete du reseau, et le
// chargeur Core ML refuse un modele qui ne la respecte pas.
//
// Une consequence merite d etre dite, parce qu elle n a pas d equivalent en
// surelevation. Un reseau de colorisation choisit ses teintes a partir de ce
// qu il voit, et il ne voit qu une tuile a la fois : deux tuiles voisines
// peuvent donc teinter le meme vetement de deux couleurs differentes. Le
// recouvrement de la section 8 fond le passage de l une a l autre, il ne fait
// pas converger deux choix eloignes. Le vrai remede est un modele stable d une
// tuile a l autre, et le seul remede que le code puisse apporter est de ne pas
// aggraver le desaccord : le fondu s en charge, et la suite de tests mesure
// qu il n ajoute lui meme aucune marche.
//

/// Modele qui colorise une tuile sans changer ses dimensions.
public protocol ModeleDeColorisation: ModeleParTuiles {
    /// Colorise une tuile.
    ///
    /// - Parameter tuile: tuile carree au cote attendu par le modele.
    /// - Returns: la meme tuile, aux memes dimensions, en couleurs.
    /// - Throws: `ErreurDeTraitementIA` quand le modele refuse l entree.
    func coloriser(_ tuile: MatriceDePixels) throws -> MatriceDePixels
}

extension ModeleDeColorisation {
    /// La colorisation ne change pas les dimensions de la page.
    public var facteur: Int {
        1
    }

    /// Le traitement d une tuile, pour un modele de colorisation, est sa mise en
    /// couleurs.
    public func traiter(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        try coloriser(tuile)
    }
}
