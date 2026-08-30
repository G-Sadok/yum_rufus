import Core
import Foundation
import GRDB

//
// MagasinDeVeilleDeChapitres
//
// Seul point d acces a l etat de la veille de F060.
//
// Les series surveillees sont celles de la bibliotheque, et seulement elles.
// Une serie seulement consultee dans un catalogue n interesse personne, et
// l interroger consommerait le budget d une serie reellement suivie.
//
// Les chapitres connus d une serie sont l union de deux ensembles : ceux que la
// base porte deja, et ceux qu une notification a annonces sans qu ils soient
// encore importes. Sans le second, la meme nouveaute repartirait a chaque
// execution jusqu a ce que l utilisateur ouvre la serie.
//
// Le magasin est asynchrone alors que GRDB est synchrone. La raison est
// l appelant : le moteur de veille est un acteur, et il ne doit pas bloquer son
// fil sur une lecture de fichier pendant les quelques dizaines de secondes que
// le systeme lui accorde.
//

/// Lit et ecrit ce que la veille de nouveaux chapitres a retenu.
public struct MagasinDeVeilleDeChapitres: MagasinDeVeille {
    private let base: BaseDeDonnees

    /// Construit le magasin sur une base deja ouverte et migree.
    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Etat des quotas

    public func etatDeVeille() async throws -> EtatDeVeille {
        try await base.ecrivain.write { connexion in
            try Self.ligneUnique(connexion).etat
        }
    }

    public func enregistrer(_ etat: EtatDeVeille) async throws {
        try await base.ecrivain.write { connexion in
            try EtatDeVeillePersiste(etat).update(connexion)
        }
    }

    // MARK: Series surveillees

    public func seriesSurveillees() async throws -> [SerieSurveillee] {
        try await base.ecrivain.read { connexion in
            let lignes = try Row.fetchAll(
                connexion,
                sql: """
                SELECT manga.id AS mangaId,
                       manga.sourceId AS sourceId,
                       manga.identifiantDistant AS identifiantDistant,
                       manga.titre AS titre,
                       veilleDeSerie.derniereVerification AS derniereVerification,
                       veilleDeSerie.chapitresAnnonces AS chapitresAnnonces
                FROM manga
                LEFT JOIN veilleDeSerie ON veilleDeSerie.mangaId = manga.id
                WHERE manga.estDansBibliotheque
                """
            )

            var series: [SerieSurveillee] = []

            for ligne in lignes {
                let identifiant: UUID = ligne["mangaId"]
                let connus = try Self.chapitresConnus(de: identifiant, ligne: ligne, connexion: connexion)

                series.append(
                    SerieSurveillee(
                        id: identifiant,
                        source: SourceID(ligne["sourceId"]),
                        identifiantDistant: ligne["identifiantDistant"],
                        titre: ligne["titre"],
                        chapitresConnus: connus,
                        derniereVerification: ligne["derniereVerification"]
                    )
                )
            }

            return series
        }
    }

    public func enregistrerLaVerification(
        de serie: UUID,
        chapitresConnus: Set<String>,
        le date: Date
    ) async throws {
        try await base.ecrivain.write { connexion in
            let importes = try Self.chapitresDeLaBase(de: serie, connexion: connexion)

            // Seuls les identifiants absents de la base sont recopies. Le reste
            // est deja connu par la table `chapitre`, et le recopier ferait
            // grossir la colonne au rythme du catalogue.
            let aRetenir = chapitresConnus.subtracting(importes)

            try VeilleDeSeriePersistee(
                mangaId: serie,
                derniereVerification: date,
                chapitresAnnonces: VeilleDeSeriePersistee.encoder(aRetenir)
            ).save(connexion)
        }
    }

    // MARK: Lectures internes

    /// Chapitres que l appareil connait deja pour cette serie.
    private static func chapitresConnus(
        de serie: UUID,
        ligne: Row,
        connexion: Database
    ) throws -> Set<String> {
        let annonces = VeilleDeSeriePersistee(
            mangaId: serie,
            chapitresAnnonces: ligne["chapitresAnnonces"] ?? "[]"
        ).identifiants

        return try chapitresDeLaBase(de: serie, connexion: connexion).union(annonces)
    }

    /// Identifiants distants des chapitres deja importes.
    private static func chapitresDeLaBase(de serie: UUID, connexion: Database) throws -> Set<String> {
        let identifiants = try String.fetchAll(
            connexion,
            sql: "SELECT identifiantDistant FROM chapitre WHERE mangaId = ?",
            arguments: [serie]
        )

        return Set(identifiants)
    }

    /// Ligne unique de l etat, creee par la migration.
    ///
    /// Elle est recreee si elle manque, comme celle de l objectif quotidien :
    /// une base restauree depuis une sauvegarde ecrite avant cette migration
    /// pourrait ne pas la porter, et la veille cesserait alors de fonctionner
    /// sans que rien ne le dise.
    private static func ligneUnique(_ connexion: Database) throws -> EtatDeVeillePersiste {
        if let ligne = try EtatDeVeillePersiste.fetchOne(
            connexion,
            key: EtatDeVeillePersiste.identifiantDeLaLigneUnique
        ) {
            return ligne
        }

        let neuve = EtatDeVeillePersiste()
        try neuve.insert(connexion)

        return neuve
    }
}
