import Core

//
// SurelevationEnTuiles
//
// Le traitement lui meme : tuiler la page, passer chaque tuile au modele,
// refondre les sorties en une page.
//
// Le traitement est synchrone et sans point de suspension, du premier pixel lu
// au dernier ecrit. Ce n est pas un oubli, c est ce qui rend la promesse de la
// section 8 tenable : l acteur qui appelle ce traitement ne peut pas rendre la
// main au milieu, donc deux traitements ne peuvent pas s entrelacer sur le meme
// appareil. Une seule ligne asynchrone ici, et la garantie tomberait sans
// qu aucun test de resultat ne s en apercoive.
//
// L annulation est verifiee avant chaque tuile. Une page de trente tuiles sur un
// reseau de surelevation se compte en secondes, et l utilisateur qui tourne la
// page ne doit pas attendre la fin d un travail dont personne ne veut plus. Le
// grain de l annulation est donc la tuile, pas la page.
//
// La page est completee avant d etre tuilee et rognee apres avoir ete refondue.
// Le remplissage ne sert qu a donner au modele l entree de taille fixe qu il
// attend, il ne figure jamais dans le resultat.
//

/// Surelevation d une page par tuiles fondues les unes dans les autres.
public struct SurelevationEnTuiles: Sendable {
    /// Decoupe appliquee a la page.
    public let tuilage: TuilageDeSurelevation

    public init(tuilage: TuilageDeSurelevation = .parDefaut) {
        self.tuilage = tuilage
    }

    /// Surelevation de la page entiere, tuile par tuile.
    ///
    /// - Parameters:
    ///   - page: pixels de la page a ameliorer.
    ///   - modele: modele qui agrandit une tuile.
    /// - Returns: la page agrandie du facteur du modele.
    /// - Throws: `ErreurDAmelioration` quand une tuile est refusee, ou
    ///   `CancellationError` quand la tache appelante est annulee.
    public func surelever(_ page: MatriceDePixels, avec modele: ModeleDeSurelevation) throws -> MatriceDePixels {
        let facteur = max(1, modele.facteur)
        let remplie = page.remplie(jusqua: tuilage.cote)
        let decoupes = tuilage.decoupes(de: remplie.taille)

        guard decoupes.isEmpty == false else {
            throw ErreurDAmelioration.pageIllisible
        }

        var tampon = TamponDeRecomposition(
            largeur: remplie.largeur * facteur,
            hauteur: remplie.hauteur * facteur,
            hauteurDeFenetre: tuilage.cote * facteur
        )
        var ligneDeTuiles = 0

        for decoupe in decoupes {
            if decoupe.ligne != ligneDeTuiles {
                tampon.avancer(jusqua: decoupe.origineY * facteur)
                ligneDeTuiles = decoupe.ligne
            }

            try deposer(decoupe, de: remplie, avec: modele, dans: &tampon)
        }

        let voulue = TailleEnPixels(largeur: page.largeur * facteur, hauteur: page.hauteur * facteur)

        guard let entiere = tampon.terminer(), let rognee = entiere.rognee(a: voulue) else {
            throw ErreurDAmelioration.pageIllisible
        }

        return rognee
    }

    /// Passe une tuile au modele et depose sa sortie dans le tampon.
    private func deposer(
        _ decoupe: DecoupeDeSurelevation,
        de page: MatriceDePixels,
        avec modele: ModeleDeSurelevation,
        dans tampon: inout TamponDeRecomposition
    ) throws {
        try Task.checkCancellation()

        guard let entree = page.extraire(
            origineX: decoupe.origineX,
            origineY: decoupe.origineY,
            taille: decoupe.taille
        ) else {
            throw ErreurDAmelioration.tuileRefusee(index: decoupe.index)
        }

        let sortie = try modele.surelever(entree)
        let attendue = modele.tailleDeSortie(pour: decoupe.taille)

        guard sortie.taille == attendue else {
            throw ErreurDAmelioration.tailleInattendue(attendue: attendue, recue: sortie.taille)
        }

        let facteur = max(1, modele.facteur)
        let fondu = tuilage.recouvrement * facteur

        tampon.deposer(
            sortie,
            origineX: decoupe.origineX * facteur,
            origineY: decoupe.origineY * facteur,
            poidsHorizontal: RampeDeFondu.poids(
                longueur: sortie.largeur,
                fondu: fondu,
                debutLibre: decoupe.contreLeBordGauche,
                finLibre: decoupe.contreLeBordDroit
            ),
            poidsVertical: RampeDeFondu.poids(
                longueur: sortie.hauteur,
                fondu: fondu,
                debutLibre: decoupe.contreLeBordHaut,
                finLibre: decoupe.contreLeBordBas
            )
        )
    }
}
