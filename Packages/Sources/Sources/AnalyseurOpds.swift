import Core
import Foundation

//
// AnalyseurOpds
//
// Le choix de la version du protocole, fait reponse par reponse.
//
// Le tableau 4.2 demande les deux versions, et la question qui vient ensuite
// est de savoir laquelle s applique. La reponse retenue ici est de ne jamais le
// demander a l utilisateur, et de ne jamais le decider a la configuration de la
// source. Un meme catalogue sert regulierement les deux : Komga publie
// `/opds/v1.2` et `/opds/v2`, et un catalogue en 2.0 peut renvoyer vers un flux
// Atom pour une section ancienne. La version est donc une propriete de la
// reponse, pas du serveur.
//
// Elle se lit dans le type de contenu quand le serveur en annonce un
// d exploitable, et dans le premier caractere utile du corps sinon. Le second
// chemin n est pas une precaution theorique : un proxy inverse mal regle
// annonce `text/plain` ou `application/octet-stream` sur les deux versions, et
// un catalogue serait alors declare illisible alors que ses octets sont
// parfaitement valables.
//
// L ordre compte. Le type de contenu d abord, parce qu il est ce que le serveur
// affirme. Le premier caractere ensuite, parce qu il ne se trompe que sur un
// document qui n est ni du XML ni du JSON, et qui n aurait donc rien donne.
//

/// Les deux versions du protocole OPDS.
enum VersionOpds: Sendable, Hashable {
    /// OPDS 1.2, un document Atom.
    case atom

    /// OPDS 2.0, un document JSON.
    case json
}

/// Lecture d un flux OPDS, quelle que soit sa version.
enum AnalyseurOpds {
    /// Ce que la source annonce accepter, les deux versions dans l ordre de
    /// preference.
    ///
    /// La 2.0 est demandee en premier parce qu elle porte plus de metadonnees
    /// pour moins d octets. Un serveur qui ne la sert pas ignore la preference
    /// et rend son flux Atom, ce que la negociation de contenu prevoit.
    static let typesAcceptes = [
        TypeOpds.fluxJson,
        TypeOpds.fluxAtom + ";" + TypeOpds.profilDeCatalogue,
        TypeOpds.fluxAtom,
    ].joined(separator: ", ")

    /// Analyse la reponse d un serveur OPDS.
    ///
    /// - Throws: `ErreurReseau.reponseVide` quand le corps ne porte rien, et
    ///   `ErreurReseau.reponseIllisible` quand il ne decrit aucun flux dans
    ///   aucune des deux versions.
    static func analyser(_ reponse: ReponseHttp) throws -> FluxOpds {
        guard reponse.corps.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }

        let version = version(de: reponse)

        guard let flux = analyser(reponse.corps, version: version) else {
            throw ErreurReseau.reponseIllisible
        }

        return flux
    }

    /// Analyse des octets dans la version nommee, puis dans l autre.
    ///
    /// Le second essai existe parce que la version deduite reste une deduction.
    /// Un serveur qui annonce `application/xml` sur un flux JSON est un defaut
    /// de configuration frequent, et refuser le catalogue pour cette raison la
    /// ferait porter a l utilisateur une erreur qu il ne peut pas corriger.
    static func analyser(_ donnees: Data, version: VersionOpds) -> FluxOpds? {
        switch version {
        case .atom:
            AnalyseAtomOpds.analyser(donnees) ?? AnalyseJsonOpds.analyser(donnees)
        case .json:
            AnalyseJsonOpds.analyser(donnees) ?? AnalyseAtomOpds.analyser(donnees)
        }
    }

    /// La version que cette reponse porte, d apres son type puis ses octets.
    static func version(de reponse: ReponseHttp) -> VersionOpds {
        if let annoncee = version(duType: reponse.entete("Content-Type")) {
            return annoncee
        }

        return version(desOctets: reponse.corps)
    }

    /// La version qu annonce un type de contenu, ou nul quand il ne dit rien.
    private static func version(duType type: String?) -> VersionOpds? {
        guard let type = type?.lowercased() else {
            return nil
        }
        if type.contains("atom") || type.contains("xml") {
            return .atom
        }
        if type.contains("json") {
            return .json
        }

        return nil
    }

    /// La version que trahit le premier caractere utile du corps.
    ///
    /// Seuls les premiers octets sont examines : une marque d ordre, quelques
    /// blancs et une declaration XML tiennent largement dedans, et lire le
    /// document entier pour en connaitre le premier caractere serait payer deux
    /// fois la meme lecture.
    private static func version(desOctets corps: Data) -> VersionOpds {
        let entete = corps.prefix(octetsExamines)

        for octet in entete {
            switch octet {
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                return .json
            case UInt8(ascii: "<"):
                return .atom
            default:
                continue
            }
        }

        return .atom
    }

    /// Nombre d octets de tete examines pour deduire la version.
    private static let octetsExamines = 64
}
