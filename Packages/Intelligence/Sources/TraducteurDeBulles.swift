import Core
import ImagePipeline

//
// TraducteurDeBulles
//
// L acteur dedie de la traduction des bulles, quatrieme des traitements de la
// section 8 du cahier de developpement.
//
// Il tient la meme discipline que les trois autres : une file serialisee, un
// budget verifie avant le premier pixel, et un resultat mis en cache pour ne
// jamais etre recalcule. La contrainte de la section 8, deux traitements ne
// tournent jamais en parallele sur le meme appareil, est tenue comme pour la
// detection de cases : la traduction porte sur une page deja produite, donc
// apres les etapes de la chaine de la section 6.3 et jamais pendant.
//
// Deux regles vivent ici et nulle part ailleurs, parce qu elles ne doivent
// dependre ni de la detection installee ni du moteur branche.
//
// La premiere est le filtrage. Une detection de texte rend toujours une longue
// queue de lectures faibles, souvent sur des onomatopees dessinees, et chacune
// poserait une surimpression qui masque le dessin pour afficher un mot faux.
// Le seuil de confiance et la fusion des cadres qui se recouvrent les ecartent.
//
// La seconde est la porte du nuage, et c est la regle qui compte le plus. Aucun
// texte ne part vers un moteur distant sans que trois conditions soient reunies
// au meme instant : le moteur distant est choisi, l accord a ete donne, et le
// reseau repond. La premiere condition vient du menu, la deuxieme de
// `ReglagesDeTraduction`, la troisieme de `DisponibiliteDuReseau`. L acteur les
// verifie dans cet ordre et refuse avant d avoir lu le moindre pixel, pour que
// le refus ne coute pas le travail qu il refuse.
//
// Le moteur local, lui, n est jamais interroge sur le reseau. C est la
// consequence directe de `EmplacementDuMoteur` : un moteur qui declare
// travailler sur l appareil n a aucune raison d etre empeche par une connexion
// absente, et la lecture hors ligne doit rester entiere.
//
// Le sens de lecture est applique au retour et non a l enregistrement, comme
// pour les cases. Il ne change ni les bulles trouvees ni les textes produits,
// seulement leur ordre, et le faire entrer dans la cle relancerait la detection
// et le moteur sur toute la serie au premier changement de sens.
//

/// Acteur dedie a la traduction des bulles, file serialisee et resultat mis en
/// cache.
public actor TraducteurDeBulles {
    /// Confiance minimale retenue par defaut.
    ///
    /// Plus haute que celle du detecteur de cases. Une case mal detectee coute
    /// une etape de navigation inutile, une bulle mal lue affiche un contresens
    /// par dessus le dessin, ce qui est plus couteux que de ne rien afficher.
    public static let seuilParDefaut = 0.6

    /// Recouvrement au dela duquel deux cadres designent la meme bulle.
    public static let recouvrementParDefaut = 0.5

    /// Nombre de planches dont les bulles traduites sont retenues.
    public static let plafondParDefaut = 12

    /// Confiance minimale retenue.
    public let seuilDeConfiance: Double

    /// Recouvrement au dela duquel deux cadres n en font qu un.
    public let recouvrementMaximal: Double

    /// Plafond memoire de la planche donnee a la detection.
    public let budget: BudgetDeTraitementIA

    private let detecteur: any DetecteurDeTexte
    private let moteurs: [EmplacementDuMoteur: any MoteurDeTraductionDeTexte]
    private let reseau: any DisponibiliteDuReseau
    private var cache: CacheDeBullesTraduites
    private var traductions = 0

    /// Prepare l acteur autour d une detection et des moteurs installes.
    ///
    /// - Parameters:
    ///   - detecteur: detection de texte, installee par la couche qui la
    ///     branche.
    ///   - moteurs: moteurs disponibles. Un emplacement sans moteur rend la
    ///     valeur correspondante du menu inoperante, et l erreur le dit.
    ///   - reseau: etat du reseau, interroge seulement pour un moteur distant.
    ///   - seuilDeConfiance: confiance minimale retenue.
    ///   - recouvrementMaximal: recouvrement au dela duquel deux cadres n en
    ///     font qu un.
    ///   - budget: plafond memoire de la planche donnee a la detection.
    ///   - plafondDuCache: nombre de planches retenues.
    public init(
        detecteur: any DetecteurDeTexte,
        moteurs: [any MoteurDeTraductionDeTexte],
        reseau: any DisponibiliteDuReseau = ReseauSuppose.coupe,
        seuilDeConfiance: Double = seuilParDefaut,
        recouvrementMaximal: Double = recouvrementParDefaut,
        budget: BudgetDeTraitementIA = .traduction,
        plafondDuCache: Int = plafondParDefaut
    ) {
        self.detecteur = detecteur
        self.reseau = reseau
        self.seuilDeConfiance = seuilDeConfiance
        self.recouvrementMaximal = recouvrementMaximal
        self.budget = budget
        self.moteurs = Dictionary(
            moteurs.map { ($0.emplacement, $0) },
            uniquingKeysWith: { premier, _ in premier }
        )
        cache = CacheDeBullesTraduites(plafond: plafondDuCache)
    }

    /// Cle sous laquelle les bulles traduites d une planche sont retenues.
    ///
    /// Elle reprend la variante d origine de la page, qui porte deja la taille
    /// demandee et les etapes precedentes de la chaine, et lui ajoute
    /// l empreinte des reglages, le nom de la detection et celui du moteur.
    /// L empreinte porte le moteur effectif : deux lectures de la meme page,
    /// l une avant l accord au nuage et l autre apres, n ont pas ete traduites
    /// par le meme moteur.
    public static func cle(
        pour page: ClePage,
        reglages: ReglagesDeTraduction,
        detecteur: any DetecteurDeTexte,
        moteur: any MoteurDeTraductionDeTexte
    ) -> ClePage {
        let empreinte = "\(reglages.empreinte);dt=\(detecteur.identifiant);mo=\(moteur.identifiant)"

        return ClePage(
            chapitre: page.chapitre,
            index: page.index,
            variante: page.variante.isEmpty ? empreinte : "\(page.variante)|\(empreinte)"
        )
    }

    /// Nom de la detection installee.
    public nonisolated var identifiantDeLaDetection: String {
        detecteur.identifiant
    }

    /// Nombre de planches traduites retenues a cet instant.
    public var nombreDePlanchesRetenues: Int {
        cache.nombreDePlanches
    }

    /// Nombre de passages reels dans la detection et le moteur.
    ///
    /// Une planche evitee par le cache ne compte pas. C est la mesure qui prouve
    /// qu un resultat n est jamais recalcule, et la suite de tests la lit pour
    /// cela.
    public var nombreDeTraductions: Int {
        traductions
    }

    /// Vrai quand un moteur est installe pour cet emplacement.
    public nonisolated func disposeDUnMoteur(_ emplacement: EmplacementDuMoteur) -> Bool {
        moteurs[emplacement] != nil
    }

    /// Bulles traduites d une planche, rangees dans le sens de lecture.
    ///
    /// - Parameters:
    ///   - planche: page decodee, apres les etapes de la chaine de la section
    ///     6.3.
    ///   - cle: identite de la page dans son etat de production.
    ///   - sens: sens de lecture de la serie, jamais celui de l interface.
    ///   - reglages: reglages de la section Traduction.
    /// - Returns: les bulles traduites, dans l ordre ou elles se lisent. Une
    ///   suite vide quand l interrupteur est inactif ou quand la planche ne
    ///   porte aucun texte.
    /// - Throws: `ErreurDeTraduction` quand la traduction ne peut pas aboutir,
    ///   ou `CancellationError` quand la tache appelante est annulee.
    public func bulles(
        de planche: ImageDePage,
        pour cle: ClePage,
        sens: SensDeLecture,
        reglages: ReglagesDeTraduction
    ) throws -> [TraductionDeBulle] {
        guard reglages.actif else { return [] }

        let moteur = try moteurAutorise(par: reglages)
        let cleDeCache = Self.cle(
            pour: cle,
            reglages: reglages,
            detecteur: detecteur,
            moteur: moteur
        )

        if let connues = cache.bulles(pour: cleDeCache) {
            return sens.ordonnerLesTraductions(connues)
        }

        let produites = try produire(planche, avec: moteur, reglages: reglages)
        cache.deposer(produites, pour: cleDeCache)

        return sens.ordonnerLesTraductions(produites)
    }

    /// Bulles traduites d une planche, ou une suite vide en cas d echec.
    ///
    /// Entree de la couche de lecture, qui doit toujours avoir de quoi afficher.
    /// Une traduction qui echoue laisse la page telle que l auteur l a dessinee,
    /// ce qui reste lisible, la ou une page a moitie recouverte ne le serait
    /// plus.
    public func bullesOuAucune(
        de planche: ImageDePage,
        pour cle: ClePage,
        sens: SensDeLecture,
        reglages: ReglagesDeTraduction
    ) -> [TraductionDeBulle] {
        (try? bulles(de: planche, pour: cle, sens: sens, reglages: reglages)) ?? []
    }

    /// Oublie les bulles d une planche sous ces reglages.
    public func oublier(_ cle: ClePage, reglages: ReglagesDeTraduction) {
        guard let moteur = try? moteurAutorise(par: reglages) else { return }

        cache.retirer(
            Self.cle(pour: cle, reglages: reglages, detecteur: detecteur, moteur: moteur)
        )
    }

    /// Vide le cache des bulles traduites.
    public func vider() {
        cache.vider()
    }

    /// Moteur que les reglages autorisent, ou l erreur qui dit pourquoi non.
    ///
    /// Le moteur est celui que `ReglagesDeTraduction.moteurEffectif` designe, et
    /// jamais celui du menu. La difference est toute la porte du nuage : sans
    /// accord donne, le moteur effectif est le moteur local, et le moteur
    /// distant n est meme pas cherche dans la table. Rien ne sort donc de
    /// l appareil tant que l accord manque, et la lecture continue au lieu de
    /// s arreter. L interface, elle, sait qu il reste a demander en lisant
    /// `attendUnConsentement`.
    ///
    /// Le reseau n est interroge que pour un moteur qui en a besoin. Un moteur
    /// local reste appele en mode avion, ce qui est exactement ce que la
    /// section 8 promet.
    private func moteurAutorise(
        par reglages: ReglagesDeTraduction
    ) throws -> any MoteurDeTraductionDeTexte {
        let choix = reglages.moteurEffectif

        guard let moteur = moteurs[choix.estDansLeNuage ? .dansLeNuage : .surLAppareil] else {
            throw ErreurDeTraduction.moteurIndisponible(moteur: choix)
        }

        if moteur.emplacement.exigeLeReseau, reseau.estAccessible == false {
            throw ErreurDeTraduction.reseauIndisponible
        }

        return moteur
    }

    /// Detecte puis traduit les bulles d une planche, sans passer par le cache.
    private func produire(
        _ planche: ImageDePage,
        avec moteur: any MoteurDeTraductionDeTexte,
        reglages: ReglagesDeTraduction
    ) throws -> [TraductionDeBulle] {
        let entree = TailleEnPixels(largeur: planche.image.width, hauteur: planche.image.height)

        guard budget.accepte(entree) else {
            throw ErreurDeTraduction.plancheTropLourde(
                octets: entree.octetsUneFoisDecodee,
                plafond: budget.octetsParPage
            )
        }

        guard let matrice = MatriceDePixels(planche.image) else {
            throw ErreurDeTraduction.plancheIllisible
        }

        try Task.checkCancellation()

        traductions += 1

        let retenues = try Self.retenir(
            detecteur.bulles(matrice),
            seuil: seuilDeConfiance,
            recouvrementMaximal: recouvrementMaximal
        )

        guard retenues.isEmpty == false else { return [] }

        let traduits = try moteur.traduire(retenues.map(\.texte), vers: reglages.langueCible)

        guard traduits.count == retenues.count else {
            throw ErreurDeTraduction.reponseIncoherente(
                attendus: retenues.count,
                recus: traduits.count
            )
        }

        return zip(retenues, traduits).map { bulle, texte in
            TraductionDeBulle(
                bulle: bulle,
                texteTraduit: texte,
                langueCible: reglages.langueCible,
                moteur: moteur.emplacement.choix
            )
        }
    }

    /// Bulles retenues parmi celles que la detection a rendues.
    ///
    /// Les cadres sont d abord tries par confiance decroissante, puis parcourus
    /// une fois : un cadre est retenu quand il ne recouvre aucun cadre deja
    /// retenu au dela du seuil. Le tri porte aussi sur la position, pour que
    /// deux cadres de meme confiance ne dependent pas de la stabilite du tri ni
    /// de l ordre de sortie de la detection, qu aucune ne promet.
    static func retenir(
        _ bulles: [BulleDeTexte],
        seuil: Double,
        recouvrementMaximal: Double
    ) -> [BulleDeTexte] {
        let candidates = bulles
            .filter { $0.confiance >= seuil }
            .sorted(by: laPlusSure)

        var retenues: [BulleDeTexte] = []

        for candidate in candidates {
            let recouvre = retenues.contains {
                $0.cadre.intersectionSurUnion(candidate.cadre) >= recouvrementMaximal
            }

            if recouvre == false {
                retenues.append(candidate)
            }
        }

        return retenues
    }

    /// Ordre de passage des candidates : la plus sure d abord, puis la position,
    /// qui rend l ordre total et donc le resultat reproductible.
    private static func laPlusSure(_ premiere: BulleDeTexte, _ seconde: BulleDeTexte) -> Bool {
        if premiere.confiance != seconde.confiance {
            return premiere.confiance > seconde.confiance
        }

        if premiere.cadre.ordonnee != seconde.cadre.ordonnee {
            return premiere.cadre.ordonnee < seconde.cadre.ordonnee
        }

        return premiere.cadre.abscisse < seconde.cadre.abscisse
    }
}
