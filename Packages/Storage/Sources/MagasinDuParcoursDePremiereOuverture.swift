import Core
import GRDB

//
// MagasinDuParcoursDePremiereOuverture
//
// Seul point d acces au drapeau du parcours de premiere ouverture, section 5.10
// de DESIGN-SPEC.md.
//
// Meme forme que le drapeau du tutoriel des zones de toucher, et pour les memes
// raisons. Le drapeau partage la table cle valeur des reglages, qui n impose
// aucune migration a l ajout d une cle, et sa cle vit hors de l espace des
// identifiants de reglage : le parcours n est pas un reglage, c est un ecran vu
// ou non vu.
//
// Le rejeu demande depuis l ecran Reglages n efface pas cette ligne. Il rouvre
// le parcours pour la session en cours, et le lancement suivant reste calme :
// quelqu un qui revoit l accueil une fois ne demande pas a le revoir a chaque
// demarrage.
//

/// Lit et ecrit le drapeau du parcours de premiere ouverture.
public struct MagasinDuParcoursDePremiereOuverture: Sendable {
    /// Cle de la ligne dans la table des reglages.
    static let cle = "premiereOuverture.parcoursFait"

    /// Forme persistee du drapeau.
    ///
    /// C est celle qu emploie `ValeurDeReglage.booleen`, parce que la ligne
    /// partage sa table. La suite de tests compare les deux ecritures pour
    /// qu elles ne puissent pas diverger.
    static let marqueDeParcoursFait = "true"

    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Vrai quand le parcours a deja ete mene a son terme sur cette
    /// installation.
    public func aEteFait() throws -> Bool {
        try base.ecrivain.read { connexion in
            try ReglagePersiste.fetchOne(connexion, key: Self.cle)?.valeur == Self.marqueDeParcoursFait
        }
    }

    /// Etat de depart du parcours, relu depuis la base.
    public func parcours() throws -> ParcoursDePremiereOuverture {
        try ParcoursDePremiereOuverture(dejaFait: aEteFait())
    }

    /// Note que le parcours a ete mene a son terme.
    ///
    /// L ecriture est idempotente : l appeler deux fois laisse la meme ligne.
    /// Le rejeu depuis les reglages la reecrit donc sans dommage a la fin du
    /// second passage.
    public func marquerFait() throws {
        try base.ecrivain.write { connexion in
            try ReglagePersiste(cle: Self.cle, valeur: Self.marqueDeParcoursFait).upsert(connexion)
        }
    }
}
