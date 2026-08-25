import Foundation

//
// MagasinDIdentifiantsEnMemoire
//
// Implementation de `MagasinDIdentifiants` qui ne persiste rien, sur le modele
// de `BaseDeDonnees.enMemoire()` : reservee aux tests et aux apercus.
//
// Elle vit dans les sources et non dans une cible de test parce que trois
// cibles de test en ont besoin, Core, Storage et bientot Sources, et que deux
// cibles de test SwiftPM ne partagent pas de code. La recopier trois fois
// garantirait que les trois copies divergent.
//
// La raison pour laquelle un double est necessaire tient en une phrase : un
// binaire de test lance par SwiftPM n est pas signe et ne porte aucun droit de
// trousseau. `SecItemAdd` y repond errSecMissingEntitlement sur le trousseau
// protege, et ouvre une fenetre de confirmation sur le trousseau de fichier
// historique. Ce que le vrai trousseau doit garantir se verifie donc sur la
// forme des requetes, dans `RequeteDeTrousseau`, pas sur son contenu.
//

/// Trousseau volatil, pour les tests et les apercus.
///
/// Rien de ce qui y est ecrit ne survit au processus. L application livree
/// n emploie jamais ce type : elle passe par `TrousseauDuSysteme`.
public actor MagasinDIdentifiantsEnMemoire: MagasinDIdentifiants {
    private var lignes: [SourceID: IdentifiantsDeSource] = [:]

    public init() {}

    /// Les sources qui ont une ligne, pour les verifications.
    public var sourcesConnues: Set<SourceID> {
        Set(lignes.keys)
    }

    public func enregistrer(_ identifiants: IdentifiantsDeSource, pour source: SourceID) {
        guard identifiants.estVide == false else {
            lignes[source] = nil

            return
        }

        lignes[source] = identifiants
    }

    public func identifiants(pour source: SourceID) -> IdentifiantsDeSource {
        lignes[source] ?? .aucun
    }

    public func supprimer(pour source: SourceID) {
        lignes[source] = nil
    }
}

extension MagasinDIdentifiantsEnMemoire: TraceDeSource {
    public nonisolated var nomDeLaTrace: String {
        "trousseau"
    }

    public func effacer(_ source: SourceID) {
        supprimer(pour: source)
    }
}
