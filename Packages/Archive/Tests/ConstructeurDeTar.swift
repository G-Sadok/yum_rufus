import Foundation

//
// ConstructeurDeTar
//
// Fabrique des archives TAR en memoire pour les tests.
//
// Meme raison que pour le constructeur de ZIP : un binaire depose dans le depot
// ne se relit pas dans une revue, et une archive cassee d une facon precise se
// decrit ici en une ligne. Le constructeur note en plus la position des octets
// de chaque entree et celle de chaque bloc d en tete. C est ce qui permet de
// prouver, avec la source espionne, qu une seconde ouverture ne relit aucun en
// tete, donc qu elle ne rescanne pas.
//

/// Facon dont un nom trop long est annonce dans l archive.
enum AnnonceDeNomLong {
    /// Le nom tient dans le bloc principal.
    case aucune

    /// Un bloc de type L precede l entree et porte son nom.
    case gnu

    /// Un en tete etendu de type x precede l entree et porte la cle path.
    case pax

    /// Le nom est coupe entre le champ prefix et le champ name, comme ustar.
    case prefixeUstar
}

/// Description d une entree a ecrire dans l archive de test.
struct EntreeTarDeTest {
    var nom: String
    var contenu: Data

    /// Valeur du champ typeflag. Le chiffre zero designe un fichier ordinaire.
    var typeflag: UInt8 = .init(ascii: "0")

    /// Facon d annoncer le nom.
    var annonceDuNomLong: AnnonceDeNomLong = .aucune

    /// Somme de controle ecrite dans l en tete, quand elle doit etre fausse.
    var sommeForcee: UInt64?

    /// Taille annoncee dans l en tete, quand elle doit mentir.
    var tailleForcee: UInt64?

    init(_ nom: String, contenu: Data = Data()) {
        self.nom = nom
        self.contenu = contenu
    }
}

/// Archive TAR fabriquee, avec de quoi verifier ce qui a ete lu.
struct ArchiveTarDeTest {
    let octets: Data

    /// Plage occupee par les octets de chaque entree.
    let plages: [String: Range<Int>]

    /// Plage occupee par le bloc d en tete de chaque entree.
    let enTetes: [String: Range<Int>]
}

enum ConstructeurDeTar {
    static let tailleDeBloc = 512

    /// Ecrit une archive TAR complete, blocs de fin compris.
    static func archive(_ entrees: [EntreeTarDeTest], blocsDeFin: Int = 2) -> ArchiveTarDeTest {
        var fichier = Data()
        var plages: [String: Range<Int>] = [:]
        var enTetes: [String: Range<Int>] = [:]

        for entree in entrees {
            ecrireAnnonceDeNomLong(entree, dans: &fichier)

            let debutEnTete = fichier.count
            fichier.append(enTete(entree))
            enTetes[entree.nom] = debutEnTete..<fichier.count

            plages[entree.nom] = fichier.count..<(fichier.count + entree.contenu.count)
            fichier.append(entree.contenu)
            fichier.append(remplissage(pour: entree.contenu.count))
        }

        fichier.append(Data(count: tailleDeBloc * blocsDeFin))

        return ArchiveTarDeTest(octets: fichier, plages: plages, enTetes: enTetes)
    }

    /// Archive de vingt quatre pages, assez etalee pour que le balayage se voie.
    ///
    /// Les en tetes sont disperses tous les huit kilo octets environ. Une
    /// ouverture qui rescanne les touche tous, une ouverture servie par le cache
    /// n en touche aucun.
    static func archiveDeVingtQuatrePages() -> ArchiveTarDeTest {
        archive((1...24).map { numero in
            EntreeTarDeTest(PagesDeTest.nom(numero), contenu: PagesDeTest.contenu(numero))
        })
    }

    // MARK: Blocs

    private static func ecrireAnnonceDeNomLong(_ entree: EntreeTarDeTest, dans fichier: inout Data) {
        switch entree.annonceDuNomLong {
        case .aucune, .prefixeUstar:
            return

        case .gnu:
            var porteur = EntreeTarDeTest("././@LongLink", contenu: Data((entree.nom + "\0").utf8))
            porteur.typeflag = UInt8(ascii: "L")
            fichier.append(enTete(porteur))
            fichier.append(porteur.contenu)
            fichier.append(remplissage(pour: porteur.contenu.count))

        case .pax:
            let dernier = entree.nom.split(separator: "/").last.map(String.init) ?? entree.nom
            var porteur = EntreeTarDeTest(
                "PaxHeaders/" + dernier,
                contenu: enregistrementPAX(cle: "path", valeur: entree.nom)
            )
            porteur.typeflag = UInt8(ascii: "x")
            fichier.append(enTete(porteur))
            fichier.append(porteur.contenu)
            fichier.append(remplissage(pour: porteur.contenu.count))
        }
    }

    /// Ecrit un bloc d en tete de 512 octets.
    private static func enTete(_ entree: EntreeTarDeTest) -> Data {
        var bloc = Data(count: tailleDeBloc)
        let decoupe = nomDeBloc(entree)

        ecrire(decoupe.nom, dans: &bloc, a: 0, longueur: 100)
        ecrire("0000644", dans: &bloc, a: 100, longueur: 8)
        ecrire("0000000", dans: &bloc, a: 108, longueur: 8)
        ecrire("0000000", dans: &bloc, a: 116, longueur: 8)
        ecrireOctal(entree.tailleForcee ?? UInt64(entree.contenu.count), dans: &bloc, a: 124)
        ecrireOctal(0, dans: &bloc, a: 136)
        bloc[bloc.startIndex + 156] = entree.typeflag
        ecrire("ustar", dans: &bloc, a: 257, longueur: 6)
        ecrire("00", dans: &bloc, a: 263, longueur: 2)
        ecrire(decoupe.prefixe, dans: &bloc, a: 345, longueur: 155)

        ecrireSomme(entree.sommeForcee ?? sommeDeControle(bloc), dans: &bloc)

        return bloc
    }

    /// Rend le nom tel qu il doit apparaitre dans le bloc, prefixe compris.
    private static func nomDeBloc(_ entree: EntreeTarDeTest) -> (nom: String, prefixe: String) {
        switch entree.annonceDuNomLong {
        case .aucune:
            (entree.nom, "")

        case .gnu, .pax:
            // Un archiveur ecrit quand meme un nom tronque dans le bloc
            // principal. Le lecteur doit preferer celui du bloc porteur ; on
            // ecrit donc ici un nom volontairement different.
            ("nom-tronque.jpg", "")

        case .prefixeUstar:
            decouperPourUstar(entree.nom)
        }
    }

    /// Coupe un chemin sur la derniere barre oblique qui tient dans le champ nom.
    private static func decouperPourUstar(_ chemin: String) -> (nom: String, prefixe: String) {
        let composants = chemin.split(separator: "/").map(String.init)
        guard let dernier = composants.last, composants.count > 1 else { return (chemin, "") }

        return (dernier, composants.dropLast().joined(separator: "/"))
    }

    /// Ecrit un enregistrement PAX au format longueur, cle, valeur.
    ///
    /// La longueur annoncee compte la ligne entiere, ses propres chiffres et le
    /// saut de ligne compris, ce qui impose de la chercher par approximations
    /// successives.
    static func enregistrementPAX(cle: String, valeur: String) -> Data {
        let corps = " \(cle)=\(valeur)\n"
        var longueur = corps.utf8.count + 1

        // La suite converge en deux ou trois tours ; la borne n est la que pour
        // qu une erreur de calcul fasse echouer un test au lieu de le suspendre.
        for _ in 0..<8 where String(longueur).utf8.count + corps.utf8.count != longueur {
            longueur = String(longueur).utf8.count + corps.utf8.count
        }

        return Data("\(longueur)\(corps)".utf8)
    }

    // MARK: Champs

    private static func ecrire(_ texte: String, dans bloc: inout Data, a debut: Int, longueur: Int) {
        let octets = Array(texte.utf8.prefix(longueur))
        for (rang, octet) in octets.enumerated() {
            bloc[bloc.startIndex + debut + rang] = octet
        }
    }

    /// Ecrit un champ numerique de douze octets, onze chiffres octaux et un zero.
    private static func ecrireOctal(_ valeur: UInt64, dans bloc: inout Data, a debut: Int) {
        let chiffres = String(valeur, radix: 8)
        let rempli = String(repeating: "0", count: max(0, 11 - chiffres.count)) + chiffres

        ecrire(rempli, dans: &bloc, a: debut, longueur: 11)
        bloc[bloc.startIndex + debut + 11] = 0
    }

    /// Ecrit la somme de controle au format attendu : six chiffres, zero, espace.
    private static func ecrireSomme(_ valeur: UInt64, dans bloc: inout Data) {
        let chiffres = String(valeur, radix: 8)
        let rempli = String(repeating: "0", count: max(0, 6 - chiffres.count)) + chiffres

        ecrire(rempli, dans: &bloc, a: 148, longueur: 6)
        bloc[bloc.startIndex + 154] = 0
        bloc[bloc.startIndex + 155] = UInt8(ascii: " ")
    }

    /// Somme attendue par le format, recalculee ici pour ne pas verifier le code
    /// de production avec lui meme.
    private static func sommeDeControle(_ bloc: Data) -> UInt64 {
        var total: UInt64 = 0
        for (rang, octet) in bloc.enumerated() {
            total += (148..<156).contains(rang) ? UInt64(UInt8(ascii: " ")) : UInt64(octet)
        }

        return total
    }

    private static func remplissage(pour taille: Int) -> Data {
        let reste = taille % tailleDeBloc

        return reste == 0 ? Data() : Data(count: tailleDeBloc - reste)
    }
}
