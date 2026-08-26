import Foundation

//
// CodeDeTransfert
//
// Le code a six chiffres qui protege la reception Wi-Fi de la section 4.4.
//
// Le type vit dans Core et non dans Sources pour la raison qui vaut deja pour
// la liste blanche de domaines : deux couches en ont besoin sans se connaitre.
// Le serveur s en sert pour refuser une requete, la feuille s en sert pour
// afficher le code a l ecran. Un code qui vivrait a cote du serveur obligerait
// la vue a dependre du transport.
//
// Trois decisions sont prises ici plutot que laissees a l appelant.
//
// La premiere est la longueur fixe. Un code est toujours ecrit sur six
// chiffres, zeros de tete compris : `042173` est un code valide, et le
// tronquer a `42173` rendrait le tirage inegal, puisque les codes commencant
// par zero seraient alors plus courts a saisir donc distinguables.
//
// La deuxieme est le tirage par le generateur du systeme. `arc4random` est
// derriere `SystemRandomNumberGenerator`, alors qu une graine tiree de
// l horloge donnerait des codes previsibles a qui connait la seconde de
// l ouverture de la feuille.
//
// La troisieme est la comparaison a temps constant. Une comparaison de chaines
// s arrete au premier caractere different, ce qui laisse mesurer la position du
// premier ecart et ramener un million d essais a soixante. La comparaison
// ecrite ici lit toujours les six chiffres.
//

/// Code a six chiffres qui protege une reception Wi-Fi.
public struct CodeDeTransfert: Sendable, Equatable, Hashable {
    /// Longueur imposee par la section 4.4.
    public static let nombreDeChiffres = 6

    /// Nombre de codes possibles, de `000000` a `999999`.
    public static let nombreDeCodes = 1_000_000

    /// Les six chiffres, zeros de tete compris.
    public let chiffres: String

    /// Construit un code a partir d un texte, ou rend nul si le texte n est pas
    /// exactement six chiffres.
    ///
    /// Les espaces autour sont retires : un code lu a l ecran et recopie dans un
    /// navigateur arrive regulierement avec un espace colle par le presse
    /// papiers, et refuser pour cette raison serait incomprehensible. Ce qui est
    /// a l interieur ne l est pas : `123 456` n est pas un code.
    public init?(_ texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)

        guard propre.count == Self.nombreDeChiffres,
              propre.allSatisfy({ $0.isASCII && $0.isNumber })
        else {
            return nil
        }

        chiffres = propre
    }

    /// Construit le code qui porte cette valeur numerique.
    ///
    /// - Returns: nul au dela de `999999`, qui ne s ecrit pas sur six chiffres.
    public init?(valeur: Int) {
        guard valeur >= 0, valeur < Self.nombreDeCodes else {
            return nil
        }

        chiffres = String(format: "%06d", valeur)
    }

    /// Tire un code au hasard avec le generateur donne.
    ///
    /// Le generateur est un parametre pour que les tests puissent verifier la
    /// forme du tirage sur une suite connue, jamais pour qu un appelant de
    /// l application en fournisse un autre que celui du systeme.
    public static func tire(avec generateur: inout some RandomNumberGenerator) -> CodeDeTransfert {
        let valeur = Int.random(in: 0..<nombreDeCodes, using: &generateur)

        // Le domaine du tirage est exactement celui de l initialiseur, qui ne
        // peut donc pas rendre nul. Le repli existe pour ne pas ecrire une
        // force unwrap, que le controle 9 interdit a juste titre.
        return CodeDeTransfert(valeur: valeur) ?? CodeDeTransfert(valeur: 0) ?? CodeDeTransfert(chiffresSurs: "000000")
    }

    /// Tire un code au hasard avec le generateur du systeme.
    public static func tire() -> CodeDeTransfert {
        var generateur = SystemRandomNumberGenerator()

        return tire(avec: &generateur)
    }

    /// Construit sans verification, pour le seul repli du tirage.
    private init(chiffresSurs: String) {
        chiffres = chiffresSurs
    }

    /// Dit si le texte presente est ce code, sans laisser mesurer ou il differe.
    ///
    /// Le texte est d abord ramene a la forme d un code. S il n en est pas un,
    /// la comparaison est menee quand meme, contre une chaine de remplissage de
    /// meme longueur : sortir tout de suite dirait a l appelant que sa saisie
    /// n avait pas la bonne forme, ce qui est deja une information.
    public func correspond(a presente: String) -> Bool {
        let candidat = CodeDeTransfert(presente)
        let attendu = Array(chiffres.utf8)
        let recu = Array((candidat?.chiffres ?? String(repeating: "\u{0}", count: Self.nombreDeChiffres)).utf8)

        var ecart: UInt8 = candidat == nil ? 1 : 0

        for index in 0..<Self.nombreDeChiffres {
            let gauche = index < attendu.count ? attendu[index] : 0
            let droite = index < recu.count ? recu[index] : 0

            ecart |= gauche ^ droite
        }

        return ecart == 0
    }

    /// Le code decoupe en deux groupes de trois, pour l affichage.
    ///
    /// Un code lu a voix haute ou recopie a la main se retient par groupes. Le
    /// decoupage est une propriete du code et non de la vue : la page de depot
    /// servie par le serveur et la feuille de l application affichent la meme
    /// chose, et elles ne partagent aucune couche d interface.
    public var groupes: String {
        let milieu = chiffres.index(chiffres.startIndex, offsetBy: Self.nombreDeChiffres / 2)

        return chiffres[chiffres.startIndex..<milieu] + " " + chiffres[milieu...]
    }
}
