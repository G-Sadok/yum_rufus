import Core
import Foundation

//
// IndexTar
//
// L index qu un TAR ne porte pas, reconstruit par balayage puis conserve.
//
// Le ZIP se termine par un index central : ouvrir la page N coute une lecture
// de fin de fichier et un saut. Le TAR n a rien de tel. Chaque entree est
// precedee de son en tete, et le seul moyen de savoir ou commence la troisieme
// est d avoir lu les deux premieres. Sur une archive de quatre cents mega
// octets, ce balayage touche autant de blocs qu il y a d entrees, dispersees
// sur tout le fichier.
//
// La section 5.3 tranche : on balaie une fois, et on garde le resultat. C est
// ce que decrit ce type. Il ne connait ni disque ni cache, il rend seulement un
// index serialisable ; ou celui ci est range, et quand il est perime, appartient
// a `CacheDIndexDArchive` et a `EmpreinteDeConteneur`.
//
// Le balayage ne lit que les blocs d en tete. Il ne lit les donnees d une
// entree que dans deux cas, les deux fois pour connaitre le nom d une autre :
// un nom long GNU, ou un en tete etendu PAX. Les pages, elles, ne sont jamais
// touchees.
//

/// Emplacement d une entree a l interieur d un TAR.
public struct EntreeTar: Sendable, Hashable, Codable {
    /// Chemin de l entree dans l archive.
    public let nom: String

    /// Position du premier octet de donnees dans le fichier.
    public let offset: UInt64

    /// Nombre d octets de donnees.
    public let taille: UInt64

    public init(nom: String, offset: UInt64, taille: UInt64) {
        self.nom = nom
        self.offset = offset
        self.taille = taille
    }
}

/// Index complet d un TAR, tel qu un balayage le produit.
public struct IndexTar: Sendable, Hashable, Codable {
    /// Version du format d index conserve sur disque.
    ///
    /// Toute evolution de ce qui est range, ou de la facon de le lire, incremente
    /// ce numero. Un index ecrit par une version anterieure est alors ignore et
    /// recalcule, plutot que relu de travers.
    public static let versionDeFormat = 1

    /// Entrees dans l ordre ou le fichier les porte.
    public let entrees: [EntreeTar]

    public init(entrees: [EntreeTar]) {
        self.entrees = entrees
    }

    /// Balaie l archive et construit son index.
    ///
    /// - Throws: `ErreurDeDocument.conteneurIllisible` si les octets ne forment
    ///   pas un TAR, `ErreurDeDocument.conteneurTronque` si une entree annonce
    ///   des donnees qui debordent du fichier.
    public static func scanner(_ source: any SourceDOctets) throws -> IndexTar {
        let taillePleine = source.taille
        let tailleDeBloc = UInt64(EnTeteTar.tailleDeBloc)

        guard taillePleine >= tailleDeBloc else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        var balayage = BalayageDeTar()
        var position: UInt64 = 0

        while position + tailleDeBloc <= taillePleine {
            let bloc = try source.lire(a: position, longueur: EnTeteTar.tailleDeBloc)
            position += tailleDeBloc

            // Un bloc entierement nul marque la fin de l archive. Aucun en tete
            // valide ne peut lui ressembler : sa somme de controle serait nulle
            // alors que huit espaces valent deja 256.
            if bloc.allSatisfy({ $0 == 0 }) {
                break
            }

            guard let enTete = EnTeteTar(bloc: bloc) else {
                throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
            }
            guard enTete.taille <= taillePleine - position else {
                throw ErreurDeDocument.conteneurTronque(chemin: source.nom)
            }

            try balayage.traiter(enTete, donneesA: position, dans: source)
            position += BalayageDeTar.blocsPleins(pour: enTete.taille) * tailleDeBloc
        }

        // Un fichier qui ne livre pas un seul en tete valide n est pas un TAR.
        // Cela couvre le fichier de zeros, qu un lecteur permissif prendrait
        // pour une archive vide et signalerait comme un chapitre sans image,
        // alors que le probleme est le format.
        guard balayage.aLuUnEnTete else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        return IndexTar(entrees: balayage.entrees)
    }
}

///
/// BalayageDeTar
///
/// Etat d un balayage en cours : les entrees deja trouvees, et le nom que le bloc
/// precedent impose a la prochaine.
///
/// Ce type existe pour que la boucle de balayage garde une seule responsabilite,
/// avancer bloc par bloc, et que le traitement d un en tete, qui depend de sa
/// nature, vive a cote de la memoire qu il manipule.
///
private struct BalayageDeTar {
    private(set) var entrees: [EntreeTar] = []

    /// Indique qu au moins un en tete valide a ete decode.
    private(set) var aLuUnEnTete = false

    /// Nom dicte par un bloc porteur, a appliquer a la prochaine entree.
    private var nomImpose: String?

    /// Prend en compte un en tete et les donnees qui le suivent.
    mutating func traiter(
        _ enTete: EnTeteTar,
        donneesA offset: UInt64,
        dans source: any SourceDOctets
    ) throws {
        aLuUnEnTete = true

        switch enTete.nature {
        case .fichier:
            let nom = nomImpose ?? enTete.nom
            nomImpose = nil
            if nom.isEmpty == false {
                entrees.append(EntreeTar(nom: nom, offset: offset, taille: enTete.taille))
            }

        case .nomLongGNU:
            let donnees = try lire(enTete, a: offset, dans: source)
            nomImpose = BalayageDeTar.nomDeDonnees(donnees)

        case .attributsPAX:
            let donnees = try lire(enTete, a: offset, dans: source)
            nomImpose = AttributsPAX.chemin(dans: donnees) ?? nomImpose

        case .ignoree:
            // Un dossier ou un lien n annule pas un nom long deja lu : GNU place
            // toujours le bloc de nom long juste avant l entree qu il nomme,
            // donc le cas ne se presente pas. On le laisse en place.
            break
        }
    }

    /// Nombre de blocs occupes par des donnees de la taille indiquee.
    static func blocsPleins(pour taille: UInt64) -> UInt64 {
        let tailleDeBloc = UInt64(EnTeteTar.tailleDeBloc)

        return (taille + tailleDeBloc - 1) / tailleDeBloc
    }

    /// Lit les donnees d un bloc porteur de nom, jamais celles d une page.
    private func lire(
        _ enTete: EnTeteTar,
        a offset: UInt64,
        dans source: any SourceDOctets
    ) throws -> Data {
        guard enTete.taille <= UInt64(Int.max) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        return try source.lire(a: offset, longueur: Int(enTete.taille))
    }

    /// Lit le nom porte par un bloc de nom long, zero final exclu.
    private static func nomDeDonnees(_ donnees: Data) -> String? {
        let utiles = donnees.prefix { $0 != 0 }
        guard utiles.isEmpty == false else { return nil }

        return TexteDArchive.lire(utiles)
    }
}

///
/// AttributsPAX
///
/// Les en tetes etendus PAX rangent des paires cle valeur dans les donnees d une
/// entree de type x, sous la forme "longueur cle=valeur\n" ou la longueur compte
/// la ligne entiere, chiffres et saut de ligne compris. Le lecteur n a besoin que
/// de la cle "path", qui remplace le nom du bloc suivant quand celui ci depasse
/// cent caracteres ou sort de l ASCII.
///
enum AttributsPAX {
    /// Rend le chemin porte par un en tete etendu, s il en contient un.
    static func chemin(dans donnees: Data) -> String? {
        var reste = donnees[donnees.startIndex...]

        while let espace = reste.firstIndex(of: UInt8(ascii: " ")) {
            let entete = TexteDArchive.lire(reste[reste.startIndex..<espace])
            guard let longueur = entete.flatMap(Int.init), longueur > 0 else { return nil }

            let fin = reste.startIndex + longueur
            guard fin <= reste.endIndex else { return nil }

            let corps = reste[reste.index(after: espace)..<fin]
            if let valeur = valeurDeChemin(corps) {
                return valeur
            }

            reste = reste[fin...]
        }

        return nil
    }

    /// Rend la valeur d un enregistrement quand sa cle est `path`.
    private static func valeurDeChemin(_ corps: Data) -> String? {
        guard let egal = corps.firstIndex(of: UInt8(ascii: "=")) else { return nil }
        guard TexteDArchive.lire(corps[corps.startIndex..<egal]) == "path" else { return nil }

        let valeur = corps[corps.index(after: egal)...].prefix { $0 != UInt8(ascii: "\n") }

        return valeur.isEmpty ? nil : TexteDArchive.lire(valeur)
    }
}
