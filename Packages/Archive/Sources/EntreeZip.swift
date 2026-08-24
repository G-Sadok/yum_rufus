import Foundation

//
// EntreeZip
//
// Description d une entree telle que l index central du ZIP l annonce.
//
// Toutes les valeurs viennent de l index central et jamais de l en tete local.
// C est une regle de survie du format : quand le drapeau de descripteur est
// pose, l en tete local porte des tailles et une somme de controle nulles, que
// seul l index central corrige. Un lecteur qui fait confiance a l en tete local
// rend des pages vides sur les archives produites en flux.
//

/// Une entree du conteneur ZIP, decrite par son index central.
struct EntreeZip: Sendable, Hashable {
    /// Chemin de l entree a l interieur de l archive.
    let nom: String

    /// Drapeaux generaux, dont le bit 0 signale le chiffrement.
    let drapeaux: UInt16

    /// Methode de compression, 0 pour stocke et 8 pour deflate.
    let methode: UInt16

    /// Somme de controle annoncee du contenu decompresse.
    let crcAttendu: UInt32

    /// Taille des octets stockes dans l archive.
    let tailleCompressee: UInt64

    /// Taille annoncee une fois decompresse.
    let tailleDecompressee: UInt64

    /// Position de l en tete local dans le fichier.
    let offsetEnTeteLocal: UInt64

    /// Indique que l entree est chiffree, ce que le lecteur ne prend pas en
    /// charge et ne prendra pas en charge en silence.
    var estChiffree: Bool {
        drapeaux & 0x0001 != 0
    }
}

/// Ce que la lecture de l index central rend.
struct ContenuZip: Sendable {
    let entrees: [EntreeZip]

    /// Commentaire global de l archive, ou vit le `ComicBookInfo` que la
    /// section 5.3 lit en secours des metadonnees.
    let commentaire: String?
}
