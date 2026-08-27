import Core
import Foundation
import GRDB

//
// MagasinDePrereglages
//
// Seul point d acces aux prereglages de lecture persistes : la liste de la
// section 7 du tableau de la section 5.5 de DESIGN-SPEC.md, sa gestion, et
// l application d un prereglage.
//
// La table `prereglageLecture` existe depuis la creation du schema, avec les
// trois colonnes de la section 3.1 et l unicite du nom. Aucune migration n est
// donc ajoutee ici : le format des reglages captures vit dans le bloc JSON, que
// la base ne relit jamais.
//
// L application d un prereglage tient dans une seule transaction. Les cinq
// lignes de reglage et le sens global sont ecrits ensemble, et les observateurs
// de `MagasinDeReglages.flux` ne voient donc jamais un etat a moitie applique.
// C est ce qui rend l application immediate au sens du critere : une ecriture,
// une notification, une passe de rendu.
//

/// Lit et ecrit les prereglages de lecture.
public struct MagasinDePrereglages: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Prereglages enregistres, dans l ordre de la liste.
    public func prereglages() throws -> [PrereglageLecture] {
        try base.ecrivain.read { connexion in
            try Self.prereglages(connexion)
        }
    }

    /// Nombre de prereglages, pour la valeur affichee par la ligne de
    /// navigation de la section 7.
    ///
    /// Un comptage plutot qu une lecture complete suivie d un `count` : la
    /// ligne n a besoin que du nombre, pas des blocs JSON.
    public func nombre() throws -> Int {
        try base.ecrivain.read { connexion in
            try PrereglageLecture.fetchCount(connexion)
        }
    }

    /// Contenu capture par un prereglage.
    ///
    /// - Throws: `ErreurDePrereglage.prereglageInconnu` quand il n existe plus,
    ///   `.contenuIllisible` ou `.formatInconnu` quand sa colonne ne se relit
    ///   pas.
    public func contenu(de identifiant: UUID) throws -> ContenuDePrereglage {
        try base.ecrivain.read { connexion in
            try Self.prereglage(connexion, identifiant).contenu()
        }
    }

    /// Flux de la liste, reemis a chaque ecriture.
    ///
    /// La ligne de navigation affiche un decompte et l ecran de gestion affiche
    /// la liste. Les deux surfaces s abonnent, aucune ne recharge a la main.
    public func flux() -> AsyncThrowingStream<[PrereglageLecture], any Error> {
        let observation = ValueObservation.tracking(Self.prereglages)
        let ecrivain = base.ecrivain

        return AsyncThrowingStream { suite in
            let tache = Task {
                do {
                    for try await prereglages in observation.values(in: ecrivain) {
                        suite.yield(prereglages)
                    }

                    suite.finish()
                } catch {
                    suite.finish(throwing: error)
                }
            }

            suite.onTermination = { _ in tache.cancel() }
        }
    }

    // MARK: Gestion de la liste

    /// Enregistre un contenu sous un nom.
    ///
    /// - Throws: `ErreurDePrereglage.nomVide` ou `.nomDejaPris`.
    @discardableResult
    public func enregistrer(nom: String, contenu: ContenuDePrereglage) throws -> PrereglageLecture {
        try base.ecrivain.write { connexion in
            let nettoye = try OrdreDesPrereglages.nomNettoye(nom)
            let existants = try Self.prereglages(connexion)
            try OrdreDesPrereglages.verifierLaDisponibilite(de: nettoye, parmi: existants)

            let prereglage = try PrereglageLecture(nom: nettoye, contenu: contenu)
            try prereglage.insert(connexion)

            return prereglage
        }
    }

    /// Capture l etat de lecture courant sous un nom.
    ///
    /// C est l action `Enregistrer l actuel comme prereglage` de la section 9.
    /// Les reglages sont relus dans la transaction d ecriture, ce qui interdit
    /// de capturer un etat deja perime au moment ou il est ecrit.
    ///
    /// - Parameter filtres: etat du panneau de filtres du lecteur. Il ne vit
    ///   pas dans la table des reglages, il est donc passe par l appelant.
    @discardableResult
    public func capturer(
        nom: String,
        filtres: ReglagesDeFiltres
    ) throws -> PrereglageLecture {
        try base.ecrivain.write { connexion in
            let nettoye = try OrdreDesPrereglages.nomNettoye(nom)
            let existants = try Self.prereglages(connexion)
            try OrdreDesPrereglages.verifierLaDisponibilite(de: nettoye, parmi: existants)

            let reglages = try MagasinDeReglages.lire(connexion)
            let contenu = ContenuDePrereglage.capture(reglages: reglages, filtres: filtres)

            let prereglage = try PrereglageLecture(nom: nettoye, contenu: contenu)
            try prereglage.insert(connexion)

            return prereglage
        }
    }

    /// Renomme un prereglage sans toucher a ce qu il capture.
    @discardableResult
    public func renommer(_ identifiant: UUID, en nom: String) throws -> PrereglageLecture {
        try base.ecrivain.write { connexion in
            let nettoye = try OrdreDesPrereglages.nomNettoye(nom)
            let existants = try Self.prereglages(connexion)

            guard var prereglage = existants.first(where: { $0.id == identifiant }) else {
                throw ErreurDePrereglage.prereglageInconnu(identifiant: identifiant)
            }

            try OrdreDesPrereglages.verifierLaDisponibilite(
                de: nettoye,
                parmi: existants,
                sauf: identifiant
            )

            prereglage.nom = nettoye
            try prereglage.update(connexion)

            return prereglage
        }
    }

    /// Remplace ce qu un prereglage capture, sans toucher a son nom.
    @discardableResult
    public func remplacer(
        _ identifiant: UUID,
        par contenu: ContenuDePrereglage
    ) throws -> PrereglageLecture {
        try base.ecrivain.write { connexion in
            var prereglage = try Self.prereglage(connexion, identifiant)
            prereglage.donneesReglages = try contenu.donnees()
            try prereglage.update(connexion)

            return prereglage
        }
    }

    /// Supprime un prereglage.
    ///
    /// Les reglages en place ne bougent pas. Supprimer un prereglage retire une
    /// facon de revenir a un etat, pas l etat courant.
    public func supprimer(_ identifiant: UUID) throws {
        try base.ecrivain.write { connexion in
            guard try PrereglageLecture.deleteOne(connexion, key: identifiant) else {
                throw ErreurDePrereglage.prereglageInconnu(identifiant: identifiant)
            }
        }
    }

    // MARK: Application

    /// Applique un prereglage et rend ce qu il a pose.
    ///
    /// Tout est ecrit dans une seule transaction : les cinq lignes de reglage
    /// et le sens de lecture global. Le contenu est rendu a l appelant pour
    /// qu il installe les filtres du panneau, qui ne vivent pas en base.
    ///
    /// Le sens global de la table est aligne sur le sens applique, mise en page
    /// comprise. Sans cela, un prereglage en defilement continu laisserait le
    /// moteur sur un sens horizontal alors que la ligne de reglage dit le
    /// contraire.
    @discardableResult
    public func appliquer(_ identifiant: UUID) throws -> ContenuDePrereglage {
        try base.ecrivain.write { connexion in
            let contenu = try Self.prereglage(connexion, identifiant).contenu()

            for (ligne, valeur) in contenu.valeursAEcrire {
                try MagasinDeReglages.ecrire(connexion, valeur, pour: ligne)
            }

            var sens = try MagasinDeSensDeLecture.reglageGlobal(connexion)
            sens.sensGlobal = contenu.sensApplique
            try sens.save(connexion)

            return contenu
        }
    }

    // MARK: Sauvegarde

    /// Part prereglages du fichier de sauvegarde de la section 10.
    ///
    /// - Throws: `ErreurDePrereglage.contenuIllisible` quand un prereglage ne
    ///   se relit pas. Une sauvegarde qui emporterait des octets qu elle ne
    ///   sait pas lire produirait des prereglages inapplicables a la
    ///   restauration.
    public func sauvegarde() throws -> SauvegardeDesPrereglages {
        try SauvegardeDesPrereglages(prereglages())
    }

    /// Restaure une part prereglages.
    ///
    /// - Parameter enRemplacant: vrai pour vider la liste avant d ecrire, faux
    ///   pour fusionner. La section 10 pose ces deux modes a l import. En
    ///   fusion, un prereglage deja present sous le meme identifiant est mis a
    ///   jour, et un nom deja pris par un autre prereglage fait echouer la
    ///   restauration plutot que de creer deux entrees indiscernables.
    public func restaurer(
        _ sauvegarde: SauvegardeDesPrereglages,
        enRemplacant remplacer: Bool
    ) throws {
        let restaures = try sauvegarde.restaures()

        try base.ecrivain.write { connexion in
            if remplacer {
                _ = try PrereglageLecture.deleteAll(connexion)
            }

            for prereglage in restaures {
                let existants = try Self.prereglages(connexion)

                try OrdreDesPrereglages.verifierLaDisponibilite(
                    de: prereglage.nom,
                    parmi: existants,
                    sauf: prereglage.id
                )

                try prereglage.upsert(connexion)
            }
        }
    }

    // MARK: Acces a la connexion

    private static func prereglages(_ connexion: Database) throws -> [PrereglageLecture] {
        try OrdreDesPrereglages.trier(PrereglageLecture.fetchAll(connexion))
    }

    private static func prereglage(
        _ connexion: Database,
        _ identifiant: UUID
    ) throws -> PrereglageLecture {
        guard let prereglage = try PrereglageLecture.fetchOne(connexion, key: identifiant) else {
            throw ErreurDePrereglage.prereglageInconnu(identifiant: identifiant)
        }

        return prereglage
    }
}
