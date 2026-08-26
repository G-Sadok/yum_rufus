import Core
import Foundation

//
// AnalyseurDePartage
//
// Le parcours d un partage reseau, qui produit la meme `AnalyseDeDossier` qu un
// dossier pose sur le disque.
//
// Rendre le meme type n est pas une commodite d ecriture, c est la seule facon
// de tenir la promesse du tableau 4.2. Un partage SMB et un dossier local
// portent la meme arborescence, ecrite par le meme utilisateur, souvent
// synchronisee de l un vers l autre. La convention a deux niveaux de la
// section 4.2 doit donc y produire exactement les memes series et les memes
// chapitres, sans quoi la meme bibliotheque changerait de forme selon qu on la
// regarde depuis l appareil ou depuis le reseau.
//
// Le parcours differe pourtant sur un point, et c est le reseau qui l impose.
// Un dossier local se liste pour presque rien ; un partage paie un aller retour
// par listage. Les listages d un meme niveau partent donc ensemble, dans un
// groupe de taches borne, au lieu de s enchainer serie apres serie. Sur une
// bibliotheque de cinq cents series, la difference n est pas un gain de confort,
// c est l ecart entre quelques secondes et plusieurs minutes.
//
// La borne du groupe est basse volontairement. Un partage SMB grand public tient
// une poignee de requetes simultanees avant de degrader ses temps de reponse,
// et un NAS domestique sature bien avant un serveur. Huit listages en vol est le
// point ou le gain cesse de croitre sur les partages qu un utilisateur possede.
//

/// Parcourt un partage reseau et en deduit les series et les chapitres.
public struct AnalyseurDePartage: Sendable {
    /// Nombre de listages menes de front.
    public static let listagesSimultanes = 8

    private let simultanes: Int

    public init(listagesSimultanes: Int = AnalyseurDePartage.listagesSimultanes) {
        simultanes = max(1, listagesSimultanes)
    }

    /// Analyse la racine d un partage.
    ///
    /// - Throws: `ErreurDeSource.sourceInjoignable` quand la racine ne se laisse
    ///   pas lister, ce qui est le seul echec qui arrete l analyse. Un sous
    ///   dossier illisible est saute : un partage dont une serie est protegee ne
    ///   doit pas perdre les quatre cents autres.
    public func analyser(_ partage: any PartageReseau) async throws -> AnalyseDeDossier {
        let racine: [EntreeDePartage]

        do {
            racine = try await partage.lister("")
        } catch {
            throw ErreurDeSource.depuis(error, source: partage.libelle)
        }

        let triees = TriNaturel.trier(retenues(racine), selon: { $0.nom })
        let dossiers = triees.filter(\.estDossier)
        let contenus = await listerEnParallele(dossiers.map(\.chemin), dans: partage)

        var series: [SerieLocale] = []

        for entree in triees {
            try Task.checkCancellation()

            if entree.estDossier {
                guard let serie = await serie(entree, contenus: contenus, partage: partage) else {
                    continue
                }

                series.append(serie)
            } else if let serie = Self.serieDepuisUneArchive(entree) {
                series.append(serie)
            }
        }

        return AnalyseDeDossier(series: series)
    }

    // MARK: Series

    /// Construit la serie portee par un dossier, ou nul quand il ne porte aucun
    /// chapitre lisible.
    private func serie(
        _ entree: EntreeDePartage,
        contenus: [String: [EntreeDePartage]],
        partage: any PartageReseau
    ) async -> SerieLocale? {
        let chapitres = await chapitres(de: entree, contenus: contenus, partage: partage)

        guard chapitres.isEmpty == false else {
            return nil
        }

        let dates = ([entree.dateModification] + chapitres.map(\.dateModification)).compactMap(\.self)

        return SerieLocale(
            identifiant: entree.chemin,
            titre: entree.nom,
            chapitres: chapitres,
            dateModification: dates.max()
        )
    }

    /// Construit la serie a chapitre unique portee par une archive posee a la
    /// racine du partage.
    private static func serieDepuisUneArchive(_ entree: EntreeDePartage) -> SerieLocale? {
        guard FormatsDeConteneur.connus.contains(entree.format) else {
            return nil
        }

        let chapitre = ChapitreLocal(
            identifiant: entree.chemin,
            titre: entree.nomSansExtension,
            numero: NumeroDeChapitre.extraire(de: entree.nom) ?? 1,
            ordre: 0,
            forme: .archive(format: entree.format),
            dateModification: entree.dateModification
        )

        return SerieLocale(
            identifiant: entree.chemin,
            titre: entree.nomSansExtension,
            chapitres: [chapitre],
            dateModification: entree.dateModification
        )
    }

    // MARK: Chapitres

    /// Rend les chapitres d un dossier de serie, dans l ordre naturel.
    private func chapitres(
        de serie: EntreeDePartage,
        contenus: [String: [EntreeDePartage]],
        partage: any PartageReseau
    ) async -> [ChapitreLocal] {
        let entrees = contenus[serie.chemin] ?? []
        let candidats = TriNaturel.trier(
            entrees.filter { $0.estDossier || FormatsDeConteneur.connus.contains($0.format) },
            selon: { $0.nom }
        )
        let pagesParDossier = await listerEnParallele(
            candidats.filter(\.estDossier).map(\.chemin),
            dans: partage
        )

        var chapitres: [ChapitreLocal] = []

        for candidat in candidats {
            guard let chapitre = Self.chapitre(
                candidat,
                pages: pagesParDossier[candidat.chemin] ?? [],
                ordre: chapitres.count
            ) else {
                continue
            }

            chapitres.append(chapitre)
        }

        if chapitres.isEmpty {
            return Self.chapitreDesImagesPosees(de: serie, entrees: entrees)
        }

        return chapitres
    }

    /// Construit un chapitre a partir d une entree candidate.
    private static func chapitre(
        _ entree: EntreeDePartage,
        pages: [EntreeDePartage],
        ordre: Int
    ) -> ChapitreLocal? {
        let forme: FormeDeChapitre
        var nombrePages: Int?

        if entree.estDossier {
            let images = EntreesDArchive.pages(parmi: pages.filter { $0.estDossier == false }.map(\.nom))

            guard images.isEmpty == false else {
                return nil
            }

            forme = .dossierDImages
            nombrePages = images.count
        } else {
            forme = .archive(format: entree.format)
        }

        return ChapitreLocal(
            identifiant: entree.chemin,
            titre: entree.nomSansExtension,
            numero: NumeroDeChapitre.extraire(de: entree.nom) ?? Double(ordre + 1),
            ordre: ordre,
            forme: forme,
            nombrePages: nombrePages,
            dateModification: entree.dateModification
        )
    }

    /// Traite le cas de la serie qui est son propre chapitre : des images posees
    /// directement dans le dossier de la serie.
    private static func chapitreDesImagesPosees(
        de serie: EntreeDePartage,
        entrees: [EntreeDePartage]
    ) -> [ChapitreLocal] {
        let images = entrees.filter { $0.estDossier == false && EntreesDArchive.estImage($0.nom) }

        guard images.isEmpty == false else {
            return []
        }

        return [
            ChapitreLocal(
                identifiant: serie.chemin,
                titre: serie.nom,
                numero: 1,
                ordre: 0,
                forme: .dossierDImages,
                nombrePages: images.count,
                dateModification: images.compactMap(\.dateModification).max()
            ),
        ]
    }

    // MARK: Listage

    /// Liste plusieurs dossiers de front et rend leur contenu par chemin.
    ///
    /// Un dossier qui refuse de se lister rend une liste vide et non une erreur.
    /// C est ce qui isole une serie protegee du reste du partage, comme la regle
    /// de la section 4.1 le demande pour les sources entre elles.
    private func listerEnParallele(
        _ chemins: [String],
        dans partage: any PartageReseau
    ) async -> [String: [EntreeDePartage]] {
        guard chemins.isEmpty == false else {
            return [:]
        }

        return await withTaskGroup(of: (String, [EntreeDePartage]).self) { groupe in
            var suivant = 0
            var resultats: [String: [EntreeDePartage]] = [:]

            func ajouter() {
                guard suivant < chemins.count else {
                    return
                }

                let chemin = chemins[suivant]
                suivant += 1
                groupe.addTask {
                    let entrees = await (try? partage.lister(chemin)) ?? []

                    return (chemin, Self.retenues(entrees))
                }
            }

            for _ in 0..<min(simultanes, chemins.count) {
                ajouter()
            }

            while let (chemin, entrees) = await groupe.next() {
                resultats[chemin] = entrees
                ajouter()
            }

            return resultats
        }
    }

    /// Ecarte les parasites de la section 5.3, comme le fait l analyse locale.
    private static func retenues(_ entrees: [EntreeDePartage]) -> [EntreeDePartage] {
        entrees.filter { EntreesDArchive.estParasite($0.nom) == false }
    }

    /// Ecarte les parasites, depuis une instance.
    private func retenues(_ entrees: [EntreeDePartage]) -> [EntreeDePartage] {
        Self.retenues(entrees)
    }
}
