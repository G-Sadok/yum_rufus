import Core
import Foundation

//
// AnalyseurDeDossier
//
// Parcours du disque qui produit une `AnalyseDeDossier`.
//
// Le parcours est volontairement plat : le contenu de la racine, puis le
// contenu de chaque dossier de serie, et le contenu des dossiers candidats au
// rang de chapitre pour savoir s ils portent des images. Trois niveaux de
// listage, jamais de descente recursive, donc un cout proportionnel au nombre
// de chapitres et non a la profondeur du disque.
//
// Le filtrage des parasites et le tri naturel viennent de Core. Ce sont les
// memes regles que pour une archive : `__MACOSX`, `.DS_Store` et les noms
// caches disparaissent des deux cotes, et `page10.jpg` ne passe jamais devant
// `page2.jpg`.
//
// Un dossier iCloud Drive fait exception sur un point, et un seul. Un fichier
// qui n est pas sur l appareil peut y etre pose sous un substitut cache,
// `.Chapitre 1.cbz.icloud`, que le filtrage des noms caches ferait disparaitre.
// Le chapitre sortirait alors de la bibliotheque tant qu il n est pas
// telecharge, c est a dire exactement quand il faudrait l afficher pour
// permettre de le telecharger. L analyse sait donc lire ces substituts, et rend
// dans les deux cas la meme bibliotheque sous les memes identifiants.
//

/// Parcourt un dossier et en deduit les series et les chapitres.
public struct AnalyseurDeDossier: Sendable {
    /// Vrai quand le dossier analyse peut porter des substituts de fichiers non
    /// telecharges, ce qui est le cas d un dossier iCloud Drive et de lui seul.
    private let substitutsUbiquitaires: Bool

    /// Le gestionnaire de fichiers n est pas `Sendable`, il n est donc pas
    /// retenu : chaque appel prend l instance partagee, dont les operations de
    /// listage sont sures depuis n importe quelle tache.
    private var gestionnaire: FileManager {
        .default
    }

    public init(substitutsUbiquitaires: Bool = false) {
        self.substitutsUbiquitaires = substitutsUbiquitaires
    }

    /// Analyse le dossier racine d une source de fichiers locaux.
    ///
    /// - Throws: `ErreurDeSource.sourceInjoignable` quand la racine ne se laisse
    ///   pas lister.
    public func analyser(_ racine: URL, source: String) throws -> AnalyseDeDossier {
        guard let entrees = contenu(de: racine) else {
            throw ErreurDeSource.sourceInjoignable(source: source)
        }

        var series: [SerieLocale] = []

        for entree in TriNaturel.trier(entrees, selon: { $0.nom }) {
            // Une bibliotheque de 5000 series se parcourt en plusieurs secondes.
            // Sans ce point d annulation, fermer la fenetre pendant une analyse
            // laisserait le disque tourner jusqu au bout.
            try Task.checkCancellation()

            if entree.estDossier {
                guard let serie = serieDepuisUnDossier(entree, racine: racine) else { continue }

                series.append(serie)
            } else if let serie = serieDepuisUneArchive(entree, racine: racine) {
                series.append(serie)
            }
        }

        return AnalyseDeDossier(series: series)
    }

    // MARK: Series

    /// Construit la serie portee par un dossier, ou nul s il ne porte aucun
    /// chapitre lisible. Un dossier vide n est pas une serie sans chapitre,
    /// c est un dossier qui ne nous concerne pas.
    private func serieDepuisUnDossier(_ entree: EntreeDeDisque, racine: URL) -> SerieLocale? {
        let chapitres = chapitres(dans: entree.url, racine: racine)

        guard chapitres.isEmpty == false else { return nil }

        let dates = ([entree.dateModification] + chapitres.map(\.dateModification)).compactMap(\.self)

        return SerieLocale(
            identifiant: cheminRelatif(de: entree.urlVisible, racine: racine),
            titre: entree.nom,
            chapitres: chapitres,
            dateModification: dates.max()
        )
    }

    /// Construit la serie a chapitre unique portee par une archive posee a la
    /// racine.
    private func serieDepuisUneArchive(_ entree: EntreeDeDisque, racine: URL) -> SerieLocale? {
        guard FormatsDeConteneur.connus.contains(entree.format) else { return nil }

        let identifiant = cheminRelatif(de: entree.urlVisible, racine: racine)
        let titre = entree.nomSansExtension
        let chapitre = ChapitreLocal(
            identifiant: identifiant,
            titre: titre,
            numero: NumeroDeChapitre.extraire(de: entree.nom) ?? 1,
            ordre: 0,
            forme: .archive(format: entree.format),
            dateModification: entree.dateModification
        )

        return SerieLocale(
            identifiant: identifiant,
            titre: titre,
            chapitres: [chapitre],
            dateModification: entree.dateModification
        )
    }

    // MARK: Chapitres

    /// Rend les chapitres d un dossier de serie, dans l ordre naturel.
    private func chapitres(dans dossier: URL, racine: URL) -> [ChapitreLocal] {
        let entrees = contenu(de: dossier) ?? []
        let candidats = TriNaturel.trier(
            entrees.filter { $0.estDossier || FormatsDeConteneur.connus.contains($0.format) },
            selon: { $0.nom }
        )

        var chapitres: [ChapitreLocal] = []

        for candidat in candidats {
            guard let chapitre = chapitre(candidat, racine: racine, ordre: chapitres.count) else { continue }

            chapitres.append(chapitre)
        }

        if chapitres.isEmpty {
            return chapitreDesImagesPosees(dans: dossier, entrees: entrees, racine: racine)
        }

        return chapitres
    }

    /// Construit un chapitre a partir d une entree candidate, ou nul quand le
    /// dossier candidat ne porte aucune image.
    private func chapitre(_ entree: EntreeDeDisque, racine: URL, ordre: Int) -> ChapitreLocal? {
        let forme: FormeDeChapitre
        var nombrePages: Int?

        if entree.estDossier {
            let pages = imagesPosees(dans: entree.url)

            guard pages.isEmpty == false else { return nil }

            forme = .dossierDImages
            nombrePages = pages.count
        } else {
            forme = .archive(format: entree.format)
        }

        return ChapitreLocal(
            identifiant: cheminRelatif(de: entree.urlVisible, racine: racine),
            titre: entree.nomSansExtension,
            numero: NumeroDeChapitre.extraire(de: entree.nom) ?? Double(ordre + 1),
            ordre: ordre,
            forme: forme,
            nombrePages: nombrePages,
            dateModification: entree.dateModification
        )
    }

    /// Traite le cas de la serie qui est son propre chapitre : des images
    /// posees directement dans le dossier de la serie.
    private func chapitreDesImagesPosees(
        dans dossier: URL,
        entrees: [EntreeDeDisque],
        racine: URL
    ) -> [ChapitreLocal] {
        let pages = entrees.filter { $0.estDossier == false && EntreesDArchive.estImage($0.nom) }

        guard pages.isEmpty == false else { return [] }

        return [
            ChapitreLocal(
                identifiant: cheminRelatif(de: dossier, racine: racine),
                titre: dossier.lastPathComponent,
                numero: 1,
                ordre: 0,
                forme: .dossierDImages,
                nombrePages: pages.count,
                dateModification: pages.compactMap(\.dateModification).max()
            ),
        ]
    }

    // MARK: Disque

    /// Rend les noms d images posees dans un dossier, dans l ordre de lecture.
    ///
    /// Utilise par l analyse pour compter les pages, et par la source pour les
    /// servir. Le filtrage et le tri sont ceux de Core, donc les memes que pour
    /// une archive.
    func imagesPosees(dans dossier: URL) -> [String] {
        let entrees = contenu(de: dossier) ?? []

        return EntreesDArchive.pages(parmi: entrees.filter { $0.estDossier == false }.map(\.nom))
    }

    /// Liste le contenu direct d un dossier, parasites ecartes.
    ///
    /// Rend nul quand le dossier ne se laisse pas lister. C est l appelant qui
    /// decide si cela vaut une erreur, parce qu une racine illisible arrete
    /// l analyse alors qu un sous dossier illisible se saute.
    private func contenu(de dossier: URL) -> [EntreeDeDisque]? {
        let cles: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .nameKey]
        // Les noms caches ne sont ecartes par le listage que quand aucun
        // substitut n est attendu. Sinon le filtrage se fait juste apres, sur
        // le vrai nom, pour ne laisser passer que les substituts.
        let options: FileManager.DirectoryEnumerationOptions = substitutsUbiquitaires
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let entrees = try? gestionnaire.contentsOfDirectory(
            at: dossier,
            includingPropertiesForKeys: cles,
            options: options
        ) else {
            return nil
        }

        return entrees
            .filter(estRetenue)
            .map { EntreeDeDisque(url: $0, visible: nomVisible(de: $0)) }
    }

    /// Vrai quand cette entree du disque concerne l analyse.
    ///
    /// Le substitut est juge sur le nom qu il annonce et non sur le sien : le
    /// substitut d un `.DS_Store` reste un parasite, celui d un chapitre est un
    /// chapitre.
    private func estRetenue(_ url: URL) -> Bool {
        let nom = url.lastPathComponent

        guard substitutsUbiquitaires, let reel = EmplacementICloud.nomReel(de: nom) else {
            return EntreesDArchive.estParasite(nom) == false
        }

        return EntreesDArchive.estParasite(reel) == false
    }

    /// Emplacement de l entree sous le nom que l utilisateur voit.
    private func nomVisible(de url: URL) -> URL {
        substitutsUbiquitaires ? EmplacementICloud.visible(url) : url
    }

    /// Rend le chemin d une entree relativement a la racine de la source.
    private func cheminRelatif(de url: URL, racine: URL) -> String {
        let chemin = EmplacementICloud.cheminNormalise(url)
        let base = racine.standardizedFileURL.path
        let prefixe = base.hasSuffix("/") ? base : base + "/"

        guard chemin.hasPrefix(prefixe) else { return url.lastPathComponent }

        return String(chemin.dropFirst(prefixe.count))
    }
}

/// Une entree de dossier, avec ce que le systeme en dit deja.
///
/// Les valeurs de ressource sont lues une seule fois, au listage, parce que
/// chaque relecture est un aller retour vers le systeme de fichiers et qu une
/// bibliotheque de 200000 chapitres en ferait autant.
struct EntreeDeDisque: Sendable {
    /// Emplacement reel sur le disque, qui peut etre un substitut.
    ///
    /// C est celui a donner au systeme de fichiers, et le seul qui existe.
    let url: URL

    /// Emplacement sous le nom que l utilisateur voit.
    ///
    /// Egal a `url` partout ailleurs que dans un dossier iCloud Drive. C est
    /// lui qui decide du nom, du format et de l identifiant, pour qu un
    /// chapitre garde le meme identifiant avant et apres son telechargement.
    let urlVisible: URL

    let nom: String
    let estDossier: Bool
    let dateModification: Date?

    init(url: URL, visible: URL? = nil) {
        let valeurs = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])

        self.url = url
        urlVisible = visible ?? url
        nom = (visible ?? url).lastPathComponent
        estDossier = valeurs?.isDirectory ?? false
        dateModification = valeurs?.contentModificationDate
    }

    /// Extension en minuscules, vide quand l entree n en porte pas.
    var format: String {
        urlVisible.pathExtension.lowercased()
    }

    /// Nom sans son extension.
    var nomSansExtension: String {
        urlVisible.deletingPathExtension().lastPathComponent
    }
}
