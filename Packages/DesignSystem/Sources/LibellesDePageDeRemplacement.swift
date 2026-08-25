import Core
import Foundation

//
// Textes de la page de remplacement du lecteur, tableau 6.4 de DESIGN-SPEC.
//
// Le document donne une seule ligne pour le lecteur pagine, celle du fichier
// que Yum ne sait pas ouvrir. Elle ne couvre pas seule les quatre causes que
// la chaine d images distingue, et la regle de fin de section 6.4 est claire :
// le nom cite dans une erreur est toujours la valeur reelle. Une page en JPEG
// XL sur un appareil trop ancien et une page tronquee par un telechargement
// interrompu ne peuvent donc pas recevoir la meme phrase, la premiere nomme le
// format, la seconde nomme l abime.
//
// Les deux actions ne changent pas selon la cause. Sauter la page est toujours
// possible, signaler le fichier l est aussi, et aucune des deux n est
// Reessayer : redecoder les memes octets donnerait le meme echec.
//

/// Motifs de texte d une page de remplacement, pris dans le catalogue.
public struct LibellesDePageDeRemplacement: Sendable, Equatable {
    /// Motif du titre, avec le numero de page, `La page %lld est illisible`.
    public let pageIllisible: String

    /// Phrase employee quand les octets ne designent aucun format connu.
    public let formatInconnu: String

    /// Phrase employee quand l appareil ne sait pas lire ce format, avec `%@`.
    public let formatNonPrisEnCharge: String

    /// Phrase employee quand le contenu du fichier est abime, avec `%@`.
    public let contenuIllisible: String

    /// Libelle de l action qui passe a la page suivante.
    public let sauterLaPage: String

    /// Libelle de l action qui rapporte le fichier.
    public let signalerLeFichier: String

    public init(
        pageIllisible: String,
        formatInconnu: String,
        formatNonPrisEnCharge: String,
        contenuIllisible: String,
        sauterLaPage: String,
        signalerLeFichier: String
    ) {
        self.pageIllisible = pageIllisible
        self.formatInconnu = formatInconnu
        self.formatNonPrisEnCharge = formatNonPrisEnCharge
        self.contenuIllisible = contenuIllisible
        self.sauterLaPage = sauterLaPage
        self.signalerLeFichier = signalerLeFichier
    }
}

/// Assemblage des textes d une page de remplacement.
public enum TexteDePageDeRemplacement {
    /// Titre, qui nomme la page reellement en cause.
    public static func titre(
        de page: PageDeRemplacement,
        libelles: LibellesDePageDeRemplacement
    ) -> String {
        String(format: libelles.pageIllisible, page.numeroDePage)
    }

    /// Phrase, qui nomme la cause reelle et le format quand il est connu.
    ///
    /// Un contenu abime dont le format n a pas pu etre nomme retombe sur la
    /// phrase du format inconnu : une phrase a trou vaut mieux qu un trou dans
    /// une phrase.
    public static func phrase(
        de page: PageDeRemplacement,
        libelles: LibellesDePageDeRemplacement
    ) -> String {
        switch page.cause {
        case let .formatNonPrisEnCharge(format):
            return String(format: libelles.formatNonPrisEnCharge, format.nomAffiche)

        case .formatInconnu:
            return libelles.formatInconnu

        case .contenuIllisible, .dimensionsIllisibles:
            guard let format = page.format else { return libelles.formatInconnu }

            return String(format: libelles.contenuIllisible, format.nomAffiche)
        }
    }
}
