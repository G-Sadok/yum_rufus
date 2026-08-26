import Archive
import Core
import Foundation

//
// OctetsDePartage
//
// La lecture en flux d un fichier pose sur un partage reseau, sans copie
// complete. C est le premier critere de la fonctionnalite, et c est ici qu il se
// joue.
//
// Le probleme a resoudre est une inversion. `SourceDOctets`, que tout le lecteur
// d archive emploie, est synchrone : demander une plage rend des octets ou leve.
// Un partage reseau, lui, est asynchrone. Les deux ne se rejoignent pas
// directement, et les trois facons habituelles de les forcer sont toutes
// mauvaises. Bloquer un fil sur un semaphore condamne une tache de la file
// cooperative et finit en interblocage sous charge. Copier le fichier entier
// avant de l ouvrir viole le critere. Prevoir a l avance les plages a rapatrier
// suppose de reimplementer le format ZIP hors du paquet qui le lit.
//
// La quatrieme facon est celle retenue, et elle n a aucun de ces defauts. La vue
// synchrone ne rend que ce qui est deja rapatrie, et leve `PlageAbsente` sinon,
// en nommant la plage qui manque. L appelant asynchrone attrape, rapatrie
// exactement cette plage, et rejoue l operation depuis le debut. La lecture
// converge en quelques tours parce que chaque tour ajoute une plage et n en
// perd aucune.
//
// Ce que cela achete depasse le critere. Le lecteur d archive n a pas une ligne
// a changer, le comportement est le meme qu il lise un disque ou un serveur, et
// la reprise apres coupure devient une propriete du tampon plutot qu une
// condition dispersee dans chaque appelant : une plage deja rapatriee n est
// jamais redemandee, donc reprendre apres une coupure ne recommence pas ce qui
// etait deja passe. C est le deuxieme critere.
//
// Les octets sont ranges par blocs alignes et non par plages exactes. Une plage
// exacte par demande donnerait une collection d intervalles a fusionner, dont le
// cout de recherche croit avec le nombre de lectures. Un bloc aligne se retrouve
// par une division, et deux lectures voisines partagent le meme bloc, ce qui est
// exactement le cas de l en tete local et des octets d une entree ZIP.
//

/// La plage demandee n est pas encore rapatriee.
///
/// Erreur de circulation interne, jamais montree a l utilisateur : elle est
/// attrapee par `ConteneurDePartage`, qui rapatrie et rejoue. Elle ne porte
/// aucun message parce qu elle ne doit jamais en avoir besoin.
struct PlageAbsente: Error, Sendable, Hashable {
    let offset: UInt64
    let longueur: Int
}

/// Vue synchrone sur les seuls octets deja rapatries d un fichier distant.
///
/// Une plage entierement rapatriee se lit comme sur un disque. Une plage qui
/// manque, meme d un seul bloc, leve `PlageAbsente` et ne rend rien de partiel :
/// rendre des octets incomplets ferait analyser un en tete tronque comme s il
/// etait entier, et le format ZIP y repondrait par une erreur de conteneur
/// corrompu qui accuserait l archive au lieu du reseau.
struct OctetsPartiels: SourceDOctets {
    let nom: String
    let taille: UInt64

    /// Blocs deja rapatries, indexes par leur rang.
    let blocs: [UInt64: Data]

    /// Taille d un bloc, en octets.
    let tailleDeBloc: Int

    func lire(a offset: UInt64, longueur: Int) throws -> Data {
        guard longueur >= 0, offset <= taille, UInt64(longueur) <= taille - offset else {
            throw ErreurDeDocument.conteneurTronque(chemin: nom)
        }
        guard longueur > 0 else {
            return Data()
        }

        let rangs = Self.rangs(offset: offset, longueur: longueur, tailleDeBloc: tailleDeBloc)

        var assemble = Data(capacity: longueur)
        for rang in rangs {
            guard let bloc = blocs[rang] else {
                throw PlageAbsente(offset: offset, longueur: longueur)
            }

            assemble.append(bloc)
        }

        // Le decoupage part du premier bloc assemble et non de zero : le premier
        // bloc commence avant la plage demandee des que l offset n est pas
        // aligne, et supposer l alignement rendrait les octets du voisin.
        guard let premier = rangs.first else {
            return Data()
        }

        let debut = Int(offset - premier * UInt64(tailleDeBloc))

        guard debut + longueur <= assemble.count else {
            // Un bloc plus court que sa taille annoncee ne peut exister qu en
            // fin de fichier, ou la borne du haut a deja ete verifiee. Y arriver
            // veut dire que le serveur a rendu moins que ce qu il annonce.
            throw ErreurDeDocument.conteneurTronque(chemin: nom)
        }

        return assemble.subdata(in: (assemble.startIndex + debut)..<(assemble.startIndex + debut + longueur))
    }

    /// Les rangs de blocs que couvre une plage.
    static func rangs(offset: UInt64, longueur: Int, tailleDeBloc: Int) -> [UInt64] {
        guard longueur > 0, tailleDeBloc > 0 else {
            return []
        }

        let taille = UInt64(tailleDeBloc)
        let premier = offset / taille
        let dernier = (offset + UInt64(longueur) - 1) / taille

        return Array(premier...dernier)
    }
}

// MARK: - Tampon

/// Les octets d un fichier distant deja rapatries, et ce qu il faut pour en
/// rapatrier d autres.
///
/// C est un acteur parce que deux pages preparees en parallele demandent des
/// plages du meme fichier, et qu un tampon partage sans isolation rapatrierait
/// deux fois le meme bloc dans le meilleur des cas.
actor TamponDePartage {
    let nom: String
    let taille: UInt64
    let tailleDeBloc: Int

    private let partage: any PartageReseau
    private let chemin: String
    private let plafond: Int
    private let essais: Int
    private let attendre: @Sendable (Int) async throws -> Void

    private var blocs: [UInt64: Data] = [:]

    /// Rang d usage des blocs, du plus ancien au plus recent.
    private var usage: [UInt64] = []

    /// Nombre d octets reellement demandes au partage depuis l ouverture.
    ///
    /// C est la mesure du premier critere. Elle compte ce qui a traverse le
    /// reseau, jamais ce que l appelant a lu : relire deux fois la meme page ne
    /// l augmente pas, et c est bien le sujet.
    private(set) var octetsRapatries: UInt64 = 0

    /// Construit le tampon sur un fichier deja localise.
    init(
        partage: any PartageReseau,
        chemin: String,
        taille: UInt64,
        nom: String,
        reglages: ReglagesDeFlux = .parDefaut
    ) {
        self.partage = partage
        self.chemin = chemin
        self.taille = taille
        self.nom = nom
        tailleDeBloc = reglages.tailleDeBloc
        plafond = reglages.plafond
        essais = reglages.essais
        attendre = reglages.attendre
    }

    /// La vue synchrone a presenter au lecteur d archive.
    func vue() -> OctetsPartiels {
        OctetsPartiels(nom: nom, taille: taille, blocs: blocs, tailleDeBloc: tailleDeBloc)
    }

    /// Rapatrie ce qui manque pour que cette plage soit lisible.
    ///
    /// Les blocs deja presents ne sont jamais redemandes, ce qui fait la reprise
    /// apres coupure : une lecture interrompue au milieu d une page reprend a
    /// l endroit exact ou elle s est arretee.
    ///
    /// - Throws: `ErreurReseau` quand le partage echoue apres toutes les
    ///   tentatives accordees, `ErreurDeDocument.conteneurTronque` quand le
    ///   serveur rend moins d octets qu il n en reste dans le fichier.
    func hydrater(offset: UInt64, longueur: Int) async throws {
        let rangs = OctetsPartiels.rangs(offset: offset, longueur: longueur, tailleDeBloc: tailleDeBloc)
        let manquants = rangs.filter { blocs[$0] == nil }

        guard manquants.isEmpty == false else {
            return
        }

        // Les blocs manquants sont demandes par suites contigues et non un par
        // un. Une page de cinq mega octets couvre dix blocs voisins, et les
        // demander separement paierait dix fois la latence pour une seule
        // lecture sequentielle.
        for suite in Self.suitesContigues(manquants) {
            try Task.checkCancellation()
            try await rapatrier(suite)
        }

        liberer(en: rangs)
    }

    /// Oublie tout ce qui a ete rapatrie.
    ///
    /// A appeler quand le fichier distant a change : les octets retenus
    /// decrivent alors une archive qui n existe plus.
    func vider() {
        blocs.removeAll()
        usage.removeAll()
    }

    // MARK: Rapatriement

    /// Demande une suite contigue de blocs, avec les tentatives accordees.
    ///
    /// La suite est reclamee jusqu a ce qu elle soit complete, et non en une
    /// seule fois. Un serveur qui rend moins que ce qu on lui demande est la
    /// regle plutot que l exception : SMB borne sa reponse a la taille de lecture
    /// negociee, NFS a celle annoncee par le montage, et un proxy place devant un
    /// serveur WebDAV coupe couramment au dela de quelques mega octets. Refuser
    /// ces reponses rendrait la lecture impossible chez eux.
    ///
    /// Chaque bloc complete est range des qu il arrive. C est ce qui fait la
    /// reprise du deuxieme critere : une coupure au milieu d une page laisse en
    /// place tout ce qui etait deja arrive, et la lecture relancee ne redemande
    /// que la suite.
    private func rapatrier(_ suite: ClosedRange<UInt64>) async throws {
        let debut = suite.lowerBound * UInt64(tailleDeBloc)

        guard debut < taille else {
            throw ErreurDeDocument.conteneurTronque(chemin: nom)
        }

        let fin = min((suite.upperBound + 1) * UInt64(tailleDeBloc), taille)
        var position = debut
        var rang = suite.lowerBound
        var attente = Data()

        while position < fin {
            try Task.checkCancellation()

            let recus = try await lireAvecReprise(a: position, longueur: Int(fin - position))

            guard recus.isEmpty == false else {
                // Le fichier a retreci entre l annonce de sa taille et sa
                // lecture, ou le serveur a coupe sans le dire. Les deux se
                // soldent par une archive incomplete, et le dire ici nomme la
                // cause au lieu de laisser le lecteur ZIP accuser l archive.
                throw ErreurDeDocument.conteneurTronque(chemin: nom)
            }

            octetsRapatries += UInt64(recus.count)
            position += UInt64(recus.count)
            attente.append(recus)

            while attente.count >= tailleDeBloc {
                ranger(attente.prefix(tailleDeBloc), a: rang)
                attente.removeFirst(tailleDeBloc)
                rang += 1
            }
        }

        // Ce qui reste ne peut etre que le dernier bloc du fichier, puisque la
        // borne haute a ete ramenee a la taille reelle. Rien ne viendra le
        // completer, il est donc range tel quel.
        if attente.isEmpty == false {
            ranger(attente, a: rang)
        }
    }

    /// Lit une plage, en reessayant les seules pannes passageres.
    private func lireAvecReprise(a offset: UInt64, longueur: Int) async throws -> Data {
        var derniere: any Error = ErreurReseau.echecDeTransport(code: 0)

        for tentative in 1...essais {
            try Task.checkCancellation()

            do {
                let recus = try await partage.lire(chemin, a: offset, longueur: longueur)

                // Un serveur qui ignore la borne haute d une plage rend la fin
                // du fichier. Tronquer ici plutot que de refuser garde ces
                // serveurs utilisables, et la longueur exacte est verifiee par
                // l appelant.
                return recus.count > longueur
                    ? recus.subdata(in: recus.startIndex..<(recus.startIndex + longueur))
                    : recus
            } catch {
                derniere = error

                guard let reseau = ErreurReseau.depuis(error), reseau.estTemporaire, tentative < essais else {
                    throw error
                }

                try await attendre(tentative)
            }
        }

        throw derniere
    }

    /// Range un bloc deja complet, ou le dernier bloc partiel du fichier.
    ///
    /// Les octets sont recopies dans une `Data` neuve. Une tranche garde les
    /// indices de son origine et retient le tampon complet dont elle est issue :
    /// la conserver telle quelle ferait vivre dans le tampon les octets deja
    /// ecoules dans les blocs precedents.
    private func ranger(_ octets: some DataProtocol, a rang: UInt64) {
        blocs[rang] = Data(octets)
        noter(rang)
    }

    // MARK: Plafond memoire

    /// Note qu un bloc vient d etre employe, pour l ordre d eviction.
    private func noter(_ rang: UInt64) {
        usage.removeAll { $0 == rang }
        usage.append(rang)
    }

    /// Ramene le tampon sous son plafond, sans toucher aux blocs de la plage en
    /// cours de lecture.
    ///
    /// L exception est indispensable : une page de vingt mega octets couvre plus
    /// de blocs que le plafond n en accorderait a une lecture au hasard, et
    /// evincer sans distinction ferait redemander les blocs du debut de la page
    /// avant que sa fin soit arrivee, indefiniment.
    private func liberer(en cours: [UInt64]) {
        let proteges = Set(cours)
        var poids = blocs.values.reduce(0) { $0 + $1.count }

        for rang in usage where poids > plafond {
            guard proteges.contains(rang) == false, let bloc = blocs[rang] else {
                continue
            }

            poids -= bloc.count
            blocs[rang] = nil
        }

        usage.removeAll { blocs[$0] == nil }
    }

    // MARK: Suites

    /// Regroupe des rangs tries en suites contigues.
    static func suitesContigues(_ rangs: [UInt64]) -> [ClosedRange<UInt64>] {
        var suites: [ClosedRange<UInt64>] = []

        for rang in rangs.sorted() {
            if let derniere = suites.last, derniere.upperBound + 1 == rang {
                suites[suites.count - 1] = derniere.lowerBound...rang
            } else {
                suites.append(rang...rang)
            }
        }

        return suites
    }
}
