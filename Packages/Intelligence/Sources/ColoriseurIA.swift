import Core
import ImagePipeline

//
// ColoriseurIA
//
// L acteur dedie de la colorisation, jumeau de celui de l amelioration.
//
// La section 8 demande la meme architecture d execution que la surelevation, et
// c est exactement ce que ce fichier livre : le meme moteur de tuilage, le meme
// cache, la meme file serialisee. Ce qui change tient en trois lignes, le modele
// n agrandit pas, l empreinte de cache est celle de la colorisation, et le
// message d erreur nomme l autre reglage.
//
// Un acteur separe et non un acteur partage, alors que la section 8 exige que
// deux traitements IA ne tournent jamais en parallele sur le meme appareil. La
// regle est tenue autrement, et il faut le dire clairement, parce que le
// raisonnement ne se lit pas dans le code.
//
// Un acteur serialise ses propres appels, il ne serialise pas ceux d un autre.
// Deux acteurs peuvent donc travailler en meme temps, et deux reseaux qui
// tournent ensemble se disputent le moteur neuronal jusqu a ce que le systeme
// termine l application. Ce qui l empeche ici est la chaine elle meme : la
// section 6.3 place l amelioration quatrieme et la colorisation cinquieme, sur
// la meme page, l une apres l autre. La sortie de la premiere est l entree de la
// seconde, elles ne peuvent pas se chevaucher sur une page donnee, et la
// precharge de la section 6.2 traite les pages une par une dans la meme tache.
//
// La consequence est une contrainte sur l appelant, et elle est ecrite ici
// parce qu elle ne se voit pas ailleurs : les deux acteurs se lancent en
// sequence sur une meme tache, jamais depuis deux taches concurrentes. Le jour
// ou la chaine voudra colorer une page pendant qu elle en ameliore une autre, la
// bonne reponse ne sera pas de retirer une garde, mais de poser un executeur
// commun aux deux acteurs.
//
// Comme pour l amelioration, le traitement ne contient aucun point de suspension
// du premier pixel lu au dernier ecrit, et la reentrance n a donc aucune
// ouverture par ou passer. L annulation traverse quand meme, `TraitementParTuiles`
// verifie la tache avant chaque tuile.
//

/// Acteur dedie a la colorisation IA, file serialisee et resultat mis en cache.
public actor ColoriseurIA {
    /// Bornes du cache des pages colorisees.
    public let plafond: PlafondDeCacheMemoire

    /// Plafond memoire d une page produite.
    public let budget: BudgetDeTraitementIA

    /// Decoupe appliquee aux pages, au cote de tuile du modele installe.
    public let tuilage: TuilageDeTraitement

    private let modele: any ModeleDeColorisation
    private let traitement: TraitementParTuiles
    private var cache: CacheDePagesIA
    private var traitements = 0

    /// Prepare l acteur autour d un modele installe.
    ///
    /// - Parameters:
    ///   - modele: modele de colorisation, charge par la couche qui l installe.
    ///   - tuilage: decoupe appliquee. Par defaut celle du modele, dont le cote
    ///     de tuile est impose par le reseau converti.
    ///   - budget: plafond memoire d une page produite.
    ///   - plafond: bornes du cache des pages colorisees.
    public init(
        modele: any ModeleDeColorisation,
        tuilage: TuilageDeTraitement? = nil,
        budget: BudgetDeTraitementIA = .colorisation,
        plafond: PlafondDeCacheMemoire = .pagesColorisees
    ) {
        self.modele = modele
        self.budget = budget
        self.plafond = plafond
        self.tuilage = tuilage ?? modele.tuilage
        traitement = TraitementParTuiles(tuilage: self.tuilage)
        cache = CacheDePagesIA(plafond: plafond)
    }

    /// Cle sous laquelle le resultat d une page est retenu.
    ///
    /// Elle reprend la variante d origine de la page, qui porte deja la taille
    /// demandee et les etapes precedentes de la chaine, amelioration comprise,
    /// et lui ajoute l empreinte des reglages et le nom du modele. Une mise a
    /// jour du modele ne peut donc pas faire ressortir une page produite par le
    /// precedent, ce que l empreinte des reglages seule ne garantirait pas.
    public static func cle(
        pour page: ClePage,
        reglages: ReglagesDeColorisation,
        modele: any ModeleDeColorisation
    ) -> ClePage {
        let empreinte = "\(reglages.empreinte);mc=\(modele.identifiant)"

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

    /// Nombre de pages colorisees retenues a cet instant.
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
    /// prouve qu un resultat n est jamais recalcule, et la suite de tests la lit
    /// pour cela.
    public var nombreDeTraitements: Int {
        traitements
    }

    /// Colorise une page, ou rend celle du cache.
    ///
    /// - Parameters:
    ///   - page: page decodee, apres les etapes precedentes de la chaine.
    ///   - cle: identite de la page dans son etat de production.
    ///   - reglages: interrupteur de la section 9.
    /// - Returns: la page colorisee, ou la page telle quelle quand
    ///   l interrupteur est inactif.
    /// - Throws: `ErreurDeTraitementIA` quand le traitement ne peut pas aboutir,
    ///   ou `CancellationError` quand la tache appelante est annulee.
    public func coloriser(
        _ page: ImageDePage,
        pour cle: ClePage,
        reglages: ReglagesDeColorisation = .arme
    ) throws -> ImageDePage {
        guard reglages.actif else { return page }

        let cleDeCache = Self.cle(pour: cle, reglages: reglages, modele: modele)

        if let connue = cache.image(pour: cleDeCache) {
            return connue
        }

        let colorisee = try produire(page)
        cache.deposer(colorisee, pour: cleDeCache)

        return colorisee
    }

    /// Colorise une page, ou la rend telle quelle en cas d echec.
    ///
    /// Entree de la chaine de lecture, qui doit toujours avoir de quoi afficher.
    /// L annulation est traitee comme les autres echecs : la tache annulee ne
    /// veut plus la page, ce qu elle recoit ne l interesse plus.
    public func coloriserOuRendreTelQuel(
        _ page: ImageDePage,
        pour cle: ClePage,
        reglages: ReglagesDeColorisation = .arme
    ) -> ImageDePage {
        (try? coloriser(page, pour: cle, reglages: reglages)) ?? page
    }

    /// Oublie le resultat d une page sous ces reglages.
    public func oublier(_ cle: ClePage, reglages: ReglagesDeColorisation) {
        cache.retirer(Self.cle(pour: cle, reglages: reglages, modele: modele))
    }

    /// Vide le cache des pages colorisees.
    public func vider() {
        cache.vider()
    }

    /// Produit la page colorisee, sans passer par le cache.
    private func produire(_ page: ImageDePage) throws -> ImageDePage {
        let entree = TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)

        guard budget.accepte(entree) else {
            throw ErreurDeTraitementIA.pageTropLourde(
                octets: entree.octetsUneFoisDecodee,
                plafond: budget.octetsParPage
            )
        }

        guard let matrice = MatriceDePixels(page.image) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        traitements += 1

        let produite = try traitement.traiter(matrice, avec: modele)

        guard produite.taille == entree else {
            throw ErreurDeTraitementIA.tailleInattendue(attendue: entree, recue: produite.taille)
        }

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
