import Core
import Foundation
import GRDB

//
// MagasinDeFicheDeSerie
//
// Seul point d acces a la fiche de serie de la section 5.6 de DESIGN-SPEC.md :
// metadonnees, liste des chapitres avec leur etat de telechargement, filtre et
// tri persistes, et les ecritures que la liste declenche.
//

/// Erreurs que la fiche de serie peut remonter jusqu a l interface.
public enum ErreurDeFicheDeSerie: Error, Sendable, Equatable {
    /// La serie visee n existe pas ou plus. L appelant revient a la
    /// bibliotheque plutot que d afficher une fiche vide.
    case serieInconnue(identifiant: UUID)
}

/// Lit et ecrit la fiche d une serie et sa liste de chapitres.
public struct MagasinDeFicheDeSerie: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Fiche complete, chapitres filtres et tries selon le reglage persiste.
    ///
    /// Tout est lu dans une seule transaction. La serie, ses chapitres et son
    /// reglage sont donc toujours coherents entre eux, meme si un
    /// telechargement se termine pendant la lecture.
    public func fiche(deLaSerie identifiant: UUID) throws -> FicheDeSerie {
        try base.ecrivain.read { connexion in
            guard let serie = try Manga.fetchOne(connexion, key: identifiant) else {
                throw ErreurDeFicheDeSerie.serieInconnue(identifiant: identifiant)
            }

            let nomDeLaSource = try String.fetchOne(
                connexion,
                sql: "SELECT nom FROM source WHERE id = ?",
                arguments: [serie.sourceId]
            ) ?? ""

            return try FicheDeSerie(
                serie: serie,
                nomDeLaSource: nomDeLaSource,
                tousLesChapitres: Self.chapitres(connexion, deLaSerie: identifiant),
                reglage: Self.reglage(connexion, pourSerie: identifiant)
            )
        }
    }

    /// Filtre et tri persistes pour cette serie.
    ///
    /// Une serie que l utilisateur n a jamais reglee rend le reglage par
    /// defaut, sans ecrire de ligne.
    public func reglage(pourSerie identifiant: UUID) throws -> ReglageDeListeDeChapitres {
        try base.ecrivain.read { connexion in
            try Self.reglage(connexion, pourSerie: identifiant)
        }
    }

    // MARK: Ecriture

    /// Enregistre le filtre et le tri de cette serie.
    ///
    /// L ecriture est un remplacement complet : le reglage est un tout, et une
    /// mise a jour partielle laisserait un tri sans son filtre en cas
    /// d interruption.
    public func definirLeReglage(
        _ reglage: ReglageDeListeDeChapitres,
        pourSerie identifiant: UUID
    ) throws {
        try base.ecrivain.write { connexion in
            guard try Manga.exists(connexion, key: identifiant) else {
                throw ErreurDeFicheDeSerie.serieInconnue(identifiant: identifiant)
            }

            try LigneDeReglageDeListe(mangaId: identifiant, reglage: reglage).save(connexion)
        }
    }

    /// Marque une selection de chapitres comme lue ou non lue.
    ///
    /// Le compteur de chapitres non lus n est pas touche ici : les declencheurs
    /// de `IndexEtDeclencheurs` s en chargent, comme partout ailleurs.
    ///
    /// Marquer lu positionne aussi la date de lecture et la page atteinte, sans
    /// quoi la ligne afficherait `Lu` avec une progression restee a zero.
    public func marquer(
        _ identifiants: [UUID],
        commeLus lus: Bool,
        le date: Date = Date()
    ) throws {
        guard !identifiants.isEmpty else {
            return
        }

        try base.ecrivain.write { connexion in
            for identifiant in identifiants {
                guard var chapitre = try Chapitre.fetchOne(connexion, key: identifiant) else {
                    continue
                }

                chapitre.estLu = lus
                chapitre.dateLecture = lus ? date : nil
                chapitre.pageAtteinte = lus ? max(chapitre.nombrePages - 1, 0) : 0

                try chapitre.update(connexion)
            }
        }
    }

    /// Marque tous les chapitres de la serie comme lus, action `Tout marquer lu`
    /// de la section 5.6.
    public func marquerToutLu(pourSerie identifiant: UUID, le date: Date = Date()) throws {
        let aMarquer = try base.ecrivain.read { connexion in
            try UUID.fetchAll(
                connexion,
                sql: "SELECT id FROM chapitre WHERE mangaId = ? AND estLu = 0",
                arguments: [identifiant]
            )
        }

        try marquer(aMarquer, commeLus: true, le: date)
    }

    // MARK: Acces a la connexion

    /// Chapitres de la serie, augmentes de leur etat de telechargement.
    ///
    /// La jointure remplace un aller retour par chapitre. Une serie de 200000
    /// chapitres, comme le jeu de mesure de la section 12 du cahier de
    /// developpement, ne tiendrait pas la seconde variante.
    private static func chapitres(
        _ connexion: Database,
        deLaSerie identifiant: UUID
    ) throws -> [ChapitreDeFiche] {
        let lignes = try Row.fetchAll(
            connexion,
            sql: """
            SELECT chapitre.*, telechargement.etat AS etatDeTelechargement
            FROM chapitre
            LEFT JOIN telechargement ON telechargement.chapitreId = chapitre.id
            WHERE chapitre.mangaId = ?
            ORDER BY chapitre.ordreDansSerie
            """,
            arguments: [identifiant]
        )

        return try lignes.map { ligne in
            let etat: EtatTelechargement? = ligne["etatDeTelechargement"]

            return try ChapitreDeFiche(
                Chapitre(row: ligne),
                estTelecharge: etat == .termine
            )
        }
    }

    private static func reglage(
        _ connexion: Database,
        pourSerie identifiant: UUID
    ) throws -> ReglageDeListeDeChapitres {
        let ligne = try LigneDeReglageDeListe.fetchOne(connexion, key: identifiant)
        return ligne?.reglage ?? .defaut
    }
}
