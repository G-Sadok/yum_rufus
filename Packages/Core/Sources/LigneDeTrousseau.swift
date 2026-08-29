import Foundation
import Security

//
// LigneDeTrousseau
//
// Une ligne du trousseau, et les trois seules choses qu on lui fait : ecrire,
// relire, effacer.
//
// Le code vivait dans `TrousseauDuSysteme`, qui ne rangeait que les
// identifiants des sources. Les jetons des services de suivi se rangent au meme
// endroit, de la meme facon, avec la meme politique d accessibilite, et sous
// une autre cle. Recopier les trois methodes aurait donne deux trousseaux qui
// se ressemblent aujourd hui et divergent au premier correctif : celui de
// l ordre entre mise a jour et creation, par exemple, dont depend le fait
// qu une source ne se retrouve jamais sans identifiants pendant une
// milliseconde.
//

/// Une ligne du trousseau du systeme, designee par son service et sa cle.
struct LigneDeTrousseau {
    /// Descriptions des requetes passees aux fonctions SecItem.
    let requetes: RequeteDeTrousseau

    /// Cle de la ligne dans le service.
    let cle: String

    /// Ecrit les identifiants, ou efface la ligne quand il n y a rien a ranger.
    func ecrire(_ identifiants: IdentifiantsDeSource) throws {
        guard identifiants.estVide == false else {
            try effacer()

            return
        }

        let donnees = try CodageDIdentifiants.encoder(identifiants)

        // On tente la mise a jour avant la creation plutot que l inverse.
        // L ordre compte : `SecItemAdd` sur une ligne existante rend
        // errSecDuplicateItem, et le rattraper par une suppression puis une
        // seconde creation laisserait une fenetre pendant laquelle la ligne
        // n existe plus du tout.
        let miseAJour = SecItemUpdate(
            requetes.designation(deCle: cle) as CFDictionary,
            requetes.miseAJour(donnees: donnees) as CFDictionary
        )

        if miseAJour == errSecSuccess {
            return
        }

        guard miseAJour == errSecItemNotFound else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: miseAJour)
        }

        let creation = SecItemAdd(requetes.creation(deCle: cle, donnees: donnees) as CFDictionary, nil)

        guard creation == errSecSuccess else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: creation)
        }
    }

    /// Relit les identifiants, ou `aucun` quand la ligne n existe pas.
    func lire() throws -> IdentifiantsDeSource {
        var trouve: CFTypeRef?
        let code = SecItemCopyMatching(requetes.lecture(deCle: cle) as CFDictionary, &trouve)

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

    /// Efface la ligne, sans lever quand elle n existait pas.
    ///
    /// Une ligne absente n est pas un echec de suppression, c est le resultat
    /// attendu. La purge est appelee pour toute source retiree et pour tout
    /// service deconnecte, y compris ceux qui n avaient jamais rien range.
    func effacer() throws {
        let code = SecItemDelete(requetes.designation(deCle: cle) as CFDictionary)

        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw ErreurDeTrousseau.refusParLeSysteme(code: code)
        }
    }
}
