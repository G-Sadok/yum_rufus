//
// ReglagesDeRognage
//
// Parametres du rognage automatique des bords, premiere etape de la chaine de
// traitement de la section 6.3.
//
// Trois seuils et deux gardes.
//
// Le seuil de variance decide qu une ligne ou une colonne est unie. Les deux
// tolerances decident qu une bande unie est assez proche du blanc ou du noir
// pur pour etre une marge de scan plutot qu un aplat voulu par le dessinateur.
// Les deux conditions sont exigees ensemble : un aplat gris uni est uni sans
// etre une marge, et une bande claire mais texturee porte du dessin.
//
// La marge de securite rend quatre pixels au contenu apres coup, comme
// l impose la section 6.3. Une detection qui affleure le trait coupe des
// pointes d encre que personne ne remarque en developpement et que tout le
// monde voit sur une planche.
//
// La part minimale conservee est la garde de derniere ligne : un rognage qui
// emporterait presque toute la page est un rognage qui s est trompe, et la page
// est alors rendue entiere. Une page mal detectee vaut infiniment mieux qu une
// page reduite a un timbre.
//
// Les valeurs sont normalisees entre zero et un, jamais en niveaux sur 255,
// pour que le meme reglage vaille quelle que soit la profondeur de la source.
//

/// Parametres de detection des marges d une page.
public struct ReglagesDeRognage: Sendable, Hashable {
    /// Vrai quand le rognage doit etre applique.
    ///
    /// Le tableau des reglages de la section 10 livre cet interrupteur inactif.
    public let actif: Bool

    /// Variance maximale, en valeurs normalisees, d une bande dite unie.
    ///
    /// La valeur par defaut vaut un ecart type de 0,04, soit environ dix
    /// niveaux sur 255. Un fond de scan compresse en JPEG bruite de deux ou
    /// trois niveaux passe dessous, un aplat trame passe au dessus.
    public let seuilDeVariance: Double

    /// Ecart maximal au blanc pur d une bande unie consideree comme marge.
    public let toleranceDeBlanc: Double

    /// Ecart maximal au noir pur d une bande unie consideree comme marge.
    public let toleranceDeNoir: Double

    /// Pixels rendus au contenu de chaque cote apres detection.
    public let margeDeSecurite: Int

    /// Part de la surface d origine sous laquelle le rognage est abandonne.
    public let partMinimaleConservee: Double

    /// Construit des reglages, en ramenant chaque valeur dans son domaine.
    public init(
        actif: Bool,
        seuilDeVariance: Double = 0.0016,
        toleranceDeBlanc: Double = 0.06,
        toleranceDeNoir: Double = 0.06,
        margeDeSecurite: Int = 4,
        partMinimaleConservee: Double = 0.25
    ) {
        self.actif = actif
        self.seuilDeVariance = max(0, seuilDeVariance)
        self.toleranceDeBlanc = min(max(0, toleranceDeBlanc), 1)
        self.toleranceDeNoir = min(max(0, toleranceDeNoir), 1)
        self.margeDeSecurite = max(0, margeDeSecurite)
        self.partMinimaleConservee = min(max(0, partMinimaleConservee), 1)
    }

    /// Reglages livres par defaut : interrupteur inactif.
    ///
    /// Conforme au tableau des reglages de la section 10, qui livre Rogner les
    /// bords inactif. Une page n est donc jamais rognee sans que l utilisateur
    /// l ait demande.
    public static let parDefaut = ReglagesDeRognage(actif: false)

    /// Reglages conseilles une fois l interrupteur arme, seuils standards.
    public static let recommande = ReglagesDeRognage(actif: true)

    /// Empreinte des parametres, destinee aux cles de cache.
    ///
    /// Deux reglages qui produisent le meme resultat portent la meme empreinte,
    /// et deux reglages qui produisent des resultats differents en portent deux.
    /// C est la seule promesse attendue d elle, et c est celle qui empeche un
    /// cache de rendre une page rognee selon des seuils que l utilisateur a
    /// changes depuis.
    ///
    /// Le rognage inactif ecrase les seuils : ils ne changent alors plus rien au
    /// resultat, les faire entrer dans l empreinte multiplierait les entrees de
    /// cache pour des pages identiques.
    public var empreinte: String {
        guard actif else { return "rognage=0" }

        return "rognage=1;v=\(seuilDeVariance);b=\(toleranceDeBlanc)"
            + ";n=\(toleranceDeNoir);m=\(margeDeSecurite);p=\(partMinimaleConservee)"
    }
}
