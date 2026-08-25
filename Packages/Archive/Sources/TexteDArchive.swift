import Foundation

//
// TexteDArchive
//
// Conversion des octets d un champ d archive en texte.
//
// Un nom d entree n est pas garanti en UTF 8. Le format TAR est anterieur a
// l unicode et n a jamais impose d encodage ; les archives produites sous
// Windows ou sous d anciens systemes portent couramment des noms en latin 1.
//
// La conversion tente donc l UTF 8, puis retombe sur le latin 1, qui accepte
// n importe quelle suite d octets. Une page nommee "chapitre-ete.jpg" reste
// donc lisible et surtout retrouvable, la ou une conversion UTF 8 stricte
// l aurait fait disparaitre de la liste, et une conversion avec remplacement
// aurait produit un nom que la lecture ne saurait plus rapprocher de l entree.
//

enum TexteDArchive {
    /// Rend le texte porte par des octets de champ d archive.
    ///
    /// - Returns: `nil` seulement si aucun encodage ne s applique, ce qui ne se
    ///   produit pas avec le latin 1 mais reste exprime plutot que suppose.
    static func lire(_ octets: some DataProtocol) -> String? {
        let donnees = Data(octets)

        return String(bytes: donnees, encoding: .utf8)
            ?? String(bytes: donnees, encoding: .isoLatin1)
    }
}
