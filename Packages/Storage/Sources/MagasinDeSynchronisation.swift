import Core
import Foundation
import GRDB

//
// MagasinDeSynchronisation
//
// Les deux coutures de la synchronisation, cote base : la ou le journal
// survit, et la ou un changement recu devient un etat visible.
//
// Les deux vivent dans le meme type parce qu elles partagent la meme
// transaction. Appliquer un changement recu et noter qu il a ete applique
// doivent partir ensemble : entre les deux, une coupure laisserait un etat
// ecrit sans trace, que le prochain rejeu reappliquerait sur un etat que
// l utilisateur aurait pu changer entre temps.
//
// L application n ecrit jamais dans l historique de lecture. Une progression
// recue d un autre appareil dit ou en est la lecture, pas qu une session de
// lecture vient d avoir lieu ici. La consigner dans l historique doublerait
// chaque chapitre lu, une fois par appareil allume, et fausserait les
// statistiques de la section 9 autant que la reprise.
//

/// Lit et ecrit le journal de synchronisation, et applique ce qui est recu.
public struct MagasinDeSynchronisation: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Identifiant de cet appareil, cree a la premiere demande et garde.
    ///
    /// Il departe les conflits a horodatage egal, et cette regle ne tient que
    /// s il ne change jamais. Un identifiant tire a chaque lancement rendrait
    /// le departage aleatoire d une execution a l autre, ce qui est exactement
    /// le contraire de ce que la deuxieme ligne de `ResolutionDeConflit`
    /// promet. Il est donc range en base, a cote du journal, et non calcule
    /// depuis le materiel : le nom d appareil du systeme change quand
    /// l utilisateur le renomme, et l identifiant de fournisseur disparait a la
    /// reinstallation.
    public func identifiantDAppareil() async throws -> String {
        try await base.ecrivain.write { connexion in
            if let existant = try PointDeSynchronisation
                .fetchOne(connexion, key: PointDeSynchronisation.identifiantDAppareil)?.valeur,
                let texte = String(data: existant, encoding: .utf8),
                texte.isEmpty == false {
                return texte
            }

            let neuf = UUID().uuidString

            try PointDeSynchronisation(
                cle: PointDeSynchronisation.identifiantDAppareil,
                valeur: Data(neuf.utf8),
                date: nil
            ).upsert(connexion)

            return neuf
        }
    }
}

// MARK: Journal

extension MagasinDeSynchronisation: MagasinDuJournalDeChangements {
    /// Changements produits ici et pas encore accuses par le distant.
    public func journal() async throws -> JournalDeChangements {
        try await base.ecrivain.read { connexion in
            let lignes = try ChangementPersiste.fetchAll(connexion)

            return JournalDeChangements(lignes.compactMap { $0.changement() })
        }
    }

    /// Ajoute des changements au journal.
    ///
    /// L ecriture passe par le journal en memoire plutot que par un upsert
    /// direct, pour que le regroupement par cle suive exactement la meme regle
    /// que le moteur. Un upsert direct ecraserait aussi quand le changement
    /// entrant est plus ancien, et une horloge qui recule ferait alors reculer
    /// la page atteinte sur tous les appareils.
    public func consigner(_ changements: [ChangementSynchronise]) async throws {
        guard changements.isEmpty == false else {
            return
        }

        try await base.ecrivain.write { connexion in
            for changement in changements {
                let cle = changement.cle.texte
                let existant = try ChangementPersiste.fetchOne(connexion, key: cle)?.changement()
                let retenu = existant.map { ResolutionDeConflit.gagnant($0, changement).changement } ?? changement

                try ChangementPersiste(retenu).upsert(connexion)
            }
        }
    }

    /// Retire du journal ce que le distant a accuse.
    public func retirer(_ envoyes: [ChangementSynchronise]) async throws {
        guard envoyes.isEmpty == false else {
            return
        }

        try await base.ecrivain.write { connexion in
            for envoye in envoyes {
                let cle = envoye.cle.texte

                // Le retrait ne porte que sur la version exacte qui est partie.
                // Une position enregistree pendant l envoi a deja remplace la
                // ligne, et elle n est jamais partie.
                guard try ChangementPersiste.fetchOne(connexion, key: cle)?.changement() == envoye else {
                    continue
                }

                try ChangementPersiste.deleteOne(connexion, key: cle)
            }
        }
    }

    /// Point de reprise du distant.
    public func jetonDistant() async throws -> Data? {
        try await base.ecrivain.read { connexion in
            try PointDeSynchronisation.fetchOne(connexion, key: PointDeSynchronisation.jetonDistant)?.valeur
        }
    }

    /// Enregistre le point de reprise rendu par le dernier echange.
    public func definirLeJetonDistant(_ jeton: Data?) async throws {
        try await base.ecrivain.write { connexion in
            try PointDeSynchronisation(
                cle: PointDeSynchronisation.jetonDistant,
                valeur: jeton,
                date: nil
            ).upsert(connexion)
        }
    }

    /// Instant du dernier envoi accepte par le distant.
    public func dernierEnvoi() async throws -> Date? {
        try await base.ecrivain.read { connexion in
            try PointDeSynchronisation.fetchOne(connexion, key: PointDeSynchronisation.dernierEnvoi)?.date
        }
    }

    /// Enregistre l instant du dernier envoi accepte.
    public func definirLeDernierEnvoi(_ date: Date) async throws {
        try await base.ecrivain.write { connexion in
            try PointDeSynchronisation(
                cle: PointDeSynchronisation.dernierEnvoi,
                valeur: nil,
                date: date
            ).upsert(connexion)
        }
    }
}

// MARK: Application

extension MagasinDeSynchronisation: ApplicateurDeChangements {
    /// Applique les changements recus et rend ceux qui ont change quelque
    /// chose.
    @discardableResult
    public func appliquer(_ changements: [ChangementSynchronise]) async throws -> [ChangementSynchronise] {
        guard changements.isEmpty == false else {
            return []
        }

        return try await base.ecrivain.write { connexion in
            try changements.filter { changement in
                try Self.appliquer(changement, dans: connexion)
            }
        }
    }

    /// Applique un changement, et dit s il a change quelque chose.
    private static func appliquer(_ changement: ChangementSynchronise, dans connexion: Database) throws -> Bool {
        guard emporteSurLApplicationPrecedente(changement, dans: connexion) else {
            return false
        }

        let applique: Bool = switch changement.cle.entite {
        case .progressionDeChapitre:
            try appliquerLaProgression(changement, dans: connexion)

        case .serieDeBibliotheque:
            try appliquerLaSerie(changement, dans: connexion)
        }

        guard applique else {
            return false
        }

        try ChangementApplique(
            cle: changement.cle.texte,
            horodatage: changement.horodatage,
            appareil: changement.appareil
        ).upsert(connexion)

        return true
    }

    /// Vrai quand ce changement est plus recent que celui deja applique.
    ///
    /// La comparaison passe par `ResolutionDeConflit`, et non par une simple
    /// comparaison de dates. C est la meme regle qu ailleurs, departages
    /// compris : deux appareils qui recoivent les memes deux versions dans deux
    /// ordres differents doivent retenir la meme.
    private static func emporteSurLApplicationPrecedente(
        _ changement: ChangementSynchronise,
        dans connexion: Database
    ) -> Bool {
        guard let precedent = try? ChangementApplique.fetchOne(connexion, key: changement.cle.texte) else {
            return true
        }

        let temoin = ChangementSynchronise(
            cle: changement.cle,
            charge: changement.charge,
            horodatage: precedent.horodatage,
            appareil: precedent.appareil
        )

        guard temoin != changement else {
            return false
        }

        return ResolutionDeConflit.gagnant(temoin, changement).changement == changement
    }

    /// Ecrit une progression recue sur le chapitre local.
    ///
    /// Le chapitre absent n est pas une erreur. La serie n est pas encore
    /// arrivee sur cet appareil, ou n y sera jamais : faire echouer le lot
    /// entier bloquerait la synchronisation de tous les autres chapitres.
    private static func appliquerLaProgression(
        _ changement: ChangementSynchronise,
        dans connexion: Database
    ) throws -> Bool {
        let progression = try ProgressionSynchronisee.lire(changement)

        guard var chapitre = try Chapitre.fetchOne(connexion, key: progression.chapitreId) else {
            return false
        }

        // La lecture locale fait autorite quand elle est plus recente. Le cas
        // arrive apres une session incognito ou apres un moment ou
        // l interrupteur etait inactif : la position locale n est alors jamais
        // passee par le journal, et rien d autre ne la protege.
        if let lectureLocale = chapitre.dateLecture, lectureLocale > progression.dateLecture {
            return false
        }

        let bornee = progression.position().normalisee(nombreDePages: chapitre.nombrePages)

        chapitre.pageAtteinte = bornee.pageIndex
        chapitre.decalageDeDefilement = bornee.decalageDeDefilement
        chapitre.dateLecture = progression.dateLecture

        // Le marquage ne recule pas. Un chapitre lu ici reste lu, meme si
        // l autre appareil envoie une position en debut de chapitre : seul un
        // demarquage explicite le fait revenir, et il ne passe pas par ici.
        chapitre.estLu = chapitre.estLu || progression.estLu

        try chapitre.update(connexion)

        // La grille trie les series par derniere lecture. Sans cette ligne, une
        // serie lue sur un autre appareil resterait au rang qu elle avait.
        try connexion.execute(
            sql: """
            UPDATE manga
            SET dateDerniereLecture = ?
            WHERE id = ? AND (dateDerniereLecture IS NULL OR dateDerniereLecture < ?)
            """,
            arguments: [progression.dateLecture, chapitre.mangaId, progression.dateLecture]
        )

        return true
    }

    /// Ecrit la presence d une serie dans la bibliotheque.
    private static func appliquerLaSerie(
        _ changement: ChangementSynchronise,
        dans connexion: Database
    ) throws -> Bool {
        let serie = try SerieSynchronisee.lire(changement)

        guard var manga = try Manga.fetchOne(connexion, key: serie.mangaId) else {
            return false
        }

        manga.estDansBibliotheque = serie.estDansBibliotheque
        manga.dateAjout = serie.dateAjout

        try manga.update(connexion)

        return true
    }
}
