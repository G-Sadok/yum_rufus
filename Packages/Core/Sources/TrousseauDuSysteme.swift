import Foundation
import Security

//
// TrousseauDuSysteme
//
// La seule implementation livree de `MagasinDIdentifiants`. Toutes les
// authentifications de source passent par elle.
//
// Elle vit dans Core et non dans Sources, alors que Core est le paquet sans
// dependance. Security est un framework du systeme, present sur les deux
// plateformes cibles, et non un paquet tiers : la regle de la section 2.3
// porte sur les dependances de paquet, elle n est donc pas entamee. La ranger
// dans Sources aurait un cout reel : la couche vue, qui presente la feuille de
// configuration, et la couche de sauvegarde, qui purge une source supprimee,
// devraient toutes deux dependre des implementations de sources pour atteindre
// le trousseau, ce que le protocole existe precisement pour eviter.
//
// Les fonctions SecItem sont synchrones et sures vis a vis des fils
// d execution. Elles satisfont telles quelles les exigences asynchrones du
// protocole, sans acteur intermediaire : ajouter un acteur serialiserait des
// lectures que le systeme sait deja mener de front.
//

/// Range les identifiants des sources dans le trousseau du systeme.
///
/// Chaque source occupe une ligne de classe mot de passe generique, accessible
/// apres premier deverrouillage, comme l impose la section 11.
public struct TrousseauDuSysteme: MagasinDIdentifiants {
    private let requetes: RequeteDeTrousseau

    public init(requetes: RequeteDeTrousseau = RequeteDeTrousseau()) {
        self.requetes = requetes
    }

    public func enregistrer(_ identifiants: IdentifiantsDeSource, pour source: SourceID) throws {
        guard identifiants.estVide == false else {
            try supprimer(pour: source)

            return
        }

        let donnees = try CodageDIdentifiants.encoder(identifiants)
        let designation = requetes.designation(de: source)

        // On tente la mise a jour avant la creation plutot que l inverse.
        // L ordre compte : `SecItemAdd` sur une ligne existante rend
        // errSecDuplicateItem, et le rattraper par une suppression puis une
        // seconde creation laisserait une fenetre pendant laquelle la source
        // n a plus d identifiants du tout.
        let miseAJour = SecItemUpdate(designation as CFDictionary, requetes.miseAJour(donnees: donnees) as CFDictionary)

        if miseAJour == errSecSuccess {
            return
        }

        guard miseAJour == errSecItemNotFound else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: miseAJour)
        }

        let creation = SecItemAdd(requetes.creation(de: source, donnees: donnees) as CFDictionary, nil)

        guard creation == errSecSuccess else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: creation)
        }
    }

    public func identifiants(pour source: SourceID) throws -> IdentifiantsDeSource {
        var trouve: CFTypeRef?
        let code = SecItemCopyMatching(requetes.lecture(de: source) as CFDictionary, &trouve)

        if code == errSecItemNotFound {
            return .aucun
        }

        guard code == errSecSuccess else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: code)
        }

        guard let donnees = trouve as? Data else {
            throw ErreurDeTrousseau.donneeIllisible
        }

        return try CodageDIdentifiants.decoder(donnees)
    }

    public func supprimer(pour source: SourceID) throws {
        let code = SecItemDelete(requetes.designation(de: source) as CFDictionary)

        // Une ligne absente n est pas un echec de suppression, c est le
        // resultat attendu. La purge est appelee pour toute source retiree,
        // y compris les sources locales qui n ont jamais eu de mot de passe.
        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: code)
        }
    }
}
