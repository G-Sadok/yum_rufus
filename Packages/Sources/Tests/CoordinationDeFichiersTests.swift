import Core
import Foundation
import Testing
@testable import Sources

//
// CoordinationDeFichiersTests
//
// Le second critere de la fonctionnalite : la coordination de fichiers evite
// les conflits.
//
// Le conflit qu il faut ecarter est precis. Un fichier d iCloud Drive est ecrit
// par un autre processus que le notre, le demon de synchronisation, qui le
// remplace quand une autre machine le modifie ou quand le telechargement se
// termine. Une lecture non coordonnee tombe alors sur un fichier a demi ecrit,
// et le lecteur affiche une archive cassee pour un fichier parfaitement sain.
//
// Les tests utilisent le vrai coordinateur du systeme et de vrais fichiers.
// Verifier un double simule ne dirait rien : c est justement le comportement du
// systeme qui est en cause.
//

struct CoordinationDeFichiersTests {
    /// Duree pendant laquelle l ecriture coordonnee tient le fichier a demi
    /// ecrit. Elle doit rester assez longue pour que les lectures lancees
    /// ensuite se presentent pendant ce temps, et assez courte pour ne pas
    /// peser sur la suite.
    private static let dureeDeLEcriture = 0.2

    @Test("Aucune lecture coordonnee ne s execute pendant une ecriture coordonnee")
    func lecturesEtEcritureNeSeChevauchentPas() async throws {
        let arbre = try ArbreDeTest(nom: "coordination")
        let fichier = try arbre.fichier("chapitre.bin", contenu: Data(repeating: 0xA0, count: 8))
        let coordination = CoordinationParLeSysteme()
        let temoin = TemoinDAcces()

        try await withThrowingTaskGroup(of: Void.self) { groupe in
            groupe.addTask {
                try await coordination.ecrire(fichier) { url in
                    temoin.entrerEnEcriture()
                    // Etat intermediaire : le fichier est plus court que ce que
                    // toute lecture doit voir.
                    try Data(repeating: 0xB0, count: 4).write(to: url)
                    Thread.sleep(forTimeInterval: Self.dureeDeLEcriture)
                    try Data(repeating: 0xC0, count: 8).write(to: url)
                    temoin.sortirDEcriture()
                }
            }

            // Laisse l ecriture prendre le verrou avant de lancer les lectures.
            try await Task.sleep(for: .milliseconds(50))

            for _ in 0..<4 {
                groupe.addTask {
                    let octets = try await coordination.lire(fichier) { url in
                        temoin.entrerEnLecture()

                        return try Data(contentsOf: url)
                    }

                    temoin.noter(octets)
                }
            }

            try await groupe.waitForAll()
        }

        #expect(temoin.lecturesPendantUneEcriture == 0)
        #expect(temoin.contenusLus.count == 4)
        #expect(temoin.contenusLus.allSatisfy { $0.count == 8 })
    }

    @Test("Une lecture coordonnee rend le resultat de son operation")
    func lectureRendSonResultat() async throws {
        let arbre = try ArbreDeTest(nom: "coordination")
        let fichier = try arbre.fichier("chapitre.bin", contenu: Data(repeating: 0xA0, count: 12))

        let taille = try await CoordinationParLeSysteme().lire(fichier) { url in
            try Data(contentsOf: url).count
        }

        #expect(taille == 12)
    }

    @Test("Une erreur levee pendant une lecture coordonnee remonte a l appelant")
    func erreurRemonte() async throws {
        let arbre = try ArbreDeTest(nom: "coordination")
        let fichier = try arbre.fichier("chapitre.bin")

        await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "chapitre.bin")) {
            _ = try await CoordinationParLeSysteme().lire(fichier) { _ -> Data in
                throw ErreurDeSource.chapitreIntrouvable(identifiant: "chapitre.bin")
            }
        }
    }
}

/// Ce que les acces coordonnes ont fait, vu de l exterieur.
///
/// La classe est `@unchecked Sendable` parce que sa surete ne vient pas du
/// compilateur mais du verrou : chaque acces a l etat passe par lui, et rien
/// n en sort autrement que par copie. Un acteur ne conviendrait pas, les acces
/// sont notes depuis l interieur de blocs synchrones que le coordinateur du
/// systeme execute sur ses propres files.
final class TemoinDAcces: @unchecked Sendable {
    private let verrou = NSLock()
    private var ecrituresEnCours = 0
    private var lecturesFautives = 0
    private var contenus: [Data] = []

    /// Nombre de lectures qui se sont ouvertes pendant une ecriture.
    var lecturesPendantUneEcriture: Int {
        verrou.withLock { lecturesFautives }
    }

    /// Contenus rendus par les lectures.
    var contenusLus: [Data] {
        verrou.withLock { contenus }
    }

    func entrerEnEcriture() {
        verrou.withLock { ecrituresEnCours += 1 }
    }

    func sortirDEcriture() {
        verrou.withLock { ecrituresEnCours -= 1 }
    }

    func entrerEnLecture() {
        verrou.withLock {
            if ecrituresEnCours > 0 {
                lecturesFautives += 1
            }
        }
    }

    func noter(_ octets: Data) {
        verrou.withLock { contenus.append(octets) }
    }
}
