import Core
import Foundation

//
// ReserveDeZoom
//
// Detentrice unique de la pleine resolution.
//
// La regle de la section 6.1 tient en une phrase : la pleine resolution
// n existe que pendant un geste de zoom, et disparait a la fin du geste. Pour
// qu elle soit verifiable et non seulement esperee, une seule porte y mene, et
// c est cet acteur. `DecodeurDePage.decoderEnPleineResolution` reste interne au
// paquet, aucun appelant exterieur ne peut donc allouer 54 Mo sans passer ici.
//
// L acteur ne retient qu une page a la fois. Commencer un geste sur une autre
// page libere la precedente avant d allouer la suivante.
//

/// Pleine resolution d une page, retenue pour la duree d un geste de zoom.
public actor ReserveDeZoom {
    private let decodeur: DecodeurDePage
    private var pageRetenue: ImageDePage?

    public init(decodeur: DecodeurDePage = DecodeurDePage()) {
        self.decodeur = decodeur
    }

    /// Vrai tant qu un geste de zoom est en cours.
    public var estActif: Bool {
        pageRetenue != nil
    }

    /// Octets que la reserve retient a cet instant. Zero hors geste.
    public var octetsRetenus: Int {
        pageRetenue?.octetsEnMemoire ?? 0
    }

    /// Page en pleine resolution du geste en cours, s il y en a un.
    public var pageEnCours: ImageDePage? {
        pageRetenue
    }

    /// Charge la pleine resolution au debut d un geste de zoom.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page.
    ///   - nom: nom de l entree, repris dans les erreurs.
    /// - Throws: `ErreurDeDecodage` quand le fichier n est pas lisible. La
    ///   reserve reste alors vide plutot que de garder le geste precedent.
    @discardableResult
    public func commencer(sur donnees: Data, nom: String) throws -> ImageDePage {
        // Libere avant de decoder, sans quoi deux pleines resolutions se
        // croisent en memoire le temps du decodage de la seconde.
        pageRetenue = nil

        let page = try decodeur.decoderEnPleineResolution(donnees, nom: nom)
        pageRetenue = page

        return page
    }

    /// Libere la pleine resolution a la fin du geste.
    ///
    /// Appelable plusieurs fois de suite sans effet supplementaire, ce dont un
    /// geste interrompu par un changement de page a besoin.
    public func terminer() {
        pageRetenue = nil
    }
}
