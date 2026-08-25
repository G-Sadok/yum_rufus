import Core
import DesignSystem
import Foundation
import Storage
import SwiftUI

//
// Ecran Historique, section 5.2 de DESIGN-SPEC.md.
//
// L ecran relie trois choses et n en decide aucune : le magasin de Storage, qui
// lit et ecrit, le composant de DesignSystem, qui affiche, et le catalogue de
// chaines, qui nomme.
//

/// Etat observable de l historique.
@MainActor
@Observable
final class EtatDHistorique {
    /// Etat de la zone de contenu.
    private(set) var etat: EtatDeListeDHistorique = .chargement

    /// Demande d effacement global, ouverte par la barre d outils.
    private(set) var effacement = ConfirmationRequise()

    private let magasin: MagasinDHistorique?

    init(magasin: MagasinDHistorique?) {
        self.magasin = magasin
    }

    /// Vrai quand la liste porte au moins une entree.
    ///
    /// La barre d outils s en sert : une commande `Effacer l historique` posee
    /// au dessus d un historique deja vide n a rien a effacer.
    var porteDesEntrees: Bool {
        guard case let .chargee(journees) = etat else {
            return false
        }

        return journees.isEmpty == false
    }

    /// Lit l historique et le groupe par jour.
    func charger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())
            return
        }

        do {
            etat = try .chargee(magasin.journees())
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Retire une entree, bouton de suppression de la section 5.2.
    func supprimer(_ entree: UUID) {
        guard let magasin else {
            return
        }

        do {
            try magasin.supprimer(entree)
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Ouvre la modale de confirmation, sans rien effacer.
    func demanderLEffacement() {
        effacement.demander()
    }

    /// Referme la modale sans rien effacer.
    func annulerLEffacement() {
        effacement.annuler()
    }

    /// Efface tout l historique, une fois la confirmation donnee.
    ///
    /// La garde est dans `ConfirmationRequise` et non dans la vue : une modale
    /// que l on oublierait d afficher ne se verrait pas, un effacement sans
    /// demande se voit au test.
    func confirmerLEffacement() {
        guard effacement.confirmer(), let magasin else {
            return
        }

        do {
            try magasin.effacer()
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Repart d un historique vide, action de l erreur du tableau 6.4.
    func repartirDeZero() {
        guard let magasin else {
            return
        }

        do {
            try magasin.effacer()
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Etat d erreur de la zone de contenu, tableau 6.4.
    ///
    /// Le tableau ne donne qu une action a cet ecran, `Repartir de zero`. Elle
    /// occupe donc la place du bouton de reprise, en variante secondaire comme
    /// l impose la section 4.10, et aucun second bouton n est invente.
    private func erreurDeLecture() -> EtatDeContenu {
        .erreur(
            titre: Chaines.Erreur.historiqueTitre,
            phrase: Chaines.Erreur.historiquePhrase,
            reessayer: ActionDEtat(libelle: Chaines.Erreur.historiqueRepartirDeZero) { [weak self] in
                self?.repartirDeZero()
            },
            repli: nil
        )
    }
}

/// Historique tel que l application l assemble.
struct EcranDHistorique: View {
    /// Etat de l ecran.
    let etat: EtatDHistorique

    /// Ouvre un chapitre dans le lecteur, nulle tant que la coquille n en
    /// expose aucun.
    let ouvrirLeChapitre: (@MainActor (UUID) -> Void)?

    /// Ouvre la bibliotheque, action de l etat vide du tableau 6.3.
    let ouvrirLaBibliotheque: () -> Void

    var body: some View {
        VueDHistorique(
            etat: etat.etat,
            etatVide: etatVide,
            effacementDemande: etat.effacement.estDemandee,
            libelles: .duCatalogue,
            commandes: commandes
        ) { _ in
            VignetteDeSerie()
        }
        .onAppear { etat.charger() }
    }

    /// Etat vide de l historique, tableau 6.3, au mot pres.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Icone.historique,
            titre: Chaines.EtatVide.historiqueTitre,
            phrase: Chaines.EtatVide.historiquePhrase,
            action: ActionDEtat(libelle: Chaines.EtatVide.historiqueAction, action: ouvrirLaBibliotheque)
        )
    }

    @MainActor
    private var commandes: CommandesDHistorique {
        CommandesDHistorique(
            ouvrir: ouvrirLeChapitre,
            supprimer: { [etat] entree in etat.supprimer(entree) },
            annulerLEffacement: { [etat] in etat.annulerLEffacement() },
            confirmerLEffacement: { [etat] in etat.confirmerLEffacement() }
        )
    }
}

/// Vignette de la serie, 44 par 66.
///
/// Le chargement des couvertures arrive avec la grille de la bibliotheque, qui
/// pose le meme besoin sur cinq colonnes et impose le decodage sous
/// echantillonne. En attendant, l historique montre une surface du systeme
/// plutot qu une image absente.
private struct VignetteDeSerie: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.surfaces.cardHover.couleur
    }
}
