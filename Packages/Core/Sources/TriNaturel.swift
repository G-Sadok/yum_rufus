import Foundation

//
// TriNaturel
//
// Comparateur de noms de pages, exige par la section 5.3 du cahier de
// developpement. Le tri lexicographique place page10.jpg avant page2.jpg,
// et l ordre des entrees d une archive ZIP n est jamais garanti : la
// bibliotheque trie toujours elle meme, avec ce comparateur.
//

/// Comparateur de tri naturel des noms de pages et de chapitres.
///
/// Le principe : la comparaison avance en parallele dans les deux noms. Quand
/// les deux positions ouvrent une suite de chiffres, la suite entiere est lue
/// et comparee comme un nombre. Partout ailleurs la comparaison se fait
/// caractere par caractere, sans tenir compte de la casse.
///
/// Avancer en parallele plutot que decouper chaque nom de son cote evite le
/// desalignement des segments. Sans cela, `page.jpg` et `page1.jpg`
/// confronteraient le segment `page.jpg` au segment `page`, et le nom sans
/// numero se retrouverait apres le nom numerote.
///
/// Trois regles de departage, dans cet ordre :
///
/// 1. A valeur numerique egale, la suite de chiffres la plus courte passe
///    devant, donc `page1.jpg` avant `page01.jpg`.
/// 2. A comparaison naturelle egale, le nom le plus court passe devant.
/// 3. En dernier recours la comparaison brute tranche, ce qui rend l ordre
///    total : deux noms distincts ne sont jamais equivalents, et le tri est
///    donc reproductible d une execution a l autre.
///
/// La comparaison de texte se fait sur les valeurs Unicode et non selon la
/// langue de l utilisateur. Un tri qui changerait avec la langue rendrait la
/// position d une page dependante des reglages systeme, ce qui est exclu pour
/// une donnee ecrite en base.
public enum TriNaturel {
    /// Compare deux noms selon l ordre naturel.
    public static func comparer(_ gauche: String, _ droite: String) -> ComparisonResult {
        let caracteresGauche = Array(gauche)
        let caracteresDroite = Array(droite)
        var positionGauche = 0
        var positionDroite = 0

        while positionGauche < caracteresGauche.count, positionDroite < caracteresDroite.count {
            let caractereGauche = caracteresGauche[positionGauche]
            let caractereDroite = caracteresDroite[positionDroite]

            if estChiffre(caractereGauche), estChiffre(caractereDroite) {
                let nombreGauche = lireNombre(caracteresGauche, depuis: positionGauche)
                let nombreDroite = lireNombre(caracteresDroite, depuis: positionDroite)

                let ordre = comparer(nombreGauche, nombreDroite)
                guard ordre == .orderedSame else { return ordre }

                positionGauche = nombreGauche.positionSuivante
                positionDroite = nombreDroite.positionSuivante
                continue
            }

            let ordre = comparerSansCasse(caractereGauche, caractereDroite)
            guard ordre == .orderedSame else { return ordre }

            positionGauche += 1
            positionDroite += 1
        }

        let resteGauche = caracteresGauche.count - positionGauche
        let resteDroite = caracteresDroite.count - positionDroite

        if resteGauche != resteDroite {
            return resteGauche < resteDroite ? .orderedAscending : .orderedDescending
        }

        if gauche == droite {
            return .orderedSame
        }

        return gauche < droite ? .orderedAscending : .orderedDescending
    }

    /// Indique si `gauche` vient avant `droite` dans l ordre naturel.
    public static func precede(_ gauche: String, _ droite: String) -> Bool {
        comparer(gauche, droite) == .orderedAscending
    }

    /// Trie des noms selon l ordre naturel.
    public static func trier(_ noms: [String]) -> [String] {
        noms.sorted(by: precede)
    }

    /// Trie des elements quelconques selon l ordre naturel d une cle textuelle.
    public static func trier<Element>(
        _ elements: [Element],
        selon cle: (Element) -> String
    ) -> [Element] {
        elements.sorted { precede(cle($0), cle($1)) }
    }
}

// MARK: - Lecture et comparaison des nombres

extension TriNaturel {
    /// Une suite de chiffres lue dans un nom, eventuellement decimale.
    ///
    /// Les parties sont conservees sous forme de chiffres et jamais converties
    /// en entier ni en flottant. Un nom de page peut porter un numero plus long
    /// que ce qu un entier 64 bits accepte, et la conversion en flottant
    /// perdrait la difference entre deux decimales voisines.
    private struct NombreLu {
        /// Partie entiere, debarrassee de ses zeros initiaux.
        let partieEntiere: ArraySlice<Character>

        /// Partie decimale, debarrassee de ses zeros finaux. Vide si absente.
        let partieDecimale: ArraySlice<Character>

        /// Longueur du texte lu, zeros compris, qui sert de dernier departage.
        let longueurLue: Int

        /// Position du premier caractere qui suit le nombre.
        let positionSuivante: Int
    }

    private static func estChiffre(_ caractere: Character) -> Bool {
        caractere.isASCII && caractere.isNumber
    }

    /// Indique si le point place a `position` ouvre une partie decimale.
    ///
    /// Le point n est une virgule decimale que s il est suivi d au moins un
    /// chiffre. Sans cette condition, le point de `page1.jpg` ouvrirait une
    /// partie decimale et le comparateur confronterait `jpg` a un nombre.
    private static func ouvreUnePartieDecimale(_ caracteres: [Character], a position: Int) -> Bool {
        guard position < caracteres.count, caracteres[position] == "." else { return false }
        guard position + 1 < caracteres.count else { return false }

        return estChiffre(caracteres[position + 1])
    }

    /// Lit la suite de chiffres qui commence a `depart`, partie decimale comprise.
    private static func lireNombre(_ caracteres: [Character], depuis depart: Int) -> NombreLu {
        var position = depart
        while position < caracteres.count, estChiffre(caracteres[position]) {
            position += 1
        }

        let finPartieEntiere = position
        var finPartieDecimale = position

        if ouvreUnePartieDecimale(caracteres, a: position) {
            position += 1
            while position < caracteres.count, estChiffre(caracteres[position]) {
                position += 1
            }
            finPartieDecimale = position
        }

        let partieEntiere = caracteres[depart..<finPartieEntiere]
        let partieDecimale = finPartieDecimale > finPartieEntiere
            ? caracteres[(finPartieEntiere + 1)..<finPartieDecimale]
            : caracteres[finPartieEntiere..<finPartieEntiere]

        return NombreLu(
            partieEntiere: sansZerosInitiaux(partieEntiere),
            partieDecimale: sansZerosFinaux(partieDecimale),
            longueurLue: position - depart,
            positionSuivante: position
        )
    }

    private static func sansZerosInitiaux(_ chiffres: ArraySlice<Character>) -> ArraySlice<Character> {
        var debut = chiffres.startIndex
        while debut < chiffres.endIndex, chiffres[debut] == "0" {
            debut += 1
        }
        return chiffres[debut..<chiffres.endIndex]
    }

    private static func sansZerosFinaux(_ chiffres: ArraySlice<Character>) -> ArraySlice<Character> {
        var fin = chiffres.endIndex
        while fin > chiffres.startIndex, chiffres[fin - 1] == "0" {
            fin -= 1
        }
        return chiffres[chiffres.startIndex..<fin]
    }

    private static func comparer(_ gauche: NombreLu, _ droite: NombreLu) -> ComparisonResult {
        let ordreEntier = comparerPartieEntiere(gauche.partieEntiere, droite.partieEntiere)
        guard ordreEntier == .orderedSame else { return ordreEntier }

        let ordreDecimal = comparerPartieDecimale(gauche.partieDecimale, droite.partieDecimale)
        guard ordreDecimal == .orderedSame else { return ordreDecimal }

        if gauche.longueurLue == droite.longueurLue {
            return .orderedSame
        }

        return gauche.longueurLue < droite.longueurLue ? .orderedAscending : .orderedDescending
    }

    /// Compare deux parties entieres sans zeros initiaux : la plus longue est
    /// la plus grande, et a longueur egale les chiffres tranchent de gauche a
    /// droite.
    private static func comparerPartieEntiere(
        _ gauche: ArraySlice<Character>,
        _ droite: ArraySlice<Character>
    ) -> ComparisonResult {
        if gauche.count != droite.count {
            return gauche.count < droite.count ? .orderedAscending : .orderedDescending
        }

        for (chiffreGauche, chiffreDroite) in zip(gauche, droite) where chiffreGauche != chiffreDroite {
            return chiffreGauche < chiffreDroite ? .orderedAscending : .orderedDescending
        }

        return .orderedSame
    }

    /// Compare deux parties decimales rang par rang, le rang absent valant zero.
    ///
    /// C est ce qui distingue `chapitre1.10` de `chapitre1.5` : le premier rang
    /// oppose 1 a 5, donc 1.10 vient avant 1.5.
    private static func comparerPartieDecimale(
        _ gauche: ArraySlice<Character>,
        _ droite: ArraySlice<Character>
    ) -> ComparisonResult {
        let chiffresGauche = Array(gauche)
        let chiffresDroite = Array(droite)
        let rangs = max(chiffresGauche.count, chiffresDroite.count)

        for rang in 0..<rangs {
            let chiffreGauche = rang < chiffresGauche.count ? chiffresGauche[rang] : "0"
            let chiffreDroite = rang < chiffresDroite.count ? chiffresDroite[rang] : "0"

            if chiffreGauche != chiffreDroite {
                return chiffreGauche < chiffreDroite ? .orderedAscending : .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func comparerSansCasse(
        _ gauche: Character,
        _ droite: Character
    ) -> ComparisonResult {
        if gauche == droite {
            return .orderedSame
        }

        let basGauche = gauche.lowercased()
        let basDroite = droite.lowercased()

        if basGauche == basDroite {
            return .orderedSame
        }

        return basGauche < basDroite ? .orderedAscending : .orderedDescending
    }
}
