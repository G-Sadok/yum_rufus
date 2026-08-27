import Core
import Foundation
@testable import Sources

//
// Les doubles du moteur de telechargement.
//
// Trois pieces, une par dependance du moteur : la file, le depot, et le serveur
// qui sert les pages. Aucune ne simule quoi que ce soit d approximatif. La file
// tient les memes invariants que le magasin, le depot distingue vraiment un
// fragment d une page scellee, et le serveur honore vraiment l entete `Range`.
//
// Le serveur retient aussi ce qu on lui a demande, et compte les requetes menees
// de front. Sans ce compte, la limite de telechargements simultanes ne se
// verifierait qu au niveau du planificateur, et rien ne dirait que le moteur
// applique bien ce que le planificateur decide.
//

/// File de telechargement en memoire, avec les memes regles que le magasin.
actor FileDeTest: JournalDeTelechargements {
    private var file: [UUID: TelechargementAffiche] = [:]
    private var ordre: [UUID] = []
    private var reglagesCourants: ReglagesDeTelechargement

    /// Nombre maximal de taches vues en cours au meme instant.
    private(set) var pointeDeTachesEnCours = 0

    init(reglages: ReglagesDeTelechargement = ReglagesDeTelechargement()) {
        reglagesCourants = reglages
    }

    // MARK: Preparation

    /// Ajoute une tache a la file.
    @discardableResult
    func ajouter(
        chapitre: UUID,
        titre: String = "Berserk",
        numero: Double = 1,
        priorite: PrioriteDeTelechargement = .normale,
        pagesTerminees: Int = 0,
        nombreDePages: Int = 0,
        octetsRecus: Int = 0,
        rang: Int = 0
    ) -> UUID {
        let tache = TelechargementAffiche(
            chapitreId: chapitre,
            serieId: UUID(),
            titreDeLaSerie: titre,
            numeroDeChapitre: numero,
            priorite: priorite,
            pagesTerminees: pagesTerminees,
            nombreDePages: nombreDePages,
            octetsRecus: octetsRecus,
            dateAjout: Date(timeIntervalSince1970: 1_700_000_000 + Double(rang))
        )

        file[tache.id] = tache
        ordre.append(tache.id)

        return tache.id
    }

    /// Tache portant cet identifiant.
    func tache(_ identifiant: UUID) -> TelechargementAffiche? {
        file[identifiant]
    }

    /// Remplace les reglages, comme le ferait le sous ecran.
    func definir(_ reglages: ReglagesDeTelechargement) {
        reglagesCourants = reglages
    }

    // MARK: Journal

    func taches() -> [TelechargementAffiche] {
        OrdreDeLaFile.trier(ordre.compactMap { file[$0] })
    }

    func reglages() -> ReglagesDeTelechargement {
        reglagesCourants
    }

    func demarrer(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.avec(etat: .enCours, messageErreur: nil)
        }

        let enCours = file.values.filter(\.occupeUnePlace).count
        pointeDeTachesEnCours = max(pointeDeTachesEnCours, enCours)
    }

    func remettreEnAttente(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.avec(etat: .enAttente, messageErreur: nil)
        }
    }

    func noterLaLongueur(de identifiant: UUID, nombreDePages: Int, octetsTotal: Int?) throws {
        try modifier(identifiant) { tache in
            tache.avec(nombreDePages: nombreDePages, octetsTotal: octetsTotal)
        }
    }

    func noterUnePageScellee(de identifiant: UUID, pagesTerminees: Int, octetsRecus: Int) throws {
        try modifier(identifiant) { tache in
            tache.avec(pagesTerminees: pagesTerminees, octetsRecus: octetsRecus)
        }
    }

    func terminer(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.avec(etat: .termine, pagesTerminees: tache.nombreDePages, messageErreur: nil)
        }
    }

    func echouer(_ identifiant: UUID, message: String) throws {
        try modifier(identifiant) { tache in
            tache.avec(etat: .echoue, messageErreur: message)
        }
    }

    private func modifier(
        _ identifiant: UUID,
        _ changement: (TelechargementAffiche) -> TelechargementAffiche
    ) throws {
        guard let tache = file[identifiant] else {
            throw ErreurDeTelechargement.tacheInconnue(identifiant: identifiant)
        }

        file[identifiant] = changement(tache)
    }
}

extension TelechargementAffiche {
    /// La meme ligne, avec les champs indiques remplaces.
    ///
    /// Le type est immuable, comme tout ce qui traverse Core. Une copie par
    /// changement coute une allocation et evite qu une reference partagee laisse
    /// deux couches voir deux etats differents de la meme tache.
    func avec(
        etat: EtatTelechargement? = nil,
        pagesTerminees: Int? = nil,
        nombreDePages: Int? = nil,
        octetsRecus: Int? = nil,
        octetsTotal: Int?? = nil,
        messageErreur: String?? = nil
    ) -> TelechargementAffiche {
        TelechargementAffiche(
            id: id,
            chapitreId: chapitreId,
            serieId: serieId,
            titreDeLaSerie: titreDeLaSerie,
            numeroDeChapitre: numeroDeChapitre,
            titreDuChapitre: titreDuChapitre,
            etat: etat ?? self.etat,
            priorite: priorite,
            pagesTerminees: pagesTerminees ?? self.pagesTerminees,
            nombreDePages: nombreDePages ?? self.nombreDePages,
            octetsRecus: octetsRecus ?? self.octetsRecus,
            octetsTotal: octetsTotal ?? self.octetsTotal,
            dateAjout: dateAjout,
            messageErreur: messageErreur ?? self.messageErreur
        )
    }
}

/// Depot en memoire qui distingue vraiment un fragment d une page scellee.
actor DepotDeTest: DepotDeChapitres {
    private var fragments: [Cle: Data] = [:]
    private var scellees: [Cle: Data] = [:]

    struct Cle: Hashable {
        let chapitre: UUID
        let page: Int
    }

    /// Depose un fragment, comme une fermeture brutale en laisse un.
    func deposerUnFragment(_ octets: Data, page: Int, du chapitre: UUID) {
        fragments[Cle(chapitre: chapitre, page: page)] = octets
    }

    /// Page scellee, nulle quand elle n a jamais ete terminee.
    func page(_ index: Int, du chapitre: UUID) -> Data? {
        scellees[Cle(chapitre: chapitre, page: index)]
    }

    /// Nombre de pages scellees pour ce chapitre.
    func nombreDePagesScellees(du chapitre: UUID) -> Int {
        scellees.keys.filter { $0.chapitre == chapitre }.count
    }

    func inventaire(du chapitre: UUID) -> InventaireDeTelechargement {
        var completes = 0

        while scellees[Cle(chapitre: chapitre, page: completes)] != nil {
            completes += 1
        }

        return InventaireDeTelechargement(
            pagesCompletes: completes,
            octetsDuFragment: fragments[Cle(chapitre: chapitre, page: completes)]?.count ?? 0
        )
    }

    func ecrire(_ octets: Data, page index: Int, du chapitre: UUID, enPoursuivant: Bool) {
        let cle = Cle(chapitre: chapitre, page: index)

        guard enPoursuivant, var existant = fragments[cle] else {
            fragments[cle] = octets

            return
        }

        existant.append(octets)
        fragments[cle] = existant
    }

    func sceller(page index: Int, du chapitre: UUID) throws -> Int {
        let cle = Cle(chapitre: chapitre, page: index)

        guard let fragment = fragments.removeValue(forKey: cle) else {
            throw ErreurDeTelechargement.chapitreSansPage(identifiant: chapitre)
        }

        scellees[cle] = fragment

        return fragment.count
    }
}

/// Pages figees d un chapitre, sous la forme que le moteur attend.
struct PagesFigees: FournisseurDePagesATelecharger {
    /// Nombre de pages par chapitre.
    let nombreDePages: Int

    func requetesDePages(duChapitre chapitre: UUID) throws -> [URLRequest] {
        (0..<nombreDePages).map { index in
            let adresse = URL(string: "https://serveur.test/\(chapitre.uuidString)/\(index)")

            return URLRequest(url: adresse ?? URL(fileURLWithPath: "/"))
        }
    }
}

/// Serveur de pages qui honore l entete `Range` et compte ce qui passe de front.
actor ServeurDePages: TransportHttp {
    /// Poids d une page servie.
    static let poidsDUnePage = 512

    private var requetes: [String] = []
    private var plagesDemandees: [String: String] = [:]
    private var enVol = 0
    private(set) var pointeDeRequetesDeFront = 0

    /// Chemins qui doivent echouer, retires apres le premier echec.
    private var pannes: [String: ErreurReseau] = [:]

    /// Delai applique a chaque reponse, pour que les requetes se chevauchent.
    private let delai: Duration

    init(delai: Duration = .milliseconds(5)) {
        self.delai = delai
    }

    /// Programme une panne sur la page d un chapitre.
    func programmerUnePanne(_ panne: ErreurReseau, page: Int, du chapitre: UUID) {
        pannes[Self.chemin(chapitre: chapitre, page: page)] = panne
    }

    /// Retire toutes les pannes programmees.
    func reparer() {
        pannes.removeAll()
    }

    /// Chemins demandes, dans l ordre.
    func journal() -> [String] {
        requetes
    }

    /// Plage demandee pour une page, nulle quand aucune ne l a ete.
    func plage(page: Int, du chapitre: UUID) -> String? {
        plagesDemandees[Self.chemin(chapitre: chapitre, page: page)]
    }

    /// Contenu complet d une page, tel que le serveur le sert.
    ///
    /// Un motif qui depend de la page, et non des octets identiques : deux pages
    /// interverties passeraient sans etre vues si toutes se ressemblaient.
    static func contenu(page: Int) -> Data {
        Data(repeating: UInt8(page % 251), count: poidsDUnePage)
    }

    static func chemin(chapitre: UUID, page: Int) -> String {
        "/\(chapitre.uuidString)/\(page)"
    }

    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        guard let chemin = requete.url?.path else {
            throw ErreurReseau.serveurIntrouvable
        }

        requetes.append(chemin)

        if let plage = requete.value(forHTTPHeaderField: RepriseDeTelechargement.enteteDeDemande) {
            plagesDemandees[chemin] = plage
        }

        enVol += 1
        pointeDeRequetesDeFront = max(pointeDeRequetesDeFront, enVol)

        defer { enVol -= 1 }

        try await Task.sleep(for: delai)

        if let panne = pannes[chemin] {
            throw panne
        }

        guard let page = Int(chemin.split(separator: "/").last ?? "") else {
            throw ErreurReseau.ressourceIntrouvable
        }

        let complet = Self.contenu(page: page)

        guard
            let plage = requete.value(forHTTPHeaderField: RepriseDeTelechargement.enteteDeDemande),
            let depuis = Int(plage.replacingOccurrences(of: "bytes=", with: "").replacingOccurrences(of: "-", with: ""))
        else {
            return ReponseHttp(code: 200, corps: complet)
        }

        guard depuis < complet.count else {
            return ReponseHttp(code: RepriseDeTelechargement.codeTrancheInvalide)
        }

        return ReponseHttp(
            code: RepriseDeTelechargement.codePartiel,
            entetes: [
                RepriseDeTelechargement.enteteDeReponse:
                    "bytes \(depuis)-\(complet.count - 1)/\(complet.count)",
            ],
            corps: complet.suffix(from: depuis)
        )
    }
}
