import Foundation

//
// EnTeteTar
//
// Un bloc d en tete TAR de 512 octets, decode.
//
// Le format n a ni signature de debut ni index : un TAR est une suite de blocs
// d en tete suivis de leurs donnees, alignees sur 512 octets. La seule chose
// qui distingue un en tete d octets quelconques est sa somme de controle, d ou
// sa verification systematique ici. Sans elle, ouvrir un fichier qui n est pas
// un TAR produirait une liste d entrees inventees au lieu d une erreur.
//
// Les champs numeriques sont en octal, en texte, termines par un zero ou un
// espace. GNU y a ajoute un encodage binaire en base 256 pour les tailles qui
// ne tiennent pas en onze chiffres octaux, soit au dela de huit gigaoctets ;
// il est lu ici parce qu il ne coute que quelques lignes.
//

/// En tete d une entree TAR, decode depuis son bloc de 512 octets.
struct EnTeteTar {
    /// Taille d un bloc TAR, en octets. Tout est aligne dessus.
    static let tailleDeBloc = 512

    /// Nature de l entree, telle que le champ `typeflag` la designe.
    enum Nature {
        /// Fichier ordinaire, dont les donnees sont des pages potentielles.
        case fichier

        /// Nom long GNU, dont les donnees portent le nom de l entree suivante.
        case nomLongGNU

        /// En tete etendu PAX, dont les donnees portent des attributs cles.
        case attributsPAX

        /// Tout le reste : dossier, lien, peripherique, en tete global.
        case ignoree
    }

    let nom: String
    let taille: UInt64
    let nature: Nature

    /// Decode un bloc d en tete.
    ///
    /// - Returns: `nil` si la somme de controle ne correspond pas, donc si le
    ///   bloc n est pas un en tete TAR.
    init?(bloc: Data) {
        guard bloc.count == EnTeteTar.tailleDeBloc else { return nil }
        guard EnTeteTar.sommeEstValide(bloc) else { return nil }
        guard let taille = EnTeteTar.entier(bloc, debut: 124, longueur: 12) else { return nil }

        self.taille = taille
        nature = EnTeteTar.nature(de: bloc[bloc.startIndex + 156])
        nom = EnTeteTar.nomComplet(bloc)
    }

    // MARK: Champs

    /// Rend le nom, prefixe ustar compris.
    ///
    /// Le format d origine limitait un nom a cent caracteres. Ustar a ajoute un
    /// champ `prefix` de cent cinquante cinq caracteres, recolle devant le nom
    /// par une barre oblique. L ignorer tronquerait le chemin des pages rangees
    /// dans des sous dossiers profonds.
    private static func nomComplet(_ bloc: Data) -> String {
        let nom = texte(bloc, debut: 0, longueur: 100)

        guard estUstar(bloc) else { return nom }

        let prefixe = texte(bloc, debut: 345, longueur: 155)
        guard prefixe.isEmpty == false else { return nom }

        return prefixe + "/" + nom
    }

    private static func estUstar(_ bloc: Data) -> Bool {
        texte(bloc, debut: 257, longueur: 6).hasPrefix("ustar")
    }

    private static func nature(de typeflag: UInt8) -> Nature {
        switch typeflag {
        // Zero binaire et le chiffre zero designent tous deux un fichier
        // ordinaire ; le chiffre sept designe un fichier contigu, que les
        // implementations modernes traitent comme un fichier ordinaire.
        case 0, UInt8(ascii: "0"), UInt8(ascii: "7"):
            .fichier
        case UInt8(ascii: "L"):
            .nomLongGNU
        case UInt8(ascii: "x"), UInt8(ascii: "X"):
            .attributsPAX
        default:
            .ignoree
        }
    }

    // MARK: Decodage

    /// Rend le texte d un champ, coupe au premier zero.
    static func texte(_ bloc: Data, debut: Int, longueur: Int) -> String {
        let octets = tranche(bloc, debut: debut, longueur: longueur)
        let utiles = octets.prefix { $0 != 0 }

        return (TexteDArchive.lire(utiles) ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// Rend un champ numerique, en octal ou en base 256.
    ///
    /// - Returns: `nil` si le champ ne contient ni l un ni l autre, ce qui
    ///   signale un bloc qui n est pas un en tete.
    static func entier(_ bloc: Data, debut: Int, longueur: Int) -> UInt64? {
        let octets = Array(tranche(bloc, debut: debut, longueur: longueur))
        guard let premier = octets.first else { return nil }

        if premier & 0x80 != 0 {
            return entierBase256(octets)
        }

        return entierOctal(octets)
    }

    /// Lit un champ octal en texte, tolerant aux espaces et aux zeros.
    ///
    /// Un champ entierement vide vaut zero : les archiveurs laissent souvent le
    /// champ `size` a blanc pour un dossier.
    private static func entierOctal(_ octets: [UInt8]) -> UInt64? {
        var valeur: UInt64 = 0
        var chiffreVu = false

        for octet in octets {
            if octet == 0 || octet == UInt8(ascii: " ") {
                // Les espaces et les zeros terminent le champ. Ce qui suit est
                // du remplissage, jamais un chiffre.
                if chiffreVu {
                    break
                } else {
                    continue
                }
            }

            guard octet >= UInt8(ascii: "0"), octet <= UInt8(ascii: "7") else { return nil }

            let (produit, debordeMultiplication) = valeur.multipliedReportingOverflow(by: 8)
            guard debordeMultiplication == false else { return nil }

            let (somme, debordeAddition) = produit.addingReportingOverflow(
                UInt64(octet - UInt8(ascii: "0"))
            )
            guard debordeAddition == false else { return nil }

            valeur = somme
            chiffreVu = true
        }

        return valeur
    }

    /// Lit l encodage binaire GNU en base 256, gros boutiste.
    ///
    /// Le bit de poids fort du premier octet marque cet encodage ; un premier
    /// octet a 0xFF marque une valeur negative, qu une taille n a pas le droit
    /// de porter.
    private static func entierBase256(_ octets: [UInt8]) -> UInt64? {
        guard octets.first != 0xFF else { return nil }

        var valeur: UInt64 = 0
        for octet in octets.dropFirst() {
            let (decale, deborde) = valeur.multipliedReportingOverflow(by: 256)
            guard deborde == false else { return nil }

            valeur = decale | UInt64(octet)
        }

        return valeur
    }

    /// Verifie la somme de controle de l en tete.
    ///
    /// Elle se calcule sur les 512 octets, le champ de somme lui meme etant
    /// compte comme huit espaces. Certains archiveurs anciens ont somme les
    /// octets comme des entiers signes ; les deux valeurs sont donc acceptees,
    /// comme le fait tout lecteur de TAR serieux.
    private static func sommeEstValide(_ bloc: Data) -> Bool {
        guard let annoncee = entier(bloc, debut: 148, longueur: 8) else { return false }

        var nonSignee: UInt64 = 0
        var signee: Int64 = 0

        for (rang, octet) in bloc.enumerated() {
            let valeur = (148..<156).contains(rang) ? UInt8(ascii: " ") : octet
            nonSignee += UInt64(valeur)
            signee += Int64(Int8(bitPattern: valeur))
        }

        return annoncee == nonSignee || Int64(annoncee) == signee
    }

    private static func tranche(_ bloc: Data, debut: Int, longueur: Int) -> Data {
        let depart = bloc.startIndex + debut

        return bloc[depart..<(depart + longueur)]
    }
}
