import Core
import Foundation

//
// ServeurDuPontNavigateur
//
// Le serveur du pont de la section 9 : une extension de navigateur envoie une
// serie vue sur une page ouverte, et l application la prend en charge.
//
// C est un acteur pour la meme raison que le serveur de la reception Wi-Fi :
// son ouverture est un etat partage, lu et ecrit par autant de taches qu il y a
// de connexions.
//
// Le serveur ne connait pas le reseau. Il recoit une requete deja lue et
// l adresse de la machine qui l a envoyee, et rend une reponse. Le refus d une
// connexion non locale, le refus d un jeton et le refus d un envoi mal forme se
// prouvent donc sans ouvrir de port. L ouverture reelle est l affaire de
// `PointDEcoute`, la duree de vie celle de `PontNavigateur`.
//
// L ordre des refus n est pas arbitraire, et chacun de ses trois etages porte
// une promesse.
//
// Le pont ferme repond avant tout le reste. Un pont desactive n a ni jeton a
// comparer ni chemin a servir, et le dire tout de suite evite qu une lecture de
// trousseau soit declenchee par une requete arrivee sur un pont qui n existe
// pas.
//
// L adresse du pair passe ensuite, avant meme l authentification. Une machine
// du reseau ne doit pas pouvoir se servir du pont comme d un oracle a jetons,
// ce qu elle ferait si un jeton faux et un jeton juste lui rendaient deux
// reponses differentes.
//
// L authentification passe avant l acheminement, et non l inverse. Sans jeton
// juste, tous les chemins repondent la meme chose : un chemin inconnu ne se
// distingue pas d un chemin servi, et la forme de l interface reste invisible
// a qui n a pas le jeton.
//
// Le jeton est relu au magasin a chaque requete, jamais garde ici. C est ce qui
// rend la revocation immediate : effacer la ligne du trousseau suffit a faire
// refuser la requete suivante, sans redemarrage, sans expiration a attendre.
// Une copie gardee en memoire, meme rafraichie souvent, ouvrirait exactement la
// fenetre que le critere interdit.
//
// Aucun entete de partage entre origines n est pose, et c est un choix. Une
// extension de navigateur qui declare cette adresse dans ses permissions
// d hotes fait ses requetes depuis son propre contexte, ou la regle d origine
// ne s applique pas. Poser une autorisation d origine large rendrait en
// revanche le pont joignable depuis n importe quelle page ouverte dans le
// navigateur, ce qui reviendrait a offrir le jeton a la premiere page qui le
// devine.
//

/// Les chemins servis par le pont navigateur.
enum CheminsDuPont {
    /// Le seul chemin qui accepte quelque chose, en POST.
    static let serie = "/serie"
}

/// Le serveur du pont navigateur, sans son transport.
public actor ServeurDuPontNavigateur {
    /// Taille maximale du corps d une requete.
    ///
    /// Un envoi porte une adresse et un titre, donc quelques centaines
    /// d octets. Le plafond est large au regard de cela et minuscule au regard
    /// de la memoire de l appareil : c est ce qui empeche une application
    /// locale de faire tomber le pont en annoncant un corps enorme.
    public static let plafondDuCorps = 64 * 1024

    private let jetons: any MagasinDeJetonDuPont
    private let reception: any ReceptionDuNavigateur

    private var ouvert = false

    public init(jetons: any MagasinDeJetonDuPont, reception: any ReceptionDuNavigateur) {
        self.jetons = jetons
        self.reception = reception
    }

    /// Vrai tant que le pont sert des requetes.
    public var estOuvert: Bool {
        ouvert
    }

    /// Ouvre le pont, qui se met a servir.
    public func ouvrir() {
        ouvert = true
    }

    /// Ferme le pont : plus aucune requete n est servie ensuite.
    public func fermer() {
        ouvert = false
    }

    /// Repond aux octets d une requete, tels qu ils arrivent du transport.
    func repondre(auxOctets octets: Data, depuis adresse: AdresseDuPair) async -> Data {
        guard ouvert else {
            return refus(.pontDesactive).octets
        }
        guard adresse.estLocale else {
            return refus(.connexionNonLocale).octets
        }

        do {
            return try await repondre(a: RequeteDeDepot.analyser(octets), depuis: adresse).octets
        } catch {
            return refus(.requeteMalformee).octets
        }
    }

    /// Repond a une requete deja lue.
    func repondre(a requete: RequeteDeDepot, depuis adresse: AdresseDuPair) async -> ReponseDeDepot {
        guard ouvert else {
            return refus(.pontDesactive)
        }
        guard adresse.estLocale else {
            return refus(.connexionNonLocale)
        }
        if let refuse = await authentifier(requete) {
            return refus(refuse)
        }

        switch (requete.methode, requete.chemin) {
        case ("POST", CheminsDuPont.serie):
            return await recevoir(requete)
        case (_, CheminsDuPont.serie):
            return refus(.methodeNonAutorisee, entetes: ["Allow": "POST"])
        default:
            return refus(.cheminInconnu)
        }
    }

    // MARK: Jeton

    /// Rend la cause du refus, ou nul quand la requete presente le bon jeton.
    private func authentifier(_ requete: RequeteDeDepot) async -> ErreurDuPont? {
        let range: JetonDuPont?

        do {
            range = try await jetons.jeton()
        } catch {
            // Le trousseau a refuse de rendre la ligne. Ce n est pas un refus
            // d authentification, c est une panne de cet appareil, et l annoncer
            // comme un jeton faux ferait chercher a l utilisateur un probleme
            // qui n est pas la ou il croit.
            return .receptionImpossible
        }

        guard let range, let presente = Self.jetonPresente(dans: requete) else {
            return .jetonAbsent
        }

        return range.correspond(a: presente) ? nil : .jetonRefuse
    }

    /// Le jeton porte par l entete d autorisation, ou nul.
    ///
    /// Le nom du schema est compare en minuscules, comme la norme le demande :
    /// une extension qui ecrit `bearer` presente un jeton parfaitement valable.
    private static func jetonPresente(dans requete: RequeteDeDepot) -> String? {
        guard let entete = requete.entete("authorization") else {
            return nil
        }

        let morceaux = entete.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

        guard morceaux.count == 2, morceaux[0].lowercased() == "bearer" else {
            return nil
        }

        return String(morceaux[1]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Envoi

    /// Traite un envoi de serie.
    private func recevoir(_ requete: RequeteDeDepot) async -> ReponseDeDepot {
        guard requete.typeDeContenu == "application/json", requete.corps.count <= Self.plafondDuCorps else {
            return refus(.envoiIllisible)
        }

        let envoi: EnvoiDuNavigateur

        do {
            envoi = try EnvoiDuNavigateur.analyser(requete.corps)
        } catch let erreur as ErreurDuPont {
            return refus(erreur)
        } catch {
            return refus(.envoiIllisible)
        }

        do {
            try await reception.recevoir(envoi)
        } catch {
            return refus(.receptionImpossible)
        }

        // 202 et non 201 : le pont ne cree rien lui meme, il transmet a la
        // couche qui range, et l extension n a aucune adresse a suivre.
        return .json(Self.corpsJson(["resultat": "recue"]), code: 202)
    }

    // MARK: Details

    private func refus(_ cause: ErreurDuPont, entetes: [String: String] = [:]) -> ReponseDeDepot {
        var complets = entetes

        if cause.codeHttp == 401 {
            complets["WWW-Authenticate"] = "Bearer"
        }

        return .json(
            Self.corpsJson(["erreur": cause.codeDeJournal, "message": cause.messageUtilisateur]),
            code: cause.codeHttp,
            entetes: complets
        )
    }

    /// Encode un objet JSON plat.
    ///
    /// Les cles sont triees pour que deux reponses de meme contenu s ecrivent
    /// pareil, ce qui rend les tests lisibles sans les rendre fragiles. Un
    /// echec d encodage rend un corps vide plutot que de lever : le code de
    /// statut porte deja le refus, et une reponse sans corps reste une reponse.
    private static func corpsJson(_ champs: [String: String]) -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return (try? encodeur.encode(champs)) ?? Data()
    }
}

extension ErreurDuPont {
    /// Code de statut qui correspond a ce refus.
    ///
    /// La correspondance vit ici et non dans Core : le domaine n a pas a
    /// connaitre HTTP, et le pont est le seul endroit ou ces erreurs deviennent
    /// des reponses.
    var codeHttp: Int {
        switch self {
        case .pontDesactive: 503
        case .connexionNonLocale: 403
        case .jetonAbsent, .jetonRefuse: 401
        case .requeteMalformee, .envoiIllisible, .adresseRefusee: 400
        case .cheminInconnu: 404
        case .methodeNonAutorisee: 405
        case .receptionImpossible: 500
        }
    }
}
