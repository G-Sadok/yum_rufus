import Core
import Foundation

//
// SauvegardeDeProgression
//
// Cadence de sauvegarde de la position de lecture, section 7.5 du cahier de
// developpement : toutes les deux secondes, et a chaque passage en arriere
// plan.
//
// Trois choix structurent ce type.
//
// Le lecteur annonce sa position a chaque page tournee et a chaque geste de
// defilement, sans jamais ecrire. Une ecriture par geste de defilement ferait
// des centaines de transactions par chapitre en webtoon, ce qui se verrait
// immediatement sur le budget de defilement de la section 12.
//
// La sauvegarde n ecrit que si la position a bouge depuis la derniere fois. Une
// echeance qui tombe sur une lecture immobile ne coute donc rien.
//
// Une ecriture qui echoue laisse la position sale. La prochaine echeance la
// reprend telle quelle, plutot que de perdre en silence la seule chose que
// cette fonctionnalite doit garantir.
//

/// Enregistre la position de lecture a intervalle regulier, et sur demande.
public actor SauvegardeDeProgression {
    /// Cadence imposee par la section 7.5.
    public static let cadenceParDefaut: Duration = .seconds(2)

    private let enregistreur: any EnregistreurDePosition
    private let cadence: Duration

    private var positionCourante: PositionDeLecture?
    private var positionEnregistree: PositionDeLecture?
    private var boucle: Task<Void, Never>?

    /// Ecriture la plus recente, gardee pour que deux depots ne se croisent
    /// jamais. Sans cette chaine, une echeance et un passage en arriere plan
    /// tombant ensemble pourraient valider leurs transactions dans le desordre
    /// et reculer la position enregistree.
    private var depotEnCours: Task<Void, Never>?

    /// Derniere erreur d ecriture rencontree, pour l ecran de diagnostic.
    ///
    /// Elle n interrompt jamais la lecture : une position perdue ne justifie pas
    /// de sortir l utilisateur de son chapitre.
    public private(set) var derniereErreur: (any Error)?

    public init(
        enregistreur: any EnregistreurDePosition,
        cadence: Duration = SauvegardeDeProgression.cadenceParDefaut
    ) {
        self.enregistreur = enregistreur
        self.cadence = cadence
    }

    /// Position deja partie en base, pour les tests et le diagnostic.
    public var derniereEnregistree: PositionDeLecture? {
        positionEnregistree
    }

    /// Demarre la cadence. Un second appel ne lance pas une seconde boucle.
    public func demarrer() {
        guard boucle == nil else {
            return
        }

        boucle = Task { [weak self] in
            await self?.boucler()
        }
    }

    /// Annonce la position courante, sans rien ecrire.
    ///
    /// A appeler a chaque page tournee et a chaque arret du defilement. L appel
    /// est volontairement bon marche : il ne touche ni au disque ni a la base.
    public func deplacerVers(_ position: PositionDeLecture) {
        positionCourante = position
    }

    /// Ecrit maintenant, et attend que ce soit fait.
    ///
    /// C est ce que l application appelle au passage en arriere plan. Le systeme
    /// n accorde qu un delai court avant de suspendre le processus : la
    /// sauvegarde doit etre terminee au retour de cet appel, pas simplement
    /// lancee.
    public func enregistrerMaintenant() async {
        await deposer()
    }

    /// Arrete la cadence apres une derniere ecriture.
    ///
    /// A appeler a la fermeture du lecteur. La derniere ecriture n est pas une
    /// precaution superflue : sans elle, fermer un chapitre moins de deux
    /// secondes apres avoir tourne une page perdrait cette page.
    public func arreter() async {
        boucle?.cancel()
        boucle = nil

        await deposer()
    }

    /// Boucle de cadence, arretee par annulation.
    private func boucler() async {
        while Task.isCancelled == false {
            // Le sommeil leve a l annulation. On sort alors sans ecrire, c est
            // `arreter` qui se charge du dernier depot.
            do {
                try await Task.sleep(for: cadence)
            } catch {
                return
            }

            await deposer()
        }
    }

    /// Enfile un depot derriere le precedent et attend son tour.
    private func deposer() async {
        let precedent = depotEnCours

        let depot = Task { [weak self] in
            await precedent?.value
            await self?.ecrireLaPositionSale()
        }

        depotEnCours = depot

        await depot.value
    }

    /// Ecrit la position, si elle a bouge depuis la derniere ecriture reussie.
    private func ecrireLaPositionSale() async {
        guard let position = positionCourante, position != positionEnregistree else {
            return
        }

        do {
            try await enregistreur.enregistrer(position)
            positionEnregistree = position
            derniereErreur = nil
        } catch {
            // La position reste sale : la prochaine echeance reessaie.
            derniereErreur = error
        }
    }
}
