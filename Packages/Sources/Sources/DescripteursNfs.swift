import Core
import Foundation

//
// DescripteursNfs
//
// Comment un chemin devient un descripteur, et comment un dossier se liste.
//
// NFS ne connait pas les chemins. Il ne connait que des descripteurs opaques et
// une procedure de recherche de nom dans un dossier. Ouvrir un fichier range
// trois niveaux plus bas veut donc dire trois recherches enchainees, chacune
// partant du descripteur que la precedente a rendu. C est pour cela que les
// descripteurs deja resolus sont retenus : sans cette memoire, chaque plage lue
// dans un CBZ couterait trois allers retours de plus, pour retrouver un
// descripteur qui n a pas change.
//
// Le listage emploie la procedure qui rend les attributs et les descripteurs
// avec les noms. Celle qui ne rend que les noms couterait ensuite une recherche
// et une lecture d attributs par entree, soit deux allers retours par chapitre
// sur une bibliotheque qui en compte des milliers.
//

extension PartageNfs {
    // MARK: Descripteurs

    /// Le descripteur d un chemin relatif, resolu composant par composant.
    func descripteur(de chemin: String) async throws -> Data {
        if let connu = descripteurs[chemin] {
            return connu
        }

        var courant = try await monter()
        var parcouru = ""

        for composant in chemin.split(separator: "/") {
            parcouru = CheminDePartage.joindre(parcouru, String(composant))

            if let connu = descripteurs[parcouru] {
                courant = connu

                continue
            }

            courant = try await rechercher(String(composant), dans: courant)
            descripteurs[parcouru] = courant
        }

        return courant
    }

    /// Cherche un nom dans un dossier et rend le descripteur trouve.
    private func rechercher(_ nom: String, dans dossier: Data) async throws -> Data {
        var arguments = EcritureXdr()
        arguments.variable(dossier)
        arguments.texte(nom)

        var resultat = try await appeler(procedure: 3, arguments: arguments.octets)

        try Self.verifierLeStatut(&resultat)

        guard let descripteur = resultat.variable() else {
            throw ErreurReseau.reponseIllisible
        }

        return descripteur
    }

    /// Lit les attributs d un descripteur.
    func attributs(descripteur: Data, chemin: String) async throws -> EntreeDePartage {
        var arguments = EcritureXdr()
        arguments.variable(descripteur)

        var resultat = try await appeler(procedure: 1, arguments: arguments.octets)

        try Self.verifierLeStatut(&resultat)

        guard let lus = AttributsNfs.lire(&resultat) else {
            throw ErreurReseau.reponseIllisible
        }

        return lus.entree(chemin: chemin)
    }

    // MARK: Listage

    /// Lit un tour de dossier, avec les attributs et les descripteurs joints.
    func lireUnTourDeDossier(
        _ descripteur: Data,
        parent: String,
        curseur: UInt64,
        verificateur: Data
    ) async throws -> TourDeDossierNfs {
        var arguments = EcritureXdr()
        arguments.variable(descripteur)
        arguments.entier64(curseur)
        arguments.fixe(verificateur)
        arguments.entier32(Self.entreesParTour)
        arguments.entier32(Self.entreesParTour * 8)

        var resultat = try await appeler(procedure: 17, arguments: arguments.octets)

        try Self.verifierLeStatut(&resultat)

        _ = AttributsNfs.lireOptionnels(&resultat)

        guard let verificateurRendu = resultat.fixe(8) else {
            throw ErreurReseau.reponseIllisible
        }

        return try Self.tour(dans: &resultat, parent: parent, verificateur: verificateurRendu)
    }

    /// Decoupe la suite d entrees rendue par un tour de listage.
    private static func tour(
        dans resultat: inout LectureXdr,
        parent: String,
        verificateur: Data
    ) throws -> TourDeDossierNfs {
        var entrees: [EntreeDePartage] = []
        var trouves: [String: Data] = [:]
        var dernier: UInt64?

        while let suit = resultat.booleen(), suit {
            guard resultat.entier64() != nil,
                  let nom = resultat.texte(),
                  let curseurDeLEntree = resultat.entier64()
            else {
                throw ErreurReseau.reponseTronquee
            }

            dernier = curseurDeLEntree

            let attributs = AttributsNfs.lireOptionnels(&resultat)
            let descripteur = lireUnDescripteurOptionnel(&resultat)

            // Le dossier lui meme et son parent reviennent dans tout listage.
            // Les garder ferait boucler l analyse indefiniment.
            guard nom != ".", nom != ".." else {
                continue
            }

            let chemin = CheminDePartage.joindre(parent, nom)

            if let descripteur {
                trouves[chemin] = descripteur
            }

            entrees.append(attributs?.entree(chemin: chemin) ?? EntreeDePartage(chemin: chemin, estDossier: false))
        }

        return TourDeDossierNfs(
            entrees: entrees,
            descripteurs: trouves,
            dernierCurseur: dernier,
            verificateur: verificateur,
            termine: resultat.booleen() ?? true
        )
    }

    // MARK: Outils

    /// Appelle une procedure du programme de fichiers.
    func appeler(procedure: UInt32, arguments: Data) async throws -> LectureXdr {
        do {
            return try await clientNfs.appeler(
                programme: Programme.fichiers,
                version: 3,
                procedure: procedure,
                arguments: arguments
            )
        } catch let erreur as ErreurRpc {
            throw erreur.reseau
        }
    }

    /// Leve quand la procedure a rendu autre chose qu un succes.
    static func verifierLeStatut(_ resultat: inout LectureXdr) throws {
        guard let statut = resultat.entier32() else {
            throw ErreurReseau.reponseIllisible
        }
        guard statut != 0 else {
            return
        }

        throw ErreurRpc.statut(programme: Programme.fichiers, code: statut).reseau
    }

    /// Lit un descripteur optionnel, tel qu il suit les attributs d une entree.
    private static func lireUnDescripteurOptionnel(_ lecture: inout LectureXdr) -> Data? {
        guard let present = lecture.booleen(), present else {
            return nil
        }

        return lecture.variable()
    }
}

// MARK: - Valeurs

/// Ce qu un tour de listage rapporte.
struct TourDeDossierNfs: Sendable {
    let entrees: [EntreeDePartage]
    let descripteurs: [String: Data]
    let dernierCurseur: UInt64?
    let verificateur: Data
    let termine: Bool
}

/// Les attributs d un objet NFS, reduits a ce dont le partage a besoin.
struct AttributsNfs: Sendable, Hashable {
    /// Deux pour un dossier, un pour un fichier ordinaire.
    let type: UInt32

    let taille: UInt64

    /// Date de derniere modification, en secondes depuis l epoque.
    let secondes: UInt32

    var estDossier: Bool {
        type == 2
    }

    func entree(chemin: String) -> EntreeDePartage {
        EntreeDePartage(
            chemin: chemin,
            estDossier: estDossier,
            taille: taille,
            dateModification: secondes == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(secondes))
        )
    }

    /// Lit un bloc d attributs, dont la disposition est fixee par la norme.
    ///
    /// Les quatre vingt quatre octets se suivent sans etiquette, et les champs
    /// que le partage n emploie pas sont sautes plutot que lus. Sauter le mauvais
    /// nombre d octets rendrait une taille de fichier prise dans un identifiant
    /// de systeme de fichiers, donc une archive dont rien ne dirait pourquoi elle
    /// est illisible.
    static func lire(_ lecture: inout LectureXdr) -> AttributsNfs? {
        guard let type = lecture.entier32(),
              lecture.sauter(16),
              let taille = lecture.entier64(),
              lecture.sauter(8),
              lecture.sauter(8),
              lecture.sauter(8),
              lecture.sauter(8),
              lecture.sauter(8),
              let secondes = lecture.entier32(),
              lecture.sauter(4),
              lecture.sauter(8)
        else {
            return nil
        }

        return AttributsNfs(type: type, taille: taille, secondes: secondes)
    }

    /// Lit un bloc d attributs precede de son drapeau de presence.
    static func lireOptionnels(_ lecture: inout LectureXdr) -> AttributsNfs? {
        guard let present = lecture.booleen(), present else {
            return nil
        }

        return lire(&lecture)
    }
}
