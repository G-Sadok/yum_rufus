import Core
import Foundation

//
// MoteurDeTelechargement
//
// Ce qui fait tourner la file de la section 4.11 de DESIGN-SPEC.md.
//
// Le moteur ne garde aucun etat. Tout ce qui compte, l ordre de passage, la
// place occupee, la page ou reprendre, vit dans le journal, donc en base. C est
// une contrainte de la fonctionnalite et non un gout d architecture : un etat
// garde en memoire ne survit pas a la fermeture de l application, et un
// telechargement interrompu doit reprendre ou il s est arrete.
//
// Le moteur n est donc pas un acteur. Un acteur serialiserait ses propres taches
// filles, et la limite de telechargements simultanes vaudrait un quoi qu on
// regle. Les places sont comptees par le planificateur, sur l etat de la file,
// et le groupe de taches ne demarre jamais plus que ce que le planificateur
// accorde.
//

/// Fait avancer la file de telechargement.
public struct MoteurDeTelechargement: Sendable {
    private let journal: any JournalDeTelechargements
    private let depot: any DepotDeChapitres
    private let pages: any FournisseurDePagesATelecharger
    private let transport: any TransportHttp

    /// Construit le moteur sur ses quatre dependances.
    ///
    /// - Parameters:
    ///   - journal: la file persistee.
    ///   - depot: ou les pages sont posees.
    ///   - pages: ce qui rapporte les requetes d un chapitre.
    ///   - transport: ce qui porte une requete jusqu au serveur.
    public init(
        journal: any JournalDeTelechargements,
        depot: any DepotDeChapitres,
        pages: any FournisseurDePagesATelecharger,
        transport: any TransportHttp
    ) {
        self.journal = journal
        self.depot = depot
        self.pages = pages
        self.transport = transport
    }

    // MARK: Tour de file

    /// Fait tourner la file jusqu a ce qu il n y ait plus rien a demarrer.
    ///
    /// La decision est recalculee apres chaque tache terminee et non une fois
    /// pour toutes. C est ce qui permet a une limite baissee pendant le
    /// telechargement, ou a une bascule du Wi-Fi vers le reseau cellulaire, de
    /// prendre effet sans attendre la fin de la file.
    ///
    /// - Parameter reseau: ce qui dit le reseau disponible, relu a chaque tour
    ///   et non fige au premier.
    public func vider(reseau: @escaping @Sendable () -> EtatDuReseau) async {
        await withTaskGroup(of: Void.self) { groupe in
            var enVol = 0

            while true {
                let decision = await prochaineDecision(reseau: reseau())

                for identifiant in decision.aRemettreEnAttente {
                    try? await journal.remettreEnAttente(identifiant)
                }

                let demarrables = await demarrer(decision.aDemarrer)

                for tache in demarrables {
                    groupe.addTask { await traiter(tache) }
                    enVol += 1
                }

                // Rien en vol et rien de nouveau : la file est vide, ou le
                // reseau la bloque, ou tout ce qui reste attend un geste de
                // l utilisateur.
                guard enVol > 0 else {
                    return
                }

                // Attendre qu une tache finisse avant de recalculer. C est ce
                // qui garde le nombre de taches en vol sous la limite : une
                // place ne se rend qu une fois liberee.
                await groupe.next()
                enVol -= 1
            }
        }
    }

    /// Un seul tour : ce que le planificateur decide, applique, sans attendre.
    ///
    /// Sert a l ecran de suivi, qui redonne la main a l utilisateur des que les
    /// taches sont lancees.
    public func unTour(reseau: EtatDuReseau) async {
        let decision = await prochaineDecision(reseau: reseau)

        for identifiant in decision.aRemettreEnAttente {
            try? await journal.remettreEnAttente(identifiant)
        }

        let demarrables = await demarrer(decision.aDemarrer)

        await withTaskGroup(of: Void.self) { groupe in
            for tache in demarrables {
                groupe.addTask { await traiter(tache) }
            }
        }
    }

    private func prochaineDecision(reseau: EtatDuReseau) async -> DecisionDeFile {
        guard
            let taches = try? await journal.taches(),
            let reglages = try? await journal.reglages()
        else {
            return DecisionDeFile()
        }

        return PlanificateurDeTelechargements.decision(
            taches: taches,
            reglages: reglages,
            reseau: reseau
        )
    }

    /// Marque les taches accordees comme demarrees, et rend celles qui l ont ete.
    ///
    /// Le marquage precede le lancement et non l inverse. Sans lui, deux tours
    /// rapproches verraient la meme tache encore en attente et la lanceraient
    /// deux fois, ce qui ferait ecrire le meme dossier par deux taches.
    private func demarrer(_ identifiants: [UUID]) async -> [TelechargementAffiche] {
        guard identifiants.isEmpty == false, let taches = try? await journal.taches() else {
            return []
        }

        let parIdentifiant = Dictionary(taches.map { ($0.id, $0) }, uniquingKeysWith: { premiere, _ in premiere })

        var demarrees: [TelechargementAffiche] = []

        for identifiant in identifiants {
            guard let tache = parIdentifiant[identifiant], tache.attendSonTour else {
                continue
            }

            do {
                try await journal.demarrer(identifiant)
                demarrees.append(tache)
            } catch {
                continue
            }
        }

        return demarrees
    }

    // MARK: Une tache

    /// Telecharge un chapitre entier, de sa page de reprise a la derniere.
    func traiter(_ tache: TelechargementAffiche) async {
        do {
            try await telecharger(tache)
            try await journal.terminer(tache.id)
        } catch is CancellationError {
            // Une annulation n est pas un echec. La tache retourne dans la file
            // et repartira de sa page de reprise au tour suivant.
            try? await journal.remettreEnAttente(tache.id)
        } catch {
            try? await journal.echouer(tache.id, message: Self.message(de: error))
        }
    }

    private func telecharger(_ tache: TelechargementAffiche) async throws {
        let requetes = try await pages.requetesDePages(duChapitre: tache.chapitreId)

        guard requetes.isEmpty == false else {
            throw ErreurDeTelechargement.chapitreSansPage(identifiant: tache.chapitreId)
        }

        try await journal.noterLaLongueur(
            de: tache.id,
            nombreDePages: requetes.count,
            octetsTotal: tache.octetsTotal
        )

        let inventaire = try await depot.inventaire(du: tache.chapitreId)

        guard
            let depart = RepriseDeTelechargement.point(
                depuis: inventaire,
                nombreDePages: requetes.count
            )
        else {
            return
        }

        var octetsRecus = tache.octetsRecus

        for index in depart.pageIndex..<requetes.count {
            try Task.checkCancellation()

            let depuis = index == depart.pageIndex ? depart.octetsDejaRecus : 0
            let ecrits = try await telechargerLaPage(
                requetes[index],
                index: index,
                chapitre: tache.chapitreId,
                depuis: depuis
            )

            octetsRecus += ecrits

            try await journal.noterUnePageScellee(
                de: tache.id,
                pagesTerminees: index + 1,
                octetsRecus: octetsRecus
            )
        }
    }

    /// Telecharge une page, en reprenant a l octet demande quand il y en a un.
    ///
    /// - Returns: le nombre d octets ajoutes par cet appel, fragment deja ecrit
    ///   exclu. C est ce qui permet au cumul de la tache de rester juste apres
    ///   une reprise, sans compter deux fois les octets d avant la coupure.
    private func telechargerLaPage(
        _ requete: URLRequest,
        index: Int,
        chapitre: UUID,
        depuis: Int
    ) async throws -> Int {
        let reponse = try await executer(requete, depuis: depuis)

        let accueil = RepriseDeTelechargement.accueil(
            code: reponse.code,
            contentRange: reponse.entete(RepriseDeTelechargement.enteteDeReponse),
            attendu: depuis
        )

        switch accueil {
        case .tranche:
            try await depot.ecrire(reponse.corps, page: index, du: chapitre, enPoursuivant: true)

        case .fichierEntier:
            try await depot.ecrire(reponse.corps, page: index, du: chapitre, enPoursuivant: false)

        case .refusee:
            // Le serveur refuse la tranche : le fichier a change de taille
            // depuis la coupure. La page repart de zero, ce qui est une seconde
            // requete et non un echec.
            let entiere = try await executer(requete, depuis: 0)
            try await depot.ecrire(entiere.corps, page: index, du: chapitre, enPoursuivant: false)
        }

        let poids = try await depot.sceller(page: index, du: chapitre)

        return max(0, poids - depuis)
    }

    /// Envoie la requete, avec la demande de tranche quand il y en a une.
    private func executer(_ requete: URLRequest, depuis: Int) async throws -> ReponseHttp {
        var partante = requete

        if let plage = RepriseDeTelechargement.enteteDePlage(a: depuis) {
            partante.setValue(plage, forHTTPHeaderField: RepriseDeTelechargement.enteteDeDemande)
        }

        let reponse = try await transport.executer(partante)

        if let erreur = Self.erreur(de: reponse) {
            throw erreur
        }

        return reponse
    }

    /// Erreur portee par le code de statut, nulle quand la reponse est bonne.
    ///
    /// Le refus de tranche n en est pas une a ce niveau : il est traite par
    /// l accueil de la reprise, qui fait repartir la page de zero. Tout autre
    /// code d erreur en est une.
    static func erreur(de reponse: ReponseHttp) -> ErreurReseau? {
        guard reponse.code != RepriseDeTelechargement.codeTrancheInvalide else {
            return nil
        }

        return ErreurReseau.depuis(codeHttp: reponse.code, nouvelEssaiApres: nil)
    }

    /// Message destine a l utilisateur, qui nomme la cause.
    ///
    /// La section 4.10 exige qu une erreur nomme sa cause reelle. Les erreurs
    /// reseau portent deja leur traduction, les autres passent par la
    /// description du domaine.
    static func message(de erreur: any Error) -> String {
        if let reseau = erreur as? ErreurReseau {
            return reseau.messageUtilisateur
        }

        if let source = erreur as? ErreurDeSource {
            return source.messageUtilisateur
        }

        return String(describing: erreur)
    }
}
