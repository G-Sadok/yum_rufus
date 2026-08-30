import Foundation

//
// EnvoiDuNavigateur
//
// Ce qu une extension de navigateur envoie au pont : une serie vue sur une page
// ouverte, reduite a son adresse et a son titre.
//
// Le corps est du JSON et non un formulaire. Le pont n est pas une page, il n a
// aucun formulaire a servir, et l extension parle a une interface de programme.
//
// Trois refus sont poses ici plutot que laisses a l appelant, et les trois
// tiennent au fait que ce corps vient de l exterieur.
//
// L adresse doit etre en HTTPS. La section 11 l exige de toute requete, et
// l exception locale qu elle prevoit vise un serveur que l utilisateur a
// configure lui meme, pas une adresse choisie par une extension. Ce refus la
// ferme aussi le chemin le plus court vers une lecture de fichier : sans lui,
// `file:///` arriverait jusqu a la couche qui ouvre l adresse.
//
// Le titre doit exister. Une extension qui envoie une serie lit le titre de la
// page qu elle regarde, et une entree sans titre n est affichable nulle part.
//
// Les deux champs sont bornes. Un titre de plusieurs mega octets ou une adresse
// de la meme taille traversent le plafond du corps sans le declencher, et
// finiraient en base.
//

/// Une serie envoyee au pont depuis une page ouverte dans le navigateur.
public struct EnvoiDuNavigateur: Sendable, Equatable, Hashable {
    /// Longueur maximale du titre, en caracteres.
    public static let plafondDuTitre = 300

    /// Longueur maximale de l adresse, en caracteres.
    ///
    /// Deux mille quarante huit est la borne que les serveurs et les
    /// navigateurs appliquent en pratique a une adresse. Une adresse plus
    /// longue ne serait de toute facon joignable par personne.
    public static let plafondDeLAdresse = 2048

    /// Adresse de la page qui porte la serie.
    public let adresse: URL

    /// Titre de la serie, tel que la page l affiche.
    public let titre: String

    public init(adresse: URL, titre: String) {
        self.adresse = adresse
        self.titre = titre
    }

    /// Lit un envoi depuis le corps JSON d une requete.
    ///
    /// - Throws: `ErreurDuPont.envoiIllisible` quand le corps n est pas un envoi
    ///   lisible, et `ErreurDuPont.adresseRefusee` quand l adresse est lisible
    ///   mais n est pas une adresse que le pont accepte.
    public static func analyser(_ octets: Data) throws -> EnvoiDuNavigateur {
        guard let brut = try? JSONDecoder().decode(EnvoiEcrit.self, from: octets) else {
            throw ErreurDuPont.envoiIllisible
        }

        let titre = brut.titre.trimmingCharacters(in: .whitespacesAndNewlines)

        guard titre.isEmpty == false, titre.count <= plafondDuTitre else {
            throw ErreurDuPont.envoiIllisible
        }
        guard brut.adresse.count <= plafondDeLAdresse, let adresse = URL(string: brut.adresse) else {
            throw ErreurDuPont.envoiIllisible
        }
        guard accepte(adresse) else {
            throw ErreurDuPont.adresseRefusee
        }

        return EnvoiDuNavigateur(adresse: adresse, titre: titre)
    }

    /// Vrai quand le pont accepte de transmettre cette adresse.
    public static func accepte(_ adresse: URL) -> Bool {
        guard adresse.scheme?.lowercased() == "https", let hote = adresse.host() else {
            return false
        }

        return hote.isEmpty == false
    }
}

/// Le corps tel qu il arrive sur le fil, avant toute verification.
///
/// Il est prive et separe du type du domaine : ce qui sort de `JSONDecoder` n a
/// franchi aucun des trois refus, et lui donner le nom du type du domaine
/// laisserait passer un envoi non verifie a la premiere distraction.
private struct EnvoiEcrit: Decodable {
    let adresse: String
    let titre: String
}

/// Ce qui prend en charge une serie envoyee par le navigateur.
///
/// Le protocole vit dans Core, a cote de `ProtocoleDeSource`, parce que le
/// serveur et la couche qui range dans la bibliotheque ne doivent pas dependre
/// l un de l autre. Les tests en fournissent une implementation qui n ecrit
/// nulle part.
public protocol ReceptionDuNavigateur: Sendable {
    /// Prend en charge une serie envoyee depuis le navigateur.
    ///
    /// - Throws: `ErreurDuPont.receptionImpossible` quand l envoi ne peut pas
    ///   etre pris en charge. L extension n a rien a faire d une cause plus
    ///   precise, et une cause precise dirait a une page ce que la bibliotheque
    ///   contient deja.
    func recevoir(_ envoi: EnvoiDuNavigateur) async throws
}
