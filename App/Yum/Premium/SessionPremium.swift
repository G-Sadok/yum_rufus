import Core
import DesignSystem
import Foundation
import Observation

//
// Etat de l abonnement dans l application.
//
// Un seul objet porte l etat de l abonnement, la demande de mur en cours et
// l etat de la feuille. Les ecrans le lisent, ils n interrogent jamais la
// boutique eux memes.
//
// L etat de l abonnement n est pas persiste. Il se recalcule depuis les
// transactions a chaque lecture, parce qu un abonnement expire pendant que
// l application est fermee et qu un interrupteur ecrit dans un fichier de
// reglages se modifie de l exterieur.
//
// Le mur ne s ouvre que par `demander`, qui passe par la garde de `Core`. Il n
// existe aucun autre chemin vers la feuille : c est ce qui tient la regle de la
// section 10, le mur ne surgit jamais pendant la lecture.
//

/// Abonnement et mur premium, partages par les ecrans.
@MainActor
@Observable
final class SessionPremium {
    /// Etat de l abonnement, recalcule depuis les transactions.
    private(set) var abonnement: EtatDePremium = .gratuit

    /// Etat de la feuille du mur.
    private(set) var mur: EtatDuMurPremium = .chargement

    /// Demande d ouverture en cours, nulle quand le mur est ferme.
    private(set) var demande: DemandeDuMurPremium?

    private let boutique: any Boutique

    init(boutique: any Boutique = BoutiqueStoreKit()) {
        self.boutique = boutique
    }

    /// Vrai quand les fonctions de la matrice premium sont ouvertes.
    var premiumActif: Bool {
        abonnement.donneAccesAuxFonctionsPremium
    }

    /// Commandes de la feuille, telles que la vue les attend.
    var commandes: CommandesDuMurPremium {
        CommandesDuMurPremium(
            acheter: { [weak self] in Task { await self?.acheter() } },
            restaurer: { [weak self] in Task { await self?.restaurer() } },
            plusTard: { [weak self] in self?.fermer() },
            reessayer: { [weak self] in Task { await self?.lireLesTarifs() } }
        )
    }

    // MARK: Ouverture

    /// Demande l ouverture du mur depuis une commande.
    ///
    /// La garde tranche. Une demande refusee ne montre rien et ne declenche
    /// aucune lecture de tarifs : refuser puis travailler quand meme reviendrait
    /// a payer le cout d un ecran que personne ne verra.
    ///
    /// - Parameters:
    ///   - origine: commande qui demande le mur.
    ///   - declencheur: geste de l utilisateur, ou decision de l application.
    ///   - lectureEnCours: vrai quand un chapitre est ouvert dans le lecteur.
    func demander(
        _ origine: OrigineDuMurPremium,
        declencheur: DeclencheurDuMurPremium = .actionDeLUtilisateur,
        lectureEnCours: Bool = false
    ) {
        let demandee = DemandeDuMurPremium(
            origine: origine,
            declencheur: declencheur,
            lectureEnCours: lectureEnCours
        )

        guard demandee.estAcceptee else {
            return
        }

        demande = demandee

        Task { await lireLesTarifs() }
    }

    /// Referme le mur sans rien acheter.
    func fermer() {
        demande = nil
    }

    // MARK: Boutique

    /// Relit l etat de l abonnement aupres de la boutique.
    func rafraichirLAbonnement() async {
        abonnement = await boutique.etatCourant()
    }

    /// Lit les tarifs et compose l offre du mur.
    func lireLesTarifs() async {
        mur = .chargement

        do {
            let produits = try await boutique.produits()

            guard let produit = CataloguePremium.misEnAvant(parmi: produits) else {
                mur = .erreur

                return
            }

            mur = await .chargee(
                OffrePremium(
                    produit: produit,
                    essaiDisponible: boutique.essaiDisponible()
                )
            )
        } catch {
            mur = .erreur
        }
    }

    /// Achete le produit mis en avant par le mur.
    ///
    /// Un renoncement referme la feuille sans message : la section 6 interdit
    /// d insister, et un echec annonce apres un geste volontaire se lit comme
    /// une insistance.
    func acheter() async {
        guard case let .chargee(offre) = mur else {
            return
        }

        do {
            switch try await boutique.acheter(offre.produit) {
            case .reussi:
                await rafraichirLAbonnement()
                fermer()

            case .annuleParLUtilisateur:
                fermer()

            case .enAttenteDeValidation:
                fermer()
            }
        } catch {
            mur = .erreur
        }
    }

    /// Restaure les achats deja faits sur ce compte.
    ///
    /// Une restauration qui ne trouve rien n est pas une erreur. Le mur reste
    /// ouvert avec son offre : l utilisateur voulait reprendre un acces, il n en
    /// a pas, et l ecran lui laisse le moyen d en prendre un.
    func restaurer() async {
        do {
            let resultat = try await boutique.restaurer()
            abonnement = resultat.etat

            if resultat.etat.donneAccesAuxFonctionsPremium {
                fermer()
            }
        } catch {
            mur = .erreur
        }
    }
}
