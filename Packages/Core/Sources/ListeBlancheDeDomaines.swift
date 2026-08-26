import Foundation

//
// ListeBlancheDeDomaines
//
// La liste blanche de la section 4.3 : chaque extension tourne derriere les
// domaines declares dans son manifeste, et toute requete hors liste est
// bloquee.
//
// Le type est dans Core et non dans Sources parce que trois couches en ont
// besoin sans se connaitre. Le manifeste s en sert pour refuser une adresse de
// base hors liste. L ecran d installation s en sert pour afficher a
// l utilisateur ce qu il confirme. Le transport s en sert pour bloquer. Une
// liste blanche qui vivrait a cote du transport obligerait l ecran a en
// dependre.
//
// Trois refus sont poses ici plutot que laisses a la charge de l appelant, et
// les trois viennent d une facon connue de contourner une liste blanche.
//
// Le premier est l adresse numerique. Une extension autorisee a joindre une
// adresse IP peut joindre 127.0.0.1, donc le serveur de transfert Wi-Fi de la
// section 4.4, qui tourne sur la meme machine. La section 4.3 interdit l acces
// aux autres sources, ce refus la en fait partie.
//
// Le deuxieme est le nom sans point, `localhost` en tete, pour la meme raison.
//
// Le troisieme est le nom non ASCII. Un nom de domaine international se compare
// sous sa forme punycode, celle que rend `URL.host()`. Comparer une forme
// Unicode declaree a une forme punycode observee ne correspondrait jamais, et
// deux ecritures Unicode differentes du meme nom se compareraient comme
// differentes. Le manifeste declare donc la forme punycode, et la forme Unicode
// est refusee au lieu d etre convertie en silence.
//

/// Un domaine que l extension a le droit de joindre.
public struct DomaineAutorise: Sendable, Hashable, Comparable {
    /// Nom d hote, en minuscules, sans point final.
    public let hote: String

    /// Vrai quand les sous domaines sont couverts, forme `*.exemple.net`.
    public let inclutLesSousDomaines: Bool

    public init(hote: String, inclutLesSousDomaines: Bool = false) {
        self.hote = hote
        self.inclutLesSousDomaines = inclutLesSousDomaines
    }

    /// Analyse la forme declaree dans un manifeste.
    ///
    /// - Throws: `ErreurDExtension.domaineMalForme` quand le texte n est pas un
    ///   nom d hote joignable par une extension.
    public init(_ texte: String) throws {
        let normalise = texte.trimmingCharacters(in: .whitespaces).lowercased()
        let sansEtoile = normalise.hasPrefix("*.") ? String(normalise.dropFirst(2)) : normalise
        let sansPointFinal = sansEtoile.hasSuffix(".") ? String(sansEtoile.dropLast()) : sansEtoile

        guard Self.estUnHoteJoignable(sansPointFinal) else {
            throw ErreurDExtension.domaineMalForme(domaine: texte)
        }

        hote = sansPointFinal
        inclutLesSousDomaines = normalise.hasPrefix("*.")
    }

    /// Forme textuelle, celle qui s affiche et qui se relit par `init(_:)`.
    public var texte: String {
        inclutLesSousDomaines ? "*." + hote : hote
    }

    /// Vrai quand ce domaine couvre l hote observe.
    ///
    /// L hote est normalise avant comparaison : `EXEMPLE.NET.` et `exemple.net`
    /// designent la meme machine, et laisser passer la difference reviendrait a
    /// n avoir aucune liste blanche.
    public func couvre(_ hoteObserve: String) -> Bool {
        let observe = Self.normaliser(hoteObserve)

        guard observe.isEmpty == false else {
            return false
        }
        if observe == hote {
            return true
        }

        return inclutLesSousDomaines && observe.hasSuffix("." + hote)
    }

    public static func < (gauche: DomaineAutorise, droite: DomaineAutorise) -> Bool {
        gauche.texte < droite.texte
    }

    /// Ramene un hote observe a la forme sous laquelle il se compare.
    static func normaliser(_ hote: String) -> String {
        let minuscule = hote.trimmingCharacters(in: .whitespaces).lowercased()

        return minuscule.hasSuffix(".") ? String(minuscule.dropLast()) : minuscule
    }

    /// Vrai quand ce nom est un hote qu une extension a le droit de joindre.
    static func estUnHoteJoignable(_ hote: String) -> Bool {
        let etiquettes = hote.split(separator: ".", omittingEmptySubsequences: false)

        guard etiquettes.count >= 2, hote.count <= 253 else {
            return false
        }
        guard etiquettes.allSatisfy(estUneEtiquetteValable) else {
            return false
        }

        // Un dernier segment entierement numerique signale une adresse IPv4
        // ecrite en clair. Un vrai domaine de premier niveau ne l est jamais.
        return etiquettes.last?.allSatisfy(\.isNumber) == false
    }

    /// Vrai quand une etiquette respecte la forme d un nom de domaine ASCII.
    private static func estUneEtiquetteValable(_ etiquette: Substring) -> Bool {
        guard (1...63).contains(etiquette.count) else {
            return false
        }
        guard etiquette.first != "-", etiquette.last != "-" else {
            return false
        }

        return etiquette.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }
}

extension DomaineAutorise: Codable {
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        try self.init(conteneur.decode(String.self))
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        try conteneur.encode(texte)
    }
}

/// Les domaines qu une extension a le droit de joindre, et rien d autre.
public struct ListeBlancheDeDomaines: Sendable, Hashable {
    /// Les domaines declares, dedoublonnes et tries.
    ///
    /// Tries parce que cette liste est celle que l utilisateur lit avant de
    /// confirmer, et qu une liste dont l ordre change d un affichage a l autre
    /// se relit mal. Dedoublonnee pour la meme raison.
    public let domaines: [DomaineAutorise]

    public init(domaines: [DomaineAutorise]) {
        self.domaines = Set(domaines).sorted()
    }

    /// Vrai quand la liste ne couvre rien, donc quand elle bloque tout.
    public var estVide: Bool {
        domaines.isEmpty
    }

    /// Vrai quand un des domaines couvre cet hote.
    public func autorise(_ hote: String) -> Bool {
        domaines.contains { $0.couvre(hote) }
    }

    /// Vrai quand cette adresse est joignable par l extension.
    ///
    /// Deux conditions, jamais une seule. Le schema doit etre HTTPS, comme la
    /// section 11 l exige de toute requete, et sans exception locale possible
    /// ici : l exception de la section 11 vise un serveur que l utilisateur a
    /// configure lui meme, pas un domaine choisi par un tiers. L hote doit
    /// ensuite figurer dans la liste.
    public func autorise(_ adresse: URL) -> Bool {
        guard adresse.scheme?.lowercased() == "https", let hote = adresse.host() else {
            return false
        }

        return autorise(hote)
    }

    /// L hote d une adresse, ou nul quand elle n en porte pas.
    ///
    /// Sert au journal de refus, qui nomme le domaine que l extension a tente
    /// de joindre.
    public static func hote(de adresse: URL) -> String? {
        adresse.host().map(DomaineAutorise.normaliser)
    }
}
