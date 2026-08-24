import Archive
import Foundation

//
// SourceEspionne
//
// Source d octets qui enregistre chaque plage lue.
//
// C est l instrument du critere d acces direct. Sans lui, on ne peut affirmer
// qu ouvrir la page N ne touche pas les pages precedentes qu en mesurant un
// temps, ce qui ne prouve rien sur une petite archive et depend de la machine.
// Avec lui, la preuve est exacte : la liste des plages lues est confrontee aux
// positions que le constructeur d archive a notees.
//

/// Source qui delegue la lecture et note ce qui a ete demande.
///
/// Marquee `@unchecked Sendable` parce que son unique etat mutable, la liste des
/// plages, n est touche que sous le verrou. Aucun autre champ n est mutable.
final class SourceEspionne: SourceDOctets, @unchecked Sendable {
    private let sousJacente: OctetsEnMemoire
    private let verrou = NSLock()
    private var plagesLues: [Range<UInt64>] = []

    var nom: String {
        sousJacente.nom
    }

    var taille: UInt64 {
        sousJacente.taille
    }

    init(_ octets: Data, nom: String = "archive.cbz") {
        sousJacente = OctetsEnMemoire(octets, nom: nom)
    }

    func lire(a offset: UInt64, longueur: Int) throws -> Data {
        let donnees = try sousJacente.lire(a: offset, longueur: longueur)

        verrou.lock()
        plagesLues.append(offset..<(offset + UInt64(longueur)))
        verrou.unlock()

        return donnees
    }

    /// Oublie tout ce qui a ete lu jusqu ici.
    func oublier() {
        verrou.lock()
        plagesLues.removeAll()
        verrou.unlock()
    }

    /// Plages lues depuis le dernier oubli.
    var plages: [Range<UInt64>] {
        verrou.lock()
        defer { verrou.unlock() }

        return plagesLues
    }

    /// Nombre total d octets demandes depuis le dernier oubli.
    var octetsLus: Int {
        plages.reduce(0) { total, plage in total + Int(plage.upperBound - plage.lowerBound) }
    }

    /// Indique si une des lectures a touche la plage donnee.
    func aTouche(_ plage: Range<Int>) -> Bool {
        let cible = UInt64(plage.lowerBound)..<UInt64(plage.upperBound)

        return plages.contains { lue in
            lue.lowerBound < cible.upperBound && cible.lowerBound < lue.upperBound
        }
    }
}
