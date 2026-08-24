import Core
import Foundation

//
// LecteurDeZip
//
// Extraction d une entree, et d une seule.
//
// C est le point ou se joue le critere d acces direct : la lecture part de la
// position que l index central donne pour cette entree, lit ses octets, et rien
// d autre. Aucune entree precedente n est ouverte ni decompressee. Un ZIP le
// permet parce que chaque entree porte son propre flux, contrairement aux
// archives solides ou les entrees partagent un dictionnaire de compression.
//

enum LecteurDeZip {
    static let signatureEnTeteLocal: UInt32 = 0x0403_4B50
    static let tailleEnTeteLocal = 30

    /// Entree rangee telle quelle, sans compression.
    static let methodeStockee: UInt16 = 0

    /// Entree compressee en deflate, seule methode compressee du format qui
    /// soit universellement implementee.
    static let methodeDeflate: UInt16 = 8

    /// Rend le contenu decompresse d une entree.
    ///
    /// - Throws: `ErreurDeDocument.conteneurChiffre` si l entree est protegee,
    ///   `ErreurDeDocument.compressionNonPriseEnCharge` si sa methode est
    ///   inconnue, `ErreurDeDocument.entreeCorrompue` si le contenu obtenu ne
    ///   correspond pas a ce que l index annonce, et
    ///   `ErreurDeDocument.conteneurTronque` si l archive s arrete avant.
    static func donnees(de entree: EntreeZip, dans source: some SourceDOctets) throws -> Data {
        guard entree.estChiffree == false else {
            throw ErreurDeDocument.conteneurChiffre(chemin: source.nom)
        }

        let brut = try octetsStockes(de: entree, dans: source)
        let contenu = try decompresser(brut, de: entree)

        try verifier(contenu, contre: entree)

        return contenu
    }

    /// Lit les octets de l entree, tels qu ils sont ranges dans l archive.
    ///
    /// La position des donnees se calcule sur l en tete local et non sur celui
    /// de l index central : les deux portent des champs additionnels de
    /// longueurs differentes, et prendre celle de l index decale la lecture de
    /// quelques octets sur presque toutes les archives modernes.
    private static func octetsStockes(de entree: EntreeZip, dans source: some SourceDOctets) throws -> Data {
        let enTete = try source.lire(a: entree.offsetEnTeteLocal, longueur: tailleEnTeteLocal)

        guard LectureBinaire.entier32(enTete, a: 0) == signatureEnTeteLocal,
              let longueurNom = LectureBinaire.entier16(enTete, a: 26),
              let longueurExtra = LectureBinaire.entier16(enTete, a: 28)
        else {
            throw ErreurDeDocument.entreeCorrompue(nom: entree.nom)
        }

        guard entree.tailleCompressee <= UInt64(Int.max) else {
            throw ErreurDeDocument.conteneurTronque(chemin: source.nom)
        }

        let debut = entree.offsetEnTeteLocal
            + UInt64(tailleEnTeteLocal)
            + UInt64(longueurNom)
            + UInt64(longueurExtra)

        return try source.lire(a: debut, longueur: Int(entree.tailleCompressee))
    }

    private static func decompresser(_ brut: Data, de entree: EntreeZip) throws -> Data {
        switch entree.methode {
        case methodeStockee:
            brut
        case methodeDeflate:
            try Deflate.decompresser(brut, nom: entree.nom)
        default:
            throw ErreurDeDocument.compressionNonPriseEnCharge(
                nom: entree.nom,
                methode: Int(entree.methode)
            )
        }
    }

    /// Confronte le contenu obtenu a ce que l index central annonce.
    ///
    /// La somme de controle est verifiee systematiquement. C est ce qui separe
    /// une page endommagee, signalee comme telle, d une image tronquee que le
    /// decodeur afficherait a moitie sans rien dire.
    private static func verifier(_ contenu: Data, contre entree: EntreeZip) throws {
        guard UInt64(contenu.count) == entree.tailleDecompressee else {
            throw ErreurDeDocument.entreeCorrompue(nom: entree.nom)
        }

        // Une entree vide annonce une somme nulle, qui est aussi celle d un
        // contenu vide : la comparaison reste juste et n a pas de cas special.
        guard SommeDeControle.crc32(contenu) == entree.crcAttendu else {
            throw ErreurDeDocument.entreeCorrompue(nom: entree.nom)
        }
    }
}
