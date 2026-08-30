import Core
import Foundation
@testable import Intelligence

//
// TraducteursDeTest
//
// Detections et moteurs synthetiques, dont la sortie exacte est connue.
//
// Aucune assertion utile ne porte sur le lecteur de texte du systeme ni sur un
// service distant. Les proprietes que la fonctionnalite promet ne portent
// pourtant pas sur eux : le seuil de confiance, la fusion des cadres, l ordre de
// lecture, le cache, la file serialisee et surtout la porte du nuage vivent tous
// autour d eux, et ce fichier les rend mesurables.
//
// Les deux moteurs comptent leurs appels. C est la mesure qui prouve les deux
// criteres qui comptent le plus : une planche n est jamais traduite deux fois,
// et le moteur distant n est jamais appele sans accord.
//

/// Detection qui rend toujours les memes bulles, et compte ses appels.
final class DetectionFigee: DetecteurDeTexte, @unchecked Sendable {
    let identifiant: String

    /// Bulles rendues a chaque appel.
    let rendues: [BulleDeTexte]

    private let verrou = NSLock()
    private var appels = 0

    init(identifiant: String = "detection-figee", rendues: [BulleDeTexte]) {
        self.identifiant = identifiant
        self.rendues = rendues
    }

    /// Nombre de passages reels dans la detection.
    var nombreDAppels: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return appels
    }

    func bulles(_: MatriceDePixels) throws -> [BulleDeTexte] {
        verrou.lock()
        appels += 1
        verrou.unlock()

        return rendues
    }
}

/// Detection qui echoue toujours, comme un lecteur refuse par l appareil.
struct DetectionEnEchec: DetecteurDeTexte {
    let identifiant = "detection-en-echec"

    func bulles(_: MatriceDePixels) throws -> [BulleDeTexte] {
        throw ErreurDeTraduction.moteurEnEchec(identifiant: identifiant)
    }
}

/// Moteur qui prefixe chaque texte, et compte ses appels.
///
/// Le prefixe rend la traduction reconnaissable : un test peut affirmer que
/// c est bien ce moteur la qui a produit le texte affiche, ce qu un moteur qui
/// renverrait son entree ne permettrait pas.
final class MoteurCompteur: MoteurDeTraductionDeTexte, @unchecked Sendable {
    let identifiant: String
    let emplacement: EmplacementDuMoteur

    /// Marque posee devant chaque texte traduit.
    let prefixe: String

    private let verrou = NSLock()
    private var appels = 0
    private var textesRecus: [String] = []

    init(identifiant: String, emplacement: EmplacementDuMoteur, prefixe: String) {
        self.identifiant = identifiant
        self.emplacement = emplacement
        self.prefixe = prefixe
    }

    /// Moteur local de reference.
    static func local() -> MoteurCompteur {
        MoteurCompteur(identifiant: "local", emplacement: .surLAppareil, prefixe: "local:")
    }

    /// Moteur distant de reference.
    static func distant() -> MoteurCompteur {
        MoteurCompteur(identifiant: "distant", emplacement: .dansLeNuage, prefixe: "nuage:")
    }

    /// Nombre d appels reels au moteur.
    var nombreDAppels: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return appels
    }

    /// Textes que le moteur a reellement recus depuis le demarrage.
    ///
    /// Pour le moteur distant, c est exactement la liste de ce qui a quitte
    /// l appareil. Un test peut donc verifier qu elle est vide plutot que de se
    /// contenter de compter les appels.
    var recus: [String] {
        verrou.lock()
        defer { verrou.unlock() }

        return textesRecus
    }

    func traduire(_ textes: [String], vers _: ChoixDeLangue) throws -> [String] {
        verrou.lock()
        appels += 1
        textesRecus.append(contentsOf: textes)
        verrou.unlock()

        return textes.map { prefixe + $0 }
    }
}

/// Moteur qui rend moins de textes qu il n en recoit.
///
/// Le cas d un service distant qui tronque sa reponse. Il ne doit jamais
/// produire un appariement decale entre les bulles et les textes.
struct MoteurBavard: MoteurDeTraductionDeTexte {
    let identifiant = "bavard"
    let emplacement = EmplacementDuMoteur.dansLeNuage

    func traduire(_ textes: [String], vers _: ChoixDeLangue) throws -> [String] {
        Array(textes.dropLast())
    }
}

/// Bulles de reference, posees a des endroits connus de la planche.
enum BullesDeTest {
    /// Bulle sure, dans le quart demande de la planche.
    static func bulle(
        abscisse: Double,
        ordonnee: Double,
        texte: String,
        confiance: Double = 0.9
    ) -> BulleDeTexte? {
        guard let cadre = CaseDePage(
            abscisse: abscisse,
            ordonnee: ordonnee,
            largeur: 0.3,
            hauteur: 0.2,
            confiance: confiance
        ) else {
            return nil
        }

        return BulleDeTexte(cadre: cadre, texte: texte)
    }

    /// Deux bulles, l une en haut a gauche, l autre en haut a droite.
    ///
    /// C est la disposition qui separe les deux sens de lecture : en droite a
    /// gauche, celle de droite se lit en premier.
    static var deuxBullesEnHaut: [BulleDeTexte] {
        [
            bulle(abscisse: 0.05, ordonnee: 0.05, texte: "a gauche"),
            bulle(abscisse: 0.6, ordonnee: 0.05, texte: "a droite"),
        ].compactMap(\.self)
    }
}
