import Foundation

//
// AdresseDuPair
//
// L adresse de la machine au bout d une connexion entrante, et la seule
// question que le pont navigateur lui pose : vient elle de cet appareil.
//
// Le type vit dans Core, pour la meme raison que la liste blanche de domaines :
// la decision se prend a deux etages qui ne se connaissent pas. L ecoute s en
// sert pour couper une connexion avant de lire un octet, le serveur s en sert
// pour refuser une requete qu on lui apporte deja lue. Une regle ecrite a cote
// du socket ne serait verifiable qu en ouvrant un port, donc ne serait pas
// verifiee.
//
// Trois refus sont poses ici plutot que laisses a l appelant, et les trois
// viennent d une facon connue de faire passer une machine distante pour locale.
//
// Le premier est le nom. `localhost` n est pas une adresse, c est un nom que le
// fichier des hotes de la machine peut faire pointer n importe ou. Le pont
// n accepte donc que des adresses numeriques, et un nom, quel qu il soit, est
// refuse.
//
// Le deuxieme est le prefixe. Tester que l adresse commence par `127.` laisse
// passer `127.0.0.1.exemple.net`, qui est un nom de domaine que n importe qui
// peut faire resoudre vers sa propre machine. L adresse est donc analysee en
// quatre octets, jamais comparee en tete.
//
// Le troisieme est la forme IPv4 mappee. Une ecoute IPv6 sur une pile double
// rapporte une connexion IPv4 sous la forme `::ffff:127.0.0.1`. La refuser
// couperait des connexions legitimes, l accepter sans regarder les quatre
// octets mappes accepterait `::ffff:192.168.1.20`, qui vient du reseau.
//

/// L adresse de la machine qui a ouvert une connexion entrante.
public struct AdresseDuPair: Sendable, Equatable, Hashable {
    /// Adresse telle que le transport la rapporte.
    public let hote: String

    public init(hote: String) {
        self.hote = hote
    }

    /// Le bouclage IPv4, l adresse d une connexion venue de cet appareil.
    public static let bouclageIPv4 = AdresseDuPair(hote: "127.0.0.1")

    /// Le bouclage IPv6, meme chose sur une pile IPv6.
    public static let bouclageIPv6 = AdresseDuPair(hote: "::1")

    /// Vrai quand cette adresse est celle de cet appareil.
    ///
    /// Toute la plage `127.0.0.0/8` compte, et pas seulement `127.0.0.1` : le
    /// systeme repond depuis n importe laquelle de ses adresses de bouclage, et
    /// aucune d elles n est routable hors de la machine.
    public var estLocale: Bool {
        let normalise = Self.normaliser(hote)

        if let octets = Self.octetsIPv4(normalise) {
            return octets[0] == 127
        }

        return Self.estUnBouclageIPv6(normalise)
    }

    /// Retire ce que le transport colle autour d une adresse numerique.
    ///
    /// Les crochets d une adresse IPv6 ecrite pour une adresse reseau, et
    /// l identifiant de zone que le systeme ajoute derriere un pourcent,
    /// `::1%lo0`. Ni l un ni l autre ne change de quelle machine il s agit.
    static func normaliser(_ hote: String) -> String {
        var texte = Substring(hote.trimmingCharacters(in: .whitespaces).lowercased())

        if texte.count >= 2, texte.hasPrefix("["), texte.hasSuffix("]") {
            texte = texte.dropFirst().dropLast()
        }
        if let pourcent = texte.firstIndex(of: "%") {
            texte = texte[texte.startIndex..<pourcent]
        }

        return String(texte)
    }

    /// Les quatre octets d une adresse IPv4 ecrite en clair, ou nul.
    static func octetsIPv4(_ texte: String) -> [UInt8]? {
        let morceaux = texte.split(separator: ".", omittingEmptySubsequences: false)

        guard morceaux.count == 4 else {
            return nil
        }

        var octets: [UInt8] = []

        for morceau in morceaux {
            // La longueur est bornee avant la conversion : sans elle, `0177`
            // passerait pour 177 alors qu il s ecrit en octal dans la plupart
            // des resolveurs, et `00000127` pour 127.
            guard (1...3).contains(morceau.count),
                  morceau.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let valeur = UInt8(morceau)
            else {
                return nil
            }

            octets.append(valeur)
        }

        return octets
    }

    /// Vrai quand cette adresse IPv6 designe cet appareil.
    static func estUnBouclageIPv6(_ texte: String) -> Bool {
        guard let groupes = groupesIPv6(texte), groupes.count == 8 else {
            return false
        }
        if groupes == [0, 0, 0, 0, 0, 0, 0, 1] {
            return true
        }

        // Forme IPv4 mappee : les quatre octets mappes decident, et le premier
        // d entre eux occupe la moitie haute du septieme groupe.
        return groupes[0..<5].allSatisfy { $0 == 0 } && groupes[5] == 0xFFFF && groupes[6] >> 8 == 127
    }

    /// Les huit groupes d une adresse IPv6, forme abregee comprise, ou nul.
    static func groupesIPv6(_ texte: String) -> [UInt16]? {
        let cotes = texte.components(separatedBy: "::")

        guard cotes.count <= 2, texte.contains(":") else {
            return nil
        }
        guard let gauche = groupesSimples(cotes[0]) else {
            return nil
        }
        guard cotes.count == 2 else {
            return gauche.count == 8 ? gauche : nil
        }
        guard let droite = groupesSimples(cotes[1]), gauche.count + droite.count < 8 else {
            return nil
        }

        return gauche + Array(repeating: 0, count: 8 - gauche.count - droite.count) + droite
    }

    /// Les groupes d une portion sans abreviation, forme IPv4 finale comprise.
    private static func groupesSimples(_ portion: String) -> [UInt16]? {
        guard portion.isEmpty == false else {
            return []
        }

        let morceaux = portion.components(separatedBy: ":")
        var groupes: [UInt16] = []

        for (index, morceau) in morceaux.enumerated() {
            if index == morceaux.count - 1, morceau.contains(".") {
                guard let octets = octetsIPv4(morceau) else {
                    return nil
                }

                groupes.append(UInt16(octets[0]) << 8 | UInt16(octets[1]))
                groupes.append(UInt16(octets[2]) << 8 | UInt16(octets[3]))

                continue
            }

            guard (1...4).contains(morceau.count), let valeur = UInt16(morceau, radix: 16) else {
                return nil
            }

            groupes.append(valeur)
        }

        return groupes
    }
}
