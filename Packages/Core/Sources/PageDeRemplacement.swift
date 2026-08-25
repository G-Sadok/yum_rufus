import Foundation

//
// PageDeRemplacement
//
// Ce que le lecteur affiche a la place d une page qu il n a pas pu decoder.
//
// La regle vient du tableau 6.4 de DESIGN-SPEC : une erreur nomme sa cause
// reelle et donne une sortie. Un chapitre qui contient une page illisible ne
// doit ni s arreter, ni afficher un rectangle vide que l utilisateur prendrait
// pour une page blanche du scan.
//
// Le type ne porte aucun texte. Il porte les faits, numero de page, nom de
// l entree et cause, et la couche vue en compose la phrase avec le catalogue
// de chaines. Sans cela, la traduction de l application supposerait de
// traduire un paquet metier.
//

/// Page substituee a une page que la chaine d images n a pas su decoder.
public struct PageDeRemplacement: Sendable, Hashable {
    /// Pourquoi la page n a pas pu etre decodee.
    public enum Cause: Sendable, Hashable {
        /// Le format est reconnu et pris en charge par le projet, mais cet
        /// appareil ne sait pas le lire.
        ///
        /// C est le cas d un format arrive avec une version du systeme plus
        /// recente que celle de l appareil. La phrase peut donc nommer le
        /// format, ce que l utilisateur peut reporter tel quel.
        case formatNonPrisEnCharge(FormatDImage)

        /// Les octets ne correspondent a aucun format connu.
        case formatInconnu

        /// Le format est lisible, le contenu ne l est pas.
        ///
        /// Fichier tronque par un telechargement interrompu, archive abimee.
        case contenuIllisible(FormatDImage?)

        /// L en tete est la, mais il n annonce aucune dimension exploitable.
        case dimensionsIllisibles(FormatDImage?)
    }

    /// Numero affiche de la page, celui que compte l utilisateur, a partir de 1.
    public let numeroDePage: Int

    /// Nom de l entree dans le chapitre, repris dans les journaux et le rapport.
    public let nomDeLEntree: String

    /// Cause de la substitution.
    public let cause: Cause

    public init(numeroDePage: Int, nomDeLEntree: String, cause: Cause) {
        self.numeroDePage = numeroDePage
        self.nomDeLEntree = nomDeLEntree
        self.cause = cause
    }

    /// Format en cause quand il a pu etre nomme.
    public var format: FormatDImage? {
        switch cause {
        case let .formatNonPrisEnCharge(format):
            format
        case .formatInconnu:
            nil
        case let .contenuIllisible(format), let .dimensionsIllisibles(format):
            format
        }
    }
}
