import Core
import Foundation
import SwiftUI

//
// Fiche de serie, section 5.6 de DESIGN-SPEC.md.
//
// Deux zones et une regle : la banniere de 300 en gabarit large, le corps en
// gabarit colonne de 580, et l en tete qui reste intact quel que soit l etat de
// la liste. Une source qui ne repond plus fait apparaitre une erreur dans la
// zone de liste, elle ne fait pas disparaitre le titre de la serie ni le bouton
// de reprise.
//

/// Fiche complete d une serie.
public struct VueDeFicheDeSerie<Couverture: View>: View {
    @Environment(\.palette) private var palette

    private let entete: EnTeteDeSerie
    private let etat: EtatDeListeDeChapitres
    private let resume: String?
    private let etatVide: EtatDeContenu
    private let libelles: LibellesDeFicheDeSerie
    private let actions: ActionsDeFicheDeSerie
    private let selection: SelectionDeChapitres
    private let commandes: CommandesDeListeDeChapitres
    private let revenir: @MainActor () -> Void
    private let couverture: Couverture

    /// Construit la fiche.
    ///
    /// - Parameters:
    ///   - entete: metadonnees deja composees.
    ///   - etat: etat de la zone de liste.
    ///   - resume: resume de la serie, replie a trois lignes.
    ///   - etatVide: etat vide compose par l appelant, tableau 6.3.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - actions: ce que declenchent les quatre boutons de l en tete.
    ///   - selection: chapitres retenus par la selection multiple.
    ///   - commandes: ce que declenchent les actions de la liste.
    ///   - couverture: vue de la couverture, nette et floutee.
    public init(
        entete: EnTeteDeSerie,
        etat: EtatDeListeDeChapitres,
        resume: String?,
        etatVide: EtatDeContenu,
        libelles: LibellesDeFicheDeSerie,
        actions: ActionsDeFicheDeSerie,
        selection: SelectionDeChapitres,
        commandes: CommandesDeListeDeChapitres,
        revenir: @escaping @MainActor () -> Void,
        @ViewBuilder couverture: () -> Couverture
    ) {
        self.entete = entete
        self.etat = etat
        self.resume = resume
        self.etatVide = etatVide
        self.libelles = libelles
        self.actions = actions
        self.selection = selection
        self.commandes = commandes
        self.revenir = revenir
        self.couverture = couverture()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            barreDeRetour

            corps
        }
        .background(palette.surfaces.canvas.couleur)
    }

    /// Le retour vers l ecran d ou la fiche a ete ouverte.
    ///
    /// La fiche se pose par dessus la coquille et couvre sa barre laterale.
    /// Sans ce bouton, une serie ouverte n a aucune sortie : elle porte son
    /// propre retour parce qu elle a masque celui de la coquille.
    private var barreDeRetour: some View {
        HStack(spacing: 0) {
            Button(action: revenir) {
                Label(libelles.retour, systemImage: Jetons.IconeDeRecherche.retour)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(BoutonDiscret(style: Jetons.FicheDeSerie.lienDeRetour))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Jetons.Contenu.margeLaterale)
        .frame(height: Jetons.BarreDOutils.hauteur)
    }

    private var corps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VueDEnTeteDeSerie(
                    entete: entete,
                    action: actionPrincipale,
                    libelles: libelles,
                    actions: actions
                ) {
                    couverture
                }

                VueDeListeDeChapitres(
                    etat: etat,
                    resume: resume,
                    etatVide: etatVide,
                    libelles: libelles,
                    selection: selection,
                    commandes: commandes
                )
                .padding(.horizontal, Jetons.Contenu.margeLaterale)
                .padding(.top, Jetons.FicheDeSerie.ecartDansLeCorps)
            }
        }
    }

    /// Cas du bouton principal.
    ///
    /// Tant que la liste n est pas lue, la serie n expose aucun chapitre connu,
    /// et le document desactive alors le bouton. C est la seule reponse honnete
    /// pendant un chargement : proposer `Commencer la lecture` avant de savoir
    /// s il y a quelque chose a lire ouvrirait sur du vide.
    private var actionPrincipale: ActionPrincipaleDeFiche {
        guard case let .chargee(fiche) = etat else {
            return .aucunChapitre
        }

        return fiche.actionPrincipale
    }
}
