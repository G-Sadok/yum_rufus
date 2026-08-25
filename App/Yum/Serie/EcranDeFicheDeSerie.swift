import Core
import DesignSystem
import Foundation
import Storage
import SwiftUI

//
// Ecran de fiche de serie, section 5.6 de DESIGN-SPEC.md.
//
// L ecran relie trois choses et n en decide aucune : le magasin de Storage, qui
// lit et ecrit, le composant de DesignSystem, qui affiche, et le catalogue de
// chaines, qui nomme.
//
// La navigation vers cet ecran arrive avec la grille de la bibliotheque. Tant
// qu elle n existe pas, l ecran s ouvre sur une serie designee par son
// identifiant, ce que la grille fera elle aussi.
//

/// Etat observable de la fiche d une serie.
@MainActor
@Observable
final class EtatDeFicheDeSerie {
    /// Etat de la zone de liste.
    private(set) var etat: EtatDeListeDeChapitres = .chargement

    /// Chapitres retenus par la selection multiple.
    private(set) var selection = SelectionDeChapitres()

    /// Serie affichee.
    let serie: UUID

    private let magasin: MagasinDeFicheDeSerie

    init(serie: UUID, magasin: MagasinDeFicheDeSerie) {
        self.serie = serie
        self.magasin = magasin
    }

    /// Fiche chargee, nulle tant que la liste n est pas lue.
    var fiche: FicheDeSerie? {
        guard case let .chargee(fiche) = etat else {
            return nil
        }

        return fiche
    }

    /// Lit la fiche et sa liste de chapitres.
    ///
    /// L echec ne fait pas disparaitre l en tete : il remplit la seule zone de
    /// liste, comme la section 5.6 l impose.
    func charger() {
        do {
            let fiche = try magasin.fiche(deLaSerie: serie)
            etat = .chargee(fiche)
            selection.restreindre(a: fiche.chapitres)
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Enregistre un filtre et un tri, puis relit la liste.
    func definir(_ reglage: ReglageDeListeDeChapitres) {
        do {
            try magasin.definirLeReglage(reglage, pourSerie: serie)
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Bascule un chapitre dans la selection multiple.
    func basculer(_ chapitre: UUID) {
        selection.basculer(chapitre)
    }

    /// Etend la selection depuis son ancre.
    func etendre(jusqua chapitre: UUID) {
        selection.etendre(jusqua: chapitre, dans: fiche?.chapitres ?? [])
    }

    /// Vide la selection et referme la barre d actions.
    func viderLaSelection() {
        selection.vider()
    }

    /// Execute une action de la barre de selection.
    ///
    /// Le telechargement et la suppression de chapitres arrivent avec l etape 6
    /// du cahier de developpement. Les declencher ici avant qu ils existent
    /// donnerait un bouton qui ment.
    func executer(_ action: ActionDeSelectionDeChapitres) {
        guard action == .marquerLu else {
            return
        }

        do {
            try magasin.marquer(Array(selection.identifiants), commeLus: true)
            selection.vider()
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Marque toute la serie comme lue.
    func marquerToutLu() {
        do {
            try magasin.marquerToutLu(pourSerie: serie)
            charger()
        } catch {
            etat = .erreur(erreurDeLecture())
        }
    }

    /// Etat d erreur de la zone de liste, tableau 6.4.
    ///
    /// La phrase nomme la source reelle et le nombre reel de chapitres deja
    /// telecharges. Faute de fiche lue, elle nomme au moins la serie demandee.
    private func erreurDeLecture() -> EtatDeContenu {
        let source = fiche?.nomDeLaSource ?? ""
        let telecharges = fiche?.chapitres.count { $0.estTelecharge } ?? 0

        return .erreur(
            titre: Chaines.Erreur.ficheDeSerieTitre,
            phrase: String(format: Chaines.Erreur.ficheDeSeriePhrase, source, telecharges),
            reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                self?.charger()
            },
            repli: nil
        )
    }
}

/// Fiche de serie telle que l application l assemble.
struct EcranDeFicheDeSerie: View {
    /// Etat de l ecran.
    let etat: EtatDeFicheDeSerie

    /// Ouvre un chapitre dans le lecteur.
    let ouvrirLeChapitre: (UUID) -> Void

    /// Revient a la bibliotheque.
    let revenir: () -> Void

    var body: some View {
        VueDeFicheDeSerie(
            entete: entete,
            etat: etat.etat,
            resume: etat.fiche?.serie.resume,
            etatVide: etatVide,
            libelles: .duCatalogue,
            actions: actions,
            selection: etat.selection,
            commandes: commandes
        ) {
            CouvertureDeSerie()
        }
        .onAppear { etat.charger() }
    }

    private var entete: EnTeteDeSerie {
        guard let fiche = etat.fiche else {
            return EnTeteDeSerie(titre: "", auteurs: "", ligneDEtat: "", genres: [])
        }

        return MetadonneesDeSerie.enTete(de: fiche.serie, nomDeLaSource: fiche.nomDeLaSource)
    }

    /// Etat vide de la fiche, tableau 6.3.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Icone.bibliotheque,
            titre: Chaines.EtatVide.ficheDeSerieTitre,
            phrase: Chaines.EtatVide.ficheDeSeriePhrase,
            action: ActionDEtat(libelle: Chaines.EtatVide.ficheDeSerieAction) {}
        )
    }

    /// Les quatre actions de l en tete.
    ///
    /// Le suivi et la liste personnelle arrivent avec les etapes 7 et 9 du
    /// cahier de developpement. Le bouton principal, lui, ouvre bien le
    /// chapitre que Core a designe.
    private var actions: ActionsDeFicheDeSerie {
        ActionsDeFicheDeSerie(
            principale: { [ouvrirLeChapitre] in
                Task { @MainActor in
                    guard let chapitre = etat.fiche?.actionPrincipale.chapitreAOuvrir else {
                        return
                    }

                    ouvrirLeChapitre(chapitre)
                }
            },
            dansMaListe: {},
            suivre: {},
            options: {}
        )
    }

    private var commandes: CommandesDeListeDeChapitres {
        CommandesDeListeDeChapitres(
            filtrer: { [etat] in Task { @MainActor in etat.definir(etat.filtreSuivant()) } },
            trier: { [etat] in Task { @MainActor in etat.definir(etat.triInverse()) } },
            toutMarquerLu: { [etat] in Task { @MainActor in etat.marquerToutLu() } },
            ouvrir: { [ouvrirLeChapitre] chapitre in
                Task { @MainActor in ouvrirLeChapitre(chapitre) }
            },
            basculerLaSelection: { [etat] chapitre in
                Task { @MainActor in etat.basculer(chapitre) }
            },
            etendreLaSelection: { [etat] chapitre in
                Task { @MainActor in etat.etendre(jusqua: chapitre) }
            },
            executer: { [etat] action in Task { @MainActor in etat.executer(action) } },
            viderLaSelection: { [etat] in Task { @MainActor in etat.viderLaSelection() } }
        )
    }
}

extension EtatDeFicheDeSerie {
    /// Filtre suivant dans l ordre de l enumeration.
    ///
    /// Le menu de filtre est un menu contextuel que la section 5.6 nomme sans
    /// le dessiner. En attendant son dessin, l action fait defiler les quatre
    /// valeurs, ce qui suffit a rendre le filtre atteignable et persistant.
    func filtreSuivant() -> ReglageDeListeDeChapitres {
        var reglage = fiche?.reglage ?? .defaut
        let valeurs = FiltreDeChapitres.allCases
        let rang = valeurs.firstIndex(of: reglage.filtre) ?? 0

        reglage.filtre = valeurs[(rang + 1) % valeurs.count]

        return reglage
    }

    /// Meme critere de tri, sens inverse.
    func triInverse() -> ReglageDeListeDeChapitres {
        var reglage = fiche?.reglage ?? .defaut
        reglage.ordre = reglage.ordre == .croissant ? .decroissant : .croissant

        return reglage
    }
}

/// Couverture de la serie.
///
/// Le chargement des couvertures arrive avec la grille de la bibliotheque, qui
/// pose le meme besoin sur cinq colonnes. En attendant, la fiche montre une
/// surface du systeme plutot qu une image absente.
private struct CouvertureDeSerie: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.surfaces.cardHover.couleur
    }
}
