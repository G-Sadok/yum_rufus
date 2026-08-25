import Foundation
import Security

//
// RequeteDeTrousseau
//
// Construction des dictionnaires d attributs passes aux fonctions SecItem.
//
// Ce fichier ne parle jamais au trousseau, il ne fait que decrire ce qui lui
// sera demande. C est voulu : le seul point ou la regle de la section 11 peut
// etre verifiee par un test est la valeur de `kSecAttrAccessible`, et un test
// qui devrait ecrire dans le vrai trousseau pour la lire ne tournerait sur
// aucune machine d integration continue. Separer la requete de son execution
// rend la regle mesurable.
//

/// Decrit les lignes de trousseau du projet.
///
/// Une ligne par source, de classe mot de passe generique, rangee sous un
/// service commun. La cle de la ligne est l identifiant de la source, ce qui
/// donne la propriete dont depend le deuxieme critere : supprimer une source,
/// c est supprimer une ligne, designee sans ambiguite.
public struct RequeteDeTrousseau: Sendable, Hashable {
    /// Accessibilite imposee par la section 11 du cahier de developpement.
    ///
    /// Apres premier deverrouillage, et non a tout moment : une source doit
    /// pouvoir se synchroniser en arriere plan appareil verrouille, mais rien
    /// ne doit etre lisible sur un appareil qui n a pas ete deverrouille une
    /// fois depuis son demarrage.
    /// La valeur est convertie en `String` des ici, et pas seulement au moment
    /// de remplir le dictionnaire. `CFString` n est pas `Sendable`, une
    /// constante globale de ce type ne compile pas en concurrence stricte, et
    /// le pont vers `CFDictionary` reconvertit de toute maniere.
    public static let accessibilite = kSecAttrAccessibleAfterFirstUnlock as String

    /// Service sous lequel toutes les lignes du projet sont rangees.
    public let service: String

    /// Service par defaut, derive de l identifiant du paquet applicatif.
    ///
    /// Le repli existe pour les binaires qui n en portent pas, ceux des tests
    /// et des apercus. Il ne s applique jamais a l application livree.
    public static var serviceParDefaut: String {
        (Bundle.main.bundleIdentifier ?? "Yum") + ".identifiants-de-source"
    }

    public init(service: String = RequeteDeTrousseau.serviceParDefaut) {
        self.service = service
    }

    /// Attributs qui designent la ligne d une source, sans rien de secret.
    ///
    /// C est le socle commun de la lecture, de l ecriture et de la suppression.
    /// Le fait qu il ne porte aucune valeur est ce qui permet de le passer a
    /// `SecItemDelete` sans avoir a connaitre le mot de passe qu on efface.
    public func designation(de source: SourceID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: source.brut.uuidString,

            // Sans cela, macOS range la ligne dans le trousseau de fichier
            // historique, qui ignore purement et simplement `kSecAttrAccessible`.
            // La regle de la section 11 ne serait alors respectee que sur iOS.
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// Requete de lecture, qui demande les octets de la ligne.
    public func lecture(de source: SourceID) -> [String: Any] {
        var requete = designation(de: source)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne

        return requete
    }

    /// Requete de creation, qui porte les octets et l accessibilite.
    public func creation(de source: SourceID, donnees: Data) -> [String: Any] {
        var requete = designation(de: source)
        requete[kSecValueData as String] = donnees
        requete[kSecAttrAccessible as String] = Self.accessibilite

        return requete
    }

    /// Attributs a ecrire quand la ligne existe deja.
    ///
    /// La designation n y figure pas : `SecItemUpdate` prend la designation
    /// d un cote et les seuls attributs a changer de l autre. L accessibilite
    /// est reecrite a chaque mise a jour, pour qu une ligne creee par une
    /// version anterieure de l application soit corrigee au lieu de survivre
    /// avec son ancienne politique.
    public func miseAJour(donnees: Data) -> [String: Any] {
        [
            kSecValueData as String: donnees,
            kSecAttrAccessible as String: Self.accessibilite,
        ]
    }
}
