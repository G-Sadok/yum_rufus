import Core
import Foundation

//
// LectureOpds
//
// La lecture d un chapitre servi par un catalogue OPDS, par les deux chemins
// que ces catalogues offrent.
//
// Le premier chemin est la diffusion page par page, l extension OPDS-PSE. Le
// catalogue publie alors un gabarit d adresse, ou le numero de page reste a
// completer, et le nombre de pages du chapitre. C est le chemin normal chez
// Komga et chez Kavita, et c est de loin le meilleur : une page pese quelques
// centaines de kilooctets, la ou le chapitre entier en pese cent fois plus.
//
// Le second chemin est le rapatriement du conteneur, exactement comme chez
// Jellyfin. Il vaut pour tous les catalogues qui ne publient pas l extension,
// et ils sont nombreux : le catalogue ne connait alors que le fichier du
// chapitre, jamais son contenu, et la seule lecture honnete est de le rapatrier
// puis de l ouvrir comme un conteneur local.
//
// Le choix entre les deux ne se fait pas a la configuration mais chapitre par
// chapitre, parce que l annonce vit dans l entree du flux et non dans le
// fichier. Une consequence en decoule et elle est assumee : un chapitre ouvert
// sans avoir vu la liste des chapitres de sa serie, ce qui arrive apres un
// redemarrage, ne connait pas cette annonce et passe par le rapatriement. La
// lecture est alors plus lente, jamais fausse.
//

extension SourceOpds {
    /// Rend les pages d un chapitre, dans l ordre de lecture.
    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        if let connues = pagesRetenues[chapitre] {
            return connues
        }

        let descripteur = try descripteurDeLecture(chapitre)
        let pages = try await pages(de: descripteur, chapitre: chapitre)
        pagesRetenues[chapitre] = pages

        return pages
    }

    /// Vide le cache de conteneurs de cette source.
    ///
    /// A appeler quand l utilisateur libere de l espace. Les pages retenues sont
    /// oubliees en meme temps : elles designent des fichiers qui n existent plus.
    public func viderLeCache() throws {
        pagesRetenues.removeAll()

        try cache.vider()
    }

    /// Ce qu il faut savoir pour lire ce chapitre.
    ///
    /// Le descripteur retenu pendant la lecture de la liste des chapitres est
    /// prefere. A defaut, l identifiant est lui meme l adresse du fichier, et le
    /// format se deduit alors de cette adresse seule.
    private func descripteurDeLecture(_ chapitre: String) throws -> DescripteurDeChapitreOpds {
        if let connu = chapitresRetenus[chapitre] {
            return connu
        }

        let adresse = try adresseDeSource(chapitre)

        return DescripteurDeChapitreOpds(
            acquisition: adresse,
            format: FormatDeConteneurOpds.deduire(type: nil, adresse: adresse),
            titre: adresse.lastPathComponent,
            diffusion: nil
        )
    }

    /// Les pages de ce chapitre, par la diffusion ou par le conteneur.
    private func pages(
        de descripteur: DescripteurDeChapitreOpds,
        chapitre: String
    ) async throws -> [PageDistante] {
        if let diffusion = descripteur.diffusion {
            return try pagesDiffusees(diffusion, chapitre: chapitre)
        }

        do {
            let rapatrie = try await rapatrier(descripteur, chapitre: chapitre)

            return try enumerer(rapatrie, descripteur: descripteur, chapitre: chapitre)
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }

    /// Les pages annoncees par la diffusion page par page.
    ///
    /// Aucune requete n est faite ici. Le catalogue a deja dit combien de pages
    /// le chapitre porte et comment fabriquer l adresse de chacune, les octets
    /// viendront quand la chaine d images les demandera.
    private func pagesDiffusees(
        _ diffusion: DiffusionDePagesOpds,
        chapitre: String
    ) throws -> [PageDistante] {
        try (0..<diffusion.nombreDePages).map { index in
            guard let adresse = diffusion.adresse(page: index) else {
                throw ErreurReseau.serveurIntrouvable
            }

            try verifier(adresse)

            return PageDistante(identifiantChapitre: chapitre, index: index, emplacement: adresse)
        }
    }

    /// Rapatrie le conteneur du chapitre, ou rend celui deja range.
    ///
    /// Le format rendu n est pas toujours celui du descripteur. Un chapitre
    /// ouvert sans que le flux de sa serie ait ete lu ne connait pas son format,
    /// et c est alors le type de contenu de la reponse qui le nomme. Le type
    /// annonce par le serveur, jamais les premiers octets du fichier : deviner
    /// au vu du contenu ouvrirait sans le dire une archive que l utilisateur
    /// croit d un autre type.
    private func rapatrier(
        _ descripteur: DescripteurDeChapitreOpds,
        chapitre: String
    ) async throws -> ConteneurRapatrie {
        if let range = cache.fichierExistant(chapitre: chapitre) {
            return ConteneurRapatrie(fichier: range, format: range.pathExtension)
        }

        try verifier(descripteur.acquisition)

        // La requete est batie a la main plutot que par le client : celle la
        // annonce accepter du JSON, ce qui n a aucun sens pour un fichier
        // binaire et ce qu un serveur strict a le droit de refuser.
        let reponse = try await client().executer(URLRequest(url: descripteur.acquisition))

        guard reponse.corps.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }

        let format = FormatDeConteneurOpds.confirme(
            descripteur.format,
            typeDeLaReponse: reponse.entete("Content-Type"),
            adresse: descripteur.acquisition
        )
        let fichier = cache.fichier(chapitre: chapitre, format: format)
        try cache.ecrire(reponse.corps, dans: fichier)

        return ConteneurRapatrie(fichier: fichier, format: format)
    }

    /// Enumere les pages du conteneur rapatrie.
    ///
    /// Seul l index du conteneur est lu, aucune page n est decompressee. Les
    /// octets viendront a la demande, par le protocole `DocumentLocal`, comme
    /// pour un chapitre pose sur le disque.
    private func enumerer(
        _ rapatrie: ConteneurRapatrie,
        descripteur: DescripteurDeChapitreOpds,
        chapitre: String
    ) throws -> [PageDistante] {
        let fichier = rapatrie.fichier
        let document = try LecteurDeConteneur.ouvrir(
            fichier,
            format: rapatrie.format,
            nom: descripteur.titre
        )

        return try document.toutesLesPages().map { reference in
            PageDistante(
                identifiantChapitre: chapitre,
                index: reference.index,
                emplacement: fichier,
                entree: reference.nom,
                octets: reference.tailleOctets
            )
        }
    }
}

// MARK: - Conteneur rapatrie

/// Un conteneur range dans le cache, et le format sous lequel il l a ete.
struct ConteneurRapatrie: Sendable, Hashable {
    let fichier: URL
    let format: String
}

// MARK: - Gabarit de diffusion

extension DiffusionDePagesOpds {
    /// Le marqueur de numero de page, tel que l extension OPDS-PSE l ecrit.
    private static let marqueur = "pageNumber"

    /// Le parametre par lequel un catalogue annonce numeroter a partir de zero.
    private static let numerotationDepuisZero = "zero_based"

    /// L adresse de la page a cet index, ou nul quand le gabarit ne s assemble
    /// pas.
    ///
    /// L index est celui du domaine, qui part de zero. Le numero envoye au
    /// serveur, lui, depend du catalogue : la plupart numerotent a partir de un,
    /// certains annoncent `zero_based` dans leur gabarit et partent de zero.
    /// Se tromper decale tout le chapitre d une page et fait manquer la
    /// derniere, ce qu aucune lecture manuelle ne remarque avant la fin.
    func adresse(page index: Int) -> URL? {
        let numero = estNumeroteDepuisZero ? index : index + 1
        let assemblee = gabarit.absoluteString
            .replacingOccurrences(of: Self.echappe, with: String(numero))
            .replacingOccurrences(of: Self.brut, with: String(numero))

        return Self.sansGabaritResiduel(assemblee)
    }

    /// Vrai quand le catalogue annonce numeroter ses pages a partir de zero.
    private var estNumeroteDepuisZero: Bool {
        URLComponents(url: gabarit, resolvingAgainstBaseURL: false)?
            .queryItems?
            .contains { $0.name == Self.numerotationDepuisZero && $0.value?.lowercased() == "true" }
            ?? false
    }

    /// Le marqueur tel qu il apparait dans une adresse assemblee.
    private static var echappe: String {
        "%7B\(marqueur)%7D"
    }

    /// Le marqueur tel qu il apparait dans le document du catalogue.
    private static var brut: String {
        "{\(marqueur)}"
    }

    /// Echappe les accolades d un gabarit pour qu il devienne une adresse.
    ///
    /// Les accolades ne sont pas des caracteres d URL, et une adresse qui en
    /// porte est refusee a l assemblage. Les echapper conserve le gabarit
    /// intact jusqu au moment de le completer.
    static func echapper(_ gabarit: String) -> String {
        gabarit
            .replacingOccurrences(of: "{", with: "%7B")
            .replacingOccurrences(of: "}", with: "%7D")
    }

    /// L adresse debarrassee des parametres qui portent encore un gabarit.
    ///
    /// L extension definit d autres marqueurs que le numero de page, la largeur
    /// maximale par exemple. Ils sont facultatifs, et les laisser en place
    /// enverrait au serveur une largeur litteralement nommee `maxWidth`, que la
    /// plupart refusent.
    private static func sansGabaritResiduel(_ adresse: String) -> URL? {
        guard var composants = URLComponents(string: adresse) else {
            return nil
        }
        if let parametres = composants.queryItems {
            let propres = parametres.filter { $0.value?.contains("%7B") == false && $0.value?.contains("{") == false }
            composants.queryItems = propres.isEmpty ? nil : propres
        }

        return composants.url
    }
}
