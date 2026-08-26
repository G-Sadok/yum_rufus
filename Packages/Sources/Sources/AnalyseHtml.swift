import Core
import Foundation

//
// AnalyseHtml
//
// L analyseur de balisage qui remplit `DocumentHtml`.
//
// Il est tolerant parce qu une page reelle l exige : balises non fermees,
// attributs sans guillemets, commentaires, doctype, script et style. Il ne
// construit jamais rien d executable, et le contenu des balises `script` et
// `style` est jete a la lecture, il n atteint meme pas l arbre.
//

/// L analyseur de balisage, tolerant par necessite.
enum AnalyseHtml {
    /// Balises qui ne se ferment jamais.
    static let balisesVides: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ]

    /// Balises dont le contenu n est pas du balisage et n entre pas dans
    /// l arbre.
    static let balisesOpaques: Set<String> = ["script", "style"]

    /// Construit le tableau d elements d une page.
    static func analyser(_ texte: String) -> [ElementHtml] {
        var constructeur = ConstructeurDeDocument()
        var reste = Substring(texte)

        while let ouverture = reste.firstIndex(of: "<") {
            constructeur.ajouterDuTexte(String(reste[reste.startIndex..<ouverture]))
            reste = reste[ouverture...]

            if let apres = sauterUnCommentaire(reste) {
                reste = apres
                continue
            }

            guard let fermeture = reste.firstIndex(of: ">") else {
                // Un chevron ouvrant sans chevron fermant termine la page. Le
                // reste est du texte, pas une balise tronquee a deviner.
                constructeur.ajouterDuTexte(String(reste))
                reste = reste[reste.endIndex...]
                break
            }

            let balise = reste[reste.index(after: reste.startIndex)..<fermeture]
            reste = reste[reste.index(after: fermeture)...]

            traiter(balise, dans: &constructeur, reste: &reste)
        }

        constructeur.ajouterDuTexte(String(reste))

        return constructeur.terminer()
    }

    /// Traite une balise ouvrante, fermante ou declarative.
    private static func traiter(
        _ balise: Substring,
        dans constructeur: inout ConstructeurDeDocument,
        reste: inout Substring
    ) {
        if balise.first == "!" || balise.first == "?" {
            return
        }
        if balise.first == "/" {
            constructeur.fermer(nom(de: balise.dropFirst()))

            return
        }

        let seFermeElleMeme = balise.last == "/"
        let corps = seFermeElleMeme ? balise.dropLast() : balise
        let nomDeBalise = nom(de: corps)

        guard nomDeBalise.isEmpty == false else {
            return
        }

        let attributs = LectureDAttributs.lire(corps.dropFirst(nomDeBalise.count))

        if balisesOpaques.contains(nomDeBalise) {
            reste = sauterJusquALaFermeture(de: nomDeBalise, dans: reste)

            return
        }

        constructeur.ouvrir(nomDeBalise, attributs: attributs)

        if seFermeElleMeme || balisesVides.contains(nomDeBalise) {
            constructeur.fermer(nomDeBalise)
        }
    }

    /// Le nom de balise en tete d une declaration.
    private static func nom(de balise: Substring) -> String {
        String(balise.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }).lowercased()
    }

    /// Saute un commentaire, et rend ce qui le suit.
    private static func sauterUnCommentaire(_ reste: Substring) -> Substring? {
        guard reste.hasPrefix("<!--") else {
            return nil
        }
        guard let fin = reste.range(of: "-->") else {
            return reste[reste.endIndex...]
        }

        return reste[fin.upperBound...]
    }

    /// Saute le contenu opaque d une balise et sa fermeture.
    private static func sauterJusquALaFermeture(de balise: String, dans reste: Substring) -> Substring {
        guard let fin = reste.range(of: "</\(balise)", options: .caseInsensitive) else {
            return reste[reste.endIndex...]
        }
        guard let apres = reste[fin.upperBound...].firstIndex(of: ">") else {
            return reste[reste.endIndex...]
        }

        return reste[reste.index(after: apres)...]
    }
}

/// Lecture des attributs d une balise ouvrante.
enum LectureDAttributs {
    /// Lit les attributs qui suivent le nom de balise.
    static func lire(_ corps: Substring) -> [String: String] {
        var attributs: [String: String] = [:]
        var reste = corps

        while true {
            reste = reste.drop(while: \.isWhitespace)

            guard reste.isEmpty == false else {
                return attributs
            }

            let nom = reste.prefix { $0.isWhitespace == false && $0 != "=" && $0 != "/" }

            guard nom.isEmpty == false else {
                reste = reste.dropFirst()
                continue
            }

            reste = reste.dropFirst(nom.count).drop(while: \.isWhitespace)

            guard reste.first == "=" else {
                // Un attribut sans valeur vaut son propre nom, comme le veut la
                // norme pour les attributs booleens.
                attributs[nom.lowercased()] = String(nom)
                continue
            }

            reste = reste.dropFirst().drop(while: \.isWhitespace)
            attributs[nom.lowercased()] = EntitesHtml.decoder(valeur(&reste))
        }
    }

    /// Lit une valeur d attribut, avec ou sans guillemets.
    private static func valeur(_ reste: inout Substring) -> String {
        guard let premier = reste.first else {
            return ""
        }

        if premier == "\"" || premier == "'" {
            reste = reste.dropFirst()
            let lue = reste.prefix { $0 != premier }
            reste = reste.dropFirst(lue.count)

            if reste.isEmpty == false {
                reste = reste.dropFirst()
            }

            return String(lue)
        }

        let lue = reste.prefix { $0.isWhitespace == false }
        reste = reste.dropFirst(lue.count)

        return String(lue)
    }
}

/// Construction progressive du tableau d elements.
private struct ConstructeurDeDocument {
    private var balises: [String] = [""]
    private var attributs: [[String: String]] = [[:]]
    private var parents: [Int?] = [nil]
    private var contenus: [[FragmentHtml]] = [[]]
    private var pile: [Int] = [0]

    /// Ajoute du texte a l element courant.
    mutating func ajouterDuTexte(_ texte: String) {
        guard texte.isEmpty == false, let courant = pile.last else {
            return
        }

        contenus[courant].append(.texte(EntitesHtml.decoder(texte)))
    }

    /// Ouvre un element sous l element courant.
    mutating func ouvrir(_ balise: String, attributs nouveaux: [String: String]) {
        guard let courant = pile.last else {
            return
        }

        let index = balises.count

        balises.append(balise)
        attributs.append(nouveaux)
        parents.append(courant)
        contenus.append([])
        contenus[courant].append(.element(index))
        pile.append(index)
    }

    /// Ferme le dernier element portant ce nom.
    ///
    /// Une fermeture qui ne correspond a rien d ouvert est ignoree, et une
    /// fermeture qui saute des niveaux les ferme tous. C est ce que font les
    /// navigateurs, et une page reelle en depend plus souvent qu on ne croit.
    mutating func fermer(_ balise: String) {
        guard let position = pile.lastIndex(where: { balises[$0] == balise }), position > 0 else {
            return
        }

        pile.removeSubrange(position...)
    }

    /// Fige le document.
    func terminer() -> [ElementHtml] {
        balises.indices.map { index in
            ElementHtml(
                index: index,
                parent: parents[index],
                balise: balises[index],
                attributs: attributs[index],
                contenu: contenus[index]
            )
        }
    }
}

/// Decodage des entites de caracteres.
enum EntitesHtml {
    /// Les entites nommees qu une page de catalogue emploie reellement.
    private static let nommees: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00a0}", "eacute": "e", "egrave": "e", "agrave": "a",
        "ccedil": "c", "hellip": "...", "mdash": "-", "ndash": "-",
    ]

    /// Remplace les entites d un texte par ce qu elles designent.
    ///
    /// Une entite inconnue est laissee telle quelle plutot que supprimee : un
    /// titre ou il manque un caractere est plus difficile a diagnostiquer qu un
    /// titre ou une entite reste visible.
    static func decoder(_ texte: String) -> String {
        guard texte.contains("&") else {
            return texte
        }

        var resultat = ""
        var reste = Substring(texte)

        while let debut = reste.firstIndex(of: "&") {
            resultat += reste[reste.startIndex..<debut]
            reste = reste[debut...]

            guard
                let fin = reste.prefix(12).firstIndex(of: ";"),
                let remplacement = remplacement(de: reste[reste.index(after: debut)..<fin])
            else {
                resultat.append("&")
                reste = reste.dropFirst()
                continue
            }

            resultat += remplacement
            reste = reste[reste.index(after: fin)...]
        }

        return resultat + reste
    }

    /// Ce que designe le corps d une entite, ou nul quand il ne designe rien.
    private static func remplacement(de corps: Substring) -> String? {
        guard corps.isEmpty == false else {
            return nil
        }
        guard corps.first == "#" else {
            return nommees[corps.lowercased()]
        }

        let chiffres = corps.dropFirst()
        let valeur = chiffres.first == "x" || chiffres.first == "X"
            ? UInt32(chiffres.dropFirst(), radix: 16)
            : UInt32(chiffres)

        guard let valeur, let scalaire = Unicode.Scalar(valeur) else {
            return nil
        }

        return String(Character(scalaire))
    }
}
