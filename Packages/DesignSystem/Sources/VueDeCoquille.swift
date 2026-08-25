import Core
import SwiftUI

//
// Coquille de l application, sections 2.1 a 2.5 de DESIGN-SPEC.md.
//
// Trois formes pour un seul etat : barre laterale deployee sur macOS et iPad
// paysage, barre laterale repliee a 56 sur iPad portrait, barre d onglets basse
// sur iPhone. La destination survit au passage d une forme a l autre.
//
// La disposition n emploie pas `NavigationSplitView`. Le document impose une
// barre encastree, a 12 des bords, avec un rayon de 14, ce que la vue du
// systeme ne sait pas produire : elle colle sa barre laterale au bord et lui
// donne le fond de la fenetre.
//

/// Coquille de l application et sa navigation principale.
public struct VueDeCoquille<Contenu: View, Actions: View>: View {
    @Environment(\.palette) private var palette
    #if !os(macOS)
        @Environment(\.horizontalSizeClass) private var classeHorizontale
    #endif

    private let etat: EtatDeCoquille
    private let entrees: [EntreeDeNavigation]
    private let appelPremium: AppelPremium?
    private let libelleDuRepli: String
    private let actions: (DestinationPrincipale) -> Actions
    private let contenu: (DestinationPrincipale) -> Contenu

    /// Construit la coquille.
    ///
    /// - Parameters:
    ///   - etat: destination courante, presentation et repli.
    ///   - entrees: les cinq entrees, dans l ordre de `DestinationPrincipale`.
    ///   - appelPremium: bloc cale en bas de la barre laterale, facultatif.
    ///   - libelleDuRepli: libelle de la bascule de repli, pris dans le
    ///     catalogue de chaines de l application.
    ///   - actions: commandes de barre d outils propres a une destination.
    ///   - contenu: vue affichee pour une destination.
    public init(
        etat: EtatDeCoquille,
        entrees: [EntreeDeNavigation],
        appelPremium: AppelPremium? = nil,
        libelleDuRepli: String,
        @ViewBuilder actions: @escaping (DestinationPrincipale) -> Actions,
        @ViewBuilder contenu: @escaping (DestinationPrincipale) -> Contenu
    ) {
        self.etat = etat
        self.entrees = entrees
        self.appelPremium = appelPremium
        self.libelleDuRepli = libelleDuRepli
        self.actions = actions
        self.contenu = contenu
    }

    public var body: some View {
        GeometryReader { geometrie in
            let contexte = contexteResolu(pour: geometrie.size)

            corps
                .onAppear { etat.sAdapter(a: contexte) }
                .onChange(of: contexte) { _, nouveau in etat.sAdapter(a: nouveau) }
        }
        .background(palette.surfaces.window.couleur)
    }

    @ViewBuilder
    private var corps: some View {
        if etat.presentation.estUneBarreDOnglets {
            coquilleAOnglets
        } else {
            coquilleALaterale
        }
    }

    private var coquilleALaterale: some View {
        VStack(spacing: 0) {
            BarreDOutilsDeCoquille(titre: titreCourant, bascule: bascule) {
                actions(etat.destination)
            }

            HStack(spacing: 0) {
                BarreLateraleDeNavigation(
                    etat: etat,
                    entrees: entrees,
                    appelPremium: appelPremium
                )
                .padding(Jetons.BarreLaterale.margeDEncastrement)

                zoneDeContenu
            }
        }
        .animation(Jetons.Mouvement.survol.animation, value: etat.barreLateraleRepliee)
    }

    private var coquilleAOnglets: some View {
        VStack(spacing: 0) {
            BarreDOutilsDeCoquille(titre: titreCourant, bascule: nil) {
                actions(etat.destination)
            }

            TabView(selection: destinationSelectionnee) {
                ForEach(entrees) { entree in
                    contenu(entree.destination)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.surfaces.canvas.couleur)
                        .tabItem { Label(entree.libelle, systemImage: entree.symbole) }
                        .tag(entree.destination)
                }
            }
        }
    }

    private var zoneDeContenu: some View {
        ZStack {
            contenu(etat.destination)
                .id(etat.destination)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surfaces.canvas.couleur)
        .animation(Jetons.Mouvement.changementDEcran.animation, value: etat.destination)
    }

    private var bascule: BasculeDeRepli {
        BasculeDeRepli(
            libelle: libelleDuRepli,
            estRepliee: etat.barreLateraleRepliee,
            action: { etat.basculerLeRepliDeLaBarreLaterale() }
        )
    }

    private var titreCourant: String {
        entrees.first { $0.destination == etat.destination }?.libelle ?? ""
    }

    private var destinationSelectionnee: Binding<DestinationPrincipale> {
        Binding(
            get: { etat.destination },
            set: { etat.selectionner($0) }
        )
    }

    /// Contexte deduit de la scene.
    ///
    /// macOS n a qu un gabarit. Sur tactile, la classe de taille horizontale
    /// distingue l iPhone de l iPad, et le rapport largeur sur hauteur distingue
    /// le paysage du portrait.
    private func contexteResolu(pour taille: CGSize) -> ContexteDeCoquille {
        #if os(macOS)
            return ContexteDeCoquille.bureau
        #else
            return ContexteDeCoquille(
                plateforme: .tactile,
                classeHorizontale: classeHorizontale == .compact ? .compacte : .reguliere,
                estEnPaysage: taille.width > taille.height
            )
        #endif
    }
}

extension VueDeCoquille where Actions == EmptyView {
    /// Coquille sans commande de barre d outils.
    ///
    /// Les ecrans qui n en portent aucune, comme Reglages, appellent cette
    /// forme plutot que de passer une vue vide.
    public init(
        etat: EtatDeCoquille,
        entrees: [EntreeDeNavigation],
        appelPremium: AppelPremium? = nil,
        libelleDuRepli: String,
        @ViewBuilder contenu: @escaping (DestinationPrincipale) -> Contenu
    ) {
        self.init(
            etat: etat,
            entrees: entrees,
            appelPremium: appelPremium,
            libelleDuRepli: libelleDuRepli,
            actions: { _ in EmptyView() },
            contenu: contenu
        )
    }
}
