import Core
import Foundation

//
// IndexCentralZip
//
// Lecture de l index central du format ZIP.
//
// C est cet index qui donne l acces aleatoire exige par la section 5.3 : il
// liste toutes les entrees avec la position de leur en tete local, donc ouvrir
// la page N revient a lire l index puis a sauter directement a cette position.
// Aucune entree precedente n est lue, et encore moins decompressee.
//
// L index se trouve en fin de fichier, derriere un enregistrement de fin dont
// la taille varie avec le commentaire de l archive. Il faut donc le chercher a
// reculons, ce que fait `positionDeLaFin`.
//

enum IndexCentralZip {
    static let signatureFin: UInt32 = 0x0605_4B50
    static let signatureFinZip64: UInt32 = 0x0606_4B50
    static let signatureLocalisateurZip64: UInt32 = 0x0706_4B50
    static let signatureEntree: UInt32 = 0x0201_4B50

    static let tailleFin = 22
    static let tailleLocalisateurZip64 = 20
    static let tailleEnTeteEntree = 46

    /// Longueur maximale de la zone fouillee pour trouver l enregistrement de
    /// fin : ses 22 octets plus le plus grand commentaire que le format
    /// autorise, soit 65535 octets.
    private static let zoneDeRecherche = 22 + 65535

    /// Lit l index central et rend toutes les entrees de l archive.
    ///
    /// - Throws: `ErreurDeDocument.conteneurIllisible` si le fichier n est pas
    ///   un ZIP, `ErreurDeDocument.conteneurTronque` s il s arrete avant ce que
    ///   son index annonce.
    static func lire(_ source: some SourceDOctets) throws -> ContenuZip {
        let queue = try queueDuFichier(source)
        guard let positionDansLaQueue = positionDeLaFin(queue) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        let fin = queue.subdata(in: (queue.startIndex + positionDansLaQueue)..<queue.endIndex)
        let positionDeFin = source.taille - UInt64(queue.count - positionDansLaQueue)

        let annonce = try annonceDeLIndex(
            fin: fin,
            queue: queue,
            positionDeFin: positionDeFin,
            source: source
        )
        let repere = try repereDeLIndex(annonce, source: source)
        let octets = try source.lire(a: repere.debut, longueur: Int(annonce.taille))
        let entrees = try entrees(dans: octets, decalage: repere.decalage, source: source)

        return ContenuZip(entrees: entrees, commentaire: commentaire(fin))
    }

    /// Ce que l enregistrement de fin annonce de l index central.
    struct AnnonceDIndex {
        /// Taille de l index central en octets.
        let taille: UInt64
        /// Position de l index central telle que l archive la declare.
        let offsetAnnonce: UInt64
        /// Position de l enregistrement de fin qui porte cette annonce.
        let positionDeLEnregistrement: UInt64
        /// Nom de la source, pour les erreurs.
        let nom: String
    }

    /// Les trois valeurs d une entree que l extension ZIP64 peut remplacer.
    struct TaillesDEntree {
        var decompressee: UInt64
        var compressee: UInt64
        var offset: UInt64
    }

    /// Position reelle de l index central et ecart avec la position annoncee.
    struct RepereDIndex {
        let debut: UInt64
        /// Ecart entre les positions annoncees et les positions reelles.
        ///
        /// Il est non nul quand des octets precedent l archive, ce qui arrive
        /// avec les archives auto extractibles et avec les CBZ fabriques en
        /// concatenant un en tete. Sans ce rattrapage, chaque page serait lue
        /// au mauvais endroit.
        let decalage: Int64
    }

    /// Lit la fin du fichier, seule zone ou l enregistrement de fin peut vivre.
    private static func queueDuFichier(_ source: some SourceDOctets) throws -> Data {
        guard source.taille >= UInt64(tailleFin) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        let longueur = Int(min(source.taille, UInt64(zoneDeRecherche)))

        return try source.lire(a: source.taille - UInt64(longueur), longueur: longueur)
    }

    /// Cherche a reculons l enregistrement de fin dans la queue du fichier.
    ///
    /// La recherche part de la fin parce qu un commentaire d archive peut
    /// contenir la signature : la derniere occurrence coherente est la bonne.
    private static func positionDeLaFin(_ queue: Data) -> Int? {
        var position = queue.count - tailleFin

        while position >= 0 {
            if estEnregistrementDeFin(queue, a: position) {
                return position
            }
            position -= 1
        }

        return nil
    }

    /// Verifie qu un enregistrement de fin commence bien a cette position.
    ///
    /// La signature ne suffit pas : elle peut apparaitre dans un commentaire ou
    /// dans une page. La longueur du commentaire annoncee doit aussi tomber
    /// exactement sur la fin du fichier.
    private static func estEnregistrementDeFin(_ queue: Data, a position: Int) -> Bool {
        guard LectureBinaire.entier32(queue, a: position) == signatureFin,
              let longueurCommentaire = LectureBinaire.entier16(queue, a: position + 20)
        else {
            return false
        }

        return position + tailleFin + Int(longueurCommentaire) == queue.count
    }

    /// Rend le commentaire global de l archive, s il en porte un.
    private static func commentaire(_ fin: Data) -> String? {
        guard let longueur = LectureBinaire.entier16(fin, a: 20), longueur > 0 else { return nil }

        let debut = fin.startIndex + tailleFin
        guard debut + Int(longueur) <= fin.endIndex else { return nil }

        return texte(fin.subdata(in: debut..<(debut + Int(longueur))))
    }
}
