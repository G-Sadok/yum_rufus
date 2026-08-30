import Core
import SwiftUI

//
// Surimpression du texte traduit sur une bulle floutee, section 8 du cahier de
// developpement.
//
// La vue ne decide rien. Elle recoit des bulles deja traduites et deja
// composees, et se contente de les poser au bon endroit. Les trois decisions qui
// comptent sont prises ailleurs, exactement la ou elles se testent.
//
// Ou couper les lignes et a quel corps ecrire : `MiseEnPageDeBulle`, dans le
// modele, avec la mesure exacte de la police. C est la piece qui garantit que
// rien ne deborde, et elle est verifiee ligne par ligne par sa propre suite de
// tests.
//
// Quel moteur a produit le texte et si l accord a ete donne :
// `ReglagesDeTraduction`, dans le modele. La vue ne lit jamais le menu
// directement, elle lirait le moteur choisi la ou seul le moteur effectif compte.
//
// Dans quel ordre les bulles se lisent : le sens de lecture de la serie, jamais
// la direction de l interface. La vue ne trie rien, elle affiche la suite telle
// que l acteur la rend.
//
// Ce que la vue decide, en revanche, c est de ne rien poser sur une bulle dont
// la traduction n apporte rien. Une bulle inchangee, parce que la planche est
// deja dans la langue cible, garde son dessin : la recouvrir pour y reecrire ce
// qu elle disait deja masquerait le trait pour rien, et la these de la section 0
// veut que l interface disparaisse.
//

/// Bulle traduite et son texte deja compose, prets a etre poses.
public struct BulleAAfficher: Identifiable, Equatable {
    /// Bulle traduite, avec son cadre et ses deux textes.
    public let traduction: TraductionDeBulle

    /// Texte compose par le modele, qui tient dans le cadre.
    public let composition: TexteDeBulleMisEnPage

    public init(traduction: TraductionDeBulle, composition: TexteDeBulleMisEnPage) {
        self.traduction = traduction
        self.composition = composition
    }

    public var id: CaseDePage {
        traduction.cadre
    }

    /// Vrai quand il y a quelque chose a poser sur la planche.
    public var meriteUneSurimpression: Bool {
        composition.estVide == false && traduction.estInchangee == false
    }
}

/// Composition de toutes les bulles d une planche, a la taille ou elle
/// s affiche.
public enum SurimpressionDeTraduction {
    /// Bulles pretes a etre posees sur une planche de cette taille.
    ///
    /// - Parameters:
    ///   - traductions: bulles traduites, deja rangees dans le sens de lecture.
    ///   - largeur: largeur de la planche affichee, en points.
    ///   - hauteur: hauteur de la planche affichee, en points.
    ///   - mesure: mesure du texte dans la police reellement posee.
    public static func composer(
        _ traductions: [TraductionDeBulle],
        largeur: Double,
        hauteur: Double,
        mesure: any MesureDeTexte = MesureDeTexteDuSysteme(graisse: Jetons.Traduction.graisse)
    ) -> [BulleAAfficher] {
        traductions.map { traduction in
            let cadre = traduction.bulle.cadreEnPoints(largeur: largeur, hauteur: hauteur)

            return BulleAAfficher(
                traduction: traduction,
                composition: MiseEnPageDeBulle.composer(
                    traduction.texteTraduit,
                    dans: cadre,
                    gabarit: Jetons.Traduction.gabarit,
                    mesure: mesure
                )
            )
        }
    }
}

/// Couche de surimpression posee sur la planche.
///
/// Elle occupe exactement la taille de la planche affichee et n intercepte
/// aucun geste : les zones de toucher de la section 5.7 continuent de repondre
/// sous elle, y compris sous une bulle traduite.
public struct VueDeSurimpressionDeTraduction: View {
    @Environment(\.palette) private var palette

    private let bulles: [BulleAAfficher]
    private let largeur: Double
    private let hauteur: Double

    /// Construit la couche.
    ///
    /// - Parameters:
    ///   - bulles: bulles deja composees, dans l ordre de lecture.
    ///   - largeur: largeur de la planche affichee, en points.
    ///   - hauteur: hauteur de la planche affichee, en points.
    public init(bulles: [BulleAAfficher], largeur: Double, hauteur: Double) {
        self.bulles = bulles
        self.largeur = largeur
        self.hauteur = hauteur
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(bulles.filter(\.meriteUneSurimpression)) { bulle in
                let cadre = bulle.traduction.bulle.cadreEnPoints(
                    largeur: largeur,
                    hauteur: hauteur
                )

                VueDeBulleTraduite(bulle: bulle)
                    .frame(width: cadre.largeur, height: cadre.hauteur)
                    .offset(x: cadre.abscisse, y: cadre.ordonnee)
            }
        }
        .frame(width: largeur, height: hauteur, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// Une bulle traduite, floutee puis voilee puis reecrite.
private struct VueDeBulleTraduite: View {
    @Environment(\.palette) private var palette

    let bulle: BulleAAfficher

    var body: some View {
        texte
            .frame(
                width: bulle.composition.largeurUtile,
                height: bulle.composition.hauteurUtile
            )
            .padding(Jetons.Traduction.margeInterne)
            .background(fond)
            .clipShape(forme)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(bulle.traduction.texteTraduit)
            .accessibilityValue(bulle.traduction.texteDOrigine)
    }

    /// Texte compose par le modele, pose ligne pour ligne.
    ///
    /// Les retours a la ligne viennent du modele et non du repli automatique de
    /// SwiftUI. Le modele a mesure chaque ligne, il sait qu elles tiennent ; un
    /// repli automatique recalculerait les coupures avec ses propres regles et
    /// pourrait rendre une ligne de plus que la hauteur ne peut porter.
    private var texte: some View {
        Text(bulle.composition.texte)
            .font(.system(size: bulle.composition.corps, weight: Jetons.Traduction.graisse.poids))
            .lineSpacing(0)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.textes.primary.couleur)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Bulle d origine floutee, puis voilee.
    ///
    /// Le meme principe que la banniere de la section 5.6, a une echelle bien
    /// plus petite. Le flou efface le lettrage d origine, le voile ramene le
    /// contraste sous le texte pose par dessus.
    private var fond: some View {
        forme
            .fill(palette.surfaces.reader.couleur)
            .opacity(Jetons.Traduction.opaciteDuVoile)
            .background(
                forme
                    .fill(.ultraThinMaterial)
                    .blur(radius: Jetons.Traduction.rayonDeFlou)
            )
    }

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: Jetons.Traduction.rayon, style: .continuous)
    }
}
