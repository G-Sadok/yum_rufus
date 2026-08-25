import Foundation

//
// IdentifiantsDeSource
//
// Ce qu une source presente pour prouver qui elle est, d apres la section 11 du
// cahier de developpement. Mot de passe, cle d API, jeton : trois formes, un
// seul type, un seul endroit ou les ranger, le trousseau du systeme.
//
// Le type est volontairement absent de `Codable`, et ce n est pas un oubli.
// C est la garantie de structure des trois criteres de la fonctionnalite. Un
// type qui ne sait pas s encoder ne peut pas atterrir dans `UserDefaults`, qui
// n accepte que des valeurs de liste de proprietes, ni dans une colonne de la
// base, qui passe par un encodeur, ni dans le JSON de sauvegarde, qui encode ce
// qu on lui donne. Le seul chemin qui reste est celui du trousseau, qui encode
// par `CodageDIdentifiants` et le fait explicitement.
//
// Ajouter une conformance a `Codable` a ce type rouvrirait les trois fuites a
// la fois. La suite de tests le verifie a l execution, parce que le compilateur
// ne sait pas interdire une conformance.
//

/// Forme d authentification attendue par une source.
///
/// Elle vit dans la configuration de la source, qui elle est persistee et
/// exportee : l interface a besoin de savoir quels champs presenter avant
/// meme de lire le trousseau, et cette information ne dit rien du secret.
public enum NatureDAuthentification: String, Sendable, Codable, CaseIterable, Hashable {
    /// Catalogue ouvert, dossier local, partage sans mot de passe.
    case aucune

    /// Compte et mot de passe, l authentification basique de Komga et de OPDS.
    case basique

    /// Cle d API unique, celle de Jellyfin.
    case cleDApi

    /// Jeton d acces avec rafraichissement, celui de Kavita.
    case jeton
}

/// Identifiants de connexion d une source, tels qu ils vivent dans le trousseau.
///
/// Aucune valeur de ce type ne doit etre journalisee : la description et la
/// description de debogage sont toutes deux caviardees, parce que la section 11
/// interdit d ecrire un identifiant dans un journal, et que le point
/// d interpolation dans une chaine est exactement l endroit ou la regle se
/// perd.
public enum IdentifiantsDeSource: Sendable, Hashable {
    /// La source ne demande rien.
    case aucun

    /// Compte et mot de passe. Le compte est range dans le trousseau avec le
    /// mot de passe, et non dans la configuration : la ligne du trousseau se
    /// suffit alors a elle meme, et la configuration exportee ne porte aucune
    /// trace du compte de l utilisateur.
    case basique(compte: String, motDePasse: String)

    /// Cle d API unique.
    case cleDApi(String)

    /// Jeton d acces, avec son jeton de rafraichissement et son echeance quand
    /// le service en publie.
    case jeton(acces: String, rafraichissement: String? = nil, expiration: Date? = nil)

    /// Forme d authentification correspondante, telle qu elle est persistee.
    public var nature: NatureDAuthentification {
        switch self {
        case .aucun: .aucune
        case .basique: .basique
        case .cleDApi: .cleDApi
        case .jeton: .jeton
        }
    }

    /// Vrai quand il n y a rien a ranger dans le trousseau.
    public var estVide: Bool {
        nature == .aucune
    }

    /// Les chaines qui ne doivent apparaitre nulle part ailleurs que dans le
    /// trousseau.
    ///
    /// Le compte ne figure pas dans cette liste : ce n est pas un secret, c est
    /// un nom. Ce que la liste sert a verifier, ce sont les mots de passe, les
    /// cles et les jetons, qui eux ne sortent jamais.
    ///
    /// Elle existe pour les controles de redaction : un test qui balaie un
    /// export ou une ligne de base a besoin de savoir quoi chercher, et le lui
    /// faire recopier a la main garantirait qu il oublie le cas ajoute demain.
    public var valeursSecretes: [String] {
        switch self {
        case .aucun:
            []
        case let .basique(_, motDePasse):
            [motDePasse]
        case let .cleDApi(cle):
            [cle]
        case let .jeton(acces, rafraichissement, _):
            [acces] + (rafraichissement.map { [$0] } ?? [])
        }
    }

    /// Nom du compte, quand la forme en porte un.
    public var compte: String? {
        guard case let .basique(compte, _) = self else {
            return nil
        }

        return compte
    }
}

extension IdentifiantsDeSource: CustomStringConvertible, CustomDebugStringConvertible {
    /// Description caviardee, qui nomme la forme sans jamais rendre le secret.
    public var description: String {
        "IdentifiantsDeSource.\(nature.rawValue)"
    }

    public var debugDescription: String {
        description
    }
}

/// Encodage des identifiants vers les octets ranges dans le trousseau.
///
/// C est le seul encodeur du projet qui a le droit de voir un secret, et il est
/// nomme pour cela. `IdentifiantsDeSource` ne conforme pas a `Codable`
/// justement pour qu aucun encodeur generique, celui de la base ou celui de la
/// sauvegarde, ne puisse serialiser un secret par accident.
public enum CodageDIdentifiants {
    /// Representation intermediaire, confinee a ce fichier.
    ///
    /// Elle est nommee champ par champ plutot que derivee de l enumeration :
    /// l encodage synthetise par le compilateur pour une enumeration a valeurs
    /// associees change de forme au moindre renommage de cas, et le trousseau
    /// deja ecrit sur les appareils, lui, ne change pas.
    private struct Charge: Codable {
        var nature: String
        var compte: String?
        var secret: String?
        var rafraichissement: String?
        var expiration: Date?
    }

    /// Octets a ranger dans le trousseau.
    public static func encoder(_ identifiants: IdentifiantsDeSource) throws -> Data {
        let charge = switch identifiants {
        case .aucun:
            Charge(nature: NatureDAuthentification.aucune.rawValue)
        case let .basique(compte, motDePasse):
            Charge(nature: NatureDAuthentification.basique.rawValue, compte: compte, secret: motDePasse)
        case let .cleDApi(cle):
            Charge(nature: NatureDAuthentification.cleDApi.rawValue, secret: cle)
        case let .jeton(acces, rafraichissement, expiration):
            Charge(
                nature: NatureDAuthentification.jeton.rawValue,
                secret: acces,
                rafraichissement: rafraichissement,
                expiration: expiration
            )
        }

        return try JSONEncoder().encode(charge)
    }

    /// Identifiants relus depuis les octets du trousseau.
    ///
    /// - Throws: `ErreurDeTrousseau.donneeIllisible` quand les octets ne sont
    ///   pas ceux que `encoder(_:)` produit, et
    ///   `ErreurDeTrousseau.identifiantsIncomplets` quand la forme est connue
    ///   mais que le secret manque.
    public static func decoder(_ donnees: Data) throws -> IdentifiantsDeSource {
        guard
            let charge = try? JSONDecoder().decode(Charge.self, from: donnees),
            let nature = NatureDAuthentification(rawValue: charge.nature)
        else {
            throw ErreurDeTrousseau.donneeIllisible
        }

        switch nature {
        case .aucune:
            return .aucun
        case .basique:
            guard let compte = charge.compte, let secret = charge.secret else {
                throw ErreurDeTrousseau.identifiantsIncomplets(nature: nature)
            }

            return .basique(compte: compte, motDePasse: secret)
        case .cleDApi:
            guard let secret = charge.secret else {
                throw ErreurDeTrousseau.identifiantsIncomplets(nature: nature)
            }

            return .cleDApi(secret)
        case .jeton:
            guard let secret = charge.secret else {
                throw ErreurDeTrousseau.identifiantsIncomplets(nature: nature)
            }

            return .jeton(
                acces: secret,
                rafraichissement: charge.rafraichissement,
                expiration: charge.expiration
            )
        }
    }
}
