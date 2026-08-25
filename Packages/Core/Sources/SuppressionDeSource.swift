import Foundation

//
// SuppressionDeSource
//
// Supprimer une source, c est effacer tout ce qu elle a laisse derriere elle,
// et le trousseau en fait partie. C est le deuxieme critere de la
// fonctionnalite, et il ne tient pas tout seul : la base efface ses lignes en
// cascade, le registre oublie l instance, mais le trousseau du systeme survit a
// tout, y compris a la desinstallation sur macOS. Une source retiree sans purge
// laisse un mot de passe que plus rien ne lit et que plus rien ne peut effacer.
//
// D ou ce fichier. Une source laisse une trace a plusieurs endroits, chaque
// endroit sait effacer la sienne, et un seul appel les parcourt tous. Ajouter
// un endroit plus tard, la file de telechargement ou le cache disque, revient a
// conformer un type de plus, pas a retrouver tous les appelants.
//
// Aucun echec n interrompt le parcours. Un trousseau qui refuse ne doit pas
// laisser la source dans la liste, et un registre qui ne la connait pas ne doit
// pas empecher la purge du trousseau. Les echecs sont recoltes et rendus.
//

/// Un endroit ou une source laisse une trace effacable.
public protocol TraceDeSource: Sendable {
    /// Nom de la trace, pour le journal et pour les messages.
    ///
    /// Il nomme l endroit, jamais la source : la regle de journalisation de la
    /// section 11 interdit d ecrire le nom d une source ou son adresse.
    var nomDeLaTrace: String { get }

    /// Efface ce que cette source a laisse ici.
    ///
    /// Ne leve pas quand il n y avait rien a effacer. Une trace absente est le
    /// resultat attendu, pas une erreur.
    func effacer(_ source: SourceID) async throws
}

/// Ce qu un endroit n a pas su effacer.
public struct EchecDEffacement: Sendable {
    public let trace: String
    public let erreur: any Error

    public init(trace: String, erreur: any Error) {
        self.trace = trace
        self.erreur = erreur
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        if let trousseau = erreur as? ErreurDeTrousseau {
            return "suppression.\(trace).\(trousseau.codeDeJournal)"
        }

        return "suppression.\(trace).\(String(describing: type(of: erreur)))"
    }
}

/// Efface une source de tous les endroits ou elle laisse une trace.
public struct SuppressionDeSource: Sendable {
    private let traces: [any TraceDeSource]

    /// - Parameter traces: les endroits a purger, dans l ordre de parcours.
    public init(traces: [any TraceDeSource]) {
        self.traces = traces
    }

    /// Efface la source partout, et rend les endroits qui ont refuse.
    ///
    /// Le parcours est sequentiel et non concurrent, parce que l ordre compte :
    /// on retire d abord la source de ce qui la sert, et on efface ensuite ce
    /// qu elle a ecrit. Effacer les identifiants pendant qu une requete en vol
    /// les relit produirait un echec d authentification affiche a l utilisateur
    /// au moment precis ou il supprime la source.
    ///
    /// - Returns: la liste vide quand tout a ete efface.
    @discardableResult
    public func supprimer(_ source: SourceID) async -> [EchecDEffacement] {
        var echecs: [EchecDEffacement] = []

        for trace in traces {
            do {
                try await trace.effacer(source)
            } catch {
                echecs.append(EchecDEffacement(trace: trace.nomDeLaTrace, erreur: error))
            }
        }

        return echecs
    }
}

extension TrousseauDuSysteme: TraceDeSource {
    public var nomDeLaTrace: String {
        "trousseau"
    }

    public func effacer(_ source: SourceID) throws {
        try supprimer(pour: source)
    }
}

extension RegistreDeSources: TraceDeSource {
    public nonisolated var nomDeLaTrace: String {
        "registre"
    }

    public func effacer(_ source: SourceID) {
        retirer(source)
    }
}
