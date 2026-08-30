import Core
import ImagePipeline

//
// DetecteurDeCases
//
// L acteur dedie de la detection de cases, troisieme des traitements par modele
// embarque de la section 8.
//
// Il tient la meme discipline que les deux autres : une file serialisee, un
// budget verifie avant le premier pixel, et un resultat mis en cache pour ne
// jamais etre recalcule. La contrainte de la section 8, deux traitements ne
// tournent jamais en parallele sur le meme appareil, est tenue de la meme
// maniere que pour la colorisation, par la chaine d appel et non par une garde :
// la detection est demandee par le geste de zoom, sur une page deja produite,
// donc apres les etapes de la chaine de la section 6.3 et jamais pendant.
//
// Trois regles sont appliquees ici et nulle part ailleurs, parce qu elles ne
// doivent pas dependre du reseau installe.
//
// Le seuil de confiance ecarte les cadres douteux. Un detecteur rend toujours
// une longue queue de detections faibles, et chacune ajoute une etape de
// navigation qui ne mene nulle part.
//
// La suppression des recouvrements ecarte les doublons. Un detecteur rend
// souvent plusieurs cadres pour la meme case, et deux cadres superposes
// obligeraient le lecteur a avancer deux fois pour changer de case, sans que
// rien ne bouge la premiere fois.
//
// L ordre de lecture vient du sens de la serie, par `SensDeLecture.ordonner`. Il
// est applique a la lecture et non a l enregistrement : la detection ne depend
// pas du sens, seul son ordre en depend, et un changement de sens en cours de
// lecture ne doit pas relancer le reseau sur des pages deja vues.
//
// Une planche sans case detectee n est pas un echec. Elle rend une suite vide,
// et la couche de lecture prend alors la planche entiere pour seule case, ce qui
// ramene la navigation case par case a la navigation par pages.
//

/// Acteur dedie a la detection de cases, file serialisee et resultat mis en
/// cache.
public actor DetecteurDeCases {
    /// Confiance minimale retenue par defaut.
    ///
    /// La moitie, comme la plupart des detecteurs d objets converti pour Core
    /// ML. Un seuil plus bas fait apparaitre des cadres sur les bulles et sur
    /// les onomatopees, un seuil plus haut perd les cases sans bordure, qui sont
    /// courantes en pleine page.
    public static let seuilParDefaut = 0.5

    /// Recouvrement au dela duquel deux cadres designent la meme case.
    public static let recouvrementParDefaut = 0.5

    /// Nombre de planches dont les cases sont retenues.
    ///
    /// Une planche pese quelques dizaines de rectangles, soit quelques
    /// centaines d octets. Le cache peut donc etre large la ou celui des pages
    /// produites est etroit, et couvrir tout le voisinage precharge de la
    /// section 6.2 sans peser sur le budget de la section 12.
    public static let plafondParDefaut = 32

    /// Confiance minimale retenue.
    public let seuilDeConfiance: Double

    /// Recouvrement au dela duquel deux cadres sont fondus en un seul.
    public let recouvrementMaximal: Double

    /// Plafond memoire de la planche donnee au reseau.
    public let budget: BudgetDeTraitementIA

    private let modele: any ModeleDeDetectionDeCases
    private var cache: CacheDeCasesDetectees
    private var detections = 0

    /// Prepare l acteur autour d un modele installe.
    ///
    /// - Parameters:
    ///   - modele: detecteur charge par la couche qui l installe.
    ///   - seuilDeConfiance: confiance minimale retenue.
    ///   - recouvrementMaximal: recouvrement au dela duquel deux cadres n en
    ///     font qu un.
    ///   - budget: plafond memoire de la planche donnee au reseau.
    ///   - plafondDuCache: nombre de planches retenues.
    public init(
        modele: any ModeleDeDetectionDeCases,
        seuilDeConfiance: Double = seuilParDefaut,
        recouvrementMaximal: Double = recouvrementParDefaut,
        budget: BudgetDeTraitementIA = .detectionDeCases,
        plafondDuCache: Int = plafondParDefaut
    ) {
        self.modele = modele
        self.seuilDeConfiance = seuilDeConfiance
        self.recouvrementMaximal = recouvrementMaximal
        self.budget = budget
        cache = CacheDeCasesDetectees(plafond: plafondDuCache)
    }

    /// Cle sous laquelle les cases d une planche sont retenues.
    ///
    /// Elle reprend la variante d origine de la page et lui ajoute le nom du
    /// modele. Le sens de lecture n y entre pas : il ne change pas les cases
    /// detectees, seulement leur ordre, et le faire entrer dans la cle
    /// relancerait le reseau sur toute la serie au premier changement de sens.
    public static func cle(pour page: ClePage, modele: any ModeleDeDetectionDeCases) -> ClePage {
        let empreinte = "md=\(modele.identifiant)"

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

    /// Nombre de planches dont les cases sont retenues a cet instant.
    public var nombreDePlanchesRetenues: Int {
        cache.nombreDePlanches
    }

    /// Nombre de passages reels dans le reseau depuis le demarrage.
    ///
    /// Une planche evitee par le cache ne compte pas. C est la mesure qui prouve
    /// qu un resultat n est jamais recalcule, et la suite de tests la lit pour
    /// cela.
    public var nombreDeDetections: Int {
        detections
    }

    /// Cases d une planche, rangees dans le sens de lecture de la serie.
    ///
    /// - Parameters:
    ///   - planche: page decodee, apres les etapes de la chaine de la section
    ///     6.3.
    ///   - cle: identite de la page dans son etat de production.
    ///   - sens: sens de lecture de la serie, jamais celui de l interface.
    /// - Returns: les cases retenues, dans l ordre ou elles se lisent. Une suite
    ///   vide quand la planche n a pas de decoupage lisible.
    /// - Throws: `ErreurDeTraitementIA` quand la detection ne peut pas aboutir,
    ///   ou `CancellationError` quand la tache appelante est annulee.
    public func cases(
        de planche: ImageDePage,
        pour cle: ClePage,
        sens: SensDeLecture
    ) throws -> [CaseDePage] {
        let cleDeCache = Self.cle(pour: cle, modele: modele)

        if let connues = cache.cases(pour: cleDeCache) {
            return sens.ordonner(connues)
        }

        let trouvees = try produire(planche)
        cache.deposer(trouvees, pour: cleDeCache)

        return sens.ordonner(trouvees)
    }

    /// Cases d une planche, ou une suite vide en cas d echec.
    ///
    /// Entree de la navigation case par case, qui doit toujours avoir de quoi
    /// repondre. L annulation est traitee comme les autres echecs : la tache
    /// annulee ne veut plus ces cases.
    public func casesOuAucune(
        de planche: ImageDePage,
        pour cle: ClePage,
        sens: SensDeLecture
    ) -> [CaseDePage] {
        (try? cases(de: planche, pour: cle, sens: sens)) ?? []
    }

    /// Oublie les cases d une planche.
    public func oublier(_ cle: ClePage) {
        cache.retirer(Self.cle(pour: cle, modele: modele))
    }

    /// Vide le cache des cases detectees.
    public func vider() {
        cache.vider()
    }

    /// Detecte les cases d une planche, sans passer par le cache.
    private func produire(_ planche: ImageDePage) throws -> [CaseDePage] {
        let entree = TailleEnPixels(largeur: planche.image.width, hauteur: planche.image.height)

        guard budget.accepte(entree) else {
            throw ErreurDeTraitementIA.pageTropLourde(
                octets: entree.octetsUneFoisDecodee,
                plafond: budget.octetsParPage
            )
        }

        guard let matrice = MatriceDePixels(planche.image) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        try Task.checkCancellation()

        detections += 1

        let brutes = try modele.detecter(matrice)

        return Self.retenir(
            brutes,
            seuil: seuilDeConfiance,
            recouvrementMaximal: recouvrementMaximal
        )
    }

    /// Cases retenues parmi celles que le reseau a rendues.
    ///
    /// Les cadres sont d abord tries par confiance decroissante, puis parcourus
    /// une fois : un cadre est retenu quand il ne recouvre aucun cadre deja
    /// retenu au dela du seuil. Le tri porte aussi sur la position, pour que
    /// deux cadres de meme confiance ne dependent pas de la stabilite du tri ni
    /// de l ordre de sortie du reseau, qu aucun modele ne promet.
    static func retenir(
        _ cases: [CaseDePage],
        seuil: Double,
        recouvrementMaximal: Double
    ) -> [CaseDePage] {
        let candidates = cases
            .filter { $0.confiance >= seuil }
            .sorted(by: laPlusSure)

        var retenues: [CaseDePage] = []

        for candidate in candidates {
            let recouvre = retenues.contains {
                $0.intersectionSurUnion(candidate) >= recouvrementMaximal
            }

            if recouvre == false {
                retenues.append(candidate)
            }
        }

        return retenues
    }

    /// Ordre de passage des candidates : la plus sure d abord, puis la position,
    /// qui rend l ordre total et donc le resultat reproductible.
    private static func laPlusSure(_ premiere: CaseDePage, _ seconde: CaseDePage) -> Bool {
        if premiere.confiance != seconde.confiance {
            return premiere.confiance > seconde.confiance
        }

        if premiere.ordonnee != seconde.ordonnee {
            return premiere.ordonnee < seconde.ordonnee
        }

        return premiere.abscisse < seconde.abscisse
    }
}
