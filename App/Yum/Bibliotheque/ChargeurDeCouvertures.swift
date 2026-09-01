import Core
import DesignSystem
import Foundation
import ImagePipeline
import Sources
import Storage

//
// ChargeurDeCouvertures
//
// Fabrique la couverture d une serie et la garde.
//
// Un dossier local ne publie pas d image de couverture : il n a que des
// chapitres. La couverture est donc la premiere page du premier chapitre,
// decodee une fois a la taille d une carte et gardee ensuite.
//
// Le decodage est sous echantillonne, comme celui du lecteur. Une page fait
// environ cinquante quatre megaoctets en pleine resolution, et une grille de
// vingt cartes en pleine resolution demanderait un gigaoctet pour afficher des
// images de deux cent soixante pixels de large.
//
// Il ne charge que ce qu on lui demande, et une grille paresseuse ne demande
// que ses cartes visibles. Une bibliotheque de deux cents series ne decode donc
// pas deux cents archives au premier affichage.
//

@MainActor
@Observable
final class ChargeurDeCouvertures {
    /// Couvertures deja decodees, par serie.
    private(set) var couvertures: [UUID: ImageDeLecteur] = [:]

    /// Series dont le decodage court.
    ///
    /// Ignoree par l observation : elle est ecrite pendant le rendu d une
    /// carte, et la faire observer relancerait ce rendu a chaque demande.
    ///
    /// Une serie en sort des que sa tentative echoue. Y laisser un echec
    /// condamnerait la carte pour toute la session, alors que la cause la plus
    /// probable est que les sources n etaient pas encore reconstruites au
    /// premier rendu de la grille.
    @ObservationIgnored private var traitees: Set<UUID> = []

    private let resolution: MagasinDeResolutionDeChapitre?
    private let sources: RegistreDesSourcesVivantes

    init(resolution: MagasinDeResolutionDeChapitre?, sources: RegistreDesSourcesVivantes) {
        self.resolution = resolution
        self.sources = sources
    }

    /// Couverture d une serie, et son decodage quand il n a pas encore eu lieu.
    ///
    /// Appelee pendant le rendu d une carte. Elle rend tout de suite ce qu elle
    /// a, et l observation reveille la grille quand le decodage aboutit.
    func couverture(_ serie: UUID) -> ImageDeLecteur? {
        if let deja = couvertures[serie] {
            return deja
        }

        guard traitees.contains(serie) == false else {
            return nil
        }

        traitees.insert(serie)

        Task { await charger(serie) }

        return nil
    }

    /// Oublie tout, quand la bibliotheque a change sous les cartes.
    func vider() {
        couvertures = [:]
        traitees = []
    }

    private func charger(_ serie: UUID) async {
        guard let resolution,
              let adresse = try? resolution.adresseDuPremierChapitre(deLaSerie: serie),
              let fichier = await sources.fichier(de: adresse),
              let image = await Self.premierePage(de: fichier)
        else {
            traitees.remove(serie)

            return
        }

        couvertures[serie] = image
    }

    /// Decode la premiere page d un chapitre, hors du fil principal.
    ///
    /// Le document et le decodeur sont construits dans la tache et n en sortent
    /// pas : les faire traverser obligerait a les rendre partageables alors
    /// qu ils ne servent qu ici, le temps d une page.
    private nonisolated static func premierePage(de fichier: URL) async -> ImageDeLecteur? {
        await Task.detached(priority: .utility) {
            do {
                let document = try LecteurDeConteneur.ouvrir(fichier)

                guard document.nombrePages > 0 else { return nil }

                let reference = try document.referencePage(0)
                let octets = try document.donneesPage(reference)
                let page = try DecodeurDePage().decoder(
                    octets,
                    nom: reference.nom,
                    dans: zoneDeCouverture
                )

                return ImageDeLecteur(
                    image: page.image,
                    largeur: page.tailleDecodee.largeur,
                    hauteur: page.tailleDecodee.hauteur
                )
            } catch {
                NSLog("Couverture : %@", String(describing: error))

                return nil
            }
        }.value
    }

    /// Taille de decodage d une couverture.
    ///
    /// Deux fois la plus grande carte de la grille, pour tenir sur un ecran a
    /// deux points par pixel sans decoder davantage.
    private nonisolated static let zoneDeCouverture = TailleEnPixels(
        largeur: Int(Jetons.CarteDeSerie.largeurMaximale * 2),
        hauteur: Int(Jetons.CarteDeSerie.largeurMaximale * 2 / Jetons.CarteDeSerie.ratio)
    )
}
