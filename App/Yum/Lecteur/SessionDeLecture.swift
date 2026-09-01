import Core
import DesignSystem
import Foundation
import ImagePipeline
import ReaderEngine
import Sources

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

    private let decodeur = DecodeurDePage()
    private let zone = TailleEnPixels(largeur: 2000, hauteur: 2600)

    /// Ouvre un fichier, archive ou dossier de pages.
    func ouvrir(_ url: URL, sens: SensDeLecture = .parDefaut) {
        fermer()

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
            pagination = PaginationEnPageSimple(nombreDePages: ouvert.nombrePages, sens: sens)

            afficherLaPageCourante()
        } catch {
            etat = .erreur(
                .erreur(
                    titre: Chaines.Lecteur.erreurTitre,
                    phrase: (error as? ErreurDeDocument)?.messageUtilisateur
                        ?? Chaines.Lecteur.erreurPhrase,
                    reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                        self?.ouvrir(url, sens: sens)
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
        document = nil
        titre = ""
        etat = .chargement

        if let acces {
            acces.stopAccessingSecurityScopedResource()
            self.acces = nil
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
