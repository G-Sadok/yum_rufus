import Core
import ImagePipeline

//
// AmeliorateurIA
//
// L acteur dedie de la section 8 : un seul traitement d intelligence a la fois
// sur l appareil, et jamais deux fois le meme.
//
// La phrase du cahier est courte et sa portee ne l est pas. Chaque traitement IA
// s execute dans un acteur dedie avec une file serialisee, deux traitements ne
// tournent jamais en parallele sur le meme appareil. Un reseau de surelevation
// sature le moteur neuronal a lui seul : deux qui tournent ensemble ne vont pas
// deux fois moins vite chacun, ils se disputent la memoire, et l appareil finit
// par terminer l application au lieu de ralentir.
//
// La serialisation est ici structurelle et non surveillee. Un acteur execute ses
// appels sur un executeur serie, et le traitement qu il lance ne contient aucun
// point de suspension, du premier pixel lu au dernier ecrit : ni acces a un
// autre acteur, ni attente d entree sortie, ni tache fille. Un appel ne peut
// donc pas rendre la main au milieu d un traitement, et la reentrance, qui est
// le vrai piege des acteurs, n a aucune ouverture par ou passer. C est aussi
// pourquoi le cache vit dans l etat de cet acteur au lieu d etre un acteur a
// lui : le consulter par un await rouvrirait exactement cette porte.
//
// La contrepartie est assumee. Le traitement occupe son fil pendant plusieurs
// secondes, sans cooperer. C est precisement ce que la regle demande : pendant
// ce temps, aucun autre traitement IA ne doit avancer. Le reste de
// l application, lui, tourne sur d autres fils et sur l acteur principal.
//
// L annulation traverse quand meme. `TraitementParTuiles` verifie la tache
// avant chaque tuile, donc un lecteur qui tourne la page arrete le travail en
// cours a la tuile suivante, sans attendre la fin de la page.
//
// La colorisation a son propre acteur, `ColoriseurIA`, qui reprend la meme
// mecanique. La raison pour laquelle deux acteurs distincts ne violent pas la
// regle de la section 8 est expliquee la bas, avec la contrainte qu elle impose
// a l appelant.
//

/// Acteur dedie aux ameliorations IA, file serialisee et resultat mis en cache.
public actor AmeliorateurIA {
    /// Bornes du cache des pages ameliorees.
    public let plafond: PlafondDeCacheMemoire

    /// Plafond memoire d une page produite.
    public let budget: BudgetDeTraitementIA

    private let modele: any ModeleDeSurelevation
    private let traitement: TraitementParTuiles
    private var cache: CacheDePagesIA
    private var traitements = 0

    /// Prepare l acteur autour d un modele installe.
    ///
    /// - Parameters:
    ///   - modele: modele de surelevation, charge par la couche qui l installe.
    ///   - tuilage: decoupe appliquee, celle de la section 8 par defaut.
    ///   - budget: plafond memoire d une page produite.
    ///   - plafond: bornes du cache des pages ameliorees.
    public init(
        modele: any ModeleDeSurelevation,
        tuilage: TuilageDeTraitement = .parDefaut,
        budget: BudgetDeTraitementIA = .surelevation,
        plafond: PlafondDeCacheMemoire = .pagesAmeliorees
    ) {
        self.modele = modele
        self.budget = budget
        self.plafond = plafond
        traitement = TraitementParTuiles(tuilage: tuilage)
        cache = CacheDePagesIA(plafond: plafond)
    }

    /// Cle sous laquelle le resultat d une page est retenu.
    ///
    /// Elle reprend la variante d origine de la page, qui porte deja la taille
    /// demandee et les etapes precedentes de la chaine, et lui ajoute
    /// l empreinte des reglages, le nom du modele et son facteur. Une mise a
    /// jour du modele ne peut donc pas faire ressortir une page produite par le
    /// precedent, ce que l empreinte des reglages seule ne garantirait pas.
    public static func cle(
        pour page: ClePage,
        reglages: ReglagesDAmelioration,
        modele: any ModeleDeSurelevation
    ) -> ClePage {
        let empreinte = "\(reglages.empreinte);m=\(modele.identifiant);f=\(modele.facteur)"

        return ClePage(
            chapitre: page.chapitre,
            index: page.index,
            variante: page.variante.isEmpty ? empreinte : "\(page.variante)|\(empreinte)"
        )
    }

    /// Nom du modele installe.
    public nonisolated var identifiantDuModele: String {
        modele.identifiant
    }

    /// Facteur d agrandissement du modele installe.
    public nonisolated var facteur: Int {
        modele.facteur
    }

    /// Nombre de pages ameliorees retenues a cet instant.
    public var nombreDePagesRetenues: Int {
        cache.nombreDePages
    }

    /// Octets que le cache detient a cet instant.
    public var octetsRetenus: Int {
        cache.octetsRetenus
    }

    /// Nombre de traitements reellement lances depuis le demarrage.
    ///
    /// Un traitement evite par le cache ne compte pas. C est la mesure qui
    /// prouve qu un resultat n est jamais recalcule, et la suite de tests la
    /// lit pour cela.
    public var nombreDeTraitements: Int {
        traitements
    }

    /// Ameliore une page, ou rend celle du cache.
    ///
    /// - Parameters:
    ///   - page: page decodee, apres les etapes precedentes de la chaine.
    ///   - cle: identite de la page dans son etat de production.
    ///   - reglages: interrupteur de la section 9.
    /// - Returns: la page amelioree, ou la page telle quelle quand
    ///   l interrupteur est inactif.
    /// - Throws: `ErreurDeTraitementIA` quand le traitement ne peut pas aboutir,
    ///   ou `CancellationError` quand la tache appelante est annulee.
    public func ameliorer(
        _ page: ImageDePage,
        pour cle: ClePage,
        reglages: ReglagesDAmelioration = .arme
    ) throws -> ImageDePage {
        guard reglages.actif else { return page }

        let cleDeCache = Self.cle(pour: cle, reglages: reglages, modele: modele)

        if let connue = cache.image(pour: cleDeCache) {
            return connue
        }

        let amelioree = try produire(page)
        cache.deposer(amelioree, pour: cleDeCache)

        return amelioree
    }

    /// Ameliore une page, ou la rend telle quelle en cas d echec.
    ///
    /// Entree de la chaine de lecture, qui doit toujours avoir de quoi afficher.
    /// L annulation est traitee comme les autres echecs : la tache annulee ne
    /// veut plus la page, ce qu elle recoit ne l interesse plus.
    public func ameliorerOuRendreTelQuel(
        _ page: ImageDePage,
        pour cle: ClePage,
        reglages: ReglagesDAmelioration = .arme
    ) -> ImageDePage {
        (try? ameliorer(page, pour: cle, reglages: reglages)) ?? page
    }

    /// Oublie le resultat d une page sous ces reglages.
    public func oublier(_ cle: ClePage, reglages: ReglagesDAmelioration) {
        cache.retirer(Self.cle(pour: cle, reglages: reglages, modele: modele))
    }

    /// Vide le cache des pages ameliorees.
    public func vider() {
        cache.vider()
    }

    /// Produit la page amelioree, sans passer par le cache.
    private func produire(_ page: ImageDePage) throws -> ImageDePage {
        let entree = TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)
        let sortie = modele.tailleDeSortie(pour: entree)

        guard budget.accepte(sortie) else {
            throw ErreurDeTraitementIA.pageTropLourde(
                octets: sortie.octetsUneFoisDecodee,
                plafond: budget.octetsParPage
            )
        }

        guard let matrice = MatriceDePixels(page.image) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        traitements += 1

        let produite = try traitement.traiter(matrice, avec: modele)

        guard let image = produite.image else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        return ImageDePage(
            image: image,
            tailleDOrigine: page.tailleDOrigine,
            tailleDecodee: produite.taille,
            niveau: page.niveau
        )
    }
}
