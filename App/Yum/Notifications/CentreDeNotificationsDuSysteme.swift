import Core
import DesignSystem
import Foundation
import UserNotifications

//
// CentreDeNotificationsDuSysteme
//
// L adaptateur entre la veille de F060 et le centre de notifications du
// systeme. Il ne decide de rien : il recoit des notifications deja regroupees
// par serie et les depose telles quelles.
//
// C est voulu, et c est ce qui tient le deuxieme critere. Un adaptateur libre de
// construire ses propres demandes pourrait en emettre une par chapitre sans que
// rien ne l en empeche. Ici, le nombre de demandes deposees est par
// construction le nombre de notifications recues, et la couche metier en fournit
// une par serie.
//
// L identifiant de la demande est celui de la serie. Une notification qui
// remplace la precedente pour la meme serie est donc une mise a jour, pas une
// seconde banniere : l utilisateur qui n a pas ouvert celle d hier n en trouve
// pas deux ce matin.
//

/// Depose les notifications de nouveaux chapitres dans le centre du systeme.
///
/// C est un acteur et non une structure parce que `UNUserNotificationCenter`
/// n est pas `Sendable`, et que la veille est un acteur qui l appelle depuis son
/// propre contexte. L isolation d acteur est la reponse exacte : la reference au
/// centre du systeme ne traverse aucune frontiere, et rien n a besoin d etre
/// declare sur non verifie.
actor CentreDeNotificationsDuSysteme: CentreDeNotifications {
    private let centre: UNUserNotificationCenter
    private let libelles: LibellesDeNotificationsDeChapitres

    init(
        centre: UNUserNotificationCenter = .current(),
        libelles: LibellesDeNotificationsDeChapitres = .duCatalogue
    ) {
        self.centre = centre
        self.libelles = libelles
    }

    /// Vrai quand l utilisateur a accorde les notifications.
    ///
    /// L etat provisoire compte comme accorde : le systeme laisse alors les
    /// notifications arriver discretement, ce qui est exactement l usage de
    /// cette fonction.
    func autorisationAccordee() async -> Bool {
        switch await centre.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }

    /// Demande l autorisation, une seule fois, au premier armement de la ligne
    /// de reglages.
    ///
    /// Rend l etat obtenu plutot que de lever : un refus est une reponse de
    /// l utilisateur, pas une erreur de programmation.
    @discardableResult
    func demanderLAutorisation() async -> Bool {
        await (try? centre.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Depose une demande par serie.
    func publier(_ notifications: [NotificationDeSerie]) async throws {
        for notification in notifications {
            try await centre.add(demande(pour: notification))
        }
    }

    /// Demande du systeme correspondant a une notification de serie.
    private func demande(pour notification: NotificationDeSerie) -> UNNotificationRequest {
        let contenu = UNMutableNotificationContent()
        contenu.title = TexteDeNotificationDeChapitres.titre(de: notification)
        contenu.body = TexteDeNotificationDeChapitres.corps(de: notification, libelles: libelles)

        // Le fil range les notifications successives d une meme serie dans la
        // meme pile chez l utilisateur.
        contenu.threadIdentifier = notification.identifiantDeRegroupement

        return UNNotificationRequest(
            identifier: notification.identifiantDeRegroupement,
            content: contenu,
            trigger: nil
        )
    }
}
