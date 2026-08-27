import Core
import Foundation
import GRDB

//
// MagasinDeTelechargements
//
// Seul point d acces a la file de la section 4.11 de DESIGN-SPEC.md : mise en
// file, ordre de passage, avancement, pause et reprise, et reglages du sous
// ecran.
//
// La file vit en base et non en memoire, et c est ce qui rend la reprise
// possible. Une application tuee pendant un telechargement ne laisse aucune
// chance a un etat garde en memoire de survivre ; la base, elle, garde le compte
// de pages scellees, et la tache repart de la page suivante au lancement
// d apres. C est aussi pourquoi `reprendreLesTachesInterrompues` existe : une
// tache laissee `enCours` par une fermeture brutale ne tourne plus, elle doit
// retourner dans la file au lieu d occuper une place pour rien.
//
// Le nombre de telechargements simultanes est range dans la table des reglages
// de l application, sous une cle que `CatalogueDeReglages` ne connait pas. Ce
// n est pas un contournement : la section 5.5 arrete l ecran Reglages a quatre
// lignes pour la section 12, et le cahier de developpement range la limite dans
// le sous ecran qui s ouvre derriere. Le magasin des reglages ignore
// explicitement les cles qu il ne reconnait pas, la cohabitation est donc sure.
//

/// Lit et ecrit la file de telechargement.
///
/// Le magasin est le journal que le moteur du paquet Sources tient a jour. Ses
/// methodes sont synchrones et satisfont malgre tout les exigences asynchrones
/// de `JournalDeTelechargements` : une ecriture GRDB prend le temps d une
/// transaction sur un fichier local, la rendre asynchrone n ajouterait qu un
/// point de suspension par page telechargee.
public struct MagasinDeTelechargements: JournalDeTelechargements {
    /// Cle du nombre de telechargements simultanes dans la table des reglages.
    static let cleDesSimultanes = "telechargements.simultanes"

    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// File entiere, dans son ordre de passage.
    public func taches() throws -> [TelechargementAffiche] {
        try base.ecrivain.read(Self.taches)
    }

    /// Tache portant cet identifiant, nulle quand elle a quitte la file.
    public func tache(_ identifiant: UUID) throws -> Telechargement? {
        try base.ecrivain.read { connexion in
            try Telechargement.fetchOne(connexion, key: identifiant)
        }
    }

    /// Tache posee sur ce chapitre, nulle quand il n est pas en file.
    ///
    /// C est ce que la ligne de chapitre de la fiche de serie interroge pour
    /// savoir si son action dit `Telecharger` ou montre un avancement.
    public func tache(pourLeChapitre chapitre: UUID) throws -> Telechargement? {
        try base.ecrivain.read { connexion in
            try Self.tache(connexion, pourLeChapitre: chapitre)
        }
    }

    /// Flux de la file, reemis a chaque ecriture.
    ///
    /// L ecran de suivi s abonne et ne recharge jamais a la main : une page
    /// terminee par le moteur repeint la ligne sans que personne ne pense a le
    /// demander, ce qui est la seule facon de tenir la progression exacte que
    /// la section 4.11 attend.
    public func flux() -> AsyncThrowingStream<[TelechargementAffiche], any Error> {
        let observation = ValueObservation.tracking(Self.taches)
        let ecrivain = base.ecrivain

        return AsyncThrowingStream { suite in
            let tache = Task {
                do {
                    for try await taches in observation.values(in: ecrivain) {
                        suite.yield(taches)
                    }

                    suite.finish()
                } catch {
                    suite.finish(throwing: error)
                }
            }

            suite.onTermination = { _ in tache.cancel() }
        }
    }

    // MARK: Mise en file

    /// Met un chapitre en file, ou releve la priorite de celui qui y est deja.
    ///
    /// Une seconde demande sur un chapitre deja en file ne cree pas de doublon,
    /// la table l interdit. Elle releve la priorite quand la nouvelle est plus
    /// haute, et relance une tache echouee ou annulee : c est ce que
    /// l utilisateur attend d un second appui sur `Telecharger`.
    ///
    /// - Throws: `ErreurDeTelechargement.chapitreInconnu` quand le chapitre
    ///   n existe pas.
    @discardableResult
    public func mettreEnFile(
        chapitre: UUID,
        priorite: PrioriteDeTelechargement = .parDefaut,
        le date: Date = Date()
    ) throws -> Telechargement {
        try base.ecrivain.write { connexion in
            try Self.verifierLeChapitre(connexion, chapitre)

            guard var existante = try Self.tache(connexion, pourLeChapitre: chapitre) else {
                let pages = try Self.nombreDePages(connexion, chapitre)
                let neuve = Telechargement(
                    chapitreId: chapitre,
                    dateAjout: date,
                    priorite: priorite,
                    nombreDePages: pages
                )

                try neuve.insert(connexion)

                return neuve
            }

            if priorite < existante.priorite {
                existante.priorite = priorite
            }

            if existante.etat.estArrete, existante.etat != .termine {
                existante.etat = .enAttente
                existante.messageErreur = nil
            }

            try existante.update(connexion)

            return existante
        }
    }

    /// Remet dans la file les taches qu une fermeture brutale a laissees en
    /// cours.
    ///
    /// Appele a l ouverture de la base, avant tout demarrage. Sans lui, une
    /// tache figee a `enCours` occuperait une place simultanee pour toujours, et
    /// la file s arreterait apres autant de fermetures brutales que la limite le
    /// permet.
    ///
    /// - Returns: le nombre de taches remises en attente.
    @discardableResult
    public func reprendreLesTachesInterrompues() throws -> Int {
        try base.ecrivain.write { connexion in
            try Telechargement
                .filter(Column("etat") == EtatTelechargement.enCours)
                .updateAll(connexion, Column("etat").set(to: EtatTelechargement.enAttente))
        }
    }

    // MARK: Commandes de ligne

    /// Marque une tache comme demarree.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func demarrer(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.etat = .enCours
            tache.messageErreur = nil
        }
    }

    /// Met une ligne en pause, geste de l utilisateur de la section 4.11.
    ///
    /// L etat `suspendu` sort la tache du calcul du planificateur : elle ne
    /// repartira pas toute seule au retour du Wi-Fi, contrairement a une tache
    /// que le reseau a arretee.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func suspendre(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            guard tache.etat != .termine else {
                return
            }

            tache.etat = .suspendu
        }
    }

    /// Remet une ligne dans la file, apres une pause ou un echec.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func remettreEnAttente(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            guard tache.etat != .termine else {
                return
            }

            tache.etat = .enAttente
            tache.messageErreur = nil
        }
    }

    /// Change le rang de passage d une tache.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func definirLaPriorite(_ priorite: PrioriteDeTelechargement, de identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.priorite = priorite
        }
    }

    /// Abandonne une tache sans retirer ce qui est deja sur le disque.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func annuler(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.etat = .annule
        }
    }

    /// Retire une tache de la file.
    ///
    /// Le dossier du chapitre n est pas supprime ici. Storage n ecrit rien sur
    /// le disque en dehors de la base, et la gestion du stockage de la section
    /// 15 s en charge avec la confirmation qu elle impose.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func retirer(_ identifiant: UUID) throws {
        try base.ecrivain.write { connexion in
            guard try Telechargement.deleteOne(connexion, key: identifiant) else {
                throw ErreurDeTelechargement.tacheInconnue(identifiant: identifiant)
            }
        }
    }

    // MARK: Avancement

    /// Enregistre la longueur du chapitre annoncee par la source.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func noterLaLongueur(de identifiant: UUID, nombreDePages: Int, octetsTotal: Int? = nil) throws {
        try modifier(identifiant) { tache in
            tache.nombreDePages = max(0, nombreDePages)
            tache.octetsTotal = octetsTotal
            tache.pagesTerminees = AvancementDeTelechargement.pagesFaites(
                tache.pagesTerminees,
                sur: tache.nombreDePages
            )
            tache.progression = AvancementDeTelechargement.part(
                tache.pagesTerminees,
                sur: tache.nombreDePages
            )
        }
    }

    /// Enregistre une page scellee et les octets recus depuis le debut.
    ///
    /// La progression est recalculee ici et jamais fournie par l appelant : deux
    /// couches qui la calculeraient chacune de leur cote finiraient par ne pas
    /// dire la meme chose, et la ligne montrerait un anneau qui ne correspond
    /// pas a sa sous ligne.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func noterUnePageScellee(de identifiant: UUID, pagesTerminees: Int, octetsRecus: Int) throws {
        try modifier(identifiant) { tache in
            tache.pagesTerminees = AvancementDeTelechargement.pagesFaites(
                pagesTerminees,
                sur: tache.nombreDePages
            )
            tache.octetsRecus = max(0, octetsRecus)
            tache.progression = AvancementDeTelechargement.part(
                tache.pagesTerminees,
                sur: tache.nombreDePages
            )
        }
    }

    /// Marque une tache comme terminee.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func terminer(_ identifiant: UUID) throws {
        try modifier(identifiant) { tache in
            tache.etat = .termine
            tache.progression = 1
            tache.messageErreur = nil

            if tache.nombreDePages > 0 {
                tache.pagesTerminees = tache.nombreDePages
            }
        }
    }

    /// Marque une tache comme echouee, avec le message destine a l utilisateur.
    ///
    /// Le point de reprise n est pas efface. C est tout l interet de l echec :
    /// la tache repart d ou elle en etait quand l utilisateur la relance.
    ///
    /// - Throws: `ErreurDeTelechargement.tacheInconnue`.
    public func echouer(_ identifiant: UUID, message: String) throws {
        try modifier(identifiant) { tache in
            tache.etat = .echoue
            tache.messageErreur = message
        }
    }

    // MARK: Reglages du sous ecran

    /// Reglages du sous ecran de telechargement.
    public func reglages() throws -> ReglagesDeTelechargement {
        try base.ecrivain.read(Self.reglages)
    }

    /// Remplace le nombre de telechargements simultanes.
    ///
    /// La valeur est ramenee dans les bornes du cahier avant d etre ecrite, ce
    /// qui evite qu une base modifiee a la main fasse ouvrir cinquante
    /// connexions au lancement suivant.
    public func definirLesSimultanes(_ simultanes: Int) throws {
        let borne = ReglagesDeTelechargement(simultanes: simultanes).simultanes

        try base.ecrivain.write { connexion in
            try ReglagePersiste(cle: Self.cleDesSimultanes, valeur: String(borne)).upsert(connexion)
        }
    }

    /// Remplace la restriction au Wi-Fi, ligne 12 de l ecran Reglages.
    public func definirLeWiFiSeulement(_ actif: Bool) throws {
        try base.ecrivain.write { connexion in
            try MagasinDeReglages.ecrire(connexion, .booleen(actif), pour: .enWiFiSeulement)
        }
    }

    // MARK: Acces a la connexion

    /// Modifie une tache en place.
    private func modifier(_ identifiant: UUID, _ changement: (inout Telechargement) -> Void) throws {
        try base.ecrivain.write { connexion in
            guard var tache = try Telechargement.fetchOne(connexion, key: identifiant) else {
                throw ErreurDeTelechargement.tacheInconnue(identifiant: identifiant)
            }

            changement(&tache)

            try tache.update(connexion)
        }
    }
}
