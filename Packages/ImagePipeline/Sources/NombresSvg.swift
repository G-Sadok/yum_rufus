import Foundation

//
// NombresSvg
//
// Lecture des suites de nombres d un document SVG.
//
// Trois attributs les emploient avec la meme grammaire et les memes pieges :
// `d` d un chemin, `points` d un polygone, et les arguments d un `transform`.
// Un seul lecteur les sert tous.
//
// Les pieges sont connus et aucun n est theorique, les exportateurs les
// produisent tous les jours.
//
// 1. Le separateur est une virgule, un espace, une tabulation ou rien du tout.
//    `10,20`, `10 20` et `10-20` sont trois fois le meme couple.
// 2. Le signe moins ouvre un nombre sans separateur devant lui.
// 3. Le point ouvre un nombre sans separateur devant lui quand le precedent
//    portait deja une partie decimale, `1.5.5` valant `1.5` puis `0.5`.
// 4. L exposant est accepte, `1e3` et `1.2E-4` sont des nombres valides.
//

/// Lecteur de la grammaire numerique commune aux attributs SVG.
struct LecteurDeNombres {
    private let caracteres: [Character]
    private var position = 0

    init(_ texte: String) {
        caracteres = Array(texte)
    }

    /// Vrai quand il ne reste rien a lire.
    var estFini: Bool {
        position >= caracteres.count
    }

    /// Caractere courant, sans avancer.
    var courant: Character? {
        estFini ? nil : caracteres[position]
    }

    /// Avance d un caractere.
    mutating func avancer() {
        position += 1
    }

    /// Passe les espaces et les virgules qui separent deux valeurs.
    mutating func sauterSeparateurs() {
        while let caractere = courant, caractere == "," || caractere.isWhitespace {
            position += 1
        }
    }

    /// Lit le prochain nombre, ou rend nil quand il n y en a plus.
    mutating func prochainNombre() -> Double? {
        sauterSeparateurs()

        let depart = position
        lireSigne()
        let chiffresAvant = lireChiffres()
        let chiffresApres = lirePartieDecimale()

        guard chiffresAvant || chiffresApres else {
            position = depart
            return nil
        }

        lireExposant()

        return Double(String(caracteres[depart..<position]))
    }

    /// Lit tous les nombres restants.
    mutating func tousLesNombres() -> [Double] {
        var valeurs: [Double] = []

        while let valeur = prochainNombre() {
            valeurs.append(valeur)
        }

        return valeurs
    }

    /// Nombres d une chaine entiere, lecture unique.
    static func tousLesNombres(de texte: String) -> [Double] {
        var lecteur = LecteurDeNombres(texte)

        return lecteur.tousLesNombres()
    }

    private mutating func lireSigne() {
        if let caractere = courant, caractere == "+" || caractere == "-" {
            position += 1
        }
    }

    /// Avance sur une suite de chiffres et dit s il y en avait.
    @discardableResult
    private mutating func lireChiffres() -> Bool {
        let depart = position

        while let caractere = courant, caractere.isNumber {
            position += 1
        }

        return position > depart
    }

    /// Avance sur un point suivi de chiffres et dit s il y en avait.
    private mutating func lirePartieDecimale() -> Bool {
        guard courant == "." else { return false }

        position += 1

        return lireChiffres()
    }

    /// Avance sur un exposant complet, et se retracte quand il est tronque.
    private mutating func lireExposant() {
        guard let caractere = courant, caractere == "e" || caractere == "E" else { return }

        let avantExposant = position
        position += 1
        lireSigne()

        if lireChiffres() == false {
            position = avantExposant
        }
    }
}
