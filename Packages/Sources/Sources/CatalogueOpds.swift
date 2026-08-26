import Core
import Foundation

//
// CatalogueOpds
//
// La traduction des entrees d un flux en entites du domaine, et ce qu il faut
// retenir au passage pour pouvoir lire un chapitre ensuite.
//
// Le point qui merite d etre lu avant de toucher a ce fichier est le choix des
// identifiants. Une entree OPDS porte un `id`, et il serait tentant de le
// prendre. Il ne sert a rien : aucun point d entree du protocole ne permet de
// retrouver une entree a partir de cet identifiant la. Ce qui est interrogeable,
// c est l adresse du lien, et c est donc elle qui sert d identifiant de serie
// comme de chapitre. Elle est absolue, resolue une fois ici, et jamais relative :
// une adresse relative rangee dans la base ne saurait plus a quoi se rapporter
// le jour ou elle en ressortirait.
//
// Le descripteur de lecture est retenu dans la meme passe. La diffusion page par
// page est annoncee dans l entree du flux, jamais dans le fichier du chapitre,
// et l identifiant du chapitre ne saurait pas la porter. La retenir ici est ce
// qui evite de rapatrier cent megaoctets quand le catalogue sait servir une page
// de trois cents kilooctets.
//

extension SourceOpds {
    /// Traduit une entree de navigation en serie du domaine.
    ///
    /// - Returns: nul quand le lien de l entree ne se resout pas en une adresse
    ///   de ce catalogue. Une entree qui pointe ailleurs est ecartee en
    ///   silence : elle existe chez les agregateurs, qui melangent plusieurs
    ///   serveurs dans un meme flux, et rien ne serait gagne a faire echouer la
    ///   page entiere pour elle.
    func mangaDistant(_ entree: EntreeOpds, relativement base: URL) -> MangaDistant? {
        guard let navigation = entree.navigation,
              let adresse = try? resoudre(navigation.adresse, relativement: base)
        else {
            return nil
        }

        return MangaDistant(
            identifiant: adresse.absoluteString,
            titre: entree.titre,
            auteurs: entree.auteurs,
            resume: entree.resume,
            genres: entree.categories,
            langue: entree.langue,
            urlCouverture: entree.couverture
                .flatMap { try? resoudre($0.adresse, relativement: base) }?
                .absoluteString
        )
    }

    /// Traduit une entree d acquisition en chapitre du domaine.
    ///
    /// Le descripteur de lecture est retenu au passage, sans quoi la lecture
    /// devrait relire le flux de la serie pour savoir comment ouvrir le
    /// chapitre que l utilisateur vient de choisir.
    func chapitreDistant(_ atteinte: EntreeAtteinte, serie: String, ordre: Int) -> ChapitreDistant? {
        guard let descripteur = descripteur(atteinte) else {
            return nil
        }

        let identifiant = descripteur.acquisition.absoluteString
        chapitresRetenus[identifiant] = descripteur

        return ChapitreDistant(
            identifiant: identifiant,
            identifiantManga: serie,
            numero: NumeroDeChapitre.extraire(de: atteinte.entree.titre) ?? Double(ordre + 1),
            titre: atteinte.entree.titre,
            langue: atteinte.entree.langue,
            datePublication: atteinte.entree.miseAJour,
            nombrePages: descripteur.diffusion?.nombreDePages ?? atteinte.entree.nombreDePages,
            ordre: ordre
        )
    }

    /// Ce qu il faut savoir pour lire le chapitre que porte cette entree.
    private func descripteur(_ atteinte: EntreeAtteinte) -> DescripteurDeChapitreOpds? {
        guard let acquisition = atteinte.entree.acquisition,
              let adresse = try? resoudre(acquisition.adresse, relativement: atteinte.adresse)
        else {
            return nil
        }

        return DescripteurDeChapitreOpds(
            acquisition: adresse,
            format: FormatDeConteneurOpds.deduire(type: acquisition.type, adresse: adresse),
            titre: atteinte.entree.titre,
            diffusion: diffusion(atteinte)
        )
    }

    /// La diffusion page par page annoncee par cette entree, quand elle l est.
    ///
    /// Le nombre de pages est exige. Un gabarit sans compte ne dit pas ou
    /// s arreter, et enumerer les pages jusqu au premier echec ferait autant de
    /// requetes inutiles que le chapitre a de pages.
    private func diffusion(_ atteinte: EntreeAtteinte) -> DiffusionDePagesOpds? {
        guard let lien = atteinte.entree.diffusionDePages,
              let nombre = lien.nombreDePages,
              nombre > 0,
              let gabarit = try? resoudre(lien.adresse, relativement: atteinte.adresse, gabarit: true)
        else {
            return nil
        }

        return DiffusionDePagesOpds(gabarit: gabarit, nombreDePages: nombre)
    }
}

// MARK: - Lecture d un chapitre

/// Ce qu il faut savoir pour lire un chapitre servi par un catalogue OPDS.
struct DescripteurDeChapitreOpds: Sendable, Hashable {
    /// L adresse du fichier du chapitre.
    let acquisition: URL

    /// Le format du conteneur, deduit du type annonce puis de l adresse.
    let format: String

    /// Le titre de l entree, qui nomme le chapitre dans les erreurs.
    let titre: String

    /// La diffusion page par page, quand le catalogue la publie.
    let diffusion: DiffusionDePagesOpds?
}

/// La diffusion page par page, telle que l extension OPDS-PSE la decrit.
struct DiffusionDePagesOpds: Sendable, Hashable {
    /// L adresse d une page, ou le numero reste a completer.
    let gabarit: URL

    /// Le nombre de pages annonce par le catalogue.
    let nombreDePages: Int
}

/// Deduction du format d un conteneur annonce par un catalogue.
enum FormatDeConteneurOpds {
    /// Les types MIME que les catalogues emploient, et le format qu ils
    /// designent.
    ///
    /// Le type prime sur l extension de l adresse, parce qu une adresse
    /// d acquisition n en porte pas toujours : beaucoup de catalogues servent
    /// leurs fichiers derriere une adresse qui se termine par un identifiant.
    private static let formatsParType: [String: String] = [
        "application/zip": "cbz",
        "application/vnd.comicbook+zip": "cbz",
        "application/x-cbz": "cbz",
        "application/x-cbt": "cbt",
        "application/x-tar": "cbt",
        "application/pdf": "pdf",
    ]

    /// Les formats qu un lecteur de conteneur du projet sait ouvrir.
    ///
    /// La liste est celle de `LecteurDeConteneur`, redite ici parce qu elle sert
    /// a une question que ce dernier ne repond pas : celle de savoir si un
    /// format deduit vaut la peine d etre garde, ou s il faut demander au
    /// serveur ce qu il sert reellement.
    private static let formatsLisibles: Set<String> = Set(formatsParType.values)

    /// Le format retenu apres la reponse du serveur.
    ///
    /// Le format deduit du flux prime quand il est lisible. Sinon le type de
    /// contenu de la reponse decide, et l adresse en dernier recours. C est le
    /// chemin qu emprunte un chapitre ouvert sans que le flux de sa serie ait
    /// ete lu, ce qui arrive apres un redemarrage.
    static func confirme(_ deduit: String, typeDeLaReponse: String?, adresse: URL) -> String {
        guard formatsLisibles.contains(deduit) == false else {
            return deduit
        }

        let annonce = deduire(type: typeDeLaReponse, adresse: adresse)

        return formatsLisibles.contains(annonce) ? annonce : deduit
    }

    /// Le format du conteneur, ou une chaine qui nomme ce qui a ete annonce.
    ///
    /// Un format inconnu n est pas remplace par un format par defaut. Ouvrir un
    /// EPUB comme un ZIP rendrait une liste de pages faite de feuilles de style,
    /// alors que le nommer laisse `ErreurDeSource.formatNonPrisEnCharge` dire ce
    /// qui manque.
    static func deduire(type: String?, adresse: URL) -> String {
        if let connu = formatConnu(type: type) {
            return connu
        }

        let extensionDeLAdresse = adresse.pathExtension.lowercased()

        if extensionDeLAdresse.isEmpty == false {
            return extensionDeLAdresse
        }

        return type?.sansBlancs ?? "inconnu"
    }

    /// Le format que designe ce type MIME, ou nul quand il n en designe aucun.
    ///
    /// Les parametres du type sont retires avant la comparaison : un serveur
    /// annonce `application/zip; charset=binary` aussi bien que `application/zip`,
    /// et les deux designent la meme chose.
    private static func formatConnu(type: String?) -> String? {
        guard let nom = type?.lowercased().split(separator: ";").first else {
            return nil
        }

        return formatsParType[nom.trimmingCharacters(in: .whitespaces)]
    }
}
