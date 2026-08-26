import Foundation

//
// EmplacementICloud
//
// Le double nom d un fichier range dans iCloud Drive.
//
// Un fichier qui n est pas sur l appareil n a pas toujours son nom. Selon la
// facon dont le dossier est monte, le systeme le laisse visible sous son vrai
// nom avec un etat de telechargement, ou le remplace par un substitut cache,
// `.Chapitre 1.cbz.icloud`, qui annonce le fichier sans le porter.
//
// Les deux cas doivent donner la meme bibliotheque. Sinon un chapitre non
// telecharge disparait de la liste sur un appareil et pas sur l autre, et la
// fonctionnalite entiere n a plus d objet : on ne telecharge pas a la demande
// un chapitre qui n est pas affiche.
//
// D ou la separation faite ici. Le nom visible est celui que l utilisateur voit
// et celui qui sert d identifiant de chapitre, stable quel que soit l etat du
// telechargement. Le nom sur le disque est celui qu il faut donner au systeme
// de fichiers maintenant, et il change quand le telechargement se termine. Rien
// d autre dans le paquet n a a connaitre cette distinction.
//

/// Nommage des fichiers d un dossier iCloud Drive.
public enum EmplacementICloud {
    /// Extension portee par le substitut d un fichier non telecharge.
    public static let extensionDeSubstitut = "icloud"

    /// Rend le vrai nom cache derriere un nom de substitut, ou nul quand ce nom
    /// n en est pas un.
    public static func nomReel(de nom: String) -> String? {
        let suffixe = "." + extensionDeSubstitut

        guard nom.hasPrefix("."), nom.hasSuffix(suffixe) else { return nil }

        let reel = nom.dropFirst().dropLast(suffixe.count)

        return reel.isEmpty ? nil : String(reel)
    }

    /// Vrai quand ce nom est celui d un substitut de fichier non telecharge.
    public static func estUnSubstitut(_ nom: String) -> Bool {
        nomReel(de: nom) != nil
    }

    /// Nom du substitut qui annoncerait ce fichier.
    public static func nomDeSubstitut(de nom: String) -> String {
        ".\(nom).\(extensionDeSubstitut)"
    }

    /// Emplacement sous le nom que l utilisateur voit.
    public static func visible(_ surLeDisque: URL) -> URL {
        guard let reel = nomReel(de: surLeDisque.lastPathComponent) else { return surLeDisque }

        return surLeDisque.deletingLastPathComponent().appending(path: reel)
    }

    /// Emplacement reellement pose sur le disque en ce moment.
    ///
    /// A relire a chaque acces et jamais a garder : le substitut disparait au
    /// profit du vrai fichier des que le telechargement se termine, et une URL
    /// retenue avant la fin ne designerait plus rien apres.
    public static func surLeDisque(_ visible: URL) -> URL {
        let gestionnaire = FileManager.default

        guard gestionnaire.fileExists(atPath: visible.path) == false else { return visible }

        let substitut = visible.deletingLastPathComponent()
            .appending(path: nomDeSubstitut(de: visible.lastPathComponent))

        return gestionnaire.fileExists(atPath: substitut.path) ? substitut : visible
    }

    /// Chemin absolu normalise d une entree, meme quand elle n existe pas.
    ///
    /// La normalisation d un chemin resout les liens symboliques de tete, et
    /// elle ne le fait que pour un chemin qui existe. Le nom visible d un
    /// fichier non telecharge n existe pas encore : normaliser son chemin
    /// entier rendrait `/var/...` la ou la racine de la source rend
    /// `/private/var/...`, et toute comparaison de prefixe echouerait. Le
    /// chapitre disparaitrait alors de sa serie tant qu il n est pas
    /// telecharge. Le dossier parent, lui, existe toujours : il est normalise
    /// seul, et le nom se recolle apres.
    public static func cheminNormalise(_ url: URL) -> String {
        let parent = url.deletingLastPathComponent().standardizedFileURL.path
        let prefixe = parent.hasSuffix("/") ? parent : parent + "/"

        return prefixe + url.lastPathComponent
    }
}
