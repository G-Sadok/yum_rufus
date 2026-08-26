import Core
import Foundation

//
// FormulaireDeDepot
//
// La lecture des deux formulaires que le navigateur envoie a la reception
// Wi-Fi : celui du code, en `application/x-www-form-urlencoded`, et celui des
// fichiers, en `multipart/form-data`.
//
// Le decoupage multipartie est ecrit ici plutot que confie a `URLSession` ou a
// un analyseur generique, parce qu aucune API du systeme ne lit ce format en
// entree : elles savent toutes l ecrire, en client, aucune ne le relit en
// serveur. Le format est simple et fige depuis 1998, et il tient en un
// decoupage sur une frontiere.
//
// Un point merite d etre nomme, parce qu il est la cause des fichiers deposes
// corrompus d un octet dans les serveurs de depot ecrits a la va vite. Le
// `\r\n` qui precede la frontiere de fin appartient a la frontiere, pas au
// contenu. Le retirer apres coup marche pour un fichier texte et casse une
// archive, dont les deux derniers octets peuvent tres bien etre ceux la. Le
// decoupage ci dessous borne donc le contenu avant ce `\r\n`, sans jamais
// retirer d octets du contenu lui meme.
//

/// Un champ d un formulaire multipartie.
struct ChampDeDepot: Sendable, Equatable {
    /// Nom du champ dans le formulaire.
    let nom: String

    /// Nom de fichier propose par le navigateur, nul pour un champ de texte.
    let nomDeFichier: String?

    /// Octets du champ.
    let contenu: Data

    /// Le champ porte un fichier, meme vide.
    var estUnFichier: Bool {
        nomDeFichier != nil
    }
}

/// Lecture des formulaires envoyes par la page de depot.
enum FormulaireDeDepot {
    /// Lit un formulaire `application/x-www-form-urlencoded`.
    static func champsEncodes(_ corps: Data) -> [String: String] {
        guard let texte = String(data: corps, encoding: .utf8) else {
            return [:]
        }

        var champs: [String: String] = [:]

        for morceau in texte.split(separator: "&") {
            let paire = morceau.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard let nom = decoder(String(paire[0])), nom.isEmpty == false else {
                continue
            }

            champs[nom] = paire.count == 2 ? decoder(String(paire[1])) ?? "" : ""
        }

        return champs
    }

    /// Lit un formulaire `multipart/form-data`.
    ///
    /// - Throws: `ErreurDeTransfert.requeteMalformee` quand la frontiere est
    ///   absente du corps ou qu une partie n a pas d entetes lisibles.
    static func champsMultipartie(_ corps: Data, frontiere: String) throws -> [ChampDeDepot] {
        guard frontiere.isEmpty == false else {
            throw ErreurDeTransfert.requeteMalformee
        }

        let separateur = Data("--\(frontiere)".utf8)
        let saut = Data("\r\n".utf8)

        guard var curseur = corps.range(of: separateur)?.upperBound else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var champs: [ChampDeDepot] = []

        while curseur < corps.endIndex {
            // La frontiere de fin porte deux tirets de plus.
            if corps.subdata(in: curseur..<min(curseur + 2, corps.endIndex)) == Data("--".utf8) {
                return champs
            }
            guard let apresSaut = corps.range(of: saut, in: curseur..<corps.endIndex)?.upperBound,
                  let finDesEntetes = corps.range(
                      of: Data(CadrageDeRequete.finDesEntetes.utf8),
                      in: curseur..<corps.endIndex
                  )
            else {
                throw ErreurDeTransfert.requeteMalformee
            }

            let entetes = try entetesDeLaPartie(corps.subdata(in: apresSaut..<finDesEntetes.lowerBound))
            let debutDuContenu = finDesEntetes.upperBound

            guard let prochaine = corps.range(of: separateur, in: debutDuContenu..<corps.endIndex) else {
                throw ErreurDeTransfert.requeteMalformee
            }

            // Le saut de ligne qui precede la frontiere lui appartient.
            let finDuContenu = max(debutDuContenu, prochaine.lowerBound - saut.count)
            let disposition = entetes["content-disposition"] ?? ""

            guard let nom = parametre("name", de: disposition) else {
                throw ErreurDeTransfert.requeteMalformee
            }

            champs.append(
                ChampDeDepot(
                    nom: nom,
                    nomDeFichier: nomDeFichier(de: disposition),
                    contenu: corps.subdata(in: debutDuContenu..<finDuContenu)
                )
            )

            curseur = prochaine.upperBound
        }

        return champs
    }

    // MARK: Details

    /// Entetes d une partie, noms ramenes en minuscules.
    private static func entetesDeLaPartie(_ octets: Data) throws -> [String: String] {
        guard let texte = String(data: octets, encoding: .utf8) else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var entetes: [String: String] = [:]

        for ligne in texte.components(separatedBy: "\r\n") where ligne.isEmpty == false {
            let paire = ligne.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

            guard paire.count == 2 else {
                throw ErreurDeTransfert.requeteMalformee
            }

            entetes[paire[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                paire[1].trimmingCharacters(in: .whitespaces)
        }

        return entetes
    }

    /// Le nom de fichier annonce par une disposition de contenu.
    ///
    /// La forme etendue `filename*=UTF-8''...` est lue en premier, parce que
    /// c est celle qu envoient les navigateurs quand le nom sort de l ASCII, et
    /// que la forme simple qui l accompagne alors est deja abimee.
    private static func nomDeFichier(de disposition: String) -> String? {
        if let etendu = parametre("filename*", de: disposition) {
            let sansJeu = etendu.components(separatedBy: "''").last ?? etendu

            return sansJeu.removingPercentEncoding ?? sansJeu
        }

        return parametre("filename", de: disposition)
    }

    /// Un parametre d entete, guillemets retires.
    private static func parametre(_ nom: String, de entete: String) -> String? {
        for morceau in entete.split(separator: ";") {
            let paire = morceau.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard paire.count == 2,
                  paire[0].trimmingCharacters(in: .whitespaces).lowercased() == nom.lowercased()
            else {
                continue
            }

            let valeur = paire[1].trimmingCharacters(in: .whitespaces)

            return valeur.hasPrefix("\"") && valeur.hasSuffix("\"") && valeur.count >= 2
                ? String(valeur.dropFirst().dropLast())
                : valeur
        }

        return nil
    }

    /// Decode une valeur de formulaire, ou le signe plus vaut espace.
    private static func decoder(_ valeur: String) -> String? {
        valeur.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }
}
