import Core
import Foundation
@testable import Sync

//
// AtelierDeSynchronisationICloud
//
// Le montage commun des tests de synchronisation : un distant partage, deux
// appareils, une horloge simulee.
//
// Il existe pour rendre le premier critere verifiable. Mesurer une propagation
// de moins de trente secondes entre deux appareils reels demanderait deux
// comptes iCloud et une attente reelle a chaque execution. Ici, l horloge est
// une variable, le distant est un dictionnaire, et la mesure porte sur ce qui
// est reellement mesurable : le nombre de secondes simulees entre le geste et
// son arrivee, sous la cadence exacte du produit.
//
// Le distant figé n est pas une simplification complaisante. Il reproduit les
// trois comportements de CloudKit dont le moteur depend : la livraison par
// lots avec jeton de reprise, l ecrasement par cle, et l arbitrage a
// l ecriture, qui empeche un appareil longtemps hors ligne d ecraser un etat
// plus recent en revenant.
//

/// Distant partage par les appareils d un test.
actor EntrepotPartage: EntrepotDeSynchronisation {
    /// Etat courant de la zone, une ligne par cle, dans l ordre d arrivee.
    private var lignes: [ChangementSynchronise] = []

    /// Nombre d appels a pousser, pour verifier le regroupement.
    private(set) var envois = 0

    /// Nombre d appels a tirer.
    private(set) var lectures = 0

    /// Erreur a lever au prochain appel, puis oubliee.
    private var prochaineErreur: ErreurDEntrepot?

    /// Nombre maximal de lignes rendues par lot.
    private let taillleDeLot: Int

    init(taillleDeLot: Int = 100) {
        self.taillleDeLot = taillleDeLot
    }

    /// Fait echouer le prochain appel, une seule fois.
    func faireEchouer(_ erreur: ErreurDEntrepot) {
        prochaineErreur = erreur
    }

    /// Etat de la zone, tel qu un troisieme appareil le lirait.
    func contenu() -> [ChangementSynchronise] {
        lignes
    }

    func pousser(_ changements: [ChangementSynchronise]) async throws {
        try leverSiDemande()
        envois += 1

        for changement in changements {
            guard let rang = lignes.firstIndex(where: { $0.cle == changement.cle }) else {
                lignes.append(changement)
                continue
            }

            // Arbitrage a l ecriture, comme le fait l entrepot CloudKit : un
            // appareil qui revient apres trois jours hors ligne ne doit pas
            // ecraser ce qui a ete lu entre temps ailleurs.
            let gagnant = ResolutionDeConflit.gagnant(lignes[rang], changement).changement

            lignes.remove(at: rang)
            lignes.append(gagnant)
        }
    }

    func tirer(depuis jeton: Data?) async throws -> LotDistant {
        try leverSiDemande()
        lectures += 1

        let depart = Self.rang(de: jeton)
        let restantes = depart < lignes.count ? Array(lignes[depart...]) : []
        let lot = Array(restantes.prefix(taillleDeLot))

        return LotDistant(
            changements: lot,
            jeton: Self.jeton(pour: depart + lot.count),
            suite: lot.count < restantes.count
        )
    }

    /// Jeton de reprise, ici un simple rang encode.
    private static func jeton(pour rang: Int) -> Data {
        Data(String(rang).utf8)
    }

    /// Rang porte par un jeton, zero quand il est nul ou illisible.
    private static func rang(de jeton: Data?) -> Int {
        guard let jeton, let texte = String(data: jeton, encoding: .utf8), let rang = Int(texte) else {
            return 0
        }

        return rang
    }

    /// Leve l erreur demandee, puis l oublie.
    private func leverSiDemande() throws {
        guard let erreur = prochaineErreur else {
            return
        }

        prochaineErreur = nil

        throw erreur
    }
}

/// Journal persiste en memoire, tenant lieu de base pour les tests.
actor MagasinDuJournalEnMemoire: MagasinDuJournalDeChangements {
    private var contenu = JournalDeChangements.vide
    private var jeton: Data?
    private var envoi: Date?

    init(_ contenu: JournalDeChangements = .vide) {
        self.contenu = contenu
    }

    func journal() async throws -> JournalDeChangements {
        contenu
    }

    func consigner(_ changements: [ChangementSynchronise]) async throws {
        contenu.consigner(changements)
    }

    func retirer(_ envoyes: [ChangementSynchronise]) async throws {
        contenu.retirer(envoyes)
    }

    func jetonDistant() async throws -> Data? {
        jeton
    }

    func definirLeJetonDistant(_ jeton: Data?) async throws {
        self.jeton = jeton
    }

    func dernierEnvoi() async throws -> Date? {
        envoi
    }

    func definirLeDernierEnvoi(_ date: Date) async throws {
        envoi = date
    }
}

/// Ce qu un appareil a reellement applique.
actor ApplicateurEspion: ApplicateurDeChangements {
    private var etats: [String: ChangementSynchronise] = [:]

    /// Nombre de lots appliques, lots vides exclus.
    private(set) var applications = 0

    @discardableResult
    func appliquer(_ changements: [ChangementSynchronise]) async throws -> [ChangementSynchronise] {
        guard changements.isEmpty == false else {
            return []
        }

        applications += 1
        var retenus: [ChangementSynchronise] = []

        for changement in changements {
            let cle = changement.cle.texte

            if let existant = etats[cle],
               ResolutionDeConflit.gagnant(existant, changement).changement != changement {
                continue
            }

            etats[cle] = changement
            retenus.append(changement)
        }

        return retenus
    }

    /// Progression connue par cet appareil pour ce chapitre.
    func progression(du chapitre: UUID) throws -> ProgressionSynchronisee? {
        let cle = CleDeChangement(entite: .progressionDeChapitre, identifiant: chapitre)

        guard let changement = etats[cle.texte] else {
            return nil
        }

        return try ProgressionSynchronisee.lire(changement)
    }
}

/// Etat du reseau et des reglages, changeable pendant un test.
///
/// La classe est `@unchecked Sendable` et c est sur : chacun de ses acces passe
/// par le meme verrou, et elle ne publie aucune reference vers son etat
/// interne. Un acteur aurait ete plus simple a justifier mais ne convient pas
/// ici, le moteur lisant son contexte par une fermeture synchrone, comme il le
/// fait en production ou les reglages viennent d une valeur deja chargee.
final class ConditionsDeTest: @unchecked Sendable {
    private let verrou = NSLock()
    private var contexte: ContexteICloud

    init(_ contexte: ContexteICloud) {
        self.contexte = contexte
    }

    /// Contexte courant, tel que le moteur le lit a chaque decision.
    var courant: ContexteICloud {
        verrou.lock()
        defer { verrou.unlock() }

        return contexte
    }

    /// Branche ou coupe le reseau.
    func definirLeReseau(_ joignable: Bool) {
        verrou.lock()
        defer { verrou.unlock() }

        contexte = contexte.avecReseau(joignable)
    }

    /// Remplace le contexte entier.
    func definir(_ nouveau: ContexteICloud) {
        verrou.lock()
        defer { verrou.unlock() }

        contexte = nouveau
    }
}

/// Un appareil complet : son journal, son applicateur, son moteur.
struct AppareilDeTest {
    let nom: String
    let magasin: MagasinDuJournalEnMemoire
    let applicateur: ApplicateurEspion
    let conditions: ConditionsDeTest
    let moteur: MoteurDeSynchronisationICloud

    init(
        nom: String,
        entrepot: EntrepotPartage,
        conditions: ConditionsDeTest = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal),
        cadence: CadenceDeSynchronisation = .parDefaut
    ) {
        self.nom = nom
        self.conditions = conditions
        magasin = MagasinDuJournalEnMemoire()
        applicateur = ApplicateurEspion()

        moteur = MoteurDeSynchronisationICloud(
            entrepot: entrepot,
            magasin: magasin,
            applicateur: applicateur,
            appareil: nom,
            cadence: cadence,
            contexte: { [conditions] in conditions.courant }
        )
    }
}

/// Montage commun des tests de synchronisation iCloud.
enum AtelierDeSynchronisationICloud {
    /// Instant de depart de toutes les horloges simulees.
    static let depart = Date(timeIntervalSince1970: 1_700_000_000)

    /// Reglages ou les deux interrupteurs de la section iCloud sont actifs.
    static var reglagesActifs: ReglagesDeLApplication {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.booleen(true), pour: .synchroniserLaProgression)
        reglages.definir(.booleen(true), pour: .synchroniserLaBibliotheque)

        return reglages
    }

    /// Installation abonnee, en ligne, sans session incognito.
    static var contexteNominal: ContexteICloud {
        ContexteICloud(reglages: reglagesActifs)
    }

    /// Progression d un chapitre a un instant donne.
    static func progression(
        chapitre: UUID,
        page: Int,
        secondes: TimeInterval
    ) -> ProgressionSynchronisee {
        ProgressionSynchronisee(
            chapitreId: chapitre,
            pageAtteinte: page,
            dateLecture: depart.addingTimeInterval(secondes)
        )
    }

    /// Instant simule, en secondes depuis le depart.
    static func instant(_ secondes: TimeInterval) -> Date {
        depart.addingTimeInterval(secondes)
    }
}
