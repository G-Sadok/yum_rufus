import Core
import Foundation
import GRDB

//
// MagasinDeTelechargements, requetes
//
// Les lectures que le magasin fait sur une connexion deja ouverte, rangees a
// part de ses commandes.
//
// La separation n est pas cosmetique. Deux d entre elles, la file et les
// reglages, sont passees telles quelles a `ValueObservation` pour alimenter le
// flux de l ecran de suivi. Une fonction observee doit rester une lecture pure,
// sans ecriture ni effet de bord, sinon l observation se reveille elle meme sans
// fin. Les garder groupees rend la regle visible.
//

extension MagasinDeTelechargements {
    /// File entiere, jointe a son chapitre et a sa serie, deja triee.
    ///
    /// La jointure remplace deux allers retours par ligne : la ligne de la
    /// section 4.11 porte le titre de la serie et le numero du chapitre, que la
    /// table `telechargement` ne connait pas.
    static func taches(_ connexion: Database) throws -> [TelechargementAffiche] {
        let lignes = try Row.fetchAll(
            connexion,
            sql: """
            SELECT telechargement.id AS id,
                   telechargement.chapitreId AS chapitreId,
                   telechargement.etat AS etat,
                   telechargement.priorite AS priorite,
                   telechargement.pagesTerminees AS pagesTerminees,
                   telechargement.nombreDePages AS nombreDePages,
                   telechargement.octetsRecus AS octetsRecus,
                   telechargement.octetsTotal AS octetsTotal,
                   telechargement.dateAjout AS dateAjout,
                   telechargement.messageErreur AS messageErreur,
                   chapitre.numero AS numeroDeChapitre,
                   chapitre.titre AS titreDuChapitre,
                   manga.id AS serieId,
                   manga.titre AS titreDeLaSerie
            FROM telechargement
            JOIN chapitre ON chapitre.id = telechargement.chapitreId
            JOIN manga ON manga.id = chapitre.mangaId
            """
        )

        return OrdreDeLaFile.trier(lignes.map(affiche(depuis:)))
    }

    /// Ligne de la file lue depuis la jointure.
    static func affiche(depuis ligne: Row) -> TelechargementAffiche {
        TelechargementAffiche(
            id: ligne["id"],
            chapitreId: ligne["chapitreId"],
            serieId: ligne["serieId"],
            titreDeLaSerie: ligne["titreDeLaSerie"],
            numeroDeChapitre: ligne["numeroDeChapitre"],
            titreDuChapitre: ligne["titreDuChapitre"],
            etat: ligne["etat"],
            priorite: ligne["priorite"],
            pagesTerminees: ligne["pagesTerminees"] ?? 0,
            nombreDePages: ligne["nombreDePages"] ?? 0,
            octetsRecus: ligne["octetsRecus"] ?? 0,
            octetsTotal: ligne["octetsTotal"],
            dateAjout: ligne["dateAjout"],
            messageErreur: ligne["messageErreur"]
        )
    }

    /// Reglages du sous ecran, defauts du cahier compris.
    ///
    /// La restriction au Wi-Fi vient du catalogue de reglages, ou elle est une
    /// ligne de l ecran Reglages. La limite simultanee vient d une cle propre au
    /// sous ecran, que le catalogue ignore.
    static func reglages(_ connexion: Database) throws -> ReglagesDeTelechargement {
        let simultanes = try ReglagePersiste
            .filter(key: cleDesSimultanes)
            .fetchOne(connexion)
            .flatMap { Int($0.valeur) }

        let enWiFiSeulement = try MagasinDeReglages
            .lire(connexion)
            .booleen(.enWiFiSeulement)

        return ReglagesDeTelechargement(
            simultanes: simultanes ?? ReglagesDeTelechargement.limiteParDefaut,
            enWiFiSeulement: enWiFiSeulement
        )
    }

    /// Tache posee sur ce chapitre, nulle quand il n est pas en file.
    static func tache(_ connexion: Database, pourLeChapitre chapitre: UUID) throws -> Telechargement? {
        try Telechargement.filter(Column("chapitreId") == chapitre).fetchOne(connexion)
    }

    /// Longueur du chapitre telle que la base la connait deja.
    ///
    /// La source la corrigera au demarrage de la tache. La lire ici evite que la
    /// ligne affiche `0 sur 0 pages` entre la mise en file et le demarrage, ce
    /// qui arrive des que la limite simultanee est atteinte.
    static func nombreDePages(_ connexion: Database, _ chapitre: UUID) throws -> Int {
        try Chapitre.fetchOne(connexion, key: chapitre)?.nombrePages ?? 0
    }

    /// Leve quand le chapitre vise n existe pas.
    static func verifierLeChapitre(_ connexion: Database, _ identifiant: UUID) throws {
        guard try Chapitre.filter(key: identifiant).fetchCount(connexion) > 0 else {
            throw ErreurDeTelechargement.chapitreInconnu(identifiant: identifiant)
        }
    }
}
