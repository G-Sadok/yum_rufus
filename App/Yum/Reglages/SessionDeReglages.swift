import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeReglages
//
// Porte l ecran Reglages : lit les valeurs depuis la base, les rend a la vue,
// et applique ce que l utilisateur change.
//
// La colonne est toujours complete, section 5.5. Une installation neuve montre
// donc les memes lignes qu une installation ancienne, seules les valeurs
// changent. C est pourquoi l ecran n a pas d etat vide : tant que la base n a
// rien rendu, il montre des squelettes plutot que rien.
//
// Chaque changement part en base immediatement. Un reglage qui ne serait ecrit
// qu a la fermeture de l ecran se perdrait au premier arret brutal, et
// l utilisateur croirait avoir regle ce qu il n a pas regle.
//

@MainActor
@Observable
final class SessionDeReglages {
    /// Etat rendu a la vue.
    private(set) var etat: EtatDeReglages = .chargement

    /// Derniere erreur d ecriture, posee en banniere au dessus de la colonne.
    private(set) var banniere: BanniereDErreurDeReglages?

    /// Ecran ouvert par dessus la colonne, nul quand elle est seule.
    var ecranOuvert: EcranDeReglages?

    private let magasin: MagasinDeReglages?

    init(magasin: MagasinDeReglages?) {
        self.magasin = magasin
    }

    /// Relit les valeurs et recompose l ecran.
    func recharger() {
        guard let magasin else { return }

        do {
            etat = .chargee(PresentationDeReglages(reglages: try magasin.reglages()))
            banniere = nil
        } catch {
            signaler(error)
        }
    }

    /// Commandes offertes aux lignes de la colonne.
    var commandes: CommandesDeReglages {
        CommandesDeReglages(
            basculer: { [weak self] identifiant, actif in
                self?.ecrire(.booleen(actif), pour: identifiant)
            },
            choisir: { [weak self] identifiant, choix in
                self?.ecrire(.choix(choix), pour: identifiant)
            },
            regler: { [weak self] identifiant, valeur in
                self?.ecrire(.curseur(valeur), pour: identifiant)
            },
            compter: { [weak self] identifiant, nombre in
                self?.ecrire(.compteur(nombre), pour: identifiant)
            },
            ouvrir: { [weak self] identifiant in
                // Seules les lignes dont l ecran existe ouvrent quelque chose.
                // Les autres restent inertes : une feuille vide couterait plus
                // cher a l utilisateur qu un clic sans effet.
                self?.ecranOuvert = EcranDeReglages(ligne: identifiant)
            }
        )
    }

    /// Ecrit une valeur, puis relit pour que l affichage suive la base et non
    /// une copie locale qui pourrait diverger.
    private func ecrire(_ valeur: ValeurDeReglage, pour identifiant: IdentifiantDeReglage) {
        guard let magasin else { return }

        do {
            try magasin.definir(valeur, pour: identifiant)
            recharger()
        } catch {
            signaler(error)
        }
    }

    private func signaler(_ erreur: any Error) {
        // La banniere ne remplace jamais la colonne, section 5.5 : une ecriture
        // ratee n empeche pas de lire ni de changer les autres reglages.
        banniere = BanniereDErreurDeReglages(
            titre: Chaines.Erreur.reglagesTitre,
            phrase: Chaines.Erreur.reglagesPhrase,
            reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                self?.recharger()
            },
            ouvrirLesReglagesDuSysteme: ActionDEtat(
                libelle: Chaines.Erreur.ouvrirLesReglagesDuSysteme
            ) {
                // L ecran Reglages du systeme n a rien a regler ici : l erreur
                // vient de la base de l application, pas d une autorisation.
            }
        )

        NSLog("Reglages : %@", String(describing: erreur))
    }
}

/// Ecran pose par dessus la colonne de reglages.
///
/// Les trois que la coquille sait presenter aujourd hui. Une ligne de
/// navigation dont l ecran n existe pas encore ne rend rien, et la colonne
/// reste ou elle est.
enum EcranDeReglages: String, Identifiable {
    case statistiques
    case stockage
    case prereglages

    var id: String { rawValue }

    init?(ligne: IdentifiantDeReglage) {
        switch ligne {
        case .statistiquesDeLecture: self = .statistiques
        case .detailDuStockage: self = .stockage
        case .prereglages: self = .prereglages
        default: return nil
        }
    }
}
