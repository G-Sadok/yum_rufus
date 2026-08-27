import Foundation

//
// SuiteDeChapitres
//
// Ordre narratif des chapitres d une serie, et marquage du chapitre quitte,
// section 7.4 du cahier de developpement.
//
// Trois choix structurent ce type.
//
// L ordre suivi est `ordreDansSerie` et jamais le numero. Le numero manque chez
// beaucoup de sources, se repete chez d autres, et un chapitre bonus numerote
// 10.5 n a pas de place stable dans une suite triee sur lui seul. Le rang, lui,
// est calcule une fois a l import et reste vrai.
//
// L ordre suivi n est pas non plus celui de la liste affichee. La fiche de
// serie se trie par date ou en ordre decroissant si l utilisateur le demande,
// et un enchainement qui suivrait cet ordre ferait remonter le lecteur vers le
// chapitre precedent. Le tri de la liste est une preference d affichage, la
// suite de lecture est une propriete de l oeuvre.
//
// Un chapitre absent de la suite n en est pas le dernier. C est ce que dit
// `estLeDernier` en rendant faux : un chapitre supprime pendant la session, ou
// ouvert depuis une recherche sans que la serie soit chargee, ne doit pas
// declencher l ecran de fin de serie.
//

/// Chapitre tel que l enchainement a besoin de le connaitre.
///
/// Volontairement plus pauvre que `Chapitre` : l enchainement n a besoin ni du
/// groupe de traduction, ni de la langue, ni de l etat de telechargement.
public struct MaillonDeChapitre: Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID

    /// Numero du chapitre, affiche par l intercalaire.
    public let numero: Double

    /// Rang dans la serie, seul ordre fiable.
    public let ordreDansSerie: Int

    /// Nombre de pages, nul tant que la source ne l annonce pas.
    public let nombreDePages: Int

    public init(id: UUID, numero: Double, ordreDansSerie: Int, nombreDePages: Int = 0) {
        self.id = id
        self.numero = numero
        self.ordreDansSerie = ordreDansSerie
        self.nombreDePages = nombreDePages
    }
}

/// Chapitres d une serie dans l ordre ou ils se lisent.
public struct SuiteDeChapitres: Sendable, Equatable {
    /// Maillons dans l ordre narratif, du premier au dernier.
    public let maillons: [MaillonDeChapitre]

    /// Rang de chaque chapitre, pour que la recherche ne parcoure pas la suite.
    ///
    /// Une serie de deux mille chapitres est courante, et l enchainement
    /// interroge la suite a chaque geste de defilement.
    private let rangs: [UUID: Int]

    /// Trie les maillons par rang, puis par numero a rang egal.
    ///
    /// Deux maillons de meme identifiant ne peuvent pas coexister : le second
    /// est ecarte, l ordre du premier fait foi.
    public init(_ maillons: [MaillonDeChapitre]) {
        var vus: Set<UUID> = []
        let uniques = maillons.filter { vus.insert($0.id).inserted }

        let ordonnes = uniques.sorted { gauche, droite in
            gauche.ordreDansSerie == droite.ordreDansSerie
                ? gauche.numero < droite.numero
                : gauche.ordreDansSerie < droite.ordreDansSerie
        }

        var rangs: [UUID: Int] = [:]
        rangs.reserveCapacity(ordonnes.count)
        for (rang, maillon) in ordonnes.enumerated() {
            rangs[maillon.id] = rang
        }

        self.maillons = ordonnes
        self.rangs = rangs
    }

    /// Suite construite depuis les lignes de la fiche de serie.
    public init(chapitres: [ChapitreDeFiche]) {
        self.init(
            chapitres.map {
                MaillonDeChapitre(
                    id: $0.id,
                    numero: $0.numero,
                    ordreDansSerie: $0.ordreDansSerie,
                    nombreDePages: $0.nombrePages
                )
            }
        )
    }

    /// Suite vide, employee tant que la liste des chapitres n est pas chargee.
    public static let vide = SuiteDeChapitres([])

    /// Nombre de chapitres de la suite.
    public var nombreDeChapitres: Int {
        maillons.count
    }

    /// Vrai quand la suite ne porte aucun chapitre.
    public var estVide: Bool {
        maillons.isEmpty
    }

    /// Premier chapitre de la serie.
    public var premier: MaillonDeChapitre? {
        maillons.first
    }

    /// Dernier chapitre de la serie.
    public var dernier: MaillonDeChapitre? {
        maillons.last
    }

    /// Rang narratif d un chapitre, nul quand il n appartient pas a la suite.
    public func rang(de chapitreId: UUID) -> Int? {
        rangs[chapitreId]
    }

    /// Maillon d un chapitre, nul quand il n appartient pas a la suite.
    public func maillon(de chapitreId: UUID) -> MaillonDeChapitre? {
        guard let rang = rangs[chapitreId] else { return nil }

        return maillons[rang]
    }

    /// Chapitre qui suit celui ci dans l ordre narratif.
    public func suivant(de chapitreId: UUID) -> MaillonDeChapitre? {
        guard let rang = rangs[chapitreId], rang + 1 < maillons.count else {
            return nil
        }

        return maillons[rang + 1]
    }

    /// Chapitre qui precede celui ci dans l ordre narratif.
    public func precedent(de chapitreId: UUID) -> MaillonDeChapitre? {
        guard let rang = rangs[chapitreId], rang > 0 else {
            return nil
        }

        return maillons[rang - 1]
    }

    /// Vrai quand ce chapitre est le dernier connu de la serie.
    ///
    /// Faux pour un chapitre etranger a la suite. L ecran de fin de serie de la
    /// section 7.4 annonce une fin, il ne doit jamais sortir d une ignorance.
    public func estLeDernier(_ chapitreId: UUID) -> Bool {
        guard let rang = rangs[chapitreId] else { return false }

        return rang == maillons.count - 1
    }
}

/// Marque un chapitre comme lu, la ou cet etat survit a la fermeture.
///
/// Meme frontiere que `EnregistreurDePosition` : le moteur de lecture declenche
/// le marquage au passage d un chapitre a l autre sans rien savoir de la base,
/// et un test remplace la base par un espion.
public protocol MarqueurDeChapitreLu: Sendable {
    /// Marque le chapitre comme lu, ou echoue en le laissant intact.
    func marquerLu(_ chapitreId: UUID) async throws
}
