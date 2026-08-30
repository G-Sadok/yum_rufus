import Foundation

//
// ContratsDeVeille
//
// Les deux coutures par lesquelles la veille de F060 touche le reste du
// produit : la ou son etat survit a la fermeture de l application, et la ou une
// notification devient une banniere sur l ecran de verrouillage.
//
// Elles sont definies par `Core`, comme celles de la synchronisation. La raison
// est la meme : le moteur de veille ne doit dependre ni de la base de donnees ni
// du centre de notifications du systeme, sans quoi verifier qu aucune
// notification ne part en mode incognito demanderait un appareil, une
// autorisation accordee a la main et un observateur humain.
//

/// La ou la veille retient ce qu elle a deja vu.
///
/// L etat doit etre persiste et non tenu en memoire. Sans cela, chaque
/// lancement de l application repartirait d un compteur d executions a zero, ce
/// qui viderait le plafond quotidien de son sens, et d une derniere
/// verification inconnue, ce qui ferait renotifier ce qui a deja ete annonce.
public protocol MagasinDeVeille: Sendable {
    /// Etat de la veille, tel que la derniere execution l a laisse.
    func etatDeVeille() async throws -> EtatDeVeille

    /// Enregistre l etat apres une execution.
    func enregistrer(_ etat: EtatDeVeille) async throws

    /// Series de la bibliotheque a surveiller, avec ce qui est deja connu
    /// d elles.
    ///
    /// La liste ne porte que les series reellement dans la bibliotheque. Une
    /// serie seulement consultee dans un catalogue n interesse personne, et
    /// l interroger consommerait le budget d une serie suivie.
    func seriesSurveillees() async throws -> [SerieSurveillee]

    /// Note qu une serie vient d etre relue, avec les chapitres desormais
    /// connus.
    ///
    /// L instant est enregistre meme quand rien n a paru : c est lui qui fait
    /// tourner la file des series, et une serie sans nouveaute repasserait
    /// sinon en tete a chaque execution, empechant les autres d etre vues.
    func enregistrerLaVerification(
        de serie: UUID,
        chapitresConnus: Set<String>,
        le date: Date
    ) async throws
}

/// La ou une notification quitte l application.
///
/// Le protocole ne parle ni de `UNNotificationRequest`, ni de fil, ni de son.
/// Il parle de notifications de serie, et c est ce qui permet a la couche metier
/// de garantir le regroupement : elle rend une notification par serie, et
/// l adaptateur du systeme n a plus la possibilite d en emettre davantage.
public protocol CentreDeNotifications: Sendable {
    /// Vrai quand l utilisateur a accorde les notifications.
    func autorisationAccordee() async -> Bool

    /// Emet ces notifications, une par serie.
    func publier(_ notifications: [NotificationDeSerie]) async throws
}
