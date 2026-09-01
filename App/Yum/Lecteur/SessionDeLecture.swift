import Core
import DesignSystem
import Foundation
import ImagePipeline
import ReaderEngine
import Sources
import Storage

//
// SessionDeLecture
//
// Ouvre un fichier pose par l utilisateur, en lit les pages et les decode a la
// demande.
//
// Le document reste ouvert pendant toute la lecture. Les pages sont decodees a
// la demande par `CacheDePagesDecodees`, qui en garde une poignee autour de
// celle qu on regarde : le chapitre entier couterait cinquante quatre
// megaoctets par page, ce que la section 12 interdit.
//
// L acces au fichier passe par un signet de securite quand le systeme l exige.
// Sans lui, un fichier ouvert au premier lancement redeviendrait illisible au
// suivant, et l utilisateur croirait l application cassee.
//
// Ce que la lecture laisse derriere elle appartient a `TraceDeLecture`.
//

@MainActor
@Observable
final class SessionDeLecture {
    private(set) var etat: EtatDeLecteur = .chargement

    /// Nom du fichier ouvert, montre dans la barre superieure.
    private(set) var titre = ""

    /// Vrai quand un document est ouvert, ce qui pose le lecteur par dessus.
    var estOuvert: Bool {
        document != nil
    }

    private var document: (any DocumentLocal)?
    private var pagination = PaginationEnPageSimple(nombreDePages: 0, sens: .parDefaut)
    private var acces: URL?

    /// Chapitre lu, nul quand le fichier ne vient pas de la bibliotheque.
    private var chapitre: UUID?

    /// Vrai quand le chapitre se deroule au lieu de se paginer.
    private var estEnDefilement = false

    /// Sens de lecture du chapitre ouvert.
    ///
    /// Il sort d ici parce que la vue en a besoin : c est lui qui decide quelle
    /// fleche avance et quel balayage recule. La vue le prenait par defaut, et
    /// un manga se tournait donc a l envers.
    private(set) var sensCourant: SensDeLecture = .parDefaut

    /// Les pages decodees, dans les deux mises en page.
    ///
    /// Rien n est decode d avance au dela des voisines immediates : le ruban
    /// demande ce qui approche de l ecran, la pagination demande la page
    /// courante et celles d a cote. Un chapitre de deux cents pages ne coute
    /// donc jamais deux cents pages decodees.
    private let cache: CacheDePagesDecodees

    private let trace: TraceDeLecture
    private let reglages: MagasinDeReglages?

    /// Disposition des zones de toucher, lue a l ouverture du chapitre.
    private var zones = ReglageDesZonesDeToucher(lus: nil)

    /// Ouvre le chapitre suivant, et rend faux quand il n y en a pas.
    ///
    /// Pose apres la construction : l ouverture de chapitre a besoin du lecteur
    /// et le lecteur a besoin d elle, et deux dependances qui se referment ne
    /// se construisent pas d un seul tenant.
    var ouvrirLeChapitreSuivant: (@MainActor (UUID) async -> Bool)?

    /// Previent qu une lecture vient de se terminer.
    ///
    /// Les compteurs de non lus et la date de derniere lecture ont change en
    /// base. Sans ce signal, la grille et la fiche continueraient d afficher ce
    /// qu elles savaient avant la lecture.
    private let apresLecture: @MainActor () -> Void

    init(
        progression: MagasinDeProgression? = nil,
        reglages: MagasinDeReglages? = nil,
        apresLecture: @escaping @MainActor () -> Void = {}
    ) {
        trace = TraceDeLecture(progression: progression)
        self.reglages = reglages
        self.apresLecture = apresLecture
        cache = CacheDePagesDecodees(zone: Self.zoneDeDecodage)

        cache.quandUnePageArrive = { [weak self] rang in
            self?.poserSiCourante(rang)
        }
        cache.quandUnePageEchoue = { [weak self] rang in
            self?.signalerLEchecDeDecodage(rang)
        }
    }

    /// Taille de decodage d une page, celle d une planche a l ecran.
    private static let zoneDeDecodage = TailleEnPixels(largeur: 2000, hauteur: 2600)

    /// Ouvre un fichier, archive ou dossier de pages.
    ///
    /// - Parameters:
    ///   - url: fichier ou dossier a lire.
    ///   - sens: sens de lecture, celui de la serie quand elle en impose un.
    ///   - chapitre: chapitre de la bibliotheque que ce fichier porte, nul
    ///     quand le fichier vient du systeme et n a pas de ligne en base. Il
    ///     decide si la lecture laisse une trace.
    func ouvrir(_ url: URL, sens: SensDeLecture = .parDefaut, chapitre: UUID? = nil) {
        fermer()

        self.chapitre = chapitre

        let autorise = url.startAccessingSecurityScopedResource()

        if autorise {
            acces = url
        }

        do {
            // Le format decide, jamais le contenu. Le choix du lecteur est
            // celui des sources : le ZIP, le TAR et le PDF passent par le meme
            // selecteur, et une seconde copie aurait diverge au premier format
            // ajoute.
            let ouvert = try LecteurDeConteneur.ouvrir(url)

            document = ouvert
            cache.ouvrir(ouvert)
            titre = url.deletingPathExtension().lastPathComponent
            // Le sens haut bas impose la mise en page continue, c est le
            // modele de Core qui le dit et non le lecteur.
            sensCourant = sens
            estEnDefilement = sens.miseEnPageImposee == .continuVertical
            zones = ReglageDesZonesDeToucher(lus: reglages)
            pagination = PaginationEnPageSimple(
                nombreDePages: ouvert.nombrePages,
                sens: sens,
                index: trace.pageDeReprise(chapitre)
            )

            afficherLaPageCourante()
        } catch {
            etat = .erreur(
                .erreur(
                    titre: Chaines.Lecteur.erreurTitre,
                    phrase: (error as? ErreurDeDocument)?.messageUtilisateur
                        ?? Chaines.Lecteur.erreurPhrase,
                    reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                        self?.ouvrir(url, sens: sens, chapitre: chapitre)
                    },
                    repli: ActionDEtat(libelle: Chaines.Lecteur.fermer) { [weak self] in
                        self?.fermer()
                    }
                )
            )

            NSLog("Lecture : %@", String(describing: error))
        }
    }

    func fermer() {
        // La position part avant que le document se referme : apres, la
        // pagination est remise a zero et il n y aurait plus rien a ecrire.
        trace.enregistrer(chapitre: chapitre, page: pageEnregistrable)

        let lisaitUnChapitre = chapitre != nil

        document = nil
        titre = ""
        chapitre = nil
        estEnDefilement = false
        sensCourant = .parDefaut
        cache.vider()
        etat = .chargement

        if let acces {
            acces.stopAccessingSecurityScopedResource()
            self.acces = nil
        }

        if lisaitUnChapitre {
            apresLecture()
        }
    }

    var commandes: CommandesDeLecteur {
        CommandesDeLecteur(
            pageSuivante: { [weak self] in
                self?.deplacer(.pageSuivante)
            },
            pagePrecedente: { [weak self] in
                self?.deplacer(.pagePrecedente)
            },
            fermer: { [weak self] in
                self?.fermer()
            },
            appuyer: { [weak self] abscisse, ordonnee in
                self?.appuyer(abscisse: abscisse, ordonnee: ordonnee) ?? false
            }
        )
    }

    // MARK: Zones de toucher

    /// Traite un appui, et dit s il a tourne une page.
    ///
    /// Rend faux en defilement continu : le doigt y sert a faire glisser le
    /// ruban, et tourner une page sous un doigt qui defile serait un saut que
    /// personne n a demande.
    private func appuyer(abscisse: Double, ordonnee: Double) -> Bool {
        guard estEnDefilement == false, pagination.estVide == false else { return false }

        let intention = zones.intention(
            abscisse: abscisse,
            ordonnee: ordonnee,
            sens: sensCourant
        )

        guard intention != .aucune else { return false }

        deplacer(intention)

        return true
    }

    var libelles: LibellesDeLecteur {
        LibellesDeLecteur(
            titre: titre,
            sousTitre: sousTitre,
            fermer: Chaines.Lecteur.fermer,
            pagePrecedente: Chaines.Lecteur.pagePrecedente,
            pageSuivante: Chaines.Lecteur.pageSuivante
        )
    }

    private var sousTitre: String {
        pagination.estVide ? "" : positionCourante.compteur
    }

    private func deplacer(_ intention: IntentionDeNavigation) {
        guard pagination.appliquer(intention) else {
            // La pagination refuse de sortir du chapitre. Une page suivante
            // demandee sur la derniere ouvre donc le chapitre d apres, ce qui
            // evite de refermer le lecteur entre deux chapitres.
            if intention == .pageSuivante, pagination.estALaDernierePage {
                enchainerLeChapitreSuivant()
            }

            return
        }

        afficherLaPageCourante()

        // A chaque page et non a cadence fixe : une page tournee est le seul
        // moment ou la position change en lecture paginee, et l ecriture est
        // une seule transaction.
        trace.enregistrer(chapitre: chapitre, page: pageEnregistrable)
    }

    /// Page a enregistrer, nulle quand aucun document n est ouvert.
    private var pageEnregistrable: Int? {
        pagination.estVide ? nil : pagination.index
    }

    private var positionCourante: PositionDansLeChapitre {
        PositionDansLeChapitre(
            numero: pagination.numeroDePage,
            total: pagination.nombreDePages
        )
    }

    // MARK: Defilement continu

    /// Page du ruban a ce rang, et son decodage quand il n a pas eu lieu.
    ///
    /// Appelee pendant le rendu de la pile. Elle rend tout de suite ce qu elle
    /// a, et l observation reveille le ruban quand le decodage aboutit.
    func page(auRang rang: Int) -> ImageDeLecteur? {
        if let deja = cache.page(rang) {
            return deja
        }

        // Les deux pages suivantes partent avec celle ci. Sans elles, chaque
        // page decodee changerait la hauteur reservee juste sous le pouce, et
        // le defilement sauterait a chaque fois.
        for voisine in rang...(rang + Self.portee) {
            cache.demander(voisine)
        }

        return nil
    }

    /// Signale la page qui vient d apparaitre dans le ruban. La progression
    /// suit le defilement comme elle suit la pagination.
    func pageAtteinte(_ rang: Int) {
        guard estEnDefilement, pagination.allerALaPage(rang) else { return }

        cache.elaguer(autourDe: rang, portee: Self.portee)

        etat = .defilement(nombreDePages: pagination.nombreDePages, position: positionCourante)
        trace.enregistrer(chapitre: chapitre, page: pageEnregistrable)
    }

    /// Montre l echec quand c est la page regardee qui a refuse de se decoder.
    ///
    /// Une voisine qui echoue ne dit rien : elle sera redemandee si le lecteur
    /// y arrive, et couvrir la page lue d une erreur pour une page qu il n a
    /// pas encore atteinte serait faux.
    private func signalerLEchecDeDecodage(_ rang: Int) {
        guard estEnDefilement == false, rang == pagination.index else { return }

        etat = .erreur(
            .erreur(
                titre: Chaines.Lecteur.erreurTitre,
                phrase: Chaines.Lecteur.erreurPhrase,
                reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                    self?.afficherLaPageCourante()
                },
                repli: ActionDEtat(libelle: Chaines.Lecteur.fermer) { [weak self] in
                    self?.fermer()
                }
            )
        )
    }

    /// Passe au chapitre suivant de la serie, quand il en reste un.
    private func enchainerLeChapitreSuivant() {
        guard let chapitre, let ouvrirLeChapitreSuivant else { return }

        Task { await ouvrirLeChapitreSuivant(chapitre) }
    }

    private func afficherLaPageCourante() {
        guard document != nil, pagination.estVide == false else {
            etat = .chargement

            return
        }

        // En defilement, aucune page n est decodee ici : le ruban demande ce
        // qui approche de l ecran, et decoder d avance couterait le chapitre
        // entier pour trois pages visibles.
        guard estEnDefilement == false else {
            etat = .defilement(nombreDePages: pagination.nombreDePages, position: positionCourante)

            return
        }

        // La page courante et ses deux voisines. Le decodage part hors du fil
        // principal : une page fait environ cinquante quatre megaoctets en
        // pleine resolution, et la decoder sous le doigt figeait l interface a
        // chaque page tournee.
        for voisine in (pagination.index - Self.portee)...(pagination.index + Self.portee) {
            cache.demander(voisine)
        }

        cache.elaguer(autourDe: pagination.index, portee: Self.portee)

        if let deja = cache.page(pagination.index) {
            etat = .page(deja, position: positionCourante)
        } else if unePageEstAffichee == false {
            etat = .chargement
        }

        // Quand une page est deja a l ecran, elle y reste le temps que la
        // suivante arrive. La remplacer par un indicateur ferait clignoter le
        // lecteur a chaque tour, y compris quand l attente est d une image.
    }

    /// Vrai quand une planche est deja posee a l ecran.
    private var unePageEstAffichee: Bool {
        if case .page = etat {
            return true
        }

        return false
    }

    /// Nombre de pages prechargees et gardees de part et d autre de la page
    /// courante.
    private static let portee = 2

    /// Pose la page qui vient d etre decodee, si c est celle qu on regarde.
    private func poserSiCourante(_ rang: Int) {
        guard estEnDefilement == false,
              rang == pagination.index,
              let page = cache.page(rang)
        else {
            return
        }

        etat = .page(page, position: positionCourante)
    }
}
