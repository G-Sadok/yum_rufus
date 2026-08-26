import Core
import Foundation

//
// LectureJellyfin
//
// La lecture d un chapitre servi par Jellyfin, et le cache qui la rend possible.
//
// C est la partie de cette source qui ne ressemble a aucune autre. Komga et
// Kavita ouvrent les conteneurs a notre place et servent les pages une par une :
// leurs `PageDistante` portent une adresse et rien d autre. Jellyfin ne fait
// pas cela. Il connait le fichier d un livre, sa taille et son emplacement, pas
// ce qu il y a dedans. Aucun de ses points d entree ne rend la page numero sept
// d un CBZ.
//
// La seule lecture honnete est donc celle ci : rapatrier le conteneur, puis le
// lire comme un conteneur local. C est exactement la forme que decrit le champ
// `entree` de `PageDistante`, celle qu emploie deja le dossier local, et elle
// traverse le reste de l application sans qu aucune couche ait a savoir d ou
// vient le fichier.
//
// Deux consequences en decoulent, et elles sont assumees.
//
// La premiere est qu ouvrir un chapitre coute son telechargement complet. C est
// pourquoi la capacite `telechargement` est declaree, et c est pourquoi les
// pages enumerees sont retenues : revenir au sommaire puis rouvrir le chapitre
// ne doit pas rapatrier deux fois le meme fichier.
//
// La seconde est qu il faut un endroit ou poser ce fichier. Le cache est propre
// a la source, pose dans le dossier de caches du systeme, donc effacable par
// l appareil quand il manque de place. Les noms de fichiers y sont assainis :
// l identifiant vient du serveur, et un serveur hostile qui rendrait un
// identifiant charge de points et de barres ecrirait sinon hors du cache.
//

extension SourceJellyfin {
    /// Rend les pages d un chapitre, en rapatriant son conteneur au besoin.
    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        if let connues = pagesRetenues[chapitre] {
            return connues
        }

        let introuvable = ErreurDeSource.chapitreIntrouvable(identifiant: chapitre)
        let livre = try await element(chapitre, siIntrouvable: introuvable)

        guard livre.estUnLivre else {
            // Un identifiant qui designe un dossier ou un film ne designe pas un
            // chapitre. Le rapatrier quand meme telechargerait une serie
            // entiere, ou un film, pour n en tirer aucune page.
            throw introuvable
        }
        guard let format = livre.format else {
            // Sans format, aucun lecteur ne peut etre choisi. Le dire nomme la
            // cause, la ou une liste de pages vide laisserait croire a un
            // chapitre non analyse par le serveur.
            throw ErreurDeSource.formatNonPrisEnCharge(nom: livre.titre, format: formatInconnu)
        }

        let fichier = try await rapatrier(chapitre, format: format)
        let pages = try enumerer(fichier, format: format, chapitre: chapitre, nom: livre.titre)
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

    /// Rapatrie le conteneur d un chapitre, ou rend celui deja range.
    private func rapatrier(_ chapitre: String, format: String) async throws -> URL {
        let fichier = cache.fichier(chapitre: chapitre, format: format)

        guard cache.contient(fichier) == false else {
            return fichier
        }

        do {
            let client = try await client()
            let adresse = try ClientHttp.adresse(
                base: base,
                chemin: CheminsJellyfin.telechargement(chapitre)
            )
            // La requete est batie a la main plutot que par `requete(chemin:)` :
            // celle la annonce accepter du JSON, ce qui n a aucun sens pour un
            // fichier binaire et ce qu un serveur strict a le droit de refuser.
            let reponse = try await client.executer(URLRequest(url: adresse))

            guard reponse.corps.isEmpty == false else {
                throw ErreurReseau.reponseVide
            }

            try cache.ecrire(reponse.corps, dans: fichier)

            return fichier
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }

    /// Enumere les pages du conteneur rapatrie.
    ///
    /// Seul l index du conteneur est lu, aucune page n est decompressee. Les
    /// octets viendront a la demande, par le protocole `DocumentLocal`, comme
    /// pour un chapitre pose sur le disque.
    private func enumerer(
        _ fichier: URL,
        format: String,
        chapitre: String,
        nom: String
    ) throws -> [PageDistante] {
        do {
            let document = try LecteurDeConteneur.ouvrir(fichier, format: format, nom: nom)

            return try document.toutesLesPages().map { reference in
                PageDistante(
                    identifiantChapitre: chapitre,
                    index: reference.index,
                    emplacement: fichier,
                    entree: reference.nom,
                    octets: reference.tailleOctets
                )
            }
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Le format annonce quand le serveur n en nomme aucun.
    private var formatInconnu: String {
        "inconnu"
    }
}

// MARK: - Cache de conteneurs

/// Ou sont ranges les conteneurs rapatries d une source Jellyfin.
///
/// Le type est minuscule et pourtant nomme : il porte l assainissement des noms
/// de fichiers, qui est une regle de securite et non un detail d ecriture. Le
/// laisser en deux lignes dans la source aurait rendu invisible le fait que ces
/// noms viennent d un serveur distant.
struct CacheDeConteneursJellyfin: Sendable, Hashable {
    /// Dossier propre a la source.
    let dossier: URL

    /// Le cache range dans le dossier de caches du systeme.
    ///
    /// Le dossier de caches et non celui de documents : un conteneur rapatrie se
    /// retelecharge, il n a donc rien a faire dans une sauvegarde, et le systeme
    /// a le droit de l effacer quand l appareil manque de place.
    static func parDefaut(source: SourceID) -> CacheDeConteneursJellyfin {
        let racine = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return CacheDeConteneursJellyfin(
            dossier: racine.appending(path: "Tsuzuki/Jellyfin/\(source.brut.uuidString)")
        )
    }

    /// Le fichier ou ranger le conteneur d un chapitre.
    func fichier(chapitre: String, format: String) -> URL {
        dossier.appending(path: "\(Self.assaini(chapitre)).\(Self.assaini(format))")
    }

    /// Vrai quand ce conteneur est deja range.
    func contient(_ fichier: URL) -> Bool {
        FileManager.default.fileExists(atPath: fichier.path)
    }

    /// Ecrit un conteneur rapatrie, en creant le dossier au besoin.
    ///
    /// L ecriture est atomique : une lecture interrompue en plein
    /// telechargement laisserait sinon un fichier tronque dans le cache, que la
    /// visite suivante prendrait pour un conteneur complet et corrompu.
    func ecrire(_ octets: Data, dans fichier: URL) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try octets.write(to: fichier, options: .atomic)
    }

    /// Efface tout ce que ce cache contient.
    func vider() throws {
        guard FileManager.default.fileExists(atPath: dossier.path) else {
            return
        }

        try FileManager.default.removeItem(at: dossier)
    }

    /// Un nom de fichier reduit a ce qui ne peut designer aucun autre dossier.
    ///
    /// Les identifiants viennent du serveur. Un serveur hostile qui rendrait un
    /// identifiant fait de points et de barres ecrirait hors du cache, et la
    /// section 11 ne laisse pas ce chemin ouvert. Tout ce qui n est ni lettre,
    /// ni chiffre, ni tiret est donc remplace.
    private static func assaini(_ brut: String) -> String {
        let propre = brut.map { caractere in
            caractere.isLetter || caractere.isNumber || caractere == "-" ? caractere : "_"
        }

        return propre.isEmpty ? "sans-nom" : String(propre)
    }
}
