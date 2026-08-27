import SwiftUI

//
// Separateur pose entre deux chapitres enchaines, section 5.8 de DESIGN-SPEC.
//
// Discret par construction. La these du document veut que l interface disparaisse
// devant le dessin, et ce separateur est le seul element d interface qui reste
// visible pendant une lecture continue : un filet a 30 pour cent d opacite et un
// numero en `text.tertiary`, rien de plus.
//
// Le bloc ne peint aucun fond. Il se pose sur le fond du lecteur choisi par
// l utilisateur, comme la page de remplacement, et pour la meme raison.
//

/// Intercalaire qui annonce le chapitre entrant pendant un enchainement.
public struct VueDIntercalaireDeChapitre: View {
    @Environment(\.palette) private var palette

    private let numero: Double
    private let libelles: LibellesDeChapitre

    /// - Parameters:
    ///   - numero: numero du chapitre qui commence.
    ///   - libelles: motifs pris dans le catalogue de chaines.
    public init(numero: Double, libelles: LibellesDeChapitre) {
        self.numero = numero
        self.libelles = libelles
    }

    public var body: some View {
        VStack(spacing: 0) {
            filet

            Text(titre)
                .style(Jetons.Enchainement.numero, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .padding(.vertical, Jetons.Enchainement.margeVerticale)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(titre)
    }

    /// Titre affiche, `Chapitre 118`.
    private var titre: String {
        String(format: libelles.chapitreNumerote, TexteDeChapitre.numero(numero))
    }

    private var filet: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .opacity(Jetons.Enchainement.opaciteDuFilet)
            .frame(height: Jetons.Enchainement.epaisseurDuFilet)
    }
}
