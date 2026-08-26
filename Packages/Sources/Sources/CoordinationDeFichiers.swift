import Core
import Foundation

//
// CoordinationDeFichiers
//
// Le second critere de la fonctionnalite, et la raison pour laquelle un dossier
// iCloud Drive n est pas un dossier local avec un telechargement en plus.
//
// Un fichier d iCloud Drive est ecrit par un autre processus que le notre. Le
// demon de synchronisation le remplace quand une autre machine le modifie, et
// le pose en entier quand un telechargement se termine. Une lecture ordinaire
// tombe alors sur un fichier a demi ecrit, et le lecteur annonce une archive
// cassee pour un fichier parfaitement sain. Le conflit est d autant plus
// desagreable qu il ne se reproduit pas : le fichier est intact la seconde
// fois.
//
// `NSFileCoordinator` est le seul moyen de s en preserver, parce qu il est le
// protocole que le demon respecte lui aussi. Une lecture coordonnee attend
// qu une ecriture en cours se termine, et une ecriture coordonnee attend que
// les lectures en cours se terminent.
//
// Le protocole existe pour que les tests puissent compter les acces sans
// remplacer le coordinateur du systeme, jamais pour le simuler : ce sont ses
// garanties a lui qui sont en cause, donc c est lui qui est teste.
//

/// Acces coordonnes a un fichier partage avec un autre processus.
public protocol CoordinationDeFichiers: Sendable {
    /// Execute une lecture sous la protection du coordinateur.
    func lire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat

    /// Execute une ecriture sous la protection du coordinateur.
    func ecrire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat
}

/// Coordination confiee au coordinateur de fichiers du systeme.
public struct CoordinationParLeSysteme: CoordinationDeFichiers {
    public init() {}

    public func lire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat {
        try await horsDeLExecuteur {
            try Self.coordonner(.lecture, fichier, operation)
        }
    }

    public func ecrire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat {
        try await horsDeLExecuteur {
            try Self.coordonner(.ecriture, fichier, operation)
        }
    }

    /// Sens de l acces demande au coordinateur.
    private enum SensDAcces {
        case lecture
        case ecriture
    }

    /// Deroule un acces coordonne et rend ce que l operation a produit.
    ///
    /// Le coordinateur rend la main par un bloc synchrone, pas par une valeur.
    /// Le resultat est donc capture dans une variable locale, que le bloc
    /// renseigne avant que le coordinateur ne rende la main.
    private static func coordonner<Resultat>(
        _ sens: SensDAcces,
        _ fichier: URL,
        _ operation: (URL) throws -> Resultat
    ) throws -> Resultat {
        var erreurDeCoordination: NSError?
        var resultat: Result<Resultat, any Error>?

        let coordinateur = NSFileCoordinator(filePresenter: nil)
        let accesseur: (URL) -> Void = { url in
            resultat = Result { try operation(url) }
        }

        switch sens {
        case .lecture:
            coordinateur.coordinate(
                readingItemAt: fichier,
                options: [],
                error: &erreurDeCoordination,
                byAccessor: accesseur
            )
        case .ecriture:
            coordinateur.coordinate(
                writingItemAt: fichier,
                options: [],
                error: &erreurDeCoordination,
                byAccessor: accesseur
            )
        }

        if let erreurDeCoordination {
            throw erreurDeCoordination
        }
        guard let resultat else {
            // Le coordinateur a refuse l acces sans rien dire. Le cas n est pas
            // documente, mais le taire rendrait un resultat inexistant.
            throw ErreurDeSource.sourceInjoignable(source: fichier.lastPathComponent)
        }

        return try resultat.get()
    }

    /// Execute un travail bloquant hors du pool cooperatif.
    ///
    /// Un acces coordonne attend le demon de synchronisation, donc il bloque
    /// son fil d execution pour une duree que personne ne borne. Le laisser sur
    /// un fil du pool cooperatif y consommerait une des rares places et
    /// figerait des taches qui n ont rien a voir avec ce fichier.
    private func horsDeLExecuteur<Resultat: Sendable>(
        _ travail: @escaping @Sendable () throws -> Resultat
    ) async throws -> Resultat {
        try await Task.detached(priority: .utility, operation: travail).value
    }
}
