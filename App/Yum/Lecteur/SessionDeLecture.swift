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
// Le document reste ouvert pendant toute la lecture, et seule la page affichee
// est decodee. Charger le chapitre entier couterait cinquante quatre megaoctets
// par page, ce que la section 12 interdit et que le decodage sous echantillonne
// evite deja page par page.
//
// L acces au fichier passe par un signet de securite quand le systeme l exige.
// Sans lui, un fichier ouvert au premier lancement redeviendrait illisible au
// suivant, et l utilisateur croirait l application cassee.
//
// La progression est enregistree quand le chapitre ouvert est un chapitre de la
// bibliotheque. Un fichier pose par le systeme n en est pas un : il n a pas de
// ligne en base, donc rien a mettre a jour, et le lecteur ne s en plaint pas.
//

@MainActor
@Observable
final class SessionDeLecture {
    private(set) var etat: EtatDeLecteur = .chargement

    /// Nom du fichier ouvert, montre dans la barre superieure.
    private(set) var titre = ""

    /// Vrai quand un document est ouvert, ce qui pose le lecteur par dessus.
    var estOuvert: Bool { document != nil }

    private var document: (any DocumentLocal)?
    private var pagination = PaginationEnPageSimple(nombreDePages: 0, sens: .parDefaut)
    private var acces: URL?

    /// Chapitre lu, nul quand le fichier ne vient pas de la bibliotheque.
    private var chapitre: UUID?

    private let progression: MagasinDeProgression?

    /// Previent qu une lecture vient de se terminer.
    ///
    /// Les compteurs de non lus et la date de derniere lecture ont change en
    /// base. Sans ce signal, la grille et la fiche continueraient d afficher ce
    /// qu elles savaient avant la lecture.
    private let apresLecture: @MainActor () -> Void

    init(
        progression: MagasinDeProgression? = nil,
        apresLecture: @escaping @MainActor () -> Void = {}
    ) {
        self.progression = progression
        self.apresLecture = apresLecture
    }

    private let decodeur = DecodeurDePage()
    private let zone = TailleEnPixels(largeur: 2000, hauteur: 2600)

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
            titre = url.deletingPathExtension().lastPathComponent
            pagination = PaginationEnPageSimple(
                nombreDePages: ouvert.nombrePages,
                sens: sens,
                index: pageDeReprise(chapitre)
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
        enregistrerLaPosition()

        let lisaitUnChapitre = chapitre != nil

        document = nil
        titre = ""
        chapitre = nil
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
            }
        )
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
        guard pagination.estVide == false else { return "" }

        return "\(pagination.numeroDePage) / \(pagination.nombreDePages)"
    }

    private func deplacer(_ intention: IntentionDeNavigation) {
        guard pagination.appliquer(intention) else { return }

        afficherLaPageCourante()

        // A chaque page et non a cadence fixe : une page tournee est le seul
        // moment ou la position change en lecture paginee, et l ecriture est
        // une seule transaction.
        enregistrerLaPosition()
    }

    /// Page ou reprendre, la premiere quand le chapitre est neuf ou inconnu.
    private func pageDeReprise(_ chapitre: UUID?) -> Int {
        guard let chapitre, let progression else { return 0 }

        return (try? progression.position(duChapitre: chapitre))?.pageIndex ?? 0
    }

    /// Ecrit la position courante, quand il y a un chapitre a mettre a jour.
    ///
    /// Un echec n interrompt pas la lecture et ne remonte a personne. La
    /// sauvegarde revient a chaque page, et une alerte a chaque echeance
    /// mettrait un message par dessus la page de manga.
    private func enregistrerLaPosition() {
        guard let chapitre, let progression, pagination.estVide == false else { return }

        do {
            try progression.enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: pagination.index)
            )
        } catch {
            NSLog("Progression : %@", String(describing: error))
        }
    }

    /// Decode la page courante et la pose a l ecran.
    private func afficherLaPageCourante() {
        guard let document, pagination.estVide == false else {
            etat = .chargement

            return
        }

        do {
            let reference = try document.referencePage(pagination.index)
            let octets = try document.donneesPage(reference)
            let page = try decodeur.decoder(octets, nom: reference.nom, dans: zone)

            etat = .page(
                ImageDeLecteur(
                    image: page.image,
                    largeur: page.tailleDecodee.largeur,
                    hauteur: page.tailleDecodee.hauteur
                ),
                position: PositionDansLeChapitre(
                    numero: pagination.numeroDePage,
                    total: pagination.nombreDePages
                )
            )
        } catch {
            etat = .erreur(
                .erreur(
                    titre: Chaines.Lecteur.erreurTitre,
                    phrase: (error as? ErreurDeDecodage)?.messageUtilisateur
                        ?? Chaines.Lecteur.erreurPhrase,
                    reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                        self?.afficherLaPageCourante()
                    },
                    repli: ActionDEtat(libelle: Chaines.Lecteur.fermer) { [weak self] in
                        self?.fermer()
                    }
                )
            )

            NSLog("Lecture : %@", String(describing: error))
        }
    }
}
