import Foundation

//
// CacheDisqueDePages
//
// Cache disque des pages, separe du cache memoire, plafond configurable, purge
// par date d acces, comme l impose le quatrieme point de la section 6.1.
//
// Separe veut dire separe : ce cache ne connait pas le cache memoire, ne
// l alimente pas et ne l invalide pas. Il conserve des octets prets a servir,
// la ou le cache memoire conserve des matrices decodees. Les deux plafonds
// n ont rien a voir, l un se compte en centaines de megaoctets de fichiers,
// l autre en pages en vol.
//
// La date d acces est tenue par nous, dans un index, et non lue sur le systeme
// de fichiers. La date d acces d un fichier n est pas fiable : de nombreux
// volumes sont montes sans sa mise a jour, et une sauvegarde ou un antivirus la
// touche sans que l utilisateur ait ouvert quoi que ce soit. Une purge fondee
// sur elle supprimerait les mauvaises pages.
//
// L index est reconcilie avec le dossier a chaque ouverture. Un fichier present
// sans entree est adopte, une entree sans fichier est oubliee, et la taille
// retenue est toujours celle du fichier sur le disque. Une ecriture interrompue
// par une coupure ne peut donc ni disparaitre du compte, ni le fausser.
//

/// Echec d une operation du cache disque.
public enum ErreurDeCacheDisque: Error, Sendable, Equatable {
    /// Le dossier de cache n existe pas et ne peut pas etre cree.
    case dossierInaccessible(chemin: String)

    /// Le fichier de la page ne peut pas etre ecrit.
    case ecritureImpossible(empreinte: String)

    /// Message destine a l utilisateur.
    public var messageUtilisateur: String {
        switch self {
        case .dossierInaccessible:
            "Le dossier de cache des images n est pas accessible. Videz le cache dans les reglages."
        case .ecritureImpossible:
            "Une page n a pas pu etre mise en cache. Verifiez l espace disque disponible."
        }
    }
}

/// Plafond du cache disque, en octets de fichiers.
public struct PlafondDeCacheDisque: Sendable, Hashable {
    /// Nombre maximal d octets que le dossier de cache peut occuper.
    public let octets: Int

    /// Construit un plafond, en refusant une borne plus petite qu une page.
    public init(octets: Int) {
        self.octets = max(Self.plancher, octets)
    }

    /// Plafond applique quand l utilisateur n en a pas choisi d autre.
    ///
    /// Le cahier laisse ce plafond configurable sans en fixer la valeur. Cinq
    /// cents millions d octets tiennent quelques centaines de pages traitees,
    /// assez pour une session de lecture complete, sans monopoliser le disque
    /// d un appareil mobile. L ecran de reglages de la section 10 l expose.
    public static let parDefaut = PlafondDeCacheDisque(octets: 500_000_000)

    private static let plancher = 64 * 1024
}

/// Horloge qui date les acces au cache disque.
///
/// Injectable pour que les tests de purge portent sur un ordre choisi et non
/// sur la resolution de l horloge de la machine.
public struct HorlogeDAcces: Sendable {
    private let lecture: @Sendable () -> Date

    public init(_ lecture: @escaping @Sendable () -> Date) {
        self.lecture = lecture
    }

    /// Horloge du systeme.
    public static let systeme = HorlogeDAcces { Date() }

    /// Instant courant selon cette horloge.
    public func maintenant() -> Date {
        lecture()
    }
}

/// Cache disque des pages, purge par date d acces.
public actor CacheDisqueDePages {
    /// Ce que l index retient d une entree.
    private struct Entree: Codable, Sendable {
        var octets: Int
        var dateDAcces: Date
    }

    /// Plafond applique a ce cache.
    public let plafond: PlafondDeCacheDisque

    private let dossier: URL
    private let horloge: HorlogeDAcces
    private let gestionnaire = FileManager.default
    private var entrees: [String: Entree] = [:]
    private var octetsUtilisesInternes = 0

    private static let nomDeLIndex = "index.json"

    /// Ouvre le cache dans un dossier, en le creant au besoin.
    ///
    /// L initialisation est asynchrone parce qu elle touche le disque : lecture
    /// de l index, reconciliation avec le dossier, et purge d ouverture qui
    /// applique un plafond eventuellement reduit depuis la derniere session.
    ///
    /// - Throws: `ErreurDeCacheDisque.dossierInaccessible` quand le dossier ne
    ///   peut etre ni ouvert ni cree.
    public init(
        dossier: URL,
        plafond: PlafondDeCacheDisque = .parDefaut,
        horloge: HorlogeDAcces = .systeme
    ) async throws {
        self.dossier = dossier
        self.plafond = plafond
        self.horloge = horloge

        try creerLeDossier()
        chargerLIndex()
        reconcilierAvecLeDossier()
        purger()
        enregistrerLIndex()
    }

    /// Octets que le dossier de cache occupe a cet instant.
    public var octetsUtilises: Int {
        octetsUtilisesInternes
    }

    /// Nombre de pages en cache a cet instant.
    public var nombreDEntrees: Int {
        entrees.count
    }

    /// Depose les octets d une page.
    ///
    /// - Returns: vrai quand la page est retenue, faux quand elle pese a elle
    ///   seule plus que le plafond. La retenir franchirait le plafond, quel que
    ///   soit ce que la purge supprime ensuite.
    /// - Throws: `ErreurDeCacheDisque.ecritureImpossible` quand le disque
    ///   refuse le fichier.
    @discardableResult
    public func deposer(_ donnees: Data, pour cle: ClePage) throws -> Bool {
        let empreinte = cle.empreinte

        guard donnees.count <= plafond.octets else {
            retirerLEntree(empreinte)
            enregistrerLIndex()

            return false
        }

        do {
            try donnees.write(to: fichier(empreinte), options: .atomic)
        } catch {
            throw ErreurDeCacheDisque.ecritureImpossible(empreinte: empreinte)
        }

        if let ancienne = entrees[empreinte] {
            octetsUtilisesInternes -= ancienne.octets
        }

        entrees[empreinte] = Entree(octets: donnees.count, dateDAcces: horloge.maintenant())
        octetsUtilisesInternes += donnees.count
        purger()
        enregistrerLIndex()

        return entrees[empreinte] != nil
    }

    /// Rend les octets d une page et met a jour sa date d acces.
    ///
    /// Une entree indexee dont le fichier a disparu est oubliee plutot que
    /// signalee : un cache est un cache, son absence n est pas une erreur.
    public func donnees(pour cle: ClePage) -> Data? {
        let empreinte = cle.empreinte

        guard entrees[empreinte] != nil else { return nil }

        guard let donnees = try? Data(contentsOf: fichier(empreinte)) else {
            retirerLEntree(empreinte)
            enregistrerLIndex()

            return nil
        }

        entrees[empreinte]?.dateDAcces = horloge.maintenant()
        enregistrerLIndex()

        return donnees
    }

    /// Vrai quand la page est en cache, sans toucher sa date d acces.
    public func contient(_ cle: ClePage) -> Bool {
        entrees[cle.empreinte] != nil
    }

    /// Date du dernier acces a une page, si elle est en cache.
    public func dateDAcces(de cle: ClePage) -> Date? {
        entrees[cle.empreinte]?.dateDAcces
    }

    /// Retire une page du cache.
    public func retirer(_ cle: ClePage) {
        retirerLEntree(cle.empreinte)
        enregistrerLIndex()
    }

    /// Vide le cache entierement.
    public func vider() {
        for empreinte in Array(entrees.keys) {
            retirerLEntree(empreinte)
        }

        enregistrerLIndex()
    }

    /// Supprime les pages les moins recemment lues jusqu a tenir le plafond.
    ///
    /// Appelee apres chaque depot et a l ouverture. Publique parce que l ecran
    /// de reglages permet de reduire le plafond, ce qui doit prendre effet sans
    /// attendre le depot suivant.
    public func purger() {
        guard octetsUtilisesInternes > plafond.octets else { return }

        // Egalite de dates possible quand l horloge est grossiere. L empreinte
        // departage, pour que deux ouvertures successives purgent les memes
        // entrees plutot que des entrees tirees au sort par le tri.
        let ordre = entrees.sorted { gauche, droite in
            gauche.value.dateDAcces == droite.value.dateDAcces
                ? gauche.key < droite.key
                : gauche.value.dateDAcces < droite.value.dateDAcces
        }

        for entree in ordre {
            guard octetsUtilisesInternes > plafond.octets else { break }

            retirerLEntree(entree.key)
        }
    }

    /// Ecrit l index sur le disque, sans quoi la recence serait perdue au
    /// prochain lancement et la purge supprimerait les mauvaises pages.
    ///
    /// Publique pour que la couche application puisse la declencher au passage
    /// en arriere plan, meme si chaque mutation l appelle deja.
    public func enregistrer() {
        enregistrerLIndex()
    }

    private func fichier(_ empreinte: String) -> URL {
        dossier.appendingPathComponent(empreinte, isDirectory: false)
    }

    private func retirerLEntree(_ empreinte: String) {
        guard let entree = entrees.removeValue(forKey: empreinte) else { return }

        octetsUtilisesInternes -= entree.octets
        try? gestionnaire.removeItem(at: fichier(empreinte))
    }

    private func creerLeDossier() throws {
        do {
            try gestionnaire.createDirectory(at: dossier, withIntermediateDirectories: true)
        } catch {
            throw ErreurDeCacheDisque.dossierInaccessible(chemin: dossier.path)
        }
    }

    private func chargerLIndex() {
        let url = dossier.appendingPathComponent(Self.nomDeLIndex, isDirectory: false)

        guard let donnees = try? Data(contentsOf: url),
              let lues = try? JSONDecoder().decode([String: Entree].self, from: donnees)
        else {
            return
        }

        entrees = lues
    }

    private func enregistrerLIndex() {
        let url = dossier.appendingPathComponent(Self.nomDeLIndex, isDirectory: false)

        guard let donnees = try? JSONEncoder().encode(entrees) else { return }

        try? donnees.write(to: url, options: .atomic)
    }

    /// Aligne l index sur ce que le dossier contient reellement.
    ///
    /// La taille retenue vient toujours du fichier, jamais de l index. Un index
    /// qui surestimerait ferait purger pour rien, un index qui sous estimerait
    /// laisserait le dossier depasser le plafond sans que personne ne le voie.
    private func reconcilierAvecLeDossier() {
        let cles: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let contenu = (try? gestionnaire.contentsOfDirectory(
            at: dossier,
            includingPropertiesForKeys: cles
        )) ?? []

        var presentes: Set<String> = []

        for url in contenu where url.lastPathComponent != Self.nomDeLIndex {
            let empreinte = url.lastPathComponent
            let valeurs = try? url.resourceValues(forKeys: Set(cles))

            presentes.insert(empreinte)
            entrees[empreinte] = Entree(
                octets: valeurs?.fileSize ?? 0,
                dateDAcces: entrees[empreinte]?.dateDAcces
                    ?? valeurs?.contentModificationDate
                    ?? Date.distantPast
            )
        }

        for empreinte in Array(entrees.keys) where presentes.contains(empreinte) == false {
            entrees.removeValue(forKey: empreinte)
        }

        octetsUtilisesInternes = entrees.values.reduce(0) { $0 + $1.octets }
    }
}
