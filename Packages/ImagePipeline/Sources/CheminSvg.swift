import CoreGraphics
import Foundation

//
// CheminSvg
//
// Traduction de l attribut `d` d un element `path` en `CGPath`.
//
// Les onze commandes de la specification sont couvertes, majuscule en
// coordonnees absolues et minuscule en coordonnees relatives, avec la
// repetition implicite : une commande suivie de plusieurs jeux d arguments se
// repete, et `M` suivi d un second couple continue en `L`, comme la
// specification l impose.
//
// Le chemin est construit dans le repere du document, ou l ordonnee croit vers
// le bas. Le rasterisateur retourne le contexte une seule fois, a la fin. Toute
// autre approche demanderait de retourner chaque courbe, et les arcs y
// perdraient leur sens de rotation.
//

/// Traducteur de la grammaire des chemins SVG.
enum CheminSvg {
    /// Chemin decrit par un attribut `d`.
    ///
    /// Un fragment illisible arrete la lecture et rend ce qui precede, plutot
    /// que de perdre tout le dessin. Un exportateur qui produit une commande
    /// inconnue coute alors la fin d une forme, pas la page.
    static func chemin(depuis donnees: String) -> CGPath {
        var constructeur = ConstructeurDeChemin()
        var lecteur = LecteurDeNombres(donnees)
        var commande: Character?

        while true {
            lecteur.sauterSeparateurs()

            if let caractere = lecteur.courant, caractere.isLetter {
                commande = caractere
                lecteur.avancer()
            }

            guard let active = commande,
                  constructeur.executer(active, lecteur: &lecteur)
            else {
                break
            }

            commande = Self.suite(de: active)
        }

        return constructeur.chemin
    }

    /// Commande implicite quand des arguments suivent sans nouvelle lettre.
    ///
    /// Deux cas particuliers. Le deplacement change de nature, la specification
    /// veut que les couples suivant un `M` tracent des lignes. La fermeture ne
    /// se repete pas : elle ne consomme aucun argument, et la repeter ferait
    /// tourner la lecture sans fin sur un chemin qui se termine par `Z`.
    private static func suite(de commande: Character) -> Character? {
        switch commande {
        case "M": "L"
        case "m": "l"
        case "Z", "z": nil
        default: commande
        }
    }
}

/// Etat courant d un chemin en construction.
private struct ConstructeurDeChemin {
    let chemin = CGMutablePath()

    private var courant = CGPoint.zero
    private var departDuTrace = CGPoint.zero
    private var controleCubique: CGPoint?
    private var controleQuadratique: CGPoint?

    /// Execute une commande, et dit si ses arguments etaient au complet.
    mutating func executer(_ commande: Character, lecteur: inout LecteurDeNombres) -> Bool {
        let relatif = commande.isLowercase

        switch Character(commande.lowercased()) {
        case "m": return deplacer(&lecteur, relatif: relatif)
        case "l": return ligne(&lecteur, relatif: relatif)
        case "h": return ligneHorizontale(&lecteur, relatif: relatif)
        case "v": return ligneVerticale(&lecteur, relatif: relatif)
        case "z": return fermer()
        default: return executerCourbe(commande, lecteur: &lecteur, relatif: relatif)
        }
    }

    private mutating func executerCourbe(
        _ commande: Character,
        lecteur: inout LecteurDeNombres,
        relatif: Bool
    ) -> Bool {
        switch Character(commande.lowercased()) {
        case "c": cubique(&lecteur, relatif: relatif)
        case "s": cubiqueEnchainee(&lecteur, relatif: relatif)
        case "q": quadratique(&lecteur, relatif: relatif)
        case "t": quadratiqueEnchainee(&lecteur, relatif: relatif)
        case "a": arc(&lecteur, relatif: relatif)
        default: false
        }
    }

    // MARK: Commandes

    private mutating func deplacer(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let destination = point(&lecteur, relatif: relatif) else { return false }

        chemin.move(to: destination)
        courant = destination
        departDuTrace = destination
        oublierLesControles()

        return true
    }

    private mutating func ligne(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let destination = point(&lecteur, relatif: relatif) else { return false }

        return tracerVers(destination)
    }

    private mutating func ligneHorizontale(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let valeur = lecteur.prochainNombre() else { return false }

        return tracerVers(CGPoint(x: relatif ? courant.x + valeur : valeur, y: courant.y))
    }

    private mutating func ligneVerticale(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let valeur = lecteur.prochainNombre() else { return false }

        return tracerVers(CGPoint(x: courant.x, y: relatif ? courant.y + valeur : valeur))
    }

    private mutating func fermer() -> Bool {
        chemin.closeSubpath()
        courant = departDuTrace
        oublierLesControles()

        return true
    }

    private mutating func cubique(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let premier = point(&lecteur, relatif: relatif),
              let second = point(&lecteur, relatif: relatif),
              let destination = point(&lecteur, relatif: relatif)
        else {
            return false
        }

        return tracerCubique(premier, second, destination)
    }

    private mutating func cubiqueEnchainee(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let second = point(&lecteur, relatif: relatif),
              let destination = point(&lecteur, relatif: relatif)
        else {
            return false
        }

        return tracerCubique(reflexion(de: controleCubique), second, destination)
    }

    private mutating func quadratique(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let controle = point(&lecteur, relatif: relatif),
              let destination = point(&lecteur, relatif: relatif)
        else {
            return false
        }

        return tracerQuadratique(controle, destination)
    }

    private mutating func quadratiqueEnchainee(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let destination = point(&lecteur, relatif: relatif) else { return false }

        return tracerQuadratique(reflexion(de: controleQuadratique), destination)
    }

    private mutating func arc(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> Bool {
        guard let rayonX = lecteur.prochainNombre(),
              let rayonY = lecteur.prochainNombre(),
              let rotation = lecteur.prochainNombre(),
              let grandArc = Self.drapeau(&lecteur),
              let sensPositif = Self.drapeau(&lecteur),
              let destination = point(&lecteur, relatif: relatif)
        else {
            return false
        }

        ArcSvg(
            depart: courant,
            arrivee: destination,
            rayonX: rayonX,
            rayonY: rayonY,
            rotation: rotation,
            grandArc: grandArc,
            sensPositif: sensPositif
        ).ajouter(a: chemin)

        courant = destination
        oublierLesControles()

        return true
    }

    // MARK: Traces

    private mutating func tracerVers(_ destination: CGPoint) -> Bool {
        chemin.addLine(to: destination)
        courant = destination
        oublierLesControles()

        return true
    }

    private mutating func tracerCubique(_ premier: CGPoint, _ second: CGPoint, _ destination: CGPoint) -> Bool {
        chemin.addCurve(to: destination, control1: premier, control2: second)
        courant = destination
        controleCubique = second
        controleQuadratique = nil

        return true
    }

    private mutating func tracerQuadratique(_ controle: CGPoint, _ destination: CGPoint) -> Bool {
        chemin.addQuadCurve(to: destination, control: controle)
        courant = destination
        controleQuadratique = controle
        controleCubique = nil

        return true
    }

    // MARK: Outils

    /// Couple de coordonnees, ramene au repere absolu.
    private mutating func point(_ lecteur: inout LecteurDeNombres, relatif: Bool) -> CGPoint? {
        guard let abscisse = lecteur.prochainNombre(), let ordonnee = lecteur.prochainNombre() else {
            return nil
        }

        return relatif
            ? CGPoint(x: courant.x + abscisse, y: courant.y + ordonnee)
            : CGPoint(x: abscisse, y: ordonnee)
    }

    /// Symetrique du dernier point de controle par rapport au point courant.
    ///
    /// Sans point de controle precedent, la specification veut que le reflet
    /// soit le point courant lui meme, ce qui degrade proprement `S` en `C`.
    private func reflexion(de controle: CGPoint?) -> CGPoint {
        guard let controle else { return courant }

        return CGPoint(x: 2 * courant.x - controle.x, y: 2 * courant.y - controle.y)
    }

    private mutating func oublierLesControles() {
        controleCubique = nil
        controleQuadratique = nil
    }

    /// Drapeau d arc, un seul caractere.
    ///
    /// Il se lit a part, parce que la specification autorise `a1 1 0 011 1` :
    /// deux drapeaux et une abscisse colles. Un lecteur de nombres y verrait
    /// `11` la ou il y a `0`, `1` et `1`.
    private static func drapeau(_ lecteur: inout LecteurDeNombres) -> Bool? {
        lecteur.sauterSeparateurs()

        guard let caractere = lecteur.courant, caractere == "0" || caractere == "1" else {
            return nil
        }

        lecteur.avancer()

        return caractere == "1"
    }
}
