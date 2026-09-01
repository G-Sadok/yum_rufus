import Core
import DesignSystem
import Foundation
import ImagePipeline

//
// CacheDePagesDecodees
//
// Les pages du chapitre ouvert, decodees a la demande et gardees le temps
// qu elles servent.
//
// Le decodage part hors du fil principal. Une page fait environ cinquante
// quatre megaoctets en pleine resolution, et la decoder sous le doigt figeait
// l interface a chaque page tournee.
//
// Le cache est borne. Sans cela il garderait le chapitre entier decode : une
// page pese une quinzaine de megaoctets a la taille ou elle est posee, et deux
// cents pages depasseraient de loin le budget memoire de la section 12.
//

@MainActor
@Observable
final class CacheDePagesDecodees {
    /// Pages deja decodees, par rang.
    private(set) var pages: [Int: ImageDeLecteur] = [:]

    /// Rangs dont le decodage court.
    ///
    /// Ignoree par l observation : elle est ecrite pendant le rendu d une vue,
    /// et la faire observer relancerait ce rendu a chaque demande.
    @ObservationIgnored private var enCours: Set<Int> = []

    /// Previent qu une page vient d arriver.
    var quandUnePageArrive: (@MainActor (Int) -> Void)?

    /// Previent qu une page a refuse de se decoder.
    var quandUnePageEchoue: (@MainActor (Int) -> Void)?

    private let zone: TailleEnPixels
    private var document: (any DocumentLocal)?
    private var nombreDePages = 0

    init(zone: TailleEnPixels) {
        self.zone = zone
    }

    /// Prend un document et oublie le precedent.
    func ouvrir(_ document: any DocumentLocal) {
        vider()

        self.document = document
        nombreDePages = document.nombrePages
    }

    func vider() {
        document = nil
        nombreDePages = 0
        pages = [:]
        enCours = []
    }

    /// Page a ce rang, nulle tant qu elle n est pas decodee.
    func page(_ rang: Int) -> ImageDeLecteur? {
        pages[rang]
    }

    /// Demande le decodage d un rang, s il n a pas deja eu lieu.
    func demander(_ rang: Int) {
        guard let document,
              rang >= 0,
              rang < nombreDePages,
              pages[rang] == nil,
              enCours.contains(rang) == false
        else {
            return
        }

        enCours.insert(rang)

        Task { [weak self, zone] in
            let decodee = await Self.decoder(document, rang: rang, dans: zone)

            guard let self else { return }

            enCours.remove(rang)

            if let decodee {
                pages[rang] = decodee
                quandUnePageArrive?(rang)
            } else {
                quandUnePageEchoue?(rang)
            }
        }
    }

    /// Oublie les pages trop loin de celle qu on regarde.
    ///
    /// La portee couvre exactement ce qui est precharge. Elaguer plus court
    /// jetterait une page qui vient d etre demandee.
    func elaguer(autourDe rang: Int, portee: Int) {
        pages = pages.filter { abs($0.key - rang) <= portee }
    }

    /// Decode une page hors du fil principal.
    ///
    /// Le decodeur est construit dans la tache et n en sort pas : le faire
    /// traverser obligerait a le rendre partageable alors qu il ne sert que la,
    /// le temps d une page.
    private nonisolated static func decoder(
        _ document: any DocumentLocal,
        rang: Int,
        dans zone: TailleEnPixels
    ) async -> ImageDeLecteur? {
        await Task.detached(priority: .userInitiated) {
            do {
                let reference = try document.referencePage(rang)
                let octets = try document.donneesPage(reference)
                let page = try DecodeurDePage().decoder(octets, nom: reference.nom, dans: zone)

                return ImageDeLecteur(
                    image: page.image,
                    largeur: page.tailleDecodee.largeur,
                    hauteur: page.tailleDecodee.hauteur
                )
            } catch {
                NSLog("Decodage de page : %@", String(describing: error))

                return nil
            }
        }.value
    }
}
