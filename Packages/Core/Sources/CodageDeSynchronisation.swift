import Foundation

//
// CodageDeSynchronisation
//
// L encodage des charges de journal, ecrit une fois pour toutes les entites.
//
// Les cles sont triees et les dates sont en ISO 8601. Ce n est pas une
// preference de forme, c est ce qui rend la troisieme ligne de la resolution de
// conflit utilisable : elle compare deux charges octet par octet, et un
// encodage dont l ordre des cles depend du hachage du processus donnerait deux
// suites d octets differentes pour le meme etat, sur le meme appareil, d une
// execution a l autre.
//

/// Encodage commun des charges qui circulent entre appareils.
public enum CodageDeSynchronisation {
    /// Encode une charge sous une forme reproductible.
    public static func encoder(_ valeur: some Encodable) throws -> Data {
        try encodeur.encode(valeur)
    }

    /// Relit une charge, apres avoir verifie qu elle decrit bien cette entite.
    ///
    /// - Throws: `ErreurDeSynchronisation.entiteInattendue` quand la ligne
    ///   decrit autre chose, `chargeIllisible` quand elle ne se decode pas.
    public static func decoder<Valeur: Decodable>(
        _ type: Valeur.Type,
        depuis changement: ChangementSynchronise,
        attendue: EntiteSynchronisee
    ) throws -> Valeur {
        guard changement.cle.entite == attendue else {
            throw ErreurDeSynchronisation.entiteInattendue(
                attendue: attendue,
                recue: changement.cle.entite
            )
        }

        guard let valeur = try? decodeur.decode(type, from: changement.charge) else {
            throw ErreurDeSynchronisation.chargeIllisible(cle: changement.cle)
        }

        return valeur
    }

    private static let encodeur: JSONEncoder = {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        encodeur.dateEncodingStrategy = .iso8601

        return encodeur
    }()

    private static let decodeur: JSONDecoder = {
        let decodeur = JSONDecoder()
        decodeur.dateDecodingStrategy = .iso8601

        return decodeur
    }()
}
