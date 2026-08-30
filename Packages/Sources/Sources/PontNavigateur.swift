import Core
import Foundation

//
// PontNavigateur
//
// La duree de vie du pont de la section 9, et le seul endroit du projet ou la
// socket locale s ouvre et se ferme.
//
// La section 9 ne demande pas seulement un pont, elle demande un pont inactif
// par defaut. Cette promesse ne peut pas tenir dans une vue : une vue peut
// disparaitre, etre remplacee, ou ne jamais etre affichee, et l ecoute resterait
// alors ouverte jusqu a la fin du processus. Elle tient donc ici, en trois
// points.
//
// Rien ne s ouvre tant que `activer` n a pas ete appelee, et `appliquer` ne
// l appelle que sur un reglage a vrai. Le reglage vaut faux au catalogue, donc
// sur une installation neuve, et le pont est alors un objet qui n a ouvert
// aucun port et tire aucun jeton.
//
// Un jeton existe des que le pont est actif, et jamais avant. L ordre compte :
// le jeton est en place avant que le port ne s ouvre, sans quoi une requete
// arrivee dans l intervalle trouverait un pont ouvert sans jeton, donc un pont
// qui refuse tout, ce qui ressemble a une panne.
//
// La desactivation arrete l ecoute avant de fermer le serveur, comme la
// reception Wi-Fi : fermer le serveur d abord laisserait un port ouvert repondre
// pendant le temps de l arret, ce qui annonce a l appareil qu il y a bien
// quelque chose ici.
//
// La desactivation ne revoque pas le jeton, et c est volontaire. Le jeton est
// colle dans l extension, sur cet appareil, par l utilisateur. Le lui faire
// recopier a chaque fois qu il coupe puis rallume le pont le pousserait a ne
// plus jamais le couper. La revocation est un geste explicite, `revoquer`, et
// elle est immediate.
//

/// Le pont navigateur, du reglage jusqu a la socket.
public actor PontNavigateur {
    /// Port sur lequel le pont ecoute.
    ///
    /// Il est fixe parce que l extension doit savoir ou frapper sans avoir a
    /// chercher, et il est pris dans la plage dynamique, au dela de 49152, ou
    /// aucun service n est enregistre. Un port deja occupe fait echouer
    /// l activation plutot que glisser vers un autre : un pont qui ecoute
    /// ailleurs que la ou l extension appelle est un pont muet qu on croit
    /// ouvert.
    public static let portParDefaut: UInt16 = 51842

    private let jetons: any MagasinDeJetonDuPont
    private let ecoute: any PointDEcoute
    private let serveur: ServeurDuPontNavigateur

    private var portOuvert: UInt16?

    public init(
        reception: any ReceptionDuNavigateur,
        jetons: any MagasinDeJetonDuPont = TrousseauDuPont(),
        ecoute: any PointDEcoute = PontNavigateur.ecouteParDefaut()
    ) {
        self.jetons = jetons
        self.ecoute = ecoute
        serveur = ServeurDuPontNavigateur(jetons: jetons, reception: reception)
    }

    /// L ecoute livree : le port du pont, bornee au bouclage.
    ///
    /// Elle est fabriquee par une fonction et non ecrite en valeur par defaut
    /// parce qu une valeur par defaut serait partagee par tous les appelants,
    /// alors qu une ecoute porte l etat d un ecouteur ouvert.
    public static func ecouteParDefaut() -> any PointDEcoute {
        EcouteHttpLocale(
            port: portParDefaut,
            plafondDuCorps: ServeurDuPontNavigateur.plafondDuCorps,
            bouclageSeulement: true
        )
    }

    /// Vrai quand la socket est ouverte.
    public var estActif: Bool {
        portOuvert != nil
    }

    /// Port ouvert, ou nul tant que le pont est inactif.
    public var port: UInt16? {
        portOuvert
    }

    /// Ouvre la socket, apres avoir assure qu un jeton existe.
    ///
    /// - Throws: `ErreurDeTrousseau` quand le jeton ne peut pas etre range, et
    ///   `ErreurReseau` quand le port ne peut pas etre pris.
    @discardableResult
    public func activer() async throws -> UInt16 {
        if let portOuvert {
            return portOuvert
        }

        try await jetons.jetonOuNouveau()

        await serveur.ouvrir()

        let serveur = serveur
        let obtenu = try await ecoute.demarrer { octets, adresse in
            await serveur.repondre(auxOctets: octets, depuis: adresse)
        }

        portOuvert = obtenu

        return obtenu
    }

    /// Ferme la socket, sans revoquer le jeton.
    public func desactiver() async {
        guard portOuvert != nil else {
            return
        }

        portOuvert = nil

        await ecoute.arreter()
        await serveur.fermer()
    }

    /// Met le pont dans l etat que les reglages decrivent.
    ///
    /// C est le seul chemin que la couche vue emprunte. Sur une installation
    /// neuve, le reglage vaut faux et cet appel ne fait rien : ni port ouvert,
    /// ni jeton tire, ni ligne de trousseau creee.
    ///
    /// - Throws: ce que `activer` leve, et seulement quand le reglage est actif.
    public func appliquer(_ reglages: ReglagesDeLApplication) async throws {
        guard reglages.booleen(.activerLePontNavigateur) else {
            return await desactiver()
        }

        try await activer()
    }

    /// Le jeton a coller dans l extension, ou nul quand le pont n en a pas.
    public func jetonAPartager() async throws -> JetonDuPont? {
        try await jetons.jeton()
    }

    /// Revoque le jeton, tout de suite.
    ///
    /// La socket reste ouverte : ce que l utilisateur revoque est l acces d une
    /// extension, pas le pont lui meme, et un renouvellement suit en general
    /// dans la foulee. La requete suivante est refusee, meme si elle presente le
    /// jeton d avant et meme si elle arrive dans la milliseconde, parce que le
    /// serveur relit le magasin a chaque requete au lieu d en garder une copie.
    public func revoquer() async throws {
        try await jetons.revoquer()
    }

    /// Revoque le jeton en place et en tire un neuf.
    @discardableResult
    public func renouvelerLeJeton() async throws -> JetonDuPont {
        try await jetons.renouveler()
    }
}
