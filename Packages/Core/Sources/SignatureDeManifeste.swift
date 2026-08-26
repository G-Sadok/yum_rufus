import CryptoKit
import Foundation

//
// SignatureDeManifeste
//
// Le manifeste signe de la section 4.3.
//
// Le paquet transporte les octets du manifeste tels quels, et non un objet JSON
// imbrique. C est ce qui rend la verification sure : une signature porte sur
// des octets, et re encoder un arbre JSON avant de verifier ferait dependre le
// resultat de l ordre des cles et de l ecriture des nombres, deux choses
// qu aucune norme ne fixe. Les octets signes sont donc exactement ceux qui sont
// ensuite lus par `ManifesteDExtension.lire(_:)`.
//
// La cle publique voyage dans le paquet, ce qui ne prouve evidemment rien a
// elle seule : n importe qui peut signer avec la sienne. Elle sert a designer
// laquelle des cles de confiance verifier, et la verification echoue si elle
// n en fait pas partie. Le trousseau de confiance est la seule racine.
//
// Le trousseau livre avec l application est vide tant qu aucune cle de
// publication n existe, et un trousseau vide refuse tout. C est volontaire :
// un systeme d extensions qui accepterait tout en attendant sa cle serait
// exactement le systeme que la section 4.3 interdit, et il partirait ainsi en
// production le jour ou personne ne penserait plus a la remplir.
//

/// Les cles de publication auxquelles l application fait confiance.
public struct TrousseauDeClesDePublication: Sendable, Hashable {
    /// Representations brutes des cles publiques Ed25519 acceptees.
    public let cles: Set<Data>

    public init(cles: Set<Data>) {
        self.cles = cles
    }

    /// Le trousseau livre avec l application.
    ///
    /// Vide tant qu aucune cle de publication n a ete produite. Un trousseau
    /// vide refuse toute extension, ce qui est le bon comportement par defaut :
    /// aucune installation ne passe avant que la cle existe.
    public static let livre = TrousseauDeClesDePublication(cles: [])

    /// Vrai quand cette cle publique est de confiance.
    public func fait(confianceA cle: Data) -> Bool {
        cles.contains(cle)
    }

    public var estVide: Bool {
        cles.isEmpty
    }
}

/// Un paquet d extension, c est a dire un manifeste et sa signature.
public struct PaquetDExtensionSigne: Sendable, Hashable {
    /// Octets du manifeste, exactement ceux qui ont ete signes.
    public let manifeste: Data

    /// Signature Ed25519 de ces octets.
    public let signature: Data

    /// Cle publique qui designe le signataire.
    public let clePublique: Data

    public init(manifeste: Data, signature: Data, clePublique: Data) {
        self.manifeste = manifeste
        self.signature = signature
        self.clePublique = clePublique
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case manifeste
        case signature
        case clePublique = "cle"
    }

    /// Lit un paquet depuis les octets du fichier qui l enveloppe.
    ///
    /// - Throws: `ErreurDExtension.manifesteIllisible` quand l enveloppe ne se
    ///   decode pas, et `ErreurDExtension.signatureAbsente` quand elle ne porte
    ///   ni signature ni cle.
    public static func lire(_ donnees: Data) throws -> PaquetDExtensionSigne {
        guard let enveloppe = try? JSONDecoder().decode(EnveloppeDePaquet.self, from: donnees) else {
            throw ErreurDExtension.manifesteIllisible
        }
        guard let manifeste = Data(base64Encoded: enveloppe.manifeste) else {
            throw ErreurDExtension.manifesteIllisible
        }
        guard
            let signature = Data(base64Encoded: enveloppe.signature),
            let clePublique = Data(base64Encoded: enveloppe.cle),
            signature.isEmpty == false, clePublique.isEmpty == false
        else {
            throw ErreurDExtension.signatureAbsente
        }

        return PaquetDExtensionSigne(manifeste: manifeste, signature: signature, clePublique: clePublique)
    }

    /// Ecrit l enveloppe qui transporte ce paquet.
    public func enveloppe() throws -> Data {
        try JSONEncoder().encode(
            EnveloppeDePaquet(
                manifeste: manifeste.base64EncodedString(),
                signature: signature.base64EncodedString(),
                cle: clePublique.base64EncodedString()
            )
        )
    }
}

/// L enveloppe JSON d un paquet, trois chaines en base 64.
struct EnveloppeDePaquet: Codable {
    let manifeste: String
    let signature: String
    let cle: String
}

/// Ce qui verifie qu un paquet a bien ete signe par une cle de confiance.
public struct VerificateurDeSignature: Sendable {
    private let trousseau: TrousseauDeClesDePublication

    public init(trousseau: TrousseauDeClesDePublication = .livre) {
        self.trousseau = trousseau
    }

    /// Verifie la signature du paquet, puis lit le manifeste qu il porte.
    ///
    /// L ordre compte. La signature est verifiee avant que le manifeste ne soit
    /// analyse, pour que rien d un paquet non signe ne soit interprete, pas
    /// meme la forme de son JSON.
    ///
    /// - Throws: `ErreurDExtension.cleDePublicationInconnue`,
    ///   `.signatureInvalide`, puis les refus de lecture du manifeste.
    public func verifier(_ paquet: PaquetDExtensionSigne) throws -> ManifesteDExtension {
        guard trousseau.fait(confianceA: paquet.clePublique) else {
            throw ErreurDExtension.cleDePublicationInconnue
        }
        guard let cle = try? Curve25519.Signing.PublicKey(rawRepresentation: paquet.clePublique) else {
            throw ErreurDExtension.cleDePublicationInconnue
        }
        guard cle.isValidSignature(paquet.signature, for: paquet.manifeste) else {
            throw ErreurDExtension.signatureInvalide
        }

        return try ManifesteDExtension.lire(paquet.manifeste)
    }

    /// Lit une enveloppe et verifie ce qu elle porte.
    public func verifier(enveloppe: Data) throws -> ManifesteDExtension {
        try verifier(PaquetDExtensionSigne.lire(enveloppe))
    }
}
