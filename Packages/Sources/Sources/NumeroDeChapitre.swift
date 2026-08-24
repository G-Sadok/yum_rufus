import Foundation

//
// NumeroDeChapitre
//
// Deduction du numero de chapitre a partir d un nom de fichier.
//
// Aucune convention n existe. Un dossier local contient aussi bien
// `Chapitre 12.cbz` que `Serie - Vol.2 Ch.03 - titre.cbz` ou `012.cbz`. Deux
// regles suffisent a couvrir l essentiel sans inventer de numeros.
//
// D abord un marqueur de chapitre, s il y en a un : le nombre qui suit `ch`,
// `chap`, `chapitre`, `chapter`, `ep`, `episode`, `c` ou `#` est le numero, et
// rien d autre ne peut le contredire.
//
// Sinon le dernier nombre du nom, les marqueurs de volume ayant ete retires au
// prealable. Sans ce retrait `Vol.2` gagnerait sur les noms qui ne portent que
// le volume et le titre, et toute la serie recevrait le numero 2.
//
// Quand aucune regle ne s applique, le numero reste inconnu. C est l analyse
// qui retombe alors sur le rang du chapitre, parce qu elle seule connait ce
// rang. Rendre zero ici serait un numero faux, pas une absence.
//

/// Lecture du numero de chapitre porte par un nom de fichier ou de dossier.
public enum NumeroDeChapitre {
    /// Les expressions sont calculees a chaque appel et non rangees dans des
    /// constantes statiques : `Regex` n est pas `Sendable`, et une constante
    /// statique d un type non `Sendable` est un etat global mutable partage, que
    /// le mode strict de Swift 6 refuse a juste titre. La construction est celle
    /// d un litteral deja analyse a la compilation, son cout est negligeable
    /// devant le listage de disque qui l entoure.
    private static var apresMarqueur: Regex<(Substring, Substring)> {
        #/(?:\b(?:chapitre|chapter|chap|ch|episode|ep|c)|#)[\s._-]*(\d+(?:[.,]\d+)?)/#
    }

    private static var marqueurDeVolume: Regex<Substring> {
        #/\b(?:volume|vol|tome|[tv])[\s._-]*\d+(?:[.,]\d+)?/#
    }

    private static var nombre: Regex<Substring> {
        #/\d+(?:[.,]\d+)?/#
    }

    /// Rend le numero porte par le nom, ou nul quand il n en porte aucun.
    ///
    /// L extension est retiree avant l analyse, sinon `serie.7z` donnerait 7.
    public static func extraire(de nom: String) -> Double? {
        let sansExtension = (nom as NSString).deletingPathExtension.lowercased()

        if let trouve = sansExtension.firstMatch(of: apresMarqueur) {
            return valeur(String(trouve.1))
        }

        let sansVolume = sansExtension.replacing(marqueurDeVolume, with: " ")

        guard let dernier = sansVolume.matches(of: nombre).last else { return nil }

        return valeur(String(dernier.0))
    }

    /// Convertit le texte du nombre, la virgule valant point decimal.
    private static func valeur(_ texte: String) -> Double? {
        Double(texte.replacingOccurrences(of: ",", with: "."))
    }
}
