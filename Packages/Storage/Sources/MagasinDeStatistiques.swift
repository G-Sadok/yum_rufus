import Core
import Foundation
import GRDB

//
// MagasinDeStatistiques
//
// Seul point d acces aux statistiques de lecture de F059 : le comptage par
// journee, l objectif quotidien et son rappel.
//
// Le premier critere de la fonctionnalite dit que les statistiques ne
// comptabilisent pas les sessions incognito. La garde est posee ici, au point
// d ecriture, et non plus haut. C est la meme decision que pour la progression
// et l historique, et elle a la meme raison : une garde posee dans une vue ou
// dans un decorateur laisserait ouverts tous les chemins qui ne passent pas par
// elle, et rien ne prouverait qu il n en apparaitra jamais.
//
// L ecriture depuis une transaction deja ouverte existe pour que le comptage
// parte avec la position de lecture qui l a produit. Une fermeture brutale
// entre les deux laisserait sinon un chapitre marque lu que les statistiques
// n auraient jamais compte.
//
// Les lectures ne sont pas gardees. Une session incognito n efface pas ce qui a
// ete compte avant elle, elle cesse de compter : l ecran reste consultable
// pendant la session, il n avance simplement plus.
//

/// Lit et ecrit les statistiques de lecture et l objectif quotidien.
public struct MagasinDeStatistiques: Sendable {
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

    /// Journees comptees, de la plus ancienne a la plus recente.
    public func journees() throws -> [JourneeDeLecture] {
        try base.ecrivain.read { connexion in
            try JourneeDeLecturePersistee
                .order(Column("jour"))
                .fetchAll(connexion)
                .map(\.journee)
        }
    }

    /// Objectif quotidien en vigueur.
    public func objectif() throws -> ObjectifQuotidien {
        try base.ecrivain.write { connexion in
            try Self.ligneUnique(connexion).objectif
        }
    }

    /// Reglage du rappel quotidien.
    public func rappel() throws -> RappelDObjectif {
        try base.ecrivain.write { connexion in
            try Self.ligneUnique(connexion).rappel
        }
    }

    /// Instantane complet, tel que l ecran de statistiques le montre.
    ///
    /// Les journees et l objectif sont lus dans la meme transaction. Un
    /// objectif change pendant la lecture ne peut donc pas donner une serie de
    /// jours calculee moitie avec l ancien, moitie avec le nouveau.
    public func statistiques(
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) throws -> StatistiquesDeLecture {
        try base.ecrivain.write { connexion in
            let journees = try JourneeDeLecturePersistee
                .order(Column("jour"))
                .fetchAll(connexion)
                .map(\.journee)

            return try StatistiquesDeLecture(
                journees: journees,
                objectif: Self.ligneUnique(connexion).objectif,
                le: date,
                calendrier: calendrier
            )
        }
    }

    /// Instant du prochain rappel, nul quand aucun rappel ne doit partir.
    ///
    /// Le calcul vit dans `PlanificationDuRappel`, le magasin ne fait que lui
    /// fournir l etat courant, session incognito comprise.
    public func prochainRappel(
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) throws -> Date? {
        let instantane = try statistiques(le: date, calendrier: calendrier)

        return try PlanificationDuRappel.prochainRappel(
            rappel: rappel(),
            objectif: instantane.objectif,
            chapitresLusAujourdHui: instantane.journeeDuJour.chapitresLus,
            session: incognito.sessionCourante,
            le: date,
            calendrier: calendrier
        )
    }

    // MARK: Ecriture

    /// Ajoute a la journee ce qu un passage de lecture a produit.
    ///
    /// Pendant une session incognito, l appel ne fait rien : le premier critere
    /// de F059 interdit tout comptage tant que la session court.
    ///
    /// - Parameters:
    ///   - chapitresLus: chapitres passes a l etat lu pendant le passage.
    ///   - pagesLues: pages nouvelles parcourues pendant le passage.
    ///   - date: instant du passage.
    ///   - calendrier: calendrier qui delimite le jour civil.
    public func consigner(
        chapitresLus: Int = 0,
        pagesLues: Int = 0,
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) throws {
        guard incognito.autorise(.statistiquesDeLecture) else {
            return
        }

        try base.ecrivain.write { connexion in
            try Self.consigner(
                chapitresLus: chapitresLus,
                pagesLues: pagesLues,
                le: date,
                calendrier: calendrier,
                dans: connexion
            )
        }
    }

    /// Remplace l objectif quotidien.
    public func definirLObjectif(_ objectif: ObjectifQuotidien) throws {
        try base.ecrivain.write { connexion in
            var ligne = try Self.ligneUnique(connexion)
            ligne.chapitresParJour = objectif.chapitresParJour
            try ligne.update(connexion)
        }
    }

    /// Remplace le reglage du rappel.
    public func definirLeRappel(_ rappel: RappelDObjectif) throws {
        try base.ecrivain.write { connexion in
            var ligne = try Self.ligneUnique(connexion)
            ligne.rappelActif = rappel.actif
            ligne.heureDeRappel = rappel.heure
            ligne.minuteDeRappel = rappel.minute
            try ligne.update(connexion)
        }
    }

    // MARK: Acces a la connexion

    /// Ajoute a la journee dans la transaction deja ouverte.
    ///
    /// Employe par `MagasinDeProgression`, pour que la position et le comptage
    /// qu elle produit partent ensemble.
    ///
    /// La garde du mode incognito n est pas repetee ici : l appelant l a deja
    /// posee, et la reposer demanderait de faire circuler le registre jusque
    /// dans une fonction qui n a pas a le connaitre. Les deux points d appel
    /// sont la methode d instance ci dessus et `MagasinDeProgression`, tous
    /// deux gardes.
    static func consigner(
        chapitresLus: Int,
        pagesLues: Int,
        le date: Date,
        calendrier: Calendar,
        dans connexion: Database
    ) throws {
        guard chapitresLus > 0 || pagesLues > 0 else {
            return
        }

        let debutDuJour = calendrier.startOfDay(for: date)

        guard var journee = try JourneeDeLecturePersistee.fetchOne(connexion, key: debutDuJour) else {
            try JourneeDeLecturePersistee(
                jour: debutDuJour,
                chapitresLus: max(chapitresLus, 0),
                pagesLues: max(pagesLues, 0)
            ).insert(connexion)

            return
        }

        journee.chapitresLus += max(chapitresLus, 0)
        journee.pagesLues += max(pagesLues, 0)

        try journee.update(connexion)
    }

    /// Ligne unique de l objectif, reinstallee a sa valeur livree si elle a
    /// disparu.
    ///
    /// La migration ecrit cette ligne. Son absence signale une base abimee, et
    /// la reecrire vaut mieux que de rendre un objectif que rien ne persiste :
    /// il reviendrait autrement au redemarrage suivant.
    static func ligneUnique(_ connexion: Database) throws -> ObjectifPersiste {
        let identifiant = ObjectifPersiste.identifiantDeLaLigneUnique

        if let ligne = try ObjectifPersiste.fetchOne(connexion, key: identifiant) {
            return ligne
        }

        let ligne = ObjectifPersiste()
        try ligne.insert(connexion)

        return ligne
    }
}
