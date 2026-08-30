import Foundation

//
// SerieSynchronisee
//
// La presence d une serie dans la bibliotheque, telle qu elle voyage entre
// deux appareils.
//
// La charge est volontairement courte : l identifiant de la serie, sa presence
// dans la bibliotheque, et la date de son ajout. Elle ne transporte ni titre,
// ni couverture, ni chapitres. Ces trois choses viennent de la source, qui les
// redonne identiques sur chaque appareil ; les faire circuler ferait payer un
// aller retour reseau pour recopier ce que l appareil sait deja retrouver, et
// ferait diverger deux appareils dont les sources ne sont pas a la meme
// version.
//
// Ce qui n y est pas encore, et qui est un choix, pas un oubli : les
// categories. Elles ont leur propre table de liaison et leur propre ordre, donc
// leur propre resolution de conflit, qui n est pas celle d un etat unique par
// cle. Les faire entrer ici demanderait de fusionner deux ensembles, ce que la
// regle par horodatage ne sait pas faire sans perdre une categorie ajoutee des
// deux cotes.
//

/// La presence d une serie dans la bibliotheque, telle qu elle circule.
public struct SerieSynchronisee: Sendable, Codable, Hashable {
    /// Serie concernee, meme identifiant sur tous les appareils.
    public let mangaId: UUID

    /// Vrai quand la serie est dans la bibliotheque.
    ///
    /// Un retrait circule comme une presence : c est une valeur, pas une
    /// absence de ligne. Une ligne effacee ne se distinguerait pas d une ligne
    /// jamais recue, et la serie retiree sur un appareil reviendrait au premier
    /// echange complet.
    public let estDansBibliotheque: Bool

    /// Date d ajout a la bibliotheque, qui decide du rang dans la grille.
    public let dateAjout: Date

    /// Instant du changement sur l appareil qui l a produit.
    public let dateDeChangement: Date

    public init(
        mangaId: UUID,
        estDansBibliotheque: Bool,
        dateAjout: Date,
        dateDeChangement: Date
    ) {
        self.mangaId = mangaId
        self.estDansBibliotheque = estDansBibliotheque
        self.dateAjout = dateAjout
        self.dateDeChangement = dateDeChangement
    }

    /// Etat tire d une serie persistee.
    public init(_ manga: Manga, le date: Date) {
        self.init(
            mangaId: manga.id,
            estDansBibliotheque: manga.estDansBibliotheque,
            dateAjout: manga.dateAjout,
            dateDeChangement: date
        )
    }

    /// Cle de journal de cette serie.
    public var cle: CleDeChangement {
        CleDeChangement(entite: .serieDeBibliotheque, identifiant: mangaId)
    }

    /// Ligne de journal correspondante, produite par cet appareil.
    public func changement(depuis appareil: String) throws -> ChangementSynchronise {
        try ChangementSynchronise(
            cle: cle,
            charge: CodageDeSynchronisation.encoder(self),
            horodatage: dateDeChangement,
            appareil: appareil
        )
    }

    /// Serie relue depuis une ligne de journal.
    public static func lire(_ changement: ChangementSynchronise) throws -> SerieSynchronisee {
        try CodageDeSynchronisation.decoder(
            SerieSynchronisee.self,
            depuis: changement,
            attendue: .serieDeBibliotheque
        )
    }
}
