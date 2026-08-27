import Core
import GRDB

//
// MagasinDuTutorielDeZones
//
// Seul point d acces au drapeau du tutoriel de premiere ouverture des zones de
// toucher, section 5.7 de DESIGN-SPEC.md.
//
// Le drapeau partage la table cle valeur des reglages, qui n impose aucune
// migration a l ajout d une cle. Sa cle vit hors de l espace des identifiants
// de reglage, sous son propre prefixe : le tutoriel n est pas un reglage, il
// n apparait dans aucune ligne de la section 5.5, et `MagasinDeReglages` ecarte
// deja toute cle que le catalogue ne reconnait pas.
//

/// Lit et ecrit le drapeau du tutoriel des zones de toucher.
public struct MagasinDuTutorielDeZones: Sendable {
    /// Cle de la ligne dans la table des reglages.
    static let cle = "tutoriel.zonesDeToucherVu"

    /// Forme persistee du drapeau.
    ///
    /// C est celle qu emploie `ValeurDeReglage.booleen`, parce que la ligne
    /// partage sa table. La suite de tests compare les deux ecritures pour
    /// qu elles ne puissent pas diverger.
    static let marqueDeVisionnage = "true"

    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Vrai quand le tutoriel a deja ete montre sur cette installation.
    public func aEteVu() throws -> Bool {
        try base.ecrivain.read { connexion in
            try ReglagePersiste.fetchOne(connexion, key: Self.cle)?.valeur == Self.marqueDeVisionnage
        }
    }

    /// Etat de depart du tutoriel, relu depuis la base.
    public func tutoriel() throws -> TutorielDeZones {
        try TutorielDeZones(dejaVu: aEteVu())
    }

    /// Note que le tutoriel a ete montre.
    ///
    /// L ecriture est idempotente : l appeler deux fois laisse la meme ligne.
    /// C est ce qui permet a l ecran de l appeler des l apparition des zones,
    /// sans attendre la fin des quatre secondes, et donc sans qu une fermeture
    /// de l application pendant le tutoriel le fasse revenir au lancement
    /// suivant.
    public func marquerVu() throws {
        try base.ecrivain.write { connexion in
            try ReglagePersiste(cle: Self.cle, valeur: Self.marqueDeVisionnage).upsert(connexion)
        }
    }
}
