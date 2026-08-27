import Core
import Foundation
import GRDB

//
// MagasinDHistorique
//
// Seul point d acces a l historique de lecture de la section 5.2 de
// DESIGN-SPEC.md : lecture groupee par jour, suppression unitaire, effacement
// global, et consignation d un passage de lecture.
//
// La table `entreeHistorique` porte une ligne par chapitre et par jour civil,
// pas une ligne par sauvegarde de position. Le moteur enregistre la position
// toutes les deux secondes pendant la lecture : une ligne par ecriture
// donnerait mille huit cents entrees pour une heure de lecture, et un ecran
// illisible des le premier chapitre.
//
// Le mode incognito de la section 11 ne ferme que la consignation. La
// suppression d une entree et l effacement global restent offerts pendant une
// session : ce sont des gestes explicites de l utilisateur, qui vont dans le
// meme sens que le mode incognito et non contre lui. Une commande qui ne ferait
// rien en silence serait un bogue, pas une protection.
//

/// Lit et ecrit l historique de lecture.
public struct MagasinDHistorique: Sendable {
    /// Nombre d entrees remontees par defaut a l ecran.
    ///
    /// Le document ne borne pas la liste. La borne existe pour que l ecran ne
    /// charge pas dix ans de lecture d un coup, et elle est assez haute pour
    /// que le defilement ne la rencontre pas dans une session normale.
    public static let limiteParDefaut = 500

    private let base: BaseDeDonnees
    private let incognito: RegistreDIncognito

    /// Construit le magasin.
    ///
    /// - Parameters:
    ///   - base: base deja ouverte et migree.
    ///   - incognito: etat du mode incognito, section 11. Un registre neuf est
    ///     inactif.
    public init(base: BaseDeDonnees, incognito: RegistreDIncognito = RegistreDIncognito()) {
        self.base = base
        self.incognito = incognito
    }

    // MARK: Lecture

    /// Lectures consignees, la plus recente en tete.
    ///
    /// La jointure sur `chapitre` et `manga` remplace deux allers retours par
    /// ligne. Le tri s appuie sur `idx_historique_date`, cree par la migration
    /// initiale.
    public func entrees(limite: Int = limiteParDefaut) throws -> [EntreeDHistorique] {
        try base.ecrivain.read { connexion in
            let lignes = try Row.fetchAll(
                connexion,
                sql: """
                SELECT entreeHistorique.id AS id,
                       entreeHistorique.chapitreId AS chapitreId,
                       entreeHistorique.dateLecture AS dateLecture,
                       chapitre.numero AS numeroDeChapitre,
                       chapitre.titre AS titreDuChapitre,
                       manga.id AS serieId,
                       manga.titre AS titreDeLaSerie,
                       manga.cheminCouvertureLocale AS cheminCouvertureLocale,
                       manga.urlCouverture AS urlCouverture
                FROM entreeHistorique
                JOIN chapitre ON chapitre.id = entreeHistorique.chapitreId
                JOIN manga ON manga.id = chapitre.mangaId
                ORDER BY entreeHistorique.dateLecture DESC
                LIMIT ?
                """,
                arguments: [limite]
            )

            return lignes.map(Self.entree(depuis:))
        }
    }

    /// Lectures groupees par jour, telles que la liste les affiche.
    ///
    /// - Parameters:
    ///   - calendrier: calendrier de l utilisateur, qui decide ou tombe minuit.
    ///   - limite: nombre maximal d entrees lues.
    public func journees(
        calendrier: Calendar = .autoupdatingCurrent,
        limite: Int = limiteParDefaut
    ) throws -> [JourneeDHistorique] {
        try RegroupementParJour.grouper(entrees(limite: limite), calendrier: calendrier)
    }

    // MARK: Ecriture

    /// Consigne une lecture, ou met a jour celle du jour pour ce chapitre.
    ///
    /// Pendant une session incognito, l appel ne fait rien : la section 11
    /// interdit toute ecriture dans l historique tant que la session court.
    ///
    /// - Parameters:
    ///   - chapitre: chapitre lu.
    ///   - pageAtteinte: page atteinte a la fin du passage.
    ///   - date: instant de la lecture.
    ///   - calendrier: calendrier qui delimite le jour civil.
    public func consigner(
        chapitre: UUID,
        pageAtteinte: Int,
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) throws {
        guard incognito.autorise(.historiqueDeLecture) else {
            return
        }

        try base.ecrivain.write { connexion in
            try Self.consigner(
                chapitre: chapitre,
                pageAtteinte: pageAtteinte,
                le: date,
                calendrier: calendrier,
                dans: connexion
            )
        }
    }

    /// Retire une entree, bouton de suppression de la section 5.2.
    ///
    /// Seule l entree part. Le chapitre garde son etat de lecture et sa page
    /// atteinte : effacer une trace n annule pas une lecture.
    public func supprimer(_ entree: UUID) throws {
        _ = try base.ecrivain.write { connexion in
            try EntreeHistorique.deleteOne(connexion, key: entree)
        }
    }

    /// Efface tout l historique, action `Effacer l historique` de la section 5.2.
    ///
    /// L appelant n arrive ici qu apres la modale de confirmation. Rien d autre
    /// n est touche, ni la bibliotheque, ni la progression, ni les
    /// telechargements.
    public func effacer() throws {
        _ = try base.ecrivain.write { connexion in
            try EntreeHistorique.deleteAll(connexion)
        }
    }

    // MARK: Acces a la connexion

    /// Consigne une lecture dans la transaction deja ouverte.
    ///
    /// Employe par `MagasinDeProgression`, pour que la position et sa trace
    /// dans l historique partent dans la meme transaction. Une fermeture
    /// brutale entre les deux laisserait sinon un historique en desaccord avec
    /// la reprise.
    static func consigner(
        chapitre: UUID,
        pageAtteinte: Int,
        le date: Date,
        calendrier: Calendar,
        dans connexion: Database
    ) throws {
        let debutDuJour = calendrier.startOfDay(for: date)
        let debutDuJourSuivant = calendrier.date(byAdding: .day, value: 1, to: debutDuJour)
            ?? date.addingTimeInterval(1)

        let existante = try EntreeHistorique
            .filter(Column("chapitreId") == chapitre)
            .filter(Column("dateLecture") >= debutDuJour)
            .filter(Column("dateLecture") < debutDuJourSuivant)
            .order(Column("dateLecture").desc)
            .fetchOne(connexion)

        guard var entree = existante else {
            try EntreeHistorique(
                chapitreId: chapitre,
                dateLecture: date,
                pageAtteinte: pageAtteinte
            ).insert(connexion)

            return
        }

        // La journee ne compte qu une entree par chapitre, et cette entree
        // porte la derniere lecture connue. Reculer la date ferait remonter une
        // ligne dans la liste au moment ou l utilisateur revient en arriere
        // dans le chapitre.
        entree.dateLecture = max(entree.dateLecture, date)
        entree.pageAtteinte = pageAtteinte

        try entree.update(connexion)
    }

    private static func entree(depuis ligne: Row) -> EntreeDHistorique {
        EntreeDHistorique(
            id: ligne["id"],
            chapitreId: ligne["chapitreId"],
            serieId: ligne["serieId"],
            titreDeLaSerie: ligne["titreDeLaSerie"],
            numeroDeChapitre: ligne["numeroDeChapitre"],
            titreDuChapitre: ligne["titreDuChapitre"],
            dateLecture: ligne["dateLecture"],
            cheminCouvertureLocale: ligne["cheminCouvertureLocale"],
            urlCouverture: ligne["urlCouverture"]
        )
    }
}
