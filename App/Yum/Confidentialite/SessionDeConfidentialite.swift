import Core
import DesignSystem
import Foundation
import Observation

//
// Mode incognito et verrouillage de l app dans l application, section 11 du
// cahier de developpement.
//
// Un seul objet porte les deux, parce qu ils repondent a la meme question, ce
// que l application laisse voir et laisse derriere elle. Les ecrans le lisent,
// ils ne decident jamais eux memes.
//
// Le registre d incognito n est pas une copie de l etat, c est l etat lui meme.
// Il est donne aux magasins a l ouverture de la base, et c est par lui que le
// mode incognito atteint la couche qui ecrit : allumer le mode ici suspend les
// ecritures la bas sans qu aucun ecran ait a s en occuper.
//
// Le verrou, lui, est une fonction du temps et non un minuteur. Le reveil pose
// au passage en arriere plan n est qu un confort : meme s il ne sonne jamais,
// parce que le systeme a gele le processus, le retour au premier plan compare
// deux dates et trouve le verrou ferme.
//

/// Mode incognito et verrouillage, partages par les ecrans.
@MainActor
@Observable
final class SessionDeConfidentialite {
    /// Session incognito, telle que la banniere et les magasins la voient.
    private(set) var session: SessionIncognito = .inactive

    /// Etat du verrou de l application.
    private(set) var verrou = VerrouillageDeLApp()

    /// Ce que l ecran de verrouillage affiche.
    private(set) var ecranDeVerrouillage: EtatDeLEcranDeVerrouillage = .attente

    /// Moyens d authentification que l appareil accepte, vides tant que la
    /// question n a pas ete posee au systeme.
    private(set) var moyensDeDeverrouillage: Set<MoyenDeDeverrouillage> = []

    /// Registre partage avec les magasins qui ecrivent.
    let registre: RegistreDIncognito

    private let authentification: any AuthentificationLocale
    private var reveil: Task<Void, Never>?

    init(
        registre: RegistreDIncognito,
        authentification: any AuthentificationLocale = AuthentificationParLeSysteme()
    ) {
        self.registre = registre
        self.authentification = authentification
    }

    // MARK: Mode incognito

    /// Banniere a poser sur l application, nulle hors session.
    var banniere: BanniereDIncognito? {
        TexteDeLaBanniereDIncognito.banniere(pour: session, libelles: .duCatalogue)
    }

    /// Allume ou eteint le mode incognito.
    ///
    /// - Parameters:
    ///   - actif: etat demande par la ligne de reglages.
    ///   - date: instant du geste.
    /// - Returns: vrai quand le mode a effectivement change d etat.
    @discardableResult
    func definirLIncognito(
        _ actif: Bool,
        le date: Date = Date()
    ) -> Bool {
        guard actif else {
            registre.arreter()
            session = registre.sessionCourante

            return true
        }

        registre.demarrer(le: date)
        session = registre.sessionCourante

        return true
    }

    // MARK: Verrouillage

    /// Interroge le systeme sur les moyens d authentification disponibles.
    func lireLesMoyensDeDeverrouillage() async {
        moyensDeDeverrouillage = await authentification.moyensDisponibles()
    }

    /// Arme ou desarme le verrouillage de l app.
    ///
    /// Le reglage refuse de s armer sur un appareil qui n a ni biometrie ni
    /// code. L ecran de verrouillage y deviendrait une porte sans clef, et la
    /// bibliotheque serait perdue pour son proprietaire.
    ///
    /// - Returns: vrai quand le reglage a pris l etat demande.
    @discardableResult
    func definirLeVerrouillage(_ arme: Bool) async -> Bool {
        guard arme else {
            verrou.desarmer()
            annulerLeReveil()

            return true
        }

        await lireLesMoyensDeDeverrouillage()

        guard PolitiqueDeDeverrouillage.peutSArmer(avec: moyensDeDeverrouillage) else {
            ecranDeVerrouillage = .echec(.aucunMoyenDisponible)

            return false
        }

        verrou.armer()

        return true
    }

    /// L application passe en arriere plan.
    ///
    /// Le reveil est pose sur l echeance annoncee par `Core`. Il ne decide de
    /// rien : il ne fait qu avancer le moment ou l etat se met a jour, pour que
    /// l application soit deja fermee quand elle revient a l ecran.
    func passerEnArrierePlan(le date: Date = Date()) {
        verrou.passerEnArrierePlan(le: date)
        poserLeReveil()
    }

    /// L application revient au premier plan.
    func revenirAuPremierPlan(le date: Date = Date()) {
        annulerLeReveil()
        verrou.revenirAuPremierPlan(le: date)

        if verrou.etat.demandeUneAuthentification {
            ecranDeVerrouillage = .attente
        }
    }

    /// Demande l authentification et rouvre l application si elle aboutit.
    func deverrouiller() async {
        do {
            _ = try await authentification.deverrouiller(raison: Chaines.Verrouillage.raison)
            verrou.deverrouiller()
            ecranDeVerrouillage = .attente
        } catch let erreur as ErreurDeVerrouillage {
            ecranDeVerrouillage = .echec(erreur)
        } catch {
            ecranDeVerrouillage = .echec(.echecDeLAuthentification)
        }
    }

    // MARK: Reveil

    private func poserLeReveil() {
        annulerLeReveil()

        guard let echeance = verrou.dateDeVerrouillagePrevue else {
            return
        }

        let attente = max(0, echeance.timeIntervalSinceNow)

        reveil = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(attente * 1_000_000_000))

            guard Task.isCancelled == false else {
                return
            }

            self?.verrou.verrouillerSiLeDelaiEstEcoule(a: Date())
        }
    }

    private func annulerLeReveil() {
        reveil?.cancel()
        reveil = nil
    }
}
