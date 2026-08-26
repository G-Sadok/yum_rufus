import Foundation

//
// CodageXdr
//
// L encodage XDR, sur lequel ONC RPC et NFS sont batis.
//
// Il tient en trois regles, et elles expliquent tout ce fichier. Les entiers
// sont sur trente deux ou soixante quatre bits, en gros boutien. Les suites
// d octets portent leur longueur devant. Et tout est aligne sur quatre octets,
// ce qui veut dire qu une chaine de cinq octets en occupe huit.
//
// Oublier le remplissage est l erreur qui decale tout ce qui suit sans rien
// casser tout de suite : le champ suivant se lit de travers, et le symptome
// apparait trois champs plus loin, sur une valeur qui n a rien a voir. C est
// pour cela que le calcul du bourrage vit dans un seul endroit, et que les deux
// sens de l encodage vivent cote a cote.
//

/// Ecriture d une suite d octets au format XDR.
struct EcritureXdr {
    private var contenu = Data()

    /// Les octets ecrits jusqu ici.
    var octets: Data {
        contenu
    }

    mutating func entier32(_ valeur: UInt32) {
        contenu.append(UInt8(valeur >> 24 & 0xFF))
        contenu.append(UInt8(valeur >> 16 & 0xFF))
        contenu.append(UInt8(valeur >> 8 & 0xFF))
        contenu.append(UInt8(valeur & 0xFF))
    }

    mutating func entier64(_ valeur: UInt64) {
        entier32(UInt32(valeur >> 32 & 0xFFFF_FFFF))
        entier32(UInt32(valeur & 0xFFFF_FFFF))
    }

    mutating func booleen(_ valeur: Bool) {
        entier32(valeur ? 1 : 0)
    }

    /// Ecrit des octets precedes de leur longueur, puis le remplissage.
    mutating func variable(_ octets: Data) {
        entier32(UInt32(octets.count))
        fixe(octets)
    }

    /// Ecrit des octets sans longueur, puis le remplissage.
    mutating func fixe(_ octets: Data) {
        contenu.append(octets)
        contenu.append(Data(repeating: 0, count: EcritureXdr.remplissage(octets.count)))
    }

    mutating func texte(_ valeur: String) {
        variable(Data(valeur.utf8))
    }

    mutating func ajouter(_ autre: Data) {
        contenu.append(autre)
    }

    /// Nombre d octets de bourrage a ajouter pour retomber sur quatre.
    static func remplissage(_ longueur: Int) -> Int {
        (4 - longueur % 4) % 4
    }
}

/// Lecture d une suite d octets au format XDR.
///
/// Chaque lecture avance la position et rend nul quand il ne reste pas assez
/// d octets. Rendre nul plutot que lever laisse l appelant nommer lui meme ce
/// qui manquait, et une reponse tronquee devient un cas nomme au lieu d un
/// plantage sur un index hors bornes.
struct LectureXdr {
    private let octets: Data
    private(set) var position: Int

    init(_ octets: Data) {
        self.octets = octets
        position = 0
    }

    var reste: Int {
        max(0, octets.count - position)
    }

    mutating func entier32() -> UInt32? {
        guard reste >= 4 else {
            return nil
        }

        let debut = octets.startIndex + position
        var valeur: UInt32 = 0

        for decalage in 0..<4 {
            valeur = valeur << 8 | UInt32(octets[debut + decalage])
        }

        position += 4

        return valeur
    }

    mutating func entier64() -> UInt64? {
        guard let haut = entier32(), let bas = entier32() else {
            return nil
        }

        return UInt64(haut) << 32 | UInt64(bas)
    }

    mutating func booleen() -> Bool? {
        entier32().map { $0 != 0 }
    }

    /// Lit des octets precedes de leur longueur, remplissage compris.
    mutating func variable() -> Data? {
        guard let longueur = entier32() else {
            return nil
        }

        return fixe(Int(longueur))
    }

    /// Lit un nombre connu d octets, remplissage compris.
    mutating func fixe(_ longueur: Int) -> Data? {
        guard longueur >= 0, reste >= longueur else {
            return nil
        }

        let debut = octets.startIndex + position
        let contenu = octets.subdata(in: debut..<(debut + longueur))
        let bourrage = EcritureXdr.remplissage(longueur)

        guard reste >= longueur + bourrage else {
            // Le dernier champ d une reponse peut arriver sans son bourrage
            // quand le serveur borne sa trame. Le contenu reste valable.
            position = octets.count

            return contenu
        }

        position += longueur + bourrage

        return contenu
    }

    /// Lit une chaine, dont la norme impose qu elle soit en UTF 8.
    ///
    /// Un nom de fichier qui ne se decode pas rend la chaine vide plutot que
    /// nul : le champ etait bien la, c est son contenu qui est douteux, et
    /// arreter tout le listage d un dossier pour un nom mal encode ferait
    /// disparaitre les series voisines.
    mutating func texte() -> String? {
        variable().map { String(bytes: $0, encoding: .utf8) ?? "" }
    }

    /// Saute un nombre d octets, sans remplissage.
    mutating func sauter(_ longueur: Int) -> Bool {
        guard reste >= longueur else {
            return false
        }

        position += longueur

        return true
    }
}
