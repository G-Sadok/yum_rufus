import Core
import Foundation

//
// ParcoursOpds
//
// Le rapprochement entre une pagination numerotee et une pagination chainee.
//
// Le protocole de la section 4.1 demande la page numero trois. OPDS ne sait pas
// ce qu est la page numero trois : il sait publier un flux, et ce flux porte
// eventuellement un lien `next` vers le suivant. Aucune adresse de page ne se
// fabrique, et un catalogue qui numerote ses pages dans ses adresses le fait
// pour lui, avec ses conventions, que rien n autorise a deviner.
//
// Le parcours retient donc les adresses deja atteintes, dans l ordre. Demander
// une page deja visitee la relit directement. Demander une page plus loin
// repart de la derniere adresse connue et suit les liens jusqu a elle. Demander
// une page qui n existe pas rend une liste vide, et non la derniere page une
// seconde fois : c est la difference entre une fin de catalogue et une boucle
// infinie de defilement.
//
// La verification des adresses est l autre moitie de ce fichier, et elle n est
// pas une precaution de style. Chaque lien vient du serveur, et chaque requete
// part avec le mot de passe de l utilisateur. Un catalogue qui publierait un
// lien vers un autre domaine se ferait presenter ces identifiants, ce qui est
// une fuite, pas une fonctionnalite. Les adresses sont donc contraintes au meme
// hote et au meme niveau de chiffrement que le catalogue configure.
//

/// Une entree, et l adresse du flux qui la portait.
///
/// Les deux voyagent ensemble parce qu un lien OPDS est relatif la plupart du
/// temps. Resoudre `?page=2` sans savoir d ou il vient ne donne rien.
struct EntreeAtteinte: Sendable {
    let entree: EntreeOpds

    /// L adresse du flux d ou vient l entree.
    let adresse: URL
}

/// Un flux, et l adresse a laquelle il a ete lu.
struct FluxAtteint: Sendable {
    let flux: FluxOpds
    let adresse: URL
}

extension SourceOpds {
    // MARK: Lecture d un flux

    /// Lit et analyse le flux publie a cette adresse.
    ///
    /// - Throws: `ErreurReseau`, dans le cas nomme qui correspond a ce qui s est
    ///   passe, y compris `reponseIllisible` quand le document n est un flux
    ///   dans aucune des deux versions du protocole.
    func flux(_ adresse: URL) async throws -> FluxOpds {
        try Task.checkCancellation()
        try verifier(adresse)

        let client = try await client()
        var requete = URLRequest(url: adresse)

        // L entete d acceptation est pose ici et non par `requete(chemin:)` du
        // client : celle la annonce accepter du JSON seul, ce qui exclurait le
        // flux Atom d un catalogue en 1.2 sur un serveur qui respecte la
        // negociation de contenu.
        requete.setValue(AnalyseurOpds.typesAcceptes, forHTTPHeaderField: "Accept")

        return try await AnalyseurOpds.analyser(client.executer(requete))
    }

    // MARK: Pagination

    /// Atteint la page demandee en suivant les liens depuis le depart.
    ///
    /// - Returns: le flux de cette page et son adresse, ou nul quand la page
    ///   demandee est au dela de la fin du catalogue.
    func parcourir(depuis depart: URL, page: Int) async throws -> FluxAtteint? {
        let voulue = max(0, page)
        let cle = depart.absoluteString
        var connues = adressesDeParcours[cle] ?? [depart]

        // Le parcours repart de la derniere adresse connue et non du debut. Un
        // defilement qui descend page par page ne relit donc jamais que la page
        // suivante, la ou repartir de la racine ferait N requetes pour la page N.
        var rang = min(voulue, connues.count - 1)
        var lu = try await flux(connues[rang])

        while rang < voulue {
            guard let suivante = lu.suivante else {
                adressesDeParcours[cle] = connues

                return nil
            }

            let adresse = try resoudre(suivante.adresse, relativement: connues[rang])
            rang += 1

            if rang < connues.count {
                connues[rang] = adresse
            } else {
                connues.append(adresse)
            }

            lu = try await flux(adresse)
        }

        adressesDeParcours[cle] = connues

        return FluxAtteint(flux: lu, adresse: connues[rang])
    }

    /// Toutes les entrees de chapitre d une serie, tous flux enchaines.
    ///
    /// Un chapitre absent de la liste est un chapitre que l utilisateur ne peut
    /// pas ouvrir, donc s arreter au premier flux serait un bogue silencieux sur
    /// toute serie de plus d une page de catalogue.
    func toutesLesEntrees(deLaSerie identifiant: String) async throws -> [EntreeAtteinte] {
        var adresse = try adresseDeSource(identifiant)
        var recoltees: [EntreeAtteinte] = []
        var flux = 0

        while flux < SourceOpds.maximumDeFluxEnchaines {
            try Task.checkCancellation()

            let lu = try await self.flux(adresse)
            recoltees.append(
                contentsOf: lu.chapitres.map { EntreeAtteinte(entree: $0, adresse: adresse) }
            )
            flux += 1

            guard let suivante = lu.suivante else {
                return recoltees
            }

            let apres = try resoudre(suivante.adresse, relativement: adresse)

            guard apres != adresse else {
                // Un lien `next` qui pointe sur le flux courant est un defaut de
                // serveur, et il se rencontre. S arreter la vaut mieux que de
                // rapatrier cinq cents fois la meme page.
                return recoltees
            }

            adresse = apres
        }

        return recoltees
    }

    /// L adresse de depart d une section du catalogue.
    ///
    /// - Throws: `ErreurDeSource.sectionNonPriseEnCharge` quand le flux racine
    ///   ne publie pas de lien pour cette section. Rendre le catalogue complet
    ///   sous le nom des nouveautes serait un classement invente.
    func depart(de section: SectionCatalogue) async throws -> URL {
        guard section != .tout else {
            return racine
        }
        if let connue = sectionsRetenues[section] {
            return connue
        }

        let nonServie = ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        let relation = section == .recentes ? RelationOpds.nouveautes : RelationOpds.populaires

        do {
            let lu = try await flux(racine)

            guard let lien = lu.section(relation) else {
                throw nonServie
            }

            let adresse = try resoudre(lien.adresse, relativement: racine)
            sectionsRetenues[section] = adresse

            return adresse
        } catch let erreur as ErreurDeSource {
            throw erreur
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    // MARK: Adresses

    /// Resout une adresse publiee par le catalogue.
    ///
    /// - Parameter gabarit: vrai quand l adresse porte encore des accolades de
    ///   gabarit. Elles sont echappees avant l assemblage, faute de quoi
    ///   l adresse serait refusee : les accolades ne sont pas des caracteres
    ///   d URL, et la diffusion page par page en met dans les siennes.
    /// - Throws: `ErreurReseau.serveurIntrouvable` quand l assemblage ne donne
    ///   rien, et les cas de `verifier(_:)` quand l adresse sort du catalogue.
    func resoudre(_ adresse: String, relativement base: URL, gabarit: Bool = false) throws -> URL {
        let ecrite = gabarit ? DiffusionDePagesOpds.echapper(adresse) : adresse

        guard let resolue = URL(string: ecrite, relativeTo: base)?.absoluteURL else {
            throw ErreurReseau.serveurIntrouvable
        }

        try verifier(resolue)

        return resolue
    }

    /// L adresse que porte un identifiant de serie ou de chapitre.
    ///
    /// - Throws: `ErreurReseau.serveurIntrouvable` quand l identifiant n est pas
    ///   une adresse, ce qui arrive quand une fiche importee d une autre source
    ///   est presentee a celle ci.
    func adresseDeSource(_ identifiant: String) throws -> URL {
        guard let adresse = URL(string: identifiant) else {
            throw ErreurReseau.serveurIntrouvable
        }

        try verifier(adresse)

        return adresse
    }

    /// Refuse une adresse a laquelle cette source n a pas a envoyer de requete.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse est en clair
    ///   sans que l utilisateur l ait confirme, et
    ///   `ErreurReseau.domaineNonAutorise` quand elle designe un autre hote que
    ///   le catalogue configure.
    func verifier(_ adresse: URL) throws {
        guard let hote = adresse.host()?.lowercased() else {
            throw ErreurReseau.serveurIntrouvable
        }
        if adresse.scheme?.lowercased() != "https", accepteLeHttpEnClair == false {
            throw ErreurReseau.transportNonChiffre
        }
        guard hote == racine.host()?.lowercased() else {
            throw ErreurReseau.domaineNonAutorise(domaine: hote)
        }
    }
}
