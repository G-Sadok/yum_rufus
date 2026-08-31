import Core
import SwiftUI

//
// Pieces du parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md.
//
// L ecran vit dans `VueDePremiereOuverture`, ses quatre pieces vivent ici : les
// points de progression, la carte de sens de lecture, la ligne de source et la
// rangee de commandes. Le decoupage suit la responsabilite et non la longueur.
// L ecran dit dans quel ordre les etapes viennent, ces types disent a quoi
// chaque element ressemble, et aucun des deux n a besoin de relire l autre.
//

/// Points de progression, en haut a droite, section 5.10.
struct PointsDeProgression: View {
    @Environment(\.palette) private var palette

    let etape: EtapeDePremiereOuverture
    let libelles: LibellesDePremiereOuverture

    var body: some View {
        HStack(spacing: Jetons.PremiereOuverture.ecartEntreLesPoints) {
            ForEach(EtapeDePremiereOuverture.allCases) { candidate in
                Circle()
                    .fill(palette.semantiques.accent.couleur)
                    .opacity(opacite(de: candidate))
                    .frame(
                        width: Jetons.PremiereOuverture.diametreDuPoint,
                        height: Jetons.PremiereOuverture.diametreDuPoint
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel(
            TexteDePremiereOuverture.etiquetteDeProgression(de: etape, libelles: libelles)
        )
    }

    private func opacite(de candidate: EtapeDePremiereOuverture) -> Double {
        candidate == etape ? 1 : Jetons.PremiereOuverture.opaciteDuPointInactif
    }
}

/// Une carte de sens de lecture, 300 de large, section 5.10.
struct CarteDeSensDeLecture: View {
    @Environment(\.palette) private var palette

    let sens: SensDeLecture
    let choisi: Bool
    let libelles: LibellesDePremiereOuverture
    let choisir: () -> Void

    var body: some View {
        Button(action: choisir) {
            VStack(spacing: Jetons.PremiereOuverture.ecartApresLeTitre) {
                apercu

                Text(libelles.libelle(de: sens))
                    .style(Jetons.PremiereOuverture.libelleDeSource)
                    .foregroundStyle(palette.textes.primary.couleur)
            }
            .padding(Jetons.PremiereOuverture.margeDeLigneDeSource)
            .frame(width: Jetons.PremiereOuverture.largeurDeCarte)
            .background(fond)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisi ? [.isButton, .isSelected] : .isButton)
    }

    /// Apercu de deux pages numerotees, section 5.10.
    ///
    /// La page 1 se place du cote d ou la lecture part. C est le seul endroit
    /// du produit ou le sens de lecture se montre au lieu de s appliquer, et
    /// l ordre des deux pages est donc calcule par le modele, jamais ecrit.
    private var apercu: some View {
        HStack(spacing: Jetons.PremiereOuverture.gouttiereDeLApercu) {
            ForEach(numerosOrdonnes, id: \.self) { numero in
                RoundedRectangle(
                    cornerRadius: Jetons.PremiereOuverture.rayonDeLApercu,
                    style: .continuous
                )
                .fill(palette.surfaces.card.couleur)
                .overlay {
                    Text(numero.description)
                        .style(Jetons.PremiereOuverture.numeroDePage)
                        .foregroundStyle(palette.textes.tertiary.couleur)
                }
            }
        }
        .frame(height: Jetons.PremiereOuverture.hauteurDeCarte)
        .accessibilityElement()
        .accessibilityLabel(libelles.apercuDuSens)
    }

    /// Numeros des deux pages, de gauche a droite a l ecran.
    private var numerosOrdonnes: [Int] {
        sens.commenceParLaDroite ? [2, 1] : [1, 2]
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.PremiereOuverture.rayonDeCarte, style: .continuous)
            .fill(palette.surfaces.card.couleur)
            .overlay {
                RoundedRectangle(
                    cornerRadius: Jetons.PremiereOuverture.rayonDeCarte,
                    style: .continuous
                )
                .strokeBorder(couleurDuContour, lineWidth: epaisseurDuContour)
            }
    }

    private var couleurDuContour: Color {
        choisi ? palette.semantiques.accent.couleur : palette.semantiques.border.couleur
    }

    private var epaisseurDuContour: Double {
        choisi ? Jetons.PremiereOuverture.epaisseurDuContourActif : Jetons.Fenetre.epaisseurDuFilet
    }
}

/// Une ligne de source de la deuxieme etape, hauteur 72, section 5.10.
struct LigneDeSourceInitiale: View {
    @Environment(\.palette) private var palette

    let type: TypeDeSource
    let etat: EtatDeLaSourceInitiale
    let libelles: LibellesDePremiereOuverture
    let ajouter: () -> Void

    var body: some View {
        Button(action: ajouter) {
            HStack(spacing: Jetons.PremiereOuverture.ecartApresLeSymbole) {
                Image(systemName: Jetons.PremiereOuverture.symbole(de: type))
                    .font(.system(size: Jetons.PremiereOuverture.tailleDuSymboleDeSource))
                    .foregroundStyle(palette.semantiques.accent.couleur)
                    .accessibilityHidden(true)

                textes

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Jetons.PremiereOuverture.margeDeLigneDeSource)
            .frame(
                maxWidth: .infinity,
                minHeight: Jetons.PremiereOuverture.hauteurDeLigneDeSource,
                alignment: .leading
            )
            .background(fond)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textes: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.x1) {
            Text(libelles.libelle(de: type))
                .style(Jetons.PremiereOuverture.libelleDeSource)
                .foregroundStyle(palette.textes.primary.couleur)

            if let sousLigne {
                Text(sousLigne)
                    .style(Jetons.PremiereOuverture.etatDeSource)
                    .foregroundStyle(couleurDeLaSousLigne)
            }
        }
    }

    /// Sous ligne d etat, absente tant que cette source n a rien a dire.
    private var sousLigne: String? {
        TexteDePremiereOuverture.sousLigne(de: etat, pour: type, libelles: libelles)
    }

    /// L echec se dit en couleur et en toutes lettres, jamais en couleur seule.
    private var couleurDeLaSousLigne: Color {
        guard case .injoignable = etat, etat.type == type else {
            return palette.textes.tertiary.couleur
        }

        return palette.lisible(palette.semantiques.danger, sur: [palette.surfaces.card]).couleur
    }

    private var fond: some View {
        RoundedRectangle(
            cornerRadius: Jetons.PremiereOuverture.rayonDeLigneDeSource,
            style: .continuous
        )
        .fill(palette.surfaces.card.couleur)
    }
}

/// Rangee des commandes d une etape, tableau 6.5.
///
/// Les boutons sont construits en parcourant la liste que le modele rend, et
/// chacun prend le gabarit que les jetons lui donnent. Deux commandes de meme
/// gabarit occupent donc exactement la meme place a l ecran.
struct RangeeDeCommandes: View {
    let commandes: [CommandeDePremiereOuverture]
    let libelles: LibellesDePremiereOuverture
    let executer: @MainActor (CommandeDePremiereOuverture) -> Void

    var body: some View {
        HStack(spacing: Jetons.PremiereOuverture.ecartEntreLesBoutons) {
            ForEach(commandes) { commande in
                bouton(commande)
            }
        }
    }

    @ViewBuilder
    private func bouton(_ commande: CommandeDePremiereOuverture) -> some View {
        let gabarit = Jetons.PremiereOuverture.gabarit(de: commande)
        let action = { executer(commande) }

        if commande == .plusTard {
            Button(libelles.libelle(de: commande), action: action)
                .buttonStyle(BoutonSecondaire(hauteur: gabarit.hauteur, rayon: gabarit.rayon))
                .frame(width: gabarit.largeur)
                .keyboardShortcut(.cancelAction)
        } else {
            Button(libelles.libelle(de: commande), action: action)
                .buttonStyle(BoutonPrincipal(hauteur: gabarit.hauteur, rayon: gabarit.rayon))
                .frame(width: gabarit.largeur)
                .keyboardShortcut(.defaultAction)
        }
    }
}
