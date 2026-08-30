import Core
import Foundation

//
// Textes des notifications de nouveaux chapitres, F060.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// Le corps est compose ici plutot que par l adaptateur du systeme, pour la meme
// raison que la sous ligne d une ligne de chapitre : il depend de ce qui est
// paru. Un chapitre unique ne se dit pas comme quatorze, et un chapitre dont la
// source ne publie aucun titre ne compose pas la meme phrase.
//
// La notification ne cite jamais le nombre de chapitres non lus ni la
// progression de lecture. Elle dit ce qui vient de paraitre, rien de ce que
// l utilisateur a lu : la section 11 interdit d ecrire une trace de lecture, et
// une banniere sur l ecran de verrouillage se lit par dessus l epaule.
//

/// Textes d une notification de nouveaux chapitres.
public struct LibellesDeNotificationsDeChapitres: Sendable, Equatable {
    /// Motif du corps quand un seul chapitre est paru, `Chapitre %@ est paru`.
    public let unChapitre: String

    /// Motif du corps quand plusieurs chapitres sont parus,
    /// `%1$lld nouveaux chapitres, jusqu au chapitre %2$@`.
    ///
    /// Les deux valeurs sont numerotees parce que toutes les langues du
    /// catalogue ne les placent pas dans le meme ordre : le japonais nomme le
    /// dernier chapitre avant le nombre. Sans numero, `String(format:)` les
    /// echangerait en silence.
    public let plusieursChapitres: String

    public init(unChapitre: String, plusieursChapitres: String) {
        self.unChapitre = unChapitre
        self.plusieursChapitres = plusieursChapitres
    }
}

/// Composition du titre et du corps d une notification de serie.
public enum TexteDeNotificationDeChapitres {
    /// Titre de la notification, le nom de la serie et rien d autre.
    ///
    /// C est ce qui rend le regroupement lisible : la pile d une serie porte son
    /// nom en tete, et le corps dit seulement ce qui vient de s y ajouter.
    public static func titre(de notification: NotificationDeSerie) -> String {
        notification.titreDeLaSerie
    }

    /// Corps de la notification, qui dit ce qui est paru.
    ///
    /// Rend une chaine vide quand la notification ne porte aucun chapitre, cas
    /// qu aucun chemin du produit ne construit : `RegroupementDeNotifications`
    /// n en fabrique pas.
    public static func corps(
        de notification: NotificationDeSerie,
        libelles: LibellesDeNotificationsDeChapitres
    ) -> String {
        guard let dernier = notification.dernierChapitre else {
            return ""
        }

        let numero = TexteDeChapitre.numero(dernier.numero)

        guard notification.nombreDeChapitres > 1 else {
            return String(format: libelles.unChapitre, numero)
        }

        return String(
            format: libelles.plusieursChapitres,
            notification.nombreDeChapitres,
            numero
        )
    }
}
