import Foundation

//
// AnalyseurDeComicBookInfo
//
// Lecture du `ComicBookInfo`, source de secours de la section 5.3 du cahier de
// developpement. Il n est pas range dans un fichier de l archive mais dans le
// commentaire global du ZIP, ou il tient en un objet JSON.
//
// L analyse passe par `JSONSerialization` et non par `Codable`. Le format n a
// jamais eu de schema applique : `issue` arrive tantot en nombre tantot en
// chaine, `volume` de meme, `credits` est parfois absent et parfois nul. Un
// `Decodable` genere echouerait en bloc sur la premiere divergence de type et
// rendrait nul un commentaire dont neuf champs sur dix etaient lisibles. Ici
// chaque champ est lu pour lui meme, et un champ illisible ne coute que lui.
//
// Aucune fonction de ce fichier ne leve, pour la meme raison que dans
// `AnalyseurDeComicInfo` : un commentaire casse ne doit jamais empecher
// l ouverture d un chapitre.
//

/// Lecture du bloc `ComicBookInfo` range dans le commentaire d une archive.
public enum AnalyseurDeComicBookInfo {
    /// Prefixe de la cle qui porte le bloc de metadonnees.
    ///
    /// La version fait partie de la cle, `ComicBookInfo/1.0` aujourd hui. On
    /// cherche donc par prefixe, pour qu une revision du format ne rende pas
    /// muet un commentaire par ailleurs identique.
    public static let prefixeDeCle = "ComicBookInfo/"

    /// Analyse le commentaire global d une archive.
    ///
    /// - Returns: les metadonnees trouvees, ou nul si le commentaire n est pas
    ///   un `ComicBookInfo` exploitable.
    public static func analyser(_ commentaire: String) -> MetadonneesComic? {
        analyser(Data(commentaire.utf8))
    }

    /// Analyse les octets d un commentaire.
    public static func analyser(_ donnees: Data) -> MetadonneesComic? {
        guard donnees.isEmpty == false else { return nil }
        guard let racine = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any] else {
            return nil
        }
        guard let bloc = blocDeMetadonnees(racine) else { return nil }

        let metadonnees = MetadonneesComic(
            serie: texte(bloc["series"]),
            titre: texte(bloc["title"]),
            numero: texte(bloc["issue"]),
            volume: entier(bloc["volume"]),
            langue: texte(bloc["language"]),
            resume: texte(bloc["comments"]),
            auteurs: intervenants(bloc["credits"], roles: rolesDAuteur),
            dessinateurs: intervenants(bloc["credits"], roles: rolesDeDessinateur),
            genres: liste(bloc["tags"]),
            editeur: texte(bloc["publisher"])
        )

        return metadonnees.estVide ? nil : metadonnees
    }

    /// Roles du bloc `credits` traites comme une signature de scenario.
    private static let rolesDAuteur: Set<String> = ["writer", "script", "story", "scenario"]

    /// Roles du bloc `credits` traites comme une signature de dessin.
    ///
    /// L encrage et la couleur n y figurent pas : ce sont des metiers distincts
    /// du dessin, et les melanger produirait des listes de six noms sur une
    /// fiche de serie qui n en attend qu un ou deux.
    private static let rolesDeDessinateur: Set<String> = ["penciller", "penciler", "artist"]

    /// Retrouve le bloc versionne parmi les cles de l objet racine.
    private static func blocDeMetadonnees(_ racine: [String: Any]) -> [String: Any]? {
        for (cle, valeur) in racine where cle.hasPrefix(prefixeDeCle) {
            if let bloc = valeur as? [String: Any] {
                return bloc
            }
        }

        return nil
    }

    /// Rend un champ en texte, qu il soit ecrit en chaine ou en nombre.
    private static func texte(_ valeur: Any?) -> String? {
        switch valeur {
        case let chaine as String:
            let nettoye = chaine.trimmingCharacters(in: .whitespacesAndNewlines)
            return nettoye.isEmpty ? nil : nettoye
        case let nombre as NSNumber:
            return nombre.stringValue
        default:
            return nil
        }
    }

    /// Rend un champ en entier, qu il soit ecrit en nombre ou en chaine.
    private static func entier(_ valeur: Any?) -> Int? {
        switch valeur {
        case let nombre as NSNumber:
            nombre.intValue
        case let chaine as String:
            Int(chaine.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            nil
        }
    }

    /// Rend un tableau de chaines, en ecartant les entrees vides.
    private static func liste(_ valeur: Any?) -> [String] {
        guard let brut = valeur as? [Any] else { return [] }

        return brut.compactMap(texte)
    }

    /// Rend les noms du bloc `credits` dont le role figure dans l ensemble
    /// demande, sans doublon et dans l ordre du fichier.
    private static func intervenants(_ valeur: Any?, roles: Set<String>) -> [String] {
        guard let credits = valeur as? [Any] else { return [] }

        var noms: [String] = []
        for credit in credits {
            guard let entree = credit as? [String: Any],
                  let role = texte(entree["role"])?.lowercased(),
                  roles.contains(role),
                  let personne = texte(entree["person"]),
                  noms.contains(personne) == false
            else {
                continue
            }

            noms.append(personne)
        }

        return noms
    }
}
