import Core
import CoreGraphics
import Foundation
import ImagePipeline
@testable import ReaderEngine

//
// AtelierEspion
//
// Atelier qui note ce qu il decode, et qui sait retenir ou ralentir un
// decodage.
//
// Un decodage reel est synchrone et occupe son fil du debut a la fin. L espion
// se comporte pareil, en bloquant le fil appelant, sans quoi il ne prouverait
// rien de ce que le vrai decodage impose. Il est donc protege par un verrou et
// non par un acteur : le test doit pouvoir l interroger pendant qu il bloque.
//

final class AtelierEspion: AtelierDeDecodage, @unchecked Sendable {
    /// Le systeme a refuse la matrice, l espion ne peut rien rendre.
    struct MatriceRefusee: Error {}

    private let verrou = NSLock()
    private var commencesInternes: [String] = []
    private var terminesInternes: [String] = []
    private var retenus: Set<String> = []
    private var ralentissements: [String: TimeInterval] = [:]

    /// Noms decodes, dans l ordre ou les decodages ont commence.
    var commences: [String] {
        verrou.lock()
        defer { verrou.unlock() }

        return commencesInternes
    }

    /// Noms dont le decodage est alle jusqu au bout.
    var termines: [String] {
        verrou.lock()
        defer { verrou.unlock() }

        return terminesInternes
    }

    /// Retient le decodage de ce nom jusqu a l appel de `liberer`.
    func retenir(_ nom: String) {
        verrou.lock()
        retenus.insert(nom)
        verrou.unlock()
    }

    /// Libere un decodage retenu.
    func liberer(_ nom: String) {
        verrou.lock()
        retenus.remove(nom)
        verrou.unlock()
    }

    /// Fait durer le decodage de ce nom, comme le ferait une grande page.
    func ralentir(_ nom: String, de duree: TimeInterval) {
        verrou.lock()
        ralentissements[nom] = duree
        verrou.unlock()
    }

    func decoder(_: Data, nom: String, dans zone: TailleEnPixels) throws -> ImageDePage {
        noterLeDebut(de: nom)

        if let duree = ralentissement(de: nom) {
            Thread.sleep(forTimeInterval: duree)
        }

        while estRetenu(nom) {
            Thread.sleep(forTimeInterval: 0.002)
        }

        guard let image = PageDecodeeDeTest.image(cote: max(1, min(zone.largeur, 64))) else {
            throw MatriceRefusee()
        }

        noterLaFin(de: nom)

        return image
    }

    private func noterLeDebut(de nom: String) {
        verrou.lock()
        commencesInternes.append(nom)
        verrou.unlock()
    }

    private func noterLaFin(de nom: String) {
        verrou.lock()
        terminesInternes.append(nom)
        verrou.unlock()
    }

    private func estRetenu(_ nom: String) -> Bool {
        verrou.lock()
        defer { verrou.unlock() }

        return retenus.contains(nom)
    }

    private func ralentissement(de nom: String) -> TimeInterval? {
        verrou.lock()
        defer { verrou.unlock() }

        return ralentissements[nom]
    }
}
