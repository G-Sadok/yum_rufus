import Foundation

//
// JournalDuStockage
//
// Ce que la gestion du stockage demande a la base, declare ici pour la meme
// raison que `JournalDeTelechargements` : le nettoyage vit dans le paquet
// Sources, la bibliotheque vit dans Storage, et Sources ne depend pas de
// Storage.
//
// Le protocole ne porte que deux methodes, et c est deliberement peu. Nommer les
// postes d un ecran de detail demande une jointure que seule la base sait faire,
// mais cette jointure sert un ecran, pas le nettoyage : elle reste du cote de
// Storage, qui la rend directement a l application.
//

/// Ce que le nettoyage apres lecture lit et ecrit dans la bibliotheque.
public protocol JournalDuStockage: Sendable {
    /// Chapitres lus parmi ceux dont le telechargement est pose sur le disque.
    ///
    /// La liste entrante vient du disque et non de la base. Un chapitre efface
    /// de la bibliotheque dont le dossier est reste ne figure dans aucun
    /// resultat, et le nettoyage ne le touche pas : il n a plus de date de
    /// lecture, donc plus de reglage qui l autorise a partir.
    func chapitresLus(parmi chapitres: [UUID]) async throws -> [TelechargementLu]

    /// Retire de la file les taches des chapitres qui viennent d etre effaces.
    ///
    /// Sans cet oubli, la file garderait des lignes `Termine` qui ne designent
    /// plus rien, et la fiche de serie continuerait d annoncer un chapitre
    /// telecharge que le disque ne porte plus.
    func oublierLesTelechargements(de chapitres: [UUID]) async throws
}
