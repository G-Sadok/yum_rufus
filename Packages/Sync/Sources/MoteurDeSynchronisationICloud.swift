import Core
import Foundation

//
// MoteurDeSynchronisationICloud
//
// La couche explicite au dessus de CloudKit annoncee par la section 2.2 du
// cahier de developpement : ce qui decide de ce qui part, quand cela part, ce
// qui arrive, et ce que l indicateur montre pendant ce temps.
//
// Le moteur ne dort jamais et ne cree aucune tache de fond. Il expose `tic`, et
// c est l appelant qui decide de la cadence reelle : une horloge de
// l application en production, une horloge simulee dans la suite de tests. Sans
// cette separation, verifier le budget de propagation de trente secondes
// demanderait d attendre trente secondes a chaque execution, et le premier
// developpeur presse desactiverait le test.
//
// Trois invariants tiennent la fonctionnalite, et chacun a coute cher ailleurs.
//
// 1. Rien ne sort du journal sans accuse du distant. Un envoi qui echoue laisse
//    le journal intact, et la ligne repart au tic suivant. C est tout le mode
//    hors ligne, et c est aussi ce qui sauve une coupure au milieu d un envoi.
// 2. Une ligne locale qui perd un conflit est retiree du journal en meme temps
//    que la version distante est appliquee. La garder ferait repartir la
//    version perimee au tic suivant, qui gagnerait alors chez les autres
//    appareils : le conflit se resoudrait dans un sens ici et dans l autre
//    la bas, indefiniment.
// 3. Le jeton de reprise n avance que lorsque le lot a ete applique. Un jeton
//    avance trop tot fait sauter un lot pour de bon : le distant ne le
//    renverra jamais.
//

/// Couche de synchronisation iCloud, avec journal de changements explicite.
public actor MoteurDeSynchronisationICloud {
    private let entrepot: any EntrepotDeSynchronisation
    private let magasin: any MagasinDuJournalDeChangements
    private let applicateur: any ApplicateurDeChangements
    private let contexte: @Sendable () -> ContexteICloud
    private let cadence: CadenceDeSynchronisation
    private let appareil: String

    private var journal = JournalDeChangements.vide
    private var jeton: Data?
    private var dernierEnvoi: Date?
    private var dernierSondage: Date?
    private var etat = EtatDeSynchronisationICloud.inactive
    private var journalCharge = false

    /// Nombre maximal de lots enchaines dans un seul tirage.
    ///
    /// CloudKit pagine une zone chargee, et une reprise apres une longue
    /// absence peut en compter beaucoup. La borne evite qu un tic reste dans la
    /// boucle pendant des minutes : ce qui reste arrive au tic suivant, le
    /// jeton ayant deja avance.
    private static let lotsParTirage = 20

    /// Construit le moteur.
    ///
    /// - Parameters:
    ///   - entrepot: le distant, CloudKit en production.
    ///   - magasin: la ou le journal survit a la fermeture de l application.
    ///   - applicateur: ce qui transforme un changement recu en etat local.
    ///   - appareil: identifiant stable de cet appareil, qui departage les
    ///     conflits a horodatage egal. Il doit etre le meme d une execution a
    ///     l autre, sans quoi la deuxieme ligne de la regle de conflit cesse
    ///     d etre stable.
    ///   - cadence: delais d envoi et de sondage.
    ///   - contexte: reglages, abonnement, session et reseau, relus a chaque
    ///     decision. Une valeur figee a la construction ferait continuer la
    ///     synchronisation apres l arret de l interrupteur.
    public init(
        entrepot: any EntrepotDeSynchronisation,
        magasin: any MagasinDuJournalDeChangements,
        applicateur: any ApplicateurDeChangements,
        appareil: String,
        cadence: CadenceDeSynchronisation = .parDefaut,
        contexte: @escaping @Sendable () -> ContexteICloud
    ) {
        self.entrepot = entrepot
        self.magasin = magasin
        self.applicateur = applicateur
        self.appareil = appareil
        self.cadence = cadence
        self.contexte = contexte
    }

    // MARK: Etat

    /// Ce que l indicateur de la section iCloud doit montrer.
    public var etatCourant: EtatDeSynchronisationICloud {
        etat
    }

    /// Instant du dernier envoi accepte, pour la ligne `Dernier envoi`.
    public var dernierEnvoiReussi: Date? {
        dernierEnvoi
    }

    /// Nombre de changements produits ici et pas encore accuses.
    public var changementsEnAttente: Int {
        journal.nombreEnAttente
    }

    /// Relit le journal persiste et le point de reprise.
    ///
    /// A appeler au lancement, avant le premier tic. Ce qui a ete produit hors
    /// ligne avant la derniere extinction revient ici, et nulle part ailleurs.
    public func demarrer() async throws {
        try await chargerLeJournal()
        rafraichirLEtat()
    }

    // MARK: Production locale

    /// Consigne une progression de lecture produite sur cet appareil.
    ///
    /// - Returns: ce que la regle a decide, que l appelant peut afficher.
    @discardableResult
    public func enregistrer(_ progression: ProgressionSynchronisee) async throws
        -> DecisionDeSynchronisationICloud {
        try await enregistrer(progression.changement(depuis: appareil), pour: .progressionDeChapitre)
    }

    /// Consigne un changement produit sur cet appareil.
    ///
    /// Le changement n est pas envoye ici. Il entre au journal, et le prochain
    /// tic decide. Envoyer immediatement ferait un appel reseau par tourne de
    /// page, la position partant toutes les deux secondes pendant la lecture.
    @discardableResult
    public func enregistrer(
        _ changement: ChangementSynchronise,
        pour entite: EntiteSynchronisee
    ) async throws -> DecisionDeSynchronisationICloud {
        try await chargerLeJournal()

        let decision = SynchronisationICloud.decision(pour: entite, selon: contexte())

        guard decision.entreAuJournal else {
            rafraichirLEtat()
            return decision
        }

        journal.consigner(changement)
        try await magasin.consigner([changement])
        rafraichirLEtat()

        return decision
    }

    // MARK: Cycle

    /// Fait avancer la synchronisation a cet instant.
    ///
    /// L appel ne fait rien tant qu aucune echeance n est atteinte, il peut
    /// donc etre appele aussi souvent que l appelant le souhaite.
    public func tic(_ maintenant: Date) async {
        guard SynchronisationICloud.estActive(selon: contexte()) else {
            etat = .inactive
            return
        }

        do {
            try await chargerLeJournal()
        } catch {
            etat = .enEchec(changements: journal.nombreEnAttente)
            return
        }

        guard contexte().enLigne else {
            etat = .horsLigne(changements: journal.nombreEnAttente)
            return
        }

        if doitPousser(a: maintenant) {
            await pousser(maintenant)
        }

        if doitSonder(a: maintenant) {
            await tirer(maintenant)
        }
    }

    /// Pousse et tire sans attendre les echeances.
    ///
    /// C est ce que declenche une notification poussee par CloudKit, et le
    /// geste `Synchroniser maintenant` de l ecran des reglages. C est aussi le
    /// chemin normal en production : le sondage n est que le filet qui garantit
    /// le budget quand aucune notification n arrive.
    public func synchroniserMaintenant(_ maintenant: Date) async {
        guard SynchronisationICloud.estActive(selon: contexte()) else {
            etat = .inactive
            return
        }

        do {
            try await chargerLeJournal()
        } catch {
            etat = .enEchec(changements: journal.nombreEnAttente)
            return
        }

        guard contexte().enLigne else {
            etat = .horsLigne(changements: journal.nombreEnAttente)
            return
        }

        if journal.estVide == false {
            await pousser(maintenant)
        }

        await tirer(maintenant)
    }

    // MARK: Envoi

    /// Vrai quand le journal a mure assez longtemps pour partir.
    private func doitPousser(a maintenant: Date) -> Bool {
        guard let plusAncien = journal.plusAncienChangement else {
            return false
        }

        return maintenant.timeIntervalSince(plusAncien) >= cadence.delaiDeRegroupement
    }

    /// Envoie le journal et ne le vide qu au retour de l accuse.
    private func pousser(_ maintenant: Date) async {
        let partants = journal.changements

        guard partants.isEmpty == false else {
            return
        }

        etat = .echangeEnCours

        do {
            try await entrepot.pousser(partants)
            journal.retirer(partants)
            try await magasin.retirer(partants)
            dernierEnvoi = maintenant
            try await magasin.definirLeDernierEnvoi(maintenant)
            rafraichirLEtat()
        } catch ErreurDEntrepot.reseauIndisponible {
            etat = .horsLigne(changements: journal.nombreEnAttente)
        } catch {
            etat = .enEchec(changements: journal.nombreEnAttente)
        }
    }

    // MARK: Reception

    /// Vrai quand l echeance de sondage est atteinte.
    private func doitSonder(a maintenant: Date) -> Bool {
        guard let dernierSondage else {
            return true
        }

        return maintenant.timeIntervalSince(dernierSondage) >= cadence.intervalleDeSondage
    }

    /// Demande au distant ce qui a change et l applique.
    private func tirer(_ maintenant: Date) async {
        etat = .echangeEnCours

        do {
            var lots = 0

            while lots < Self.lotsParTirage {
                let lot = try await lotSuivant()
                try await appliquer(lot.changements)

                jeton = lot.jeton
                try await magasin.definirLeJetonDistant(lot.jeton)
                lots += 1

                guard lot.suite else {
                    break
                }
            }

            dernierSondage = maintenant
            rafraichirLEtat()
        } catch ErreurDEntrepot.reseauIndisponible {
            etat = .horsLigne(changements: journal.nombreEnAttente)
        } catch {
            etat = .enEchec(changements: journal.nombreEnAttente)
        }
    }

    /// Lot suivant, en repartant de zero quand le distant refuse le jeton.
    ///
    /// Un jeton perime n est pas une panne. CloudKit l invalide apres une
    /// absence prolongee, et la reponse attendue est de redemander la zone
    /// entiere. Les lignes deja connues seront simplement reappliquees, sans
    /// effet, la resolution de conflit ecartant tout ce qui n est pas plus
    /// recent que l etat local.
    private func lotSuivant() async throws -> LotDistant {
        do {
            return try await entrepot.tirer(depuis: jeton)
        } catch ErreurDEntrepot.jetonPerime {
            jeton = nil
            try await magasin.definirLeJetonDistant(nil)

            return try await entrepot.tirer(depuis: nil)
        }
    }

    /// Applique un lot recu, apres arbitrage avec ce qui attend de partir.
    private func appliquer(_ recus: [ChangementSynchronise]) async throws {
        guard recus.isEmpty == false else {
            return
        }

        var retenus: [ChangementSynchronise] = []
        var perimes: [ChangementSynchronise] = []

        for recu in recus {
            guard let enAttente = journal.changement(pour: recu.cle) else {
                retenus.append(recu)
                continue
            }

            // La ligne locale attend encore son tour. Si elle gagne, le lot
            // recu est ignore et elle partira ; si elle perd, elle doit
            // disparaitre du journal, faute de quoi elle repartirait et
            // ecraserait chez les autres la version qui vient de gagner ici.
            guard ResolutionDeConflit.gagnant(enAttente, recu).changement == recu else {
                continue
            }

            perimes.append(enAttente)
            retenus.append(recu)
        }

        if perimes.isEmpty == false {
            journal.retirer(perimes)
            try await magasin.retirer(perimes)
        }

        try await applicateur.appliquer(retenus)
    }

    // MARK: Journal

    /// Relit le journal persiste, une seule fois par execution.
    private func chargerLeJournal() async throws {
        guard journalCharge == false else {
            return
        }

        journal = try await magasin.journal()
        jeton = try await magasin.jetonDistant()
        dernierEnvoi = try await magasin.dernierEnvoi()
        journalCharge = true
    }

    /// Remet l indicateur en accord avec ce qui reste a faire.
    private func rafraichirLEtat() {
        guard SynchronisationICloud.estActive(selon: contexte()) else {
            etat = .inactive
            return
        }

        guard contexte().enLigne else {
            etat = .horsLigne(changements: journal.nombreEnAttente)
            return
        }

        etat = journal.estVide ? .aJour(le: dernierEnvoi) : .enAttente(changements: journal.nombreEnAttente)
    }
}
