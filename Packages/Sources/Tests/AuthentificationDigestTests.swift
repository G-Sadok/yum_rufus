import CryptoKit
import Foundation
import Testing
@testable import Sources

//
// AuthentificationDigestTests
//
// Le troisieme critere de la fonctionnalite, verifie sur les vecteurs publies
// par les normes plutot que sur ce que le code rend.
//
// La difference est tout le sujet. Un test qui comparerait la reponse Digest a
// une valeur produite par le meme code ne prouverait que sa coherence avec lui
// meme, et une erreur d ordre dans les termes haches passerait inapercue jusqu a
// ce qu un vrai serveur refuse. La RFC 2617 publie une reponse complete pour un
// jeu d entrees donne, et c est cette constante la qui sert de juge.
//
// La variante SHA-256 de la RFC 7616 est verifiee autrement, contre une
// reimplementation ecrite ici meme a partir de la formule de la norme. C est une
// seconde implementation, pas la meme relue : elle compose les termes a la main
// et hache avec CryptoKit, sans passer par une seule ligne du code teste.
//

struct AuthentificationDigestTests {
    // MARK: Vecteurs des normes

    @Test("La reponse MD5 est celle que publie la RFC 2617")
    func vecteurDeLaRfc2617() {
        let defi = DefiDigest(
            domaine: "testrealm@host.com",
            nonce: "dcd98b7102dd2f0e8b11d0f600bfb0c093",
            opaque: "5ccc069c403ebaf9f0171e9517f40e41",
            qualite: "auth",
            algorithme: .md5,
            perime: false
        )
        let reponse = ReponseDigest(
            compte: "Mufasa",
            motDePasse: "Circle Of Life",
            defi: defi,
            methode: "GET",
            uri: "/dir/index.html",
            cnonce: "0a4f113b",
            compteur: 1
        )

        #expect(reponse.reponse() == "6629fae49393a05397450978507c4ef1")
    }

    @Test("La reponse SHA-256 suit la formule de la RFC 7616")
    func vecteurSha256() {
        let defi = DefiDigest(
            domaine: "http-auth@example.org",
            nonce: "7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v",
            opaque: nil,
            qualite: "auth",
            algorithme: .sha256,
            perime: false
        )
        let reponse = ReponseDigest(
            compte: "Mufasa",
            motDePasse: "Circle of Life",
            defi: defi,
            methode: "GET",
            uri: "/dir/index.html",
            cnonce: "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ",
            compteur: 1
        )

        #expect(reponse.reponse() == ReferenceDigest.sha256(reponse))
    }

    @Test("La variante de session melange le nonce et le cnonce au premier terme")
    func varianteDeSession() {
        let defi = DefiDigest(
            domaine: "Partage",
            nonce: "nonce-du-serveur",
            opaque: nil,
            qualite: "auth",
            algorithme: .md5Session,
            perime: false
        )
        let reponse = ReponseDigest(
            compte: "utilisateur",
            motDePasse: "motdepasse",
            defi: defi,
            methode: "GET",
            uri: "/dav/fichier.cbz",
            cnonce: "cnonce-fige",
            compteur: 3
        )

        #expect(reponse.reponse() == ReferenceDigest.md5DeSession(reponse))

        // Sans la variante de session, le meme jeu d entrees donne une reponse
        // differente. Sans ce controle, une implementation qui ignorerait le
        // suffixe passerait le test precedent.
        let sansSession = ReponseDigest(
            compte: reponse.compte,
            motDePasse: reponse.motDePasse,
            defi: DefiDigest(
                domaine: defi.domaine,
                nonce: defi.nonce,
                opaque: nil,
                qualite: defi.qualite,
                algorithme: .md5,
                perime: false
            ),
            methode: reponse.methode,
            uri: reponse.uri,
            cnonce: reponse.cnonce,
            compteur: reponse.compteur
        )

        #expect(sansSession.reponse() != reponse.reponse())
    }

    @Test("Un serveur sans qop recoit la forme historique, sans compteur")
    func sansQualiteDeProtection() {
        let defi = DefiDigest(
            domaine: "Partage",
            nonce: "abc",
            opaque: nil,
            qualite: nil,
            algorithme: .md5,
            perime: false
        )
        let reponse = ReponseDigest(
            compte: "u",
            motDePasse: "p",
            defi: defi,
            methode: "GET",
            uri: "/f",
            cnonce: "cn",
            compteur: 7
        )

        #expect(reponse.reponse() == ReferenceDigest.md5SansQualite(reponse))
        #expect(reponse.entete().contains("nc=") == false)
        #expect(reponse.entete().contains("cnonce=") == false)
    }

    // MARK: Entete produit

    @Test("L entete porte tous les champs que le serveur verifie")
    func enteteComplet() {
        let defi = DefiDigest(
            domaine: "Partage",
            nonce: "n1",
            opaque: "o1",
            qualite: "auth",
            algorithme: .sha256,
            perime: false
        )
        let entete = ReponseDigest(
            compte: "leo",
            motDePasse: "secret",
            defi: defi,
            methode: "PROPFIND",
            uri: "/dav/Mangas",
            cnonce: "cn9",
            compteur: 42
        ).entete()

        let champs = ParametresDEntete.lire(String(entete.dropFirst("Digest ".count)))

        #expect(champs["username"] == "leo")
        #expect(champs["realm"] == "Partage")
        #expect(champs["nonce"] == "n1")
        #expect(champs["uri"] == "/dav/Mangas")
        #expect(champs["opaque"] == "o1")
        #expect(champs["qop"] == "auth")
        #expect(champs["algorithm"] == "SHA-256")
        #expect(champs["nc"] == "0000002a")
        #expect(champs["cnonce"] == "cn9")
    }

    @Test("Le compteur est ecrit sur huit chiffres hexadecimaux")
    func compteurSurHuitChiffres() {
        #expect(ReponseDigest.compteurHexadecimal(1) == "00000001")
        #expect(ReponseDigest.compteurHexadecimal(255) == "000000ff")
        #expect(ReponseDigest.compteurHexadecimal(4_294_967_295) == "ffffffff")
    }

    // MARK: Lecture du defi

    @Test("Un defi complet se lit champ par champ")
    func lectureDUnDefi() throws {
        let entete = """
        Digest realm="http-auth@example.org", qop="auth, auth-int", \
        algorithm=SHA-256, nonce="abc", opaque="xyz", stale=TRUE
        """
        let defi = try #require(DefiDigest.meilleur(dans: entete))

        #expect(defi.domaine == "http-auth@example.org")
        #expect(defi.nonce == "abc")
        #expect(defi.opaque == "xyz")
        #expect(defi.algorithme == .sha256)
        #expect(defi.perime)

        // La virgule interieure a `qop` ne doit pas couper le parametre en deux,
        // et `auth-int` ne doit jamais etre retenue : elle imposerait de hacher
        // un corps de requete que la lecture n a pas.
        #expect(defi.qualite == "auth")
    }

    @Test("Entre deux defis proposes ensemble, le plus solide est retenu")
    func choixDuDefiLePlusSolide() throws {
        let entete = """
        Digest realm="r", nonce="n256", algorithm=SHA-256, qop="auth", \
        Digest realm="r", nonce="nmd5", algorithm=MD5, qop="auth"
        """
        let defi = try #require(DefiDigest.meilleur(dans: entete))

        #expect(defi.algorithme == .sha256)
        #expect(defi.nonce == "n256")
    }

    @Test("Un algorithme inconnu est refuse plutot que ramene a MD5")
    func algorithmeInconnuRefuse() {
        // Calculer une reponse avec la mauvaise fonction produirait un refus que
        // personne ne saurait expliquer. Mieux vaut ne pas repondre.
        #expect(DefiDigest.meilleur(dans: "Digest realm=\"r\", nonce=\"n\", algorithm=SHA-512-256") == nil)
        #expect(AlgorithmeDigest.depuis("SHA-512") == nil)
    }

    @Test("Un defi sans nonce n est pas un defi")
    func defiSansNonce() {
        #expect(DefiDigest.meilleur(dans: "Digest realm=\"r\", qop=\"auth\"") == nil)
        #expect(DefiDigest.meilleur(dans: "Basic realm=\"r\"") == nil)
        #expect(DefiDigest.meilleur(dans: nil) == nil)
    }

    @Test("Une valeur entre guillemets garde ses virgules et ses guillemets echappes")
    func valeursEchappees() {
        let champs = ParametresDEntete.lire("realm=\"Le \\\"grand\\\" partage, chez moi\", nonce=\"n\"")

        #expect(champs["realm"] == "Le \"grand\" partage, chez moi")
        #expect(champs["nonce"] == "n")
    }
}

///
/// ReferenceDigest
///
/// La seconde implementation, ecrite a partir des formules de la RFC 7616 et sans
/// reutiliser une ligne du code teste. Elle sert la ou aucune constante n est
/// publiee par la norme.
///
enum ReferenceDigest {
    static func sha256(_ reponse: ReponseDigest) -> String {
        let defi = reponse.defi
        let premier = hacherSha("\(reponse.compte):\(defi.domaine):\(reponse.motDePasse)")
        let second = hacherSha("\(reponse.methode):\(reponse.uri)")
        let compteur = String(format: "%08x", reponse.compteur)

        return hacherSha(
            "\(premier):\(defi.nonce):\(compteur):\(reponse.cnonce):auth:\(second)"
        )
    }

    static func md5DeSession(_ reponse: ReponseDigest) -> String {
        let defi = reponse.defi
        let base = hacherMd5("\(reponse.compte):\(defi.domaine):\(reponse.motDePasse)")
        let premier = hacherMd5("\(base):\(defi.nonce):\(reponse.cnonce)")
        let second = hacherMd5("\(reponse.methode):\(reponse.uri)")
        let compteur = String(format: "%08x", reponse.compteur)

        return hacherMd5(
            "\(premier):\(defi.nonce):\(compteur):\(reponse.cnonce):auth:\(second)"
        )
    }

    static func md5SansQualite(_ reponse: ReponseDigest) -> String {
        let defi = reponse.defi
        let premier = hacherMd5("\(reponse.compte):\(defi.domaine):\(reponse.motDePasse)")
        let second = hacherMd5("\(reponse.methode):\(reponse.uri)")

        return hacherMd5("\(premier):\(defi.nonce):\(second)")
    }

    static func hacherMd5(_ texte: String) -> String {
        Insecure.MD5.hash(data: Data(texte.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func hacherSha(_ texte: String) -> String {
        SHA256.hash(data: Data(texte.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
