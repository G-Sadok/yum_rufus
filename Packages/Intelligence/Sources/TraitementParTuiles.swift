import Core

//
// TraitementParTuiles
//
// Le traitement lui meme : tuiler la page, passer chaque tuile au modele,
// refondre les sorties en une page.
//
// Le moteur ne sait pas ce que le modele fait de la tuile. Il ne connait que
// deux choses de lui, le cote qu il attend et le facteur par lequel il
// multiplie ce cote, et c est assez pour la surelevation comme pour la
// colorisation. La section 8 demande d ailleurs la meme architecture
// d execution aux deux, ce qui se dit ici en une phrase : un seul moteur, deux
// modeles.
//
// Le traitement est synchrone et sans point de suspension, du premier pixel lu
// au dernier ecrit. Ce n est pas un oubli, c est ce qui rend la promesse de la
// section 8 tenable : l acteur qui appelle ce traitement ne peut pas rendre la
// main au milieu, donc deux traitements ne peuvent pas s entrelacer sur le meme
// appareil. Une seule ligne asynchrone ici, et la garantie tomberait sans
// qu aucun test de resultat ne s en apercoive.
//
// L annulation est verifiee avant chaque tuile. Une page de trente tuiles sur un
// reseau se compte en secondes, et l utilisateur qui tourne la page ne doit pas
// attendre la fin d un travail dont personne ne veut plus. Le grain de
// l annulation est donc la tuile, pas la page.
//
// La page est completee avant d etre tuilee et rognee apres avoir ete refondue.
// Le remplissage ne sert qu a donner au modele l entree de taille fixe qu il
// attend, il ne figure jamais dans le resultat.
//

/// Traitement d une page par tuiles fondues les unes dans les autres.
public struct TraitementParTuiles: Sendable {
    /// Decoupe appliquee a la page.
    public let tuilage: TuilageDeTraitement

    public init(tuilage: TuilageDeTraitement = .parDefaut) {
        self.tuilage = tuilage
    }

    /// Traitement de la page entiere, tuile par tuile.
    ///
    /// - Parameters:
    ///   - page: pixels de la page a traiter.
    ///   - modele: modele qui traite une tuile.
    /// - Returns: la page traitee, chaque cote multiplie par le facteur du
    ///   modele.
    /// - Throws: `ErreurDeTraitementIA` quand une tuile est refusee, ou
    ///   `CancellationError` quand la tache appelante est annulee.
    public func traiter(_ page: MatriceDePixels, avec modele: ModeleParTuiles) throws -> MatriceDePixels {
        let facteur = max(1, modele.facteur)
        let remplie = page.remplie(jusqua: tuilage.cote)
        let decoupes = tuilage.decoupes(de: remplie.taille)

        guard decoupes.isEmpty == false else {
            throw ErreurDeTraitementIA.pageIllisible
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
            throw ErreurDeTraitementIA.pageIllisible
        }

        return rognee
    }

    /// Passe une tuile au modele et depose sa sortie dans le tampon.
    private func deposer(
        _ decoupe: DecoupeDeTraitement,
        de page: MatriceDePixels,
        avec modele: ModeleParTuiles,
        dans tampon: inout TamponDeRecomposition
    ) throws {
        try Task.checkCancellation()

        guard let entree = page.extraire(
            origineX: decoupe.origineX,
            origineY: decoupe.origineY,
            taille: decoupe.taille
        ) else {
            throw ErreurDeTraitementIA.tuileRefusee(index: decoupe.index)
        }

        let sortie = try modele.traiter(entree)
        let attendue = modele.tailleDeSortie(pour: decoupe.taille)

        guard sortie.taille == attendue else {
            throw ErreurDeTraitementIA.tailleInattendue(attendue: attendue, recue: sortie.taille)
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
