import Core
import Foundation

//
// TelechargeurICloud
//
// Le rapatriement a la demande d un fichier d iCloud Drive, et la publication
// de son avancement.
//
// C est un acteur pour la raison qui compte ici : deux ouvertures du meme
// chapitre ne doivent pas donner deux telechargements. Le cas arrive tout seul,
// la fiche de serie precharge la premiere page pendant que le lecteur ouvre le
// chapitre. Sans serialisation, le systeme recoit deux demandes, publie deux
// progressions concurrentes sur la meme ligne, et la barre recule.
//
// L avancement se suit par sondage et non par notification. Le systeme ne
// previent de rien sans `NSMetadataQuery`, qui demande une boucle d execution
// et un conteneur d ubiquite declare par l application, deux choses qu un
// paquet metier n a pas. Le sondage a cadence fixe coute une lecture de valeurs
// de ressource toutes les demi secondes par fichier en cours, ce qui est sans
// commune mesure avec le telechargement lui meme.
//
// Le telechargement qui n avance plus est traite comme une panne et non comme
// une attente. Un fichier dont le nuage ne rend plus un octet apres trente
// secondes ne se debloquera pas tout seul, et laisser tourner la boucle
// laisserait la barre de progression figee sans jamais rien dire.
//

/// Rapatrie les fichiers d un dossier iCloud Drive et publie leur avancement.
public actor TelechargeurICloud {
    /// Intervalle entre deux sondages de l etat d un telechargement.
    public static let cadenceParDefaut = Duration.milliseconds(500)

    /// Nombre de sondages sans le moindre octet avant d abandonner.
    public static let sondagesSansProgresParDefaut = 60

    /// Nom de la source, repris dans les erreurs.
    public let nom: String

    private let depot: any DepotICloud
    private let cadence: Duration
    private let sondagesSansProgres: Int

    private var enCours: [String: Task<Bool, any Error>] = [:]
    private var dernieres: [String: ProgressionDeTelechargement] = [:]
    private var abonnes: [UUID: AsyncStream<ProgressionDeTelechargement>.Continuation] = [:]

    public init(
        nom: String,
        depot: any DepotICloud,
        cadence: Duration = TelechargeurICloud.cadenceParDefaut,
        sondagesSansProgres: Int = TelechargeurICloud.sondagesSansProgresParDefaut
    ) {
        self.nom = nom
        self.depot = depot
        self.cadence = cadence
        self.sondagesSansProgres = max(1, sondagesSansProgres)
    }

    // MARK: Progression

    /// Ouvre un flux des progressions publiees par ce telechargeur.
    ///
    /// Le flux ne se termine jamais de lui meme : il sert les telechargements
    /// les uns apres les autres, et c est l abonne qui decide quand s arreter.
    /// Chaque abonne recoit toutes les progressions, a lui de retenir celles
    /// qui portent l identifiant qui l interesse.
    public func progressions() -> AsyncStream<ProgressionDeTelechargement> {
        let cle = UUID()
        let (flux, suite) = AsyncStream<ProgressionDeTelechargement>.makeStream()

        abonnes[cle] = suite
        suite.onTermination = { [weak self] _ in
            Task { await self?.oublier(cle) }
        }

        return flux
    }

    /// Derniere progression connue pour cet identifiant.
    ///
    /// Sert a l ecran qui s ouvre alors qu un telechargement a deja commence,
    /// et qui ne peut pas recevoir les progressions deja passees.
    public func progression(de identifiant: String) -> ProgressionDeTelechargement? {
        dernieres[identifiant]
    }

    // MARK: Rapatriement

    /// S assure que le fichier est sur l appareil, en le rapatriant au besoin.
    ///
    /// - Returns: vrai quand un telechargement a ete necessaire.
    /// - Throws: `ErreurDeSource`, dans le cas nomme qui correspond a ce qui
    ///   s est passe. Un telechargement qui n avance plus y arrive sous
    ///   `reseau(.delaiDepasse)`, et relancer le meme appel repart d une
    ///   nouvelle demande.
    @discardableResult
    public func assurerLaPresence(de visible: URL, identifiant: String) async throws -> Bool {
        // La cle est le chemin sous le nom visible, et non celui du disque : le
        // second change quand le substitut cede la place au vrai fichier, et
        // deux demandes sur le meme chapitre ne se reconnaitraient plus.
        let cle = EmplacementICloud.cheminNormalise(visible)

        if let deja = enCours[cle] {
            return try await resultat(de: deja)
        }

        // La tache est posee dans la table avant la moindre suspension. Une
        // seconde demande arrivee pendant la verification de l etat trouve
        // alors la premiere et l attend, au lieu d en lancer une autre.
        let tache = Task { [self] in
            try await verifierPuisRapatrier(visible, identifiant: identifiant)
        }

        enCours[cle] = tache

        defer { enCours[cle] = nil }

        return try await resultat(de: tache)
    }

    /// Annule les telechargements en cours et oublie ce qui a ete publie.
    public func liberer() {
        for tache in enCours.values {
            tache.cancel()
        }

        enCours.removeAll()
        dernieres.removeAll()

        for suite in abonnes.values {
            suite.finish()
        }

        abonnes.removeAll()
    }

    // MARK: Deroulement

    private func verifierPuisRapatrier(_ visible: URL, identifiant: String) async throws -> Bool {
        let depart = try await etatCourant(de: visible)

        guard depart.estLocal == false else { return false }

        try await rapatrier(visible, identifiant: identifiant, depart: depart)

        return true
    }

    private func rapatrier(_ visible: URL, identifiant: String, depart: EtatDeFichierICloud) async throws {
        // La premiere progression part de l etat observe avant la demande, pour
        // que la barre apparaisse a zero au moment ou l utilisateur ouvre le
        // chapitre et non au premier octet recu.
        publier(depart, identifiant: identifiant)

        try await depot.demanderLeTelechargement(de: EmplacementICloud.surLeDisque(visible))

        var etat = depart
        var octetsPrecedents = depart.octetsPresents
        var sondagesSterils = 0

        while etat.estLocal == false {
            try Task.checkCancellation()
            try await Task.sleep(for: cadence)

            etat = try await etatCourant(de: visible)

            if etat.octetsPresents > octetsPrecedents {
                octetsPrecedents = etat.octetsPresents
                sondagesSterils = 0
            } else {
                sondagesSterils += 1

                guard sondagesSterils < sondagesSansProgres else {
                    throw ErreurDeSource.reseau(.delaiDepasse, source: nom)
                }
            }

            publier(etat, identifiant: identifiant)
        }
    }

    /// Etat du fichier, sous le nom qu il porte sur le disque en ce moment.
    private func etatCourant(de visible: URL) async throws -> EtatDeFichierICloud {
        try await depot.etat(de: EmplacementICloud.surLeDisque(visible))
    }

    private func publier(_ etat: EtatDeFichierICloud, identifiant: String) {
        let attendus = max(etat.octetsAttendus, etat.octetsPresents)
        let progression = ProgressionDeTelechargement(
            identifiant: identifiant,
            octetsRecus: etat.estLocal ? attendus : etat.octetsPresents,
            octetsAttendus: attendus,
            estTermine: etat.estLocal
        )

        dernieres[identifiant] = progression

        for suite in abonnes.values {
            suite.yield(progression)
        }
    }

    private func oublier(_ abonne: UUID) {
        abonnes[abonne] = nil
    }

    /// Attend une tache de rapatriement et traduit ce qu elle leve.
    private func resultat(de tache: Task<Bool, any Error>) async throws -> Bool {
        do {
            return try await tache.value
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }
}
