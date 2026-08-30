//
// ModeleDeSurelevation
//
// Ce que la surelevation attend d un modele, et rien de plus.
//
// La section 8 nomme un modele precis, Real ESRGAN converti en Core ML dans sa
// variante anime. Le tuilage, le fondu, la serialisation et le cache n en
// dependent pourtant pas : ils dependent de `ModeleParTuiles`, dont ce protocole
// n est qu une specialisation nommee.
//
// Le nom compte, meme s il n ajoute aucune exigence. Un modele de surelevation
// et un modele de colorisation ont la meme forme et ne sont pas
// interchangeables : le premier agrandit, le second recolore, et les confondre
// donnerait une page a la mauvaise echelle ou une page en noir et blanc que le
// cache retiendrait comme colorisee. Les deux protocoles rendent l erreur
// impossible a l appel, sans dupliquer une ligne du moteur.
//

/// Modele qui agrandit une tuile d un facteur entier.
public protocol ModeleDeSurelevation: ModeleParTuiles {
    /// Agrandit une tuile.
    ///
    /// - Parameter tuile: tuile carree au cote attendu par le modele.
    /// - Returns: la meme tuile, chaque cote multiplie par le facteur.
    /// - Throws: `ErreurDeTraitementIA` quand le modele refuse l entree.
    func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels
}

extension ModeleDeSurelevation {
    /// Le traitement d une tuile, pour un modele de surelevation, est son
    /// agrandissement.
    public func traiter(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        try surelever(tuile)
    }
}
