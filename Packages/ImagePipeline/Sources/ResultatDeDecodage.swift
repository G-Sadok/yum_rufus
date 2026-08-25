import Core
import Foundation

//
// ResultatDeDecodage
//
// Ce que la chaine d images rend au lecteur pour une page : la page, ou de quoi
// afficher a sa place.
//
// La distinction est volontairement portee par le type de retour et non par une
// erreur levee. Une page illisible au milieu d un chapitre n est pas un echec de
// l ouverture du chapitre : les autres pages restent lisibles, la position reste
// valide, et l utilisateur doit pouvoir continuer. Une erreur levee pousserait
// chaque appelant a decider seul s il arrete tout ou s il continue, et le
// premier qui choisirait mal ferait tomber un chapitre entier pour une page.
//

/// Page decodee, ou page de remplacement quand le decodage a echoue.
public enum ResultatDeDecodage: Sendable {
    case page(ImageDePage)
    case remplacement(PageDeRemplacement)

    /// Page decodee, nil quand c est un remplacement.
    public var image: ImageDePage? {
        guard case let .page(image) = self else { return nil }

        return image
    }

    /// Remplacement, nil quand la page a ete decodee.
    public var remplacementEventuel: PageDeRemplacement? {
        guard case let .remplacement(remplacement) = self else { return nil }

        return remplacement
    }
}

extension DecodeurDePage {
    /// Decode une page, ou dit pourquoi elle est remplacee.
    ///
    /// C est l entree que le lecteur emploie. Elle ne leve jamais : tout echec
    /// devient une page de remplacement qui nomme sa cause, conformement au
    /// tableau 6.4 de DESIGN-SPEC.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page.
    ///   - nom: nom de l entree dans le chapitre.
    ///   - numeroDePage: numero affiche, celui que compte l utilisateur.
    ///   - zone: zone d affichage en pixels reels.
    ///   - budget: plafond memoire de la page decodee.
    public func decoderOuRemplacer(
        _ donnees: Data,
        nom: String,
        numeroDePage: Int,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage = .parDefaut
    ) -> ResultatDeDecodage {
        // Le format retenu pour la phrase est celui des octets, jamais celui de
        // l extension. Une archive de scans porte regulierement des pages WebP
        // nommees `.jpg`, et nommer JPEG une page WebP dans un message d erreur
        // enverrait l utilisateur chercher au mauvais endroit.
        let format = FormatDImage.depuis(octets: donnees)

        func remplacer(_ cause: PageDeRemplacement.Cause) -> ResultatDeDecodage {
            .remplacement(PageDeRemplacement(
                numeroDePage: numeroDePage,
                nomDeLEntree: nom,
                cause: cause
            ))
        }

        if let refus = CauseDeRemplacement.refusAvantDecodage(format: format) {
            return remplacer(refus)
        }

        do {
            return try .page(decoder(donnees, nom: nom, dans: zone, budget: budget))
        } catch {
            return remplacer(CauseDeRemplacement.apresEchec(error, format: format))
        }
    }
}

/// Traduction d un echec de decodage en cause de page de remplacement.
///
/// Isolee du decodeur pour rester verifiable : la prise en charge d un format
/// depend de la version du systeme, et un test ne peut pas la faire varier sur
/// la machine qui l execute.
enum CauseDeRemplacement {
    /// Cause connue avant meme d essayer de decoder, nil quand rien ne s y oppose.
    ///
    /// Un format que le projet connait mais que cet appareil ne sait pas lire
    /// est ecarte des ici. Le message nomme alors le format, au lieu de parler
    /// d un contenu illisible, ce qui serait faux : le fichier est intact.
    static func refusAvantDecodage(
        format: FormatDImage?,
        lisibles: Set<FormatDImage> = SupportDesFormats.lisibles
    ) -> PageDeRemplacement.Cause? {
        guard let format, lisibles.contains(format) == false else { return nil }

        return .formatNonPrisEnCharge(format)
    }

    /// Cause deduite de l erreur levee par le decodeur.
    static func apresEchec(_ erreur: Error, format: FormatDImage?) -> PageDeRemplacement.Cause {
        guard let erreur = erreur as? ErreurDeDecodage else {
            return .contenuIllisible(format)
        }

        switch erreur {
        case .formatInconnu:
            // Des octets qu Image I/O refuse alors que la signature etait
            // reconnue decrivent un fichier abime, pas un format inconnu.
            return format.map { .contenuIllisible($0) } ?? .formatInconnu
        case .dimensionsIllisibles:
            return .dimensionsIllisibles(format)
        case .decodageImpossible:
            return .contenuIllisible(format)
        }
    }
}
