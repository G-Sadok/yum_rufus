import Core
import Foundation
import GRDB
import Storage

//
// GenerateurDeJeuDeTest
//
// Materialise le corpus de 5000 series et 200000 chapitres de la section 12.
//
// Le corpus passe par le schema reel de Storage et par ses declencheurs, il
// n est pas ecrit directement en SQL. C est la seule facon d obtenir un
// `chapitresNonLus` juste sur 5000 series, et donc de mesurer le defilement de
// la grille sur des donnees que l application produirait elle meme. Un corpus
// insere a cote des declencheurs mesurerait une grille dont la pastille de non
// lus est fausse, ce qui est exactement le cas que la section 12 veut couvrir.
//

/// Ce que la generation a depose, rendu a l appelant pour qu il l affiche.
public struct ResultatDeGeneration: Sendable, Hashable {
    public let series: Int
    public let chapitres: Int
    public let chapitresSurDisque: Int
    public let base: URL

    public init(series: Int, chapitres: Int, chapitresSurDisque: Int, base: URL) {
        self.series = series
        self.chapitres = chapitres
        self.chapitresSurDisque = chapitresSurDisque
        self.base = base
    }
}

/// Fabrique du corpus volumineux.
public enum GenerateurDeJeuDeTest {
    /// Amplitude de la variation du nombre de chapitres autour de la moyenne.
    ///
    /// Une bibliotheque ou toutes les series ont exactement quarante chapitres
    /// rendrait la grille trop reguliere : les pastilles de non lus auraient
    /// toutes la meme largeur, et rien ne dirait ce que coute une serie de trois
    /// cents chapitres a cote d une serie qui en a deux.
    static let amplitude = 30

    /// Ecrit le corpus complet a l emplacement donne.
    ///
    /// L emplacement est efface avant, sans quoi une seconde generation
    /// ajouterait 200000 chapitres aux 200000 precedents et le corpus cesserait
    /// de correspondre a son manifeste.
    @discardableResult
    public static func materialiser(
        _ manifeste: ManifesteDuJeuDeTest,
        vers emplacement: EmplacementDuJeuDeTest,
        journal: (String) -> Void = { _ in }
    ) throws -> ResultatDeGeneration {
        let fichiers = FileManager.default

        if fichiers.fileExists(atPath: emplacement.genere.path) {
            try fichiers.removeItem(at: emplacement.genere)
        }

        try fichiers.createDirectory(at: emplacement.chapitres, withIntermediateDirectories: true)

        journal("Ecriture de \(manifeste.chapitresSurDisque) chapitres en CBZ")
        try ecrireLesChapitres(manifeste, vers: emplacement)

        journal("Ecriture de \(manifeste.series) series et \(manifeste.chapitres) chapitres en base")
        let base = try BaseDeDonnees.surDisque(a: emplacement.bibliotheque)
        try remplir(base, avec: manifeste, journal: journal)

        return ResultatDeGeneration(
            series: manifeste.series,
            chapitres: manifeste.chapitres,
            chapitresSurDisque: manifeste.chapitresSurDisque,
            base: emplacement.bibliotheque
        )
    }

    /// Pose les chapitres qui existent reellement sur le disque.
    static func ecrireLesChapitres(
        _ manifeste: ManifesteDuJeuDeTest,
        vers emplacement: EmplacementDuJeuDeTest
    ) throws {
        for rang in 0..<manifeste.chapitresSurDisque {
            try EcrivainDeCbz.ecrire(
                vers: emplacement.chapitre(rang: rang),
                pages: manifeste.pagesParChapitreSurDisque,
                largeur: manifeste.largeurDePage,
                hauteur: manifeste.hauteurDePage,
                graine: manifeste.graine &+ UInt64(rang &* 1000)
            )
        }
    }

    /// Remplit la base avec la source, les series et les chapitres.
    static func remplir(
        _ base: BaseDeDonnees,
        avec manifeste: ManifesteDuJeuDeTest,
        journal: (String) -> Void = { _ in }
    ) throws {
        var tirage = GrainePseudoAleatoire(graine: manifeste.graine)
        let source = Source(
            id: tirage.identifiant(),
            type: .fichiersLocaux,
            nom: "Dossier du jeu de test"
        )

        let repartition = repartitionDesChapitres(manifeste, tirage: &tirage)
        let origine = Date(timeIntervalSince1970: 1_700_000_000)

        try base.ecrivain.write { connexion in
            try source.insert(connexion)

            for rang in 0..<manifeste.series {
                let serie = serie(
                    rang: rang,
                    source: source.id,
                    origine: origine,
                    tirage: &tirage
                )
                try serie.insert(connexion)

                let contexte = ContexteDeSerie(
                    serie: serie.id,
                    rang: rang,
                    manifeste: manifeste,
                    origine: origine
                )

                try inserer(
                    chapitres: repartition[rang],
                    de: contexte,
                    tirage: &tirage,
                    dans: connexion
                )

                if rang % 500 == 499 {
                    journal("  \(rang + 1) series ecrites")
                }
            }
        }
    }

    // MARK: Composition du corpus

    /// Nombre de chapitres de chaque serie, dont la somme fait exactement le
    /// total du manifeste.
    ///
    /// La moyenne est recalculee a chaque serie sur ce qui reste. Sans cela un
    /// tirage genereux en tete laisserait trop peu pour la queue, et les
    /// dernieres series se retrouveraient toutes a un chapitre.
    static func repartitionDesChapitres(
        _ manifeste: ManifesteDuJeuDeTest,
        tirage: inout GrainePseudoAleatoire
    ) -> [Int] {
        var repartition: [Int] = []
        repartition.reserveCapacity(manifeste.series)

        var restant = manifeste.chapitres

        for rang in 0..<manifeste.series {
            let seriesRestantes = manifeste.series - rang

            guard seriesRestantes > 1 else {
                repartition.append(restant)
                break
            }

            let moyenne = restant / seriesRestantes
            let bas = max(1, moyenne - amplitude)
            let haut = max(bas, min(moyenne + amplitude, restant - (seriesRestantes - 1)))
            let nombre = tirage.entier(de: bas, a: haut)

            repartition.append(nombre)
            restant -= nombre
        }

        return repartition
    }

    /// Une serie du corpus.
    static func serie(
        rang: Int,
        source: UUID,
        origine: Date,
        tirage: inout GrainePseudoAleatoire
    ) -> Manga {
        // La date de derniere lecture porte le tri de la grille et l index
        // idx_manga_bibliotheque. La faire varier serie par serie evite un index
        // ou toutes les cles sont egales, qui degenererait en balayage complet
        // et rendrait la mesure du defilement trop optimiste.
        let recul = TimeInterval(tirage.entier(de: 0, a: 3_600_000))

        return Manga(
            id: tirage.identifiant(),
            sourceId: source,
            identifiantDistant: "serie-\(rang)",
            titre: titre(rang: rang),
            statut: .enCours,
            langue: "fr",
            estDansBibliotheque: true,
            dateAjout: origine,
            dateDerniereLecture: origine.addingTimeInterval(-recul)
        )
    }

    /// Titre d une serie, assez varie pour que le tri et la recherche aient
    /// quelque chose a mordre.
    static func titre(rang: Int) -> String {
        let familles = [
            "Chroniques", "Legende", "Sentier", "Cite", "Orage",
            "Marees", "Cendres", "Reverie", "Frontiere", "Silence",
        ]
        let complements = [
            "du nord", "de verre", "sans fin", "d automne", "des sables",
            "en hiver", "du dernier jour", "de la vallee", "au crepuscule", "des origines",
        ]

        let famille = familles[rang % familles.count]
        let complement = complements[(rang / familles.count) % complements.count]

        return "\(famille) \(complement) \(rang)"
    }

    /// Insere les chapitres d une serie.
    ///
    /// Environ un tiers des chapitres est marque lu. Une bibliotheque
    /// entierement non lue donnerait un `chapitresNonLus` egal au nombre de
    /// chapitres pour toutes les series, ce qui ne testerait pas le declencheur
    /// et rendrait la pastille de la grille uniforme.
    private static func inserer(
        chapitres nombre: Int,
        de contexte: ContexteDeSerie,
        tirage: inout GrainePseudoAleatoire,
        dans connexion: Database
    ) throws {
        let manifeste = contexte.manifeste

        for rang in 0..<nombre {
            let surDisque = contexte.rang == 0 && rang < manifeste.chapitresSurDisque
            let pages = surDisque ? manifeste.pagesParChapitreSurDisque : tirage.entier(de: 12, a: 60)
            let lu = surDisque == false && tirage.entier(de: 0, a: 2) == 0

            let chapitre = Chapitre(
                id: tirage.identifiant(),
                mangaId: contexte.serie,
                identifiantDistant: "chapitre-\(rang)",
                numero: Double(rang + 1),
                titre: "Chapitre \(rang + 1)",
                langue: "fr",
                datePublication: contexte.origine.addingTimeInterval(TimeInterval(rang) * 86400),
                nombrePages: pages,
                estLu: lu,
                ordreDansSerie: rang
            )

            try chapitre.insert(connexion)
        }
    }
}

/// Ce qu il faut savoir de la serie en cours pour lui ecrire ses chapitres.
///
/// Ces quatre valeurs voyagent toujours ensemble et ne varient pas d un chapitre
/// a l autre. Les passer une par une donnait une fonction a sept parametres, que
/// l analyse statique refuse a juste titre.
private struct ContexteDeSerie {
    let serie: UUID
    let rang: Int
    let manifeste: ManifesteDuJeuDeTest
    let origine: Date
}
