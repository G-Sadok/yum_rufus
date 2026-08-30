import Foundation

//
// SauvegardeDeLaProgression
//
// La part progression du fichier JSON versionne de la section 10 du cahier de
// developpement.
//
// Elle est separee de la part bibliotheque, alors que les colonnes concernees
// vivent dans les memes tables. Deux raisons.
//
// La premiere est le mode incognito de la section 11. `EcritureDeSession`
// enumere les traces de lecture, et la date de derniere lecture d une serie en
// fait partie au meme titre que la page atteinte d un chapitre. Les tenir dans
// une part a elles rend visible, dans le fichier comme dans le code, ce qu une
// future option `exporter sans la progression` aurait a retirer.
//
// La seconde est le compteur denormalise de chapitres non lus. Un chapitre
// arrive non lu par la part bibliotheque, puis prend son etat ici. Les
// declencheurs voient donc une insertion puis une mise a jour, chacune traitee
// une fois, plutot qu une insertion deja marquee lue dont le compteur devrait se
// corriger a rebours.
//

/// L avancement d une serie tel qu il figure dans une sauvegarde.
public struct ProgressionDeSerieExportee: Sendable, Codable, Hashable {
    public let mangaId: UUID
    public let dateDerniereLecture: Date?

    /// Projette l avancement d une serie vers sa forme exportable.
    public init(_ manga: Manga) {
        mangaId = manga.id
        dateDerniereLecture = manga.dateDerniereLecture
    }
}

/// L avancement d un chapitre tel qu il figure dans une sauvegarde.
///
/// C est la position de reprise de la section 7.5 en entier : le chapitre, la
/// page, et le decalage de defilement des modes verticaux. Exporter les deux
/// premiers seulement rouvrirait un chapitre webtoon en haut d une page de vingt
/// mille pixels que l utilisateur avait presque finie.
public struct ProgressionDeChapitreExportee: Sendable, Codable, Hashable {
    public let chapitreId: UUID
    public let estLu: Bool
    public let pageAtteinte: Int
    public let decalageDeDefilement: Double
    public let dateLecture: Date?

    /// Projette l avancement d un chapitre vers sa forme exportable.
    public init(_ chapitre: Chapitre) {
        chapitreId = chapitre.id
        estLu = chapitre.estLu
        pageAtteinte = chapitre.pageAtteinte
        decalageDeDefilement = chapitre.decalageDeDefilement
        dateLecture = chapitre.dateLecture
    }

    /// Position de reprise que cet avancement decrit.
    public func position() -> PositionDeLecture {
        PositionDeLecture(
            chapitreId: chapitreId,
            pageIndex: pageAtteinte,
            decalageDeDefilement: decalageDeDefilement
        )
    }
}

/// La part progression d une sauvegarde, versionnee.
public struct SauvegardeDeLaProgression: Sendable, Codable, Hashable {
    /// Version du format de la part progression.
    public static let versionCourante = 1

    public let version: Int
    public let series: [ProgressionDeSerieExportee]
    public let chapitres: [ProgressionDeChapitreExportee]

    public init(
        version: Int = SauvegardeDeLaProgression.versionCourante,
        series: [ProgressionDeSerieExportee],
        chapitres: [ProgressionDeChapitreExportee]
    ) {
        self.version = version
        self.series = series
        self.chapitres = chapitres
    }

    /// Construit la part progression a partir des entites persistees.
    ///
    /// Une serie jamais ouverte et un chapitre jamais lu figurent quand meme
    /// dans la liste. Les omettre ferait dependre le contenu du fichier de
    /// l etat de lecture, et une comparaison d exports ne dirait plus rien.
    public init(series: [Manga], chapitres: [Chapitre]) {
        self.init(
            series: series.map(ProgressionDeSerieExportee.init),
            chapitres: chapitres.map(ProgressionDeChapitreExportee.init)
        )
    }

    /// Part vide, celle que la migration d une sauvegarde anterieure installe.
    public static let vide = SauvegardeDeLaProgression(series: [], chapitres: [])
}
