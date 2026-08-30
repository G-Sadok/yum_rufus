import Foundation

//
// JetonDuPont
//
// Le jeton qui authentifie l extension de navigateur aupres du pont de la
// section 9, rubrique Pont navigateur.
//
// Le type vit dans Core et non dans Sources pour la meme raison que
// `CodeDeTransfert` : deux couches en ont besoin sans se connaitre. Le serveur
// s en sert pour refuser une requete, l ecran des reglages s en sert pour
// afficher a l utilisateur ce qu il doit coller dans son extension.
//
// Quatre decisions sont prises ici plutot que laissees a l appelant.
//
// La longueur. Deux cent cinquante six bits, ecrits sur soixante quatre
// chiffres hexadecimaux. Le jeton n est pas saisi a la main, il se copie, donc
// rien n oblige a le raccourcir, et un jeton court serait le seul point faible
// d une socket qui accepte des essais aussi vite que la machine les traite.
//
// Le tirage par le generateur du systeme, jamais par une graine tiree de
// l horloge : le pont s active a un instant qu un tiers peut observer.
//
// La comparaison a temps constant, deleguee a `ComparaisonSecrete`.
//
// L absence de `Codable`. Un jeton ne doit atterrir ni dans une sauvegarde, ni
// dans un journal, ni dans un document exporte. La seule sortie prevue est le
// trousseau, par `MagasinDeJetonDuPont`, et la description du type est masquee
// pour qu une interpolation distraite dans une trace ne l ecrive pas en clair.
//

/// Le jeton qui authentifie l extension de navigateur aupres du pont.
public struct JetonDuPont: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Longueur du jeton, en chiffres hexadecimaux.
    public static let nombreDeChiffres = 64

    /// Les soixante quatre chiffres hexadecimaux, en minuscules.
    public let valeur: String

    /// Construit un jeton a partir d un texte, ou rend nul si le texte n en est
    /// pas un.
    ///
    /// Les espaces autour sont retires : un jeton colle depuis un champ de
    /// l application arrive regulierement avec un retour a la ligne.
    public init?(_ texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard propre.count == Self.nombreDeChiffres,
              propre.allSatisfy({ $0.isASCII && $0.isHexDigit })
        else {
            return nil
        }

        valeur = propre
    }

    /// Construit sans verification, pour le seul tirage.
    private init(chiffresSurs: String) {
        valeur = chiffresSurs
    }

    /// Tire un jeton avec le generateur donne.
    ///
    /// Le generateur est un parametre pour que les tests puissent verifier la
    /// forme du tirage sur une suite connue, jamais pour qu un appelant de
    /// l application en fournisse un autre que celui du systeme.
    public static func tire(avec generateur: inout some RandomNumberGenerator) -> JetonDuPont {
        var chiffres = ""

        for _ in 0..<(nombreDeChiffres / 16) {
            chiffres += String(format: "%016lx", UInt64.random(in: UInt64.min...UInt64.max, using: &generateur))
        }

        return JetonDuPont(chiffresSurs: chiffres)
    }

    /// Tire un jeton avec le generateur du systeme.
    public static func tire() -> JetonDuPont {
        var generateur = SystemRandomNumberGenerator()

        return tire(avec: &generateur)
    }

    /// Dit si le texte presente est ce jeton, sans laisser mesurer ou il differe.
    ///
    /// Le texte est compare tel quel, sans passer par l initialiseur : ramener
    /// d abord la saisie a la forme d un jeton repondrait plus vite a un texte
    /// mal forme qu a un jeton faux, ce qui est deja une information.
    public func correspond(a presente: String) -> Bool {
        ComparaisonSecrete.egales(valeur, presente)
    }

    /// Description masquee, pour qu une trace n ecrive jamais le jeton.
    public var description: String {
        "jeton du pont, masque"
    }

    public var debugDescription: String {
        description
    }
}

extension JetonDuPont: Equatable {
    /// Egalite a temps constant, comme la comparaison a un texte presente.
    ///
    /// L egalite synthetisee comparerait les chaines caractere par caractere et
    /// s arreterait au premier ecart. Deux jetons ne se comparent pas sur un
    /// chemin expose aujourd hui, mais laisser une egalite en temps variable sur
    /// un type secret revient a poser un piege pour le prochain appelant.
    public static func == (gauche: JetonDuPont, droite: JetonDuPont) -> Bool {
        ComparaisonSecrete.egales(gauche.valeur, droite.valeur)
    }
}
