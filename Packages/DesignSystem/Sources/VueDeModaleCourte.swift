import SwiftUI

//
// Modale courte, section 4.8 de DESIGN-SPEC.md.
//
// 380 par 196, rayon 20, fond `surface.sheet` avec contour, elevation 2 sur
// voile. Deux capsules de 150 par 34 en pied, la confirmation a droite.
//
// La modale se pose en superposition de l ecran qui la demande, et non dans une
// fenetre du systeme. C est ce qui permet au voile de couvrir exactement la
// zone de contenu, et au declencheur de rester dans la hierarchie pour
// recuperer le focus a la fermeture.
//

/// Contenu d une modale courte de confirmation.
public struct ContenuDeModaleCourte {
    /// Titre, 16 en graisse 700.
    public let titre: String

    /// Description, deux lignes maximum.
    public let description: String

    /// Action de gauche, qui referme sans rien faire.
    public let annuler: ActionDEtat

    /// Action de droite, qui execute.
    public let confirmer: ActionDEtat

    /// Vrai quand la confirmation detruit quelque chose.
    ///
    /// Le bouton passe alors en variante destructive du tableau 4.6, sans
    /// aplat : ce qui detruit n est pas ce qui attire l oeil.
    public let confirmationEstDestructive: Bool

    public init(
        titre: String,
        description: String,
        annuler: ActionDEtat,
        confirmer: ActionDEtat,
        confirmationEstDestructive: Bool = false
    ) {
        self.titre = titre
        self.description = description
        self.annuler = annuler
        self.confirmer = confirmer
        self.confirmationEstDestructive = confirmationEstDestructive
    }
}

/// Modale courte, section 4.8.
public struct VueDeModaleCourte: View {
    @Environment(\.palette) private var palette

    private let contenu: ContenuDeModaleCourte

    public init(_ contenu: ContenuDeModaleCourte) {
        self.contenu = contenu
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(contenu.titre)
                .style(Jetons.Modale.titre)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.Modale.ecartApresLeTitre)

            Text(contenu.description)
                .style(Jetons.Modale.description)
                .foregroundStyle(palette.textes.secondary.couleur)
                .lineLimit(Jetons.Modale.lignesDeDescription)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Jetons.Modale.ecartAvantLesBoutons)

            boutons
        }
        .padding(.horizontal, Jetons.Modale.margeHaute)
        .padding(.top, Jetons.Modale.margeHaute)
        .padding(.bottom, Jetons.Modale.margeBasse)
        .frame(width: Jetons.Modale.largeur, alignment: .leading)
        .frame(minHeight: Jetons.Modale.hauteurDeReference, alignment: .top)
        .background(fond)
        .elevation(Jetons.Modale.elevation, rayon: Jetons.Modale.rayon, palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Modale.rayon, style: .continuous)
            .fill(palette.surfaces.sheet.couleur)
            .overlay {
                RoundedRectangle(cornerRadius: Jetons.Modale.rayon, style: .continuous)
                    .strokeBorder(
                        palette.semantiques.border.couleur,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }

    private var boutons: some View {
        HStack(spacing: Jetons.Modale.gouttiereEntreBoutons) {
            Button(contenu.annuler.libelle, action: contenu.annuler.action)
                .buttonStyle(
                    BoutonSecondaire(
                        hauteur: Jetons.Modale.hauteurDeBouton,
                        rayon: Jetons.Modale.rayonDeBouton
                    )
                )
                .frame(width: Jetons.Modale.largeurDeBouton)
                // La touche d echappement referme la modale, section 4.8.
                .keyboardShortcut(.cancelAction)

            confirmation
                .frame(width: Jetons.Modale.largeurDeBouton)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var confirmation: some View {
        if contenu.confirmationEstDestructive {
            Button(contenu.confirmer.libelle, action: contenu.confirmer.action)
                .buttonStyle(
                    BoutonDestructif(
                        hauteur: Jetons.Modale.hauteurDeBouton,
                        rayon: Jetons.Modale.rayonDeBouton
                    )
                )
        } else {
            Button(contenu.confirmer.libelle, action: contenu.confirmer.action)
                .buttonStyle(
                    BoutonPrincipal(
                        hauteur: Jetons.Modale.hauteurDeBouton,
                        rayon: Jetons.Modale.rayonDeBouton
                    )
                )
        }
    }
}

extension View {
    /// Presente une modale courte au dessus de cette vue, section 4.8.
    ///
    /// Le voile `scrim` couvre la vue, absorbe le clic et le renvoie sur
    /// Annuler, comme le demande la section 4.8. La vue appelante reste dans la
    /// hierarchie, donc le focus revient a l element declencheur quand la
    /// modale disparait.
    ///
    /// - Parameters:
    ///   - presentee: vrai quand la modale doit etre visible.
    ///   - contenu: titre, description et deux actions.
    public func modaleCourte(
        presentee: Bool,
        contenu: ContenuDeModaleCourte
    ) -> some View {
        modifier(ModaleCourtePresentee(presentee: presentee, contenu: contenu))
    }
}

/// Voile et modale poses au dessus d une vue.
private struct ModaleCourtePresentee: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites

    let presentee: Bool
    let contenu: ContenuDeModaleCourte

    func body(content: Content) -> some View {
        content
            .overlay { superposition }
            .animation(animation, value: presentee)
    }

    @ViewBuilder
    private var superposition: some View {
        if presentee {
            ZStack {
                voile
                VueDeModaleCourte(contenu)
            }
            .transition(.opacity)
        }
    }

    private var voile: some View {
        palette.semantiques.scrim.couleur
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: contenu.annuler.action)
            .accessibilityHidden(true)
    }

    private var animation: Animation? {
        animationsReduites
            ? Jetons.Mouvement.animationsReduites.animation
            : Jetons.Mouvement.modale.animation
    }
}
