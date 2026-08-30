import Core
import Foundation
@testable import Sync

//
// AtelierDeVeille
//
// Les doublures de la veille de F060 : un magasin en memoire, un centre de
// notifications qui retient ce qu on lui donne, une source qui annonce les
// chapitres que le test decide, et une horloge que le test avance.
//
// Aucune ne touche le systeme. C est ce qui permet de verifier le respect des
// quotas, le regroupement et le silence du mode incognito sans autorisation
// accordee a la main, sans reveil du systeme et sans attendre quatre heures.
//

/// Horloge pilotee par le test.
///
/// `@unchecked Sendable` est sur ici parce que le seul etat mutable est
/// `instant`, et que tous ses acces passent par `verrou`.
final class HorlogeDeTest: @unchecked Sendable {
    private let verrou = NSLock()
    private var instant: Date
    private let pasParLecture: TimeInterval

    /// - Parameters:
    ///   - depart: instant rendu par la premiere lecture.
    ///   - pasParLecture: temps ajoute apres chaque lecture, pour jouer une
    ///     execution qui consomme son budget.
    init(depart: Date, pasParLecture: TimeInterval = 0) {
        instant = depart
        self.pasParLecture = pasParLecture
    }

    /// Instant courant, puis avancee du pas.
    func maintenant() -> Date {
        verrou.withLock {
            let courant = instant
            instant = instant.addingTimeInterval(pasParLecture)

            return courant
        }
    }

    /// Avance l horloge a la main.
    func avancer(de duree: TimeInterval) {
        verrou.withLock { instant = instant.addingTimeInterval(duree) }
    }
}

/// Magasin de veille tenu en memoire.
actor MagasinDeVeilleEnMemoire: MagasinDeVeille {
    private var etat: EtatDeVeille
    private var series: [SerieSurveillee]
    private let echoueALaLecture: Bool

    /// Verifications enregistrees, dans l ordre.
    private(set) var verifications: [(serie: UUID, date: Date)] = []

    /// Nombre d ecritures d etat, qui compte les executions reellement lancees.
    private(set) var enregistrements = 0

    init(
        etat: EtatDeVeille = .neuf,
        series: [SerieSurveillee] = [],
        echoueALaLecture: Bool = false
    ) {
        self.etat = etat
        self.series = series
        self.echoueALaLecture = echoueALaLecture
    }

    /// Etat courant, tel que la derniere execution l a laisse.
    var etatCourant: EtatDeVeille {
        etat
    }

    func etatDeVeille() async throws -> EtatDeVeille {
        if echoueALaLecture {
            throw ErreurDeMagasinDeTest.indisponible
        }

        return etat
    }

    func enregistrer(_ etat: EtatDeVeille) async throws {
        self.etat = etat
        enregistrements += 1
    }

    func seriesSurveillees() async throws -> [SerieSurveillee] {
        series
    }

    func enregistrerLaVerification(de serie: UUID, chapitresConnus: Set<String>, le date: Date) async throws {
        verifications.append((serie: serie, date: date))

        series = series.map { surveillee in
            guard surveillee.id == serie else {
                return surveillee
            }

            return SerieSurveillee(
                id: surveillee.id,
                source: surveillee.source,
                identifiantDistant: surveillee.identifiantDistant,
                titre: surveillee.titre,
                chapitresConnus: surveillee.chapitresConnus.union(chapitresConnus),
                derniereVerification: date
            )
        }
    }
}

/// Panne du magasin, pour couvrir le refus de travailler sans etat.
enum ErreurDeMagasinDeTest: Error {
    case indisponible
}

/// Centre de notifications qui retient ce qu on lui remet.
actor CentreDeNotificationsDeTest: CentreDeNotifications {
    private let autorisation: Bool
    private let echoueALEmission: Bool

    /// Chaque appel d emission, avec ce qu il portait.
    private(set) var emissions: [[NotificationDeSerie]] = []

    init(autorisation: Bool = true, echoueALEmission: Bool = false) {
        self.autorisation = autorisation
        self.echoueALEmission = echoueALEmission
    }

    /// Toutes les notifications emises, tous appels confondus.
    var notificationsEmises: [NotificationDeSerie] {
        emissions.flatMap(\.self)
    }

    func autorisationAccordee() async -> Bool {
        autorisation
    }

    func publier(_ notifications: [NotificationDeSerie]) async throws {
        if echoueALEmission {
            throw ErreurDeMagasinDeTest.indisponible
        }

        emissions.append(notifications)
    }
}

/// Source qui annonce les chapitres decides par le test.
actor SourceDeChapitresDeTest: SourceProvider {
    nonisolated let id: SourceID
    nonisolated let nom: String
    nonisolated let capacites: SourceCapacites

    private let chapitresParSerie: [String: [ChapitreDistant]]
    private let echoue: Bool
    private let aLInterrogation: (@Sendable () -> Void)?

    private var interrogees: [String] = []

    init(
        id: SourceID = SourceID(),
        nom: String = "Serveur",
        capacites: SourceCapacites = [.veilleDeNouveautes],
        chapitresParSerie: [String: [ChapitreDistant]] = [:],
        echoue: Bool = false,
        aLInterrogation: (@Sendable () -> Void)? = nil
    ) {
        self.id = id
        self.nom = nom
        self.capacites = capacites
        self.chapitresParSerie = chapitresParSerie
        self.echoue = echoue
        self.aLInterrogation = aLInterrogation
    }

    /// Series interrogees, dans l ordre.
    var seriesInterrogees: [String] {
        interrogees
    }

    func verifierConnexion() async -> EtatConnexion {
        echoue ? .injoignable : .connecte
    }

    func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
        try exiger(.recherche)

        return PageResultats(elements: [], page: requete.page, ilResteDesPages: false)
    }

    func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        PageResultats(elements: [], page: page, ilResteDesPages: false)
    }

    func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
    }

    func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        interrogees.append(identifiant)
        aLInterrogation?()

        if echoue {
            throw ErreurDeSource.sourceInjoignable(source: nom)
        }

        return chapitresParSerie[identifiant] ?? []
    }

    func pages(pour chapitre: String) async throws -> [PageDistante] {
        []
    }

    func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        URLRequest(url: page.emplacement)
    }
}

extension ChapitreDistant {
    /// Chapitre minimal, dont seuls l identifiant et le rang comptent ici.
    static func deTest(_ identifiant: String, serie: String, ordre: Int) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: identifiant,
            identifiantManga: serie,
            numero: Double(ordre),
            ordre: ordre
        )
    }
}

//
// Montage commun aux deux suites de la veille.
//
// Il vit ici plutot que dans l une des deux, pour que le regroupement et les
// quotas partagent exactement le meme moteur. Deux montages voisins finiraient
// par diverger, et une suite mesurerait alors autre chose que l autre.
//

/// Instant de reference, un mercredi a midi.
let midiDeVeille = Date(timeIntervalSince1970: 1_700_000_000)

/// Calendrier fixe, pour que les journees ne dependent pas du fuseau de la
/// machine qui lance la suite.
func calendrierDeVeille() -> Calendar {
    var calendrier = Calendar(identifier: .gregorian)
    calendrier.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    return calendrier
}

/// Reglages ou l interrupteur de la section General est arme.
var veilleArmee: ReglagesDeLApplication {
    ReglagesDeLApplication([.notificationsDeNouveauxChapitres: .booleen(true)])
}

/// Serie surveillee, deja vue une fois sauf mention contraire.
func serieSurveillee(
    _ numero: Int,
    source: SourceID,
    connus: Set<String>,
    vueLe: Date? = midiDeVeille.addingTimeInterval(-24 * 3600)
) -> SerieSurveillee {
    SerieSurveillee(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(String(format: "%02d", numero))") ?? UUID(),
        source: source,
        identifiantDistant: "serie-\(numero)",
        titre: "Serie \(numero)",
        chapitresConnus: connus,
        derniereVerification: vueLe
    )
}

/// Monte un moteur autour des doublures, avec une seule source.
func moteurDeVeille(
    source: SourceDeChapitresDeTest,
    magasin: MagasinDeVeilleEnMemoire,
    centre: CentreDeNotificationsDeTest,
    horloge: HorlogeDeTest,
    incognito: RegistreDIncognito = RegistreDIncognito(),
    quota: QuotaDeVeille = .parDefaut,
    enLigne: Bool = true
) async -> MoteurDeVeilleDeChapitres {
    let registre = RegistreDeSources()
    await registre.inscrire(source)

    return moteurDeVeille(
        registre: registre,
        magasin: magasin,
        centre: centre,
        horloge: horloge,
        incognito: incognito,
        quota: quota,
        enLigne: enLigne
    )
}

/// Monte un moteur autour d un registre deja peuple.
func moteurDeVeille(
    registre: RegistreDeSources,
    magasin: MagasinDeVeilleEnMemoire,
    centre: CentreDeNotificationsDeTest,
    horloge: HorlogeDeTest,
    incognito: RegistreDIncognito = RegistreDIncognito(),
    quota: QuotaDeVeille = .parDefaut,
    enLigne: Bool = true
) -> MoteurDeVeilleDeChapitres {
    MoteurDeVeilleDeChapitres(
        registre: registre,
        magasin: magasin,
        centre: centre,
        quota: quota,
        calendrier: calendrierDeVeille(),
        contexte: {
            ContexteDeVeille(
                reglages: veilleArmee,
                session: incognito.sessionCourante,
                enLigne: enLigne
            )
        },
        horloge: horloge.maintenant
    )
}
