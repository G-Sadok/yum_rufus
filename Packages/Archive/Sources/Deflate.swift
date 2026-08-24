import Compression
import Core
import Foundation

//
// Deflate
//
// Decompression du flux deflate brut, seule methode compressee que le format
// ZIP impose de connaitre, et la seule que produisent les outils qui fabriquent
// des CBZ.
//
// Le decodage passe par le cadre Compression du systeme. Sa constante
// COMPRESSION_ZLIB designe le flux deflate brut, sans les deux octets d en tete
// ni la somme de controle finale du format zlib, ce qui correspond exactement a
// ce que le ZIP stocke.
//

enum Deflate {
    /// Taille du tampon de sortie, choisie pour tenir dans les caches et pour
    /// limiter le nombre d appels sur une page de plusieurs mega octets.
    private static let tailleDuTampon = 64 * 1024

    /// Decompresse un flux deflate brut.
    ///
    /// - Throws: `ErreurDeDocument.entreeCorrompue` des que le flux est
    ///   invalide, vide, ou s arrete avant sa fin.
    static func decompresser(_ entree: Data, nom: String) throws -> Data {
        guard entree.isEmpty == false else {
            throw ErreurDeDocument.entreeCorrompue(nom: nom)
        }

        let flux = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { flux.deallocate() }

        guard compression_stream_init(flux, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            == COMPRESSION_STATUS_OK
        else {
            throw ErreurDeDocument.entreeCorrompue(nom: nom)
        }
        defer { compression_stream_destroy(flux) }

        let tampon = UnsafeMutablePointer<UInt8>.allocate(capacity: tailleDuTampon)
        defer { tampon.deallocate() }

        var sortie = Data()
        var echec = false

        entree.withUnsafeBytes { brut in
            guard let source = brut.bindMemory(to: UInt8.self).baseAddress else {
                echec = true
                return
            }

            flux.pointee.src_ptr = source
            flux.pointee.src_size = brut.count

            var termine = false
            while termine == false {
                flux.pointee.dst_ptr = tampon
                flux.pointee.dst_size = tailleDuTampon

                let statut = compression_stream_process(flux, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produit = tailleDuTampon - flux.pointee.dst_size

                if produit > 0 {
                    sortie.append(tampon, count: produit)
                }

                switch statut {
                case COMPRESSION_STATUS_OK:
                    // Le tampon est plein et le flux continue. Sans cette garde,
                    // un flux qui ne consomme plus rien ferait tourner la boucle
                    // sans fin sur une archive fabriquee pour cela.
                    if produit == 0, flux.pointee.src_size == 0 {
                        echec = true
                        termine = true
                    }
                case COMPRESSION_STATUS_END:
                    termine = true
                default:
                    echec = true
                    termine = true
                }
            }
        }

        guard echec == false else {
            throw ErreurDeDocument.entreeCorrompue(nom: nom)
        }

        return sortie
    }
}
