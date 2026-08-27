import Core
import GRDB

//
// MagasinDeReglages
//
// Seul point d acces aux reglages de la section 5.5 de DESIGN-SPEC.md.
//
// Deux facons de lire : une lecture ponctuelle, et un flux qui reemet a chaque
// ecriture. La section 5.5 impose la seconde. Un reglage change dans une
// fenetre doit se voir dans l autre, et le theme choisi ici repeint toute
// l application : recharger a la main a chaque apparition d ecran laisserait
// forcement une vue en retard.
//

/// Lit et ecrit les reglages de l application.
public struct MagasinDeReglages: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Tous les reglages, valeurs par defaut du catalogue comprises.
    public func reglages() throws -> ReglagesDeLApplication {
        try base.ecrivain.read(Self.lire)
    }

    /// Valeur d un reglage.
    public func valeur(de identifiant: IdentifiantDeReglage) throws -> ValeurDeReglage {
        try reglages()[identifiant]
    }

    /// Flux des reglages, reemis a chaque ecriture.
    ///
    /// La premiere valeur arrive sans attendre une ecriture : un ecran qui
    /// s abonne obtient l etat courant, puis ses suites. L annulation de la
    /// tache qui consomme le flux arrete l observation.
    public func flux() -> AsyncThrowingStream<ReglagesDeLApplication, any Error> {
        let observation = ValueObservation.tracking(Self.lire)
        let ecrivain = base.ecrivain

        return AsyncThrowingStream { suite in
            let tache = Task {
                do {
                    for try await reglages in observation.values(in: ecrivain) {
                        suite.yield(reglages)
                    }

                    suite.finish()
                } catch {
                    suite.finish(throwing: error)
                }
            }

            suite.onTermination = { _ in tache.cancel() }
        }
    }

    // MARK: Ecriture

    /// Remplace la valeur d un reglage.
    ///
    /// Une valeur `aucune` efface la ligne : une ligne de navigation n a rien a
    /// ecrire, et un reglage remis a son defaut n a pas a occuper la table.
    public func definir(_ valeur: ValeurDeReglage, pour identifiant: IdentifiantDeReglage) throws {
        try base.ecrivain.write { connexion in
            try Self.ecrire(connexion, valeur, pour: identifiant)
        }
    }

    /// Remet un reglage a la valeur du catalogue.
    public func reinitialiser(_ identifiant: IdentifiantDeReglage) throws {
        _ = try base.ecrivain.write { connexion in
            try ReglagePersiste.deleteOne(connexion, key: identifiant.rawValue)
        }
    }

    /// Remet tous les reglages a leurs valeurs par defaut.
    public func toutReinitialiser() throws {
        _ = try base.ecrivain.write { connexion in
            try ReglagePersiste.deleteAll(connexion)
        }
    }

    // MARK: Acces a la connexion

    /// Ecrit une valeur de reglage dans la connexion donnee.
    ///
    /// Le magasin des prereglages en a besoin pour poser tout un jeu de
    /// reglages dans une seule transaction. Une application ligne par ligne
    /// ferait passer les observateurs par des etats intermediaires, moitie
    /// ancien prereglage moitie nouveau, et le lecteur repeindrait la page
    /// autant de fois qu il y a de lignes.
    static func ecrire(
        _ connexion: Database,
        _ valeur: ValeurDeReglage,
        pour identifiant: IdentifiantDeReglage
    ) throws {
        guard let texte = valeur.texte else {
            _ = try ReglagePersiste.deleteOne(connexion, key: identifiant.rawValue)
            return
        }

        try ReglagePersiste(cle: identifiant.rawValue, valeur: texte).upsert(connexion)
    }

    /// Lit la table et ecarte toute ligne que le catalogue ne reconnait plus.
    ///
    /// Une cle inconnue vient forcement d une version anterieure du produit.
    /// La garder en memoire ne servirait a rien, et la supprimer pendant une
    /// simple lecture serait pire : une bascule de version en arriere perdrait
    /// alors le reglage pour de bon. Elle reste donc en base, ignoree.
    static func lire(_ connexion: Database) throws -> ReglagesDeLApplication {
        let lignes = try ReglagePersiste.fetchAll(connexion)

        let valeurs = lignes.reduce(into: [IdentifiantDeReglage: ValeurDeReglage]()) { resultat, ligne in
            guard let identifiant = IdentifiantDeReglage(rawValue: ligne.cle) else {
                return
            }

            let modele = CatalogueDeReglages.valeurParDefaut(de: identifiant)

            guard let valeur = ValeurDeReglage.lire(ligne.valeur, selon: modele) else {
                return
            }

            resultat[identifiant] = valeur
        }

        return ReglagesDeLApplication(valeurs)
    }
}
