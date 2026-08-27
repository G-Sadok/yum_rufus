import Core
import Foundation

//
// EnchainementDeChapitres
//
// Chargement du chapitre suivant sans quitter le lecteur, marquage du chapitre
// quitte, et fin de serie, section 7.4 du cahier de developpement.
//
// Quatre choix structurent cet acteur.
//
// Le chapitre suivant se charge en avance, pas au moment ou le bas du ruban est
// atteint. Une source distante repond en centaines de millisecondes, et un
// defilement qui s arrete au bas du chapitre pour attendre ces octets est
// exactement ce que la section 7.4 cherche a eviter. L avance se compte en
// hauteurs de fenetre, ce qui la garde juste quelle que soit la taille de
// l ecran.
//
// Le marquage a lieu au passage, une seule fois par chapitre, et jamais dans
// l autre sens. Un retour en arriere dans le chapitre precedent ne le demarque
// pas : seul un demarquage explicite depuis la fiche de serie le fait, et il
// vit dans Storage.
//
// Un marquage qui echoue reste du. Il est repris au geste suivant, comme la
// position sale de la sauvegarde de progression. Perdre en silence le seul
// effet durable de l enchainement laisserait la fiche de serie afficher un
// chapitre en cours que l utilisateur a fini.
//
// La fin de la serie est un etat, pas un effet de bord. Elle n est annoncee que
// lorsque le dernier chapitre connu est reellement termine, et jamais parce que
// la suite est inconnue : un lecteur ouvert sans sa liste de chapitres continue
// simplement de lire.
//

/// Prepare le chapitre suivant et rend le segment a poser dans le ruban.
///
/// La couche vue implemente ce protocole : elle seule sait ouvrir la source,
/// mesurer les pages a la largeur de colonne choisie, et decider si le chapitre
/// se lit en defilement continu ou en webtoon.
public protocol ChargeurDeChapitre: Sendable {
    /// Segment du chapitre demande, pile comprise.
    ///
    /// - Throws: l erreur de la source. L enchainement la garde et laisse le
    ///   lecteur dans le chapitre courant.
    func segment(pourChapitre chapitreId: UUID) async throws -> SegmentDeChapitre
}

/// Ce que le lecteur montre au bas du chapitre courant.
public enum EtatDEnchainement: Sendable, Equatable {
    /// Lecture ordinaire du chapitre nomme.
    case enLecture(chapitre: UUID)

    /// Le chapitre nomme arrive, ses octets sont en route.
    case chargement(chapitreEntrant: UUID)

    /// Le dernier chapitre de la serie est termine.
    case finDeLaSerie

    /// Le chapitre nomme n a pas pu etre charge.
    case chapitreIndisponible(chapitre: UUID)
}

/// Enchaine les chapitres d une serie dans un meme defilement vertical.
public actor EnchainementDeChapitres {
    /// Avance de chargement, en hauteurs de fenetre.
    ///
    /// Une fenetre : le chapitre suivant part des que son intercalaire est a un
    /// ecran du bas de l ecran. Plus tot, on telecharge des chapitres que
    /// l utilisateur ne lira pas ; plus tard, le defilement attend.
    public static let avanceParDefaut: Double = 1

    private let suite: SuiteDeChapitres
    private let chargeur: any ChargeurDeChapitre
    private let marqueur: any MarqueurDeChapitreLu
    private let avanceDeChargement: Double

    private var rubanInterne: RubanDeChapitres
    private var etatInterne: EtatDEnchainement
    private var rangCourant = 0

    /// Chapitres a marquer lus, dans l ordre ou ils ont ete quittes.
    private var aMarquer: [UUID] = []

    /// Chapitres deja marques, pour ne jamais reecrire le meme.
    private var dejaMarques: Set<UUID> = []

    /// Vrai pendant une ecriture de marquage. L acteur rend la main pendant
    /// l ecriture, et sans ce drapeau un second geste de defilement enverrait le
    /// meme chapitre une seconde fois.
    private var marquageEnCours = false

    private var chargement: Task<Void, Never>?
    private var chapitreEnCoursDeChargement: UUID?

    /// Derniere erreur de chargement rencontree, pour l ecran de diagnostic.
    public private(set) var derniereErreurDeChargement: (any Error)?

    /// Derniere erreur de marquage rencontree.
    ///
    /// Elle n interrompt jamais la lecture. Le marquage reste du et repart au
    /// geste suivant.
    public private(set) var derniereErreurDeMarquage: (any Error)?

    /// Ouvre un enchainement sur un chapitre deja charge.
    ///
    /// - Parameters:
    ///   - suite: chapitres de la serie dans l ordre narratif.
    ///   - premier: chapitre ouvert par l utilisateur.
    ///   - chargeur: prepare les chapitres suivants.
    ///   - marqueur: marque lu le chapitre quitte.
    ///   - intercalaire: hauteur du separateur, donnee par la couche vue.
    ///   - avanceDeChargement: avance de declenchement, en hauteurs de fenetre.
    public init(
        suite: SuiteDeChapitres,
        premier: SegmentDeChapitre,
        chargeur: any ChargeurDeChapitre,
        marqueur: any MarqueurDeChapitreLu,
        intercalaire: Double = 0,
        avanceDeChargement: Double = EnchainementDeChapitres.avanceParDefaut
    ) {
        self.suite = suite
        self.chargeur = chargeur
        self.marqueur = marqueur
        self.avanceDeChargement = max(0, avanceDeChargement)
        rubanInterne = RubanDeChapitres(intercalaire: intercalaire, segments: [premier])
        etatInterne = .enLecture(chapitre: premier.chapitreId)
    }

    /// Ruban courant, tel que la vue doit le poser.
    public var ruban: RubanDeChapitres {
        rubanInterne
    }

    /// Etat courant du bas de lecture.
    public var etat: EtatDEnchainement {
        etatInterne
    }

    /// Chapitre lu en ce moment.
    public var chapitreCourant: UUID {
        rubanInterne.segments[rangCourant].chapitreId
    }

    /// Chapitres marques lus depuis l ouverture, dans l ordre.
    public var chapitresMarquesLus: [UUID] {
        rubanInterne.segments
            .map(\.chapitreId)
            .filter { dejaMarques.contains($0) }
    }

    /// Vrai quand un marquage attend encore d etre ecrit.
    public var marquageEnAttente: Bool {
        aMarquer.isEmpty == false
    }

    /// Annonce le decalage atteint par le defilement.
    ///
    /// A appeler a chaque arret du defilement, avec la hauteur visible. C est le
    /// seul point d entree : il marque le chapitre quitte, lance le chapitre
    /// suivant, et annonce la fin de la serie.
    ///
    /// - Parameters:
    ///   - decalage: position du bord haut de la fenetre dans le ruban.
    ///   - hauteurDeLaFenetre: hauteur visible, en points.
    public func avancerA(_ decalage: Double, hauteurDeLaFenetre: Double) async {
        guard let rang = rubanInterne.segmentCourant(auDecalage: decalage) else {
            return
        }

        franchir(jusquAu: rang)
        regarderLeBas(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)

        await ecrireLesMarquages()
    }

    /// Position de reprise a enregistrer pour ce decalage.
    ///
    /// Elle nomme le chapitre reellement lu. C est ce que `SauvegardeDeProgression`
    /// depose ensuite, sans savoir qu un enchainement a eu lieu.
    public func positionDeLecture(auDecalage decalage: Double) -> PositionDeLecture? {
        rubanInterne.positionDeLecture(auDecalage: decalage)
    }

    /// Arrete l enchainement et annule le chargement en cours.
    ///
    /// A appeler a la fermeture du lecteur. Les marquages encore dus partent
    /// avant de rendre la main, pour la meme raison que la derniere ecriture de
    /// position : fermer le lecteur juste apres avoir change de chapitre ne doit
    /// pas perdre ce chapitre.
    public func arreter() async {
        chargement?.cancel()
        chargement = nil
        chapitreEnCoursDeChargement = nil

        await ecrireLesMarquages()
    }

    /// Enregistre le passage dans un nouveau chapitre.
    ///
    /// Tous les chapitres franchis sont marques, pas seulement le precedent. Un
    /// defilement lance sur un chapitre court peut en traverser deux entre deux
    /// annonces, et le chapitre du milieu resterait sinon en cours pour
    /// toujours.
    private func franchir(jusquAu rang: Int) {
        guard rang != rangCourant else { return }

        // Un retour en arriere change le chapitre lu, jamais l etat lu des
        // chapitres deja franchis.
        if rang > rangCourant {
            for franchi in rangCourant..<rang {
                demanderLeMarquage(de: rubanInterne.segments[franchi].chapitreId)
            }
        }

        rangCourant = rang

        // Un chargement en cours garde la parole : le lecteur montre le chapitre
        // qui arrive, pas celui qu il vient de quitter.
        if chapitreEnCoursDeChargement == nil {
            etatInterne = .enLecture(chapitre: rubanInterne.segments[rang].chapitreId)
        }
    }

    /// Decide s il faut charger la suite, ou annoncer la fin de la serie.
    private func regarderLeBas(auDecalage decalage: Double, hauteurDeLaFenetre: Double) {
        guard let dernier = rubanInterne.segments.last else { return }

        let reste = rubanInterne.resteAParcourir(
            auDecalage: decalage,
            hauteurDeLaFenetre: hauteurDeLaFenetre
        )

        guard let suivant = suite.suivant(de: dernier.chapitreId) else {
            terminerLaSerie(de: dernier.chapitreId, reste: reste)
            return
        }

        guard reste <= hauteurDeLaFenetre * avanceDeChargement,
              chapitreEnCoursDeChargement == nil,
              rubanInterne.contient(suivant.id) == false
        else {
            return
        }

        demarrerLeChargement(de: suivant.id)
    }

    /// Annonce la fin de la serie quand le dernier chapitre connu est termine.
    ///
    /// Le dernier chapitre est marque lu ici : il n est le precedent de personne,
    /// et sans cette ligne la serie finirait avec un chapitre en cours.
    private func terminerLaSerie(de chapitreId: UUID, reste: Double) {
        guard suite.estLeDernier(chapitreId), reste <= 0 else {
            return
        }

        demanderLeMarquage(de: chapitreId)
        etatInterne = .finDeLaSerie
    }

    /// Lance le chargement du chapitre entrant, hors de l acteur.
    private func demarrerLeChargement(de chapitreId: UUID) {
        chapitreEnCoursDeChargement = chapitreId
        etatInterne = .chargement(chapitreEntrant: chapitreId)

        chargement = Task { [weak self, chargeur] in
            do {
                let segment = try await chargeur.segment(pourChapitre: chapitreId)

                guard Task.isCancelled == false else { return }

                await self?.poser(segment)
            } catch {
                guard Task.isCancelled == false else { return }

                await self?.echouer(chapitreId, avec: error)
            }
        }
    }

    /// Pose le chapitre charge a la suite du ruban.
    private func poser(_ segment: SegmentDeChapitre) {
        chargement = nil
        chapitreEnCoursDeChargement = nil
        derniereErreurDeChargement = nil

        rubanInterne.ajouter(segment)
        etatInterne = .enLecture(chapitre: rubanInterne.segments[rangCourant].chapitreId)
    }

    /// Retient l echec du chargement, sans sortir l utilisateur de sa lecture.
    ///
    /// Le chapitre reste chargeable : la prochaine annonce de decalage le
    /// redemande, ce qui rattrape une coupure reseau passagere sans que
    /// l utilisateur ait a rouvrir quoi que ce soit.
    private func echouer(_ chapitreId: UUID, avec erreur: any Error) {
        chargement = nil
        chapitreEnCoursDeChargement = nil
        derniereErreurDeChargement = erreur
        etatInterne = .chapitreIndisponible(chapitre: chapitreId)
    }

    /// Met un chapitre dans la file de marquage, une seule fois.
    private func demanderLeMarquage(de chapitreId: UUID) {
        guard dejaMarques.contains(chapitreId) == false,
              aMarquer.contains(chapitreId) == false
        else {
            return
        }

        aMarquer.append(chapitreId)
    }

    /// Ecrit les marquages dus, et laisse en file ceux qui echouent.
    private func ecrireLesMarquages() async {
        guard marquageEnCours == false else { return }

        marquageEnCours = true
        defer { marquageEnCours = false }

        while let chapitreId = aMarquer.first {
            do {
                try await marqueur.marquerLu(chapitreId)

                aMarquer.removeAll { $0 == chapitreId }
                dejaMarques.insert(chapitreId)
                derniereErreurDeMarquage = nil
            } catch {
                derniereErreurDeMarquage = error
                return
            }
        }
    }
}
