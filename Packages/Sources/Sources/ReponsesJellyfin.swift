import Core
import Foundation

//
// ReponsesJellyfin
//
// La forme exacte de ce que Jellyfin repond, et sa traduction vers les entites
// distantes de la section 4.1.
//
// Un seul type decrit tout ce que le serveur rend, et ce n est pas un
// raccourci : Jellyfin serialise ses bibliotheques, ses dossiers et ses livres
// dans la meme enveloppe, `BaseItemDto`, dont chaque champ est facultatif selon
// ce que l element est. Trois types identiques a trois champs pres auraient
// triple la surface a maintenir sans rien distinguer que le champ `Type` ne
// distingue deja.
//
// Ce champ `Type` est le seul qui ne soit jamais facultatif dans nos yeux. Le
// tableau 4.2 exige de ne remonter que les elements de type livre, et le filtre
// envoye au serveur ne suffit pas a le garantir : un serveur d une version
// voisine, ou un proxy qui reecrit une requete, peut rendre autre chose que ce
// qui a ete demande. Le tri est donc refait a la reception, et un element dont
// le type est absent est ecarte : un type inconnu n est pas un type livre.
//
// Deux pieges de ce serveur sont traites ici et nulle part ailleurs.
//
// Le premier est le nom de champ. Jellyfin ecrit ses cles en capitale initiale,
// la ou Komga et Kavita les ecrivent en minuscule. Les correspondances sont
// declarees une fois, dans les cles de codage, et jamais recopiees ailleurs.
//
// Le second est la date. Jellyfin tient deux dates par element, celle de
// parution et celle d ajout a la bibliotheque. La liste des chapitres affiche
// une parution : preferer la date d ajout ferait vieillir toute une serie le
// jour ou l utilisateur la reimporte.
//

// MARK: - Enveloppe

/// Une tranche de liste, telle que Jellyfin la rend.
///
/// Le champ des elements est obligatoire, contrairement a tous les autres. Le
/// rendre facultatif ferait passer pour un catalogue vide la reponse d une
/// adresse qui ne sert pas Jellyfin, alors qu une adresse fausse doit se voir
/// comme une erreur et non comme une bibliotheque sans livre.
struct TrancheDeJellyfin: Decodable, Sendable {
    let elements: [ElementDeJellyfin]

    /// Nombre total d elements sous ce parent, decalage non compris.
    let total: Int?

    private enum CodingKeys: String, CodingKey {
        case elements = "Items"
        case total = "TotalRecordCount"
    }
}

/// Un element de la bibliotheque, quelle que soit sa nature.
struct ElementDeJellyfin: Decodable, Sendable {
    let id: String
    let nom: String?

    /// Nature de l element, `Folder` pour une serie, `Book` pour un chapitre.
    let type: String?

    /// Type de collection, present sur les seules bibliotheques.
    let typeDeCollection: String?

    let resume: String?
    let genres: [String]?

    /// Date de parution annoncee par les metadonnees.
    let dateDeParution: String?

    /// Date d ajout a la bibliotheque, le repli quand la parution est inconnue.
    let dateDAjout: String?

    /// Chemin du fichier sur le serveur, d ou se deduit le format faute de mieux.
    let chemin: String?

    /// Format du fichier, quand le serveur le nomme.
    let conteneur: String?

    /// Numero annonce par les metadonnees, quand elles en portent un.
    let numero: Int?

    /// Nombre d elements contenus, pour un dossier.
    let nombreDEnfants: Int?

    /// Etiquettes de version des images, dont la couverture.
    let etiquettesDImages: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case nom = "Name"
        case type = "Type"
        case typeDeCollection = "CollectionType"
        case resume = "Overview"
        case genres = "Genres"
        case dateDeParution = "PremiereDate"
        case dateDAjout = "DateCreated"
        case chemin = "Path"
        case conteneur = "Container"
        case numero = "IndexNumber"
        case nombreDEnfants = "ChildCount"
        case etiquettesDImages = "ImageTags"
    }
}

// MARK: - Tri par type

extension ElementDeJellyfin {
    /// Vrai quand cet element est une bibliotheque de livres.
    ///
    /// C est le premier filtre du tableau 4.2, et le plus economique : une
    /// bibliotheque de films ecartee ici epargne toutes les requetes qu elle
    /// aurait values.
    var estUneBibliothequeDeLivres: Bool {
        typeDeCollection?.lowercased() == "books"
    }

    /// Vrai quand cet element est un livre, donc un chapitre.
    var estUnLivre: Bool {
        type == TypeDElementJellyfin.livre.rawValue
    }

    /// Vrai quand cet element est un dossier, donc une serie.
    var estUnDossier: Bool {
        type == TypeDElementJellyfin.dossier.rawValue
    }

    /// Le titre a afficher, ou l identifiant quand le serveur n en donne aucun.
    var titre: String {
        nom?.sansBlancs ?? id
    }

    /// Le format du conteneur, ou nul quand rien ne permet de le nommer.
    ///
    /// Le champ dedie prime sur l extension du chemin : un serveur qui range ses
    /// livres sans extension le remplit quand meme, et deviner au vu du chemin
    /// donnerait alors un format vide.
    var format: String? {
        if let nomme = conteneur?.sansBlancs {
            return nomme.lowercased()
        }

        guard let suffixe = chemin?.sansBlancs.map({ ($0 as NSString).pathExtension }) else {
            return nil
        }

        return suffixe.sansBlancs?.lowercased()
    }
}

// MARK: - Traduction vers les entites distantes

extension TrancheDeJellyfin {
    /// Les bibliotheques de livres de cette tranche.
    var bibliothequesDeLivres: [String] {
        elements.filter(\.estUneBibliothequeDeLivres).map(\.id)
    }

    /// Les series de cette tranche, les elements d un autre type ecartes.
    func series(base: URL) -> [MangaDistant] {
        elements.filter(\.estUnDossier).map { $0.mangaDistant(base: base) }
    }
}

extension ElementDeJellyfin {
    /// La serie traduite pour le reste de l application.
    ///
    /// Le statut editorial reste inconnu et la langue nulle, et ce n est pas un
    /// oubli : Jellyfin ne tient ni l un ni l autre sur un dossier. Inventer un
    /// statut afficherait une serie declaree en cours alors que rien ne le dit.
    func mangaDistant(base: URL) -> MangaDistant {
        MangaDistant(
            identifiant: id,
            titre: titre,
            resume: resume?.sansBlancs,
            genres: (genres ?? []).compactMap(\.sansBlancs),
            urlCouverture: AdressesJellyfin.couverture(base: base, element: self),
            nombreChapitres: nombreDEnfants
        )
    }

    /// Le chapitre traduit, a son rang dans la serie.
    ///
    /// Le nombre de pages reste nul, et c est exact : Jellyfin ne compte pas les
    /// pages d un livre, il en sert le fichier. Annoncer zero marquerait le
    /// chapitre lu des son ouverture, la part lue etant calculee sur un total nul.
    func chapitreDistant(ordre: Int, serie: String) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: id,
            identifiantManga: serie,
            numero: numeroDeChapitre(ordre: ordre),
            titre: titreDeChapitre(ordre: ordre),
            datePublication: dateDeChapitre,
            ordre: ordre
        )
    }

    /// Le numero du chapitre, du plus sur au plus devine.
    ///
    /// Le numero annonce par les metadonnees prime, parce qu il a ete saisi ou
    /// releve par le serveur. Sans lui, le nom du fichier est analyse comme il
    /// l est pour un dossier local. Sans nom exploitable, le rang fait office de
    /// numero : c est un repli, pas une mesure, et il vaut mieux qu un zero
    /// recopie sur toute une serie.
    private func numeroDeChapitre(ordre: Int) -> Double {
        if let numero {
            return Double(numero)
        }

        return NumeroDeChapitre.extraire(de: nom ?? "") ?? Double(ordre + 1)
    }

    /// Le titre du chapitre, ou nul quand il ne ferait que repeter son numero.
    ///
    /// Un livre nomme `12` affiche deja son numero dans la colonne d a cote.
    /// L afficher deux fois donnerait une liste ou chaque ligne se repete.
    private func titreDeChapitre(ordre: Int) -> String? {
        guard let propre = nom?.sansBlancs else {
            return nil
        }

        let numero = numeroDeChapitre(ordre: ordre)

        guard Double(propre.replacingOccurrences(of: ",", with: ".")) != numero else {
            return nil
        }

        return propre
    }

    /// La date a afficher, parution d abord, ajout ensuite.
    private var dateDeChapitre: Date? {
        LecteurDeDateDeServeur.lire(dateDeParution) ?? LecteurDeDateDeServeur.lire(dateDAjout)
    }
}

// MARK: - Adresses

/// Construction des adresses d images de Jellyfin.
enum AdressesJellyfin {
    /// L adresse de la couverture d un element, ou nul quand il n en a pas.
    ///
    /// Aucune cle d API n est posee dans cette adresse, contrairement a Kavita,
    /// et c est une decision de securite et non une economie. Cette adresse est
    /// persistee dans la base par la couche d import, et la section 11 interdit
    /// qu un identifiant y atterrisse. Jellyfin sert ses images sans preuve
    /// d identite, l adresse se suffit donc a elle meme.
    ///
    /// L echec ne leve pas : une couverture manquante se remplace par un visuel
    /// de repli, alors qu une erreur remontee ferait echouer toute une tranche de
    /// catalogue pour une image.
    static func couverture(base: URL, element: ElementDeJellyfin) -> String? {
        guard let etiquette = element.etiquettesDImages?["Primary"]?.sansBlancs else {
            // Sans etiquette, le serveur n a pas d image pour cet element. Batir
            // l adresse quand meme donnerait une vignette cassee a chaque ligne
            // d une bibliotheque sans couverture.
            return nil
        }

        return try? ClientHttp.adresse(
            base: base,
            chemin: CheminsJellyfin.imagePrincipale(element.id),
            parametres: ParametresJellyfin.image(etiquette: etiquette)
        ).absoluteString
    }
}
