import Core
import SwiftUI

//
// Rangee d une source dans l ecran Rechercher, section 5.4 de DESIGN-SPEC.md.
//
// Nom de source en `headline`, compteur en `footnote` `text.tertiary`, lien
// Tout voir en `callout` `accent.text` aligne a droite, puis une bande
// horizontale de vignettes de 132 par 198 espacees de 16.
//
// Chaque rangee ne lit que son propre groupe. Aucune ne connait l etat des
// autres, ce qui est la forme que prend ici le premier critere : une source
// lente ne peut pas retenir une rangee qui a deja de quoi s afficher.
//

/// Une rangee de resultats, ou la ligne d erreur qui prend sa place.
public struct VueDeRangeeDeRecherche<Vignette: View>: View {
    private let groupe: GroupeDeRecherche
    private let libelles: LibellesDeRecherche
    private let delaiEnSecondes: Int
    private let toutVoir: () -> Void
    private let reessayer: () -> Void
    private let ouvrirLaSerie: (@MainActor (MangaDistant) -> Void)?
    private let vignette: (MangaDistant) -> Vignette

    /// Construit la rangee.
    ///
    /// - Parameters:
    ///   - groupe: source et etat de sa reponse.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - delaiEnSecondes: delai accorde a une source, ecrit dans la ligne
    ///     d erreur quand c est lui qui a expire.
    ///   - toutVoir: ouvre la liste complete de la source.
    ///   - reessayer: relance la seule source de cette rangee.
    ///   - ouvrirLaSerie: ouvre la fiche d une serie, nulle tant qu aucune
    ///     fiche n est atteignable depuis cet ecran.
    ///   - vignette: couverture d une serie, fournie par l appelant.
    public init(
        groupe: GroupeDeRecherche,
        libelles: LibellesDeRecherche,
        delaiEnSecondes: Int,
        toutVoir: @escaping () -> Void,
        reessayer: @escaping () -> Void,
        ouvrirLaSerie: (@MainActor (MangaDistant) -> Void)?,
        @ViewBuilder vignette: @escaping (MangaDistant) -> Vignette
    ) {
        self.groupe = groupe
        self.libelles = libelles
        self.delaiEnSecondes = delaiEnSecondes
        self.toutVoir = toutVoir
        self.reessayer = reessayer
        self.ouvrirLaSerie = ouvrirLaSerie
        self.vignette = vignette
    }

    public var body: some View {
        if let erreur = groupe.erreur {
            VueDeLigneDErreurDeSource(
                texte: TexteDeRecherche.ligneDErreur(
                    source: groupe.nom,
                    erreur: erreur,
                    delaiEnSecondes: delaiEnSecondes,
                    libelles: libelles
                ),
                libelleDeReprise: libelles.reessayer,
                reessayer: reessayer
            )
        } else {
            rangee
        }
    }

    private var rangee: some View {
        VStack(alignment: .leading, spacing: Jetons.Recherche.ecartApresLEnTete) {
            EnTeteDeRangeeDeRecherche(
                groupe: groupe,
                libelles: libelles,
                toutVoir: toutVoir
            )

            contenu
        }
    }

    @ViewBuilder
    private var contenu: some View {
        if groupe.estEnChargement {
            SquelettesDeRangee()
        } else {
            bande
        }
    }

    private var bande: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Jetons.Recherche.gouttiereEntreVignettes) {
                ForEach(groupe.resultats, id: \.identifiant) { serie in
                    carte(serie)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Une carte de resultat, isolee au fil principal comme le geste qui
    /// l ouvre : l ouverture d une fiche touche un etat qui vit la.
    @MainActor
    private func carte(_ serie: MangaDistant) -> some View {
        VueDeCarteDeResultat(
            serie: serie,
            ouvrir: ouvrirLaSerie.map { ouvrir in { ouvrir(serie) } },
            vignette: { vignette(serie) }
        )
    }
}

// MARK: - En tete d une rangee

/// Nom de la source, compteur de resultats et lien Tout voir.
struct EnTeteDeRangeeDeRecherche: View {
    @Environment(\.palette) private var palette
    @FocusState private var lienFocalise: Bool

    let groupe: GroupeDeRecherche
    let libelles: LibellesDeRecherche
    let toutVoir: () -> Void

    var body: some View {
        HStack(spacing: Jetons.Recherche.ecartAvantLeCompteur) {
            Text(groupe.nom)
                .style(Jetons.Recherche.nomDeSource)
                .foregroundStyle(palette.textes.primary.couleur)
                .accessibilityAddTraits(.isHeader)

            if let compteur = TexteDeRecherche.compteur(de: groupe, libelles: libelles) {
                Text(compteur)
                    .style(Jetons.Recherche.compteurDeResultats, chiffresTabulaires: true)
                    .foregroundStyle(palette.textes.tertiary.couleur)
            }

            Spacer(minLength: Jetons.Recherche.gouttiereEntreVignettes)

            if groupe.porteDesResultats {
                lien
            }
        }
        .lineLimit(1)
    }

    /// Lien Tout voir, en `callout` `accent.text` aligne a droite.
    ///
    /// L etiquette d accessibilite nomme la source : `Tout voir` seul, lu hors
    /// contexte par VoiceOver, ne dirait pas de quelle source il s agit.
    private var lien: some View {
        Button(libelles.toutVoir, action: toutVoir)
            .buttonStyle(BoutonDiscret(style: Jetons.Recherche.lienToutVoir))
            .focused($lienFocalise)
            .focusEffectDisabled()
            .overlay(contourDeFocus)
            .accessibilityLabel("\(libelles.toutVoir) \(groupe.nom)")
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if lienFocalise {
            RoundedRectangle(cornerRadius: Jetons.Rayon.ongletActif, style: .continuous)
                .strokeBorder(
                    palette.semantiques.focusRing.couleur,
                    lineWidth: Jetons.Focus.epaisseur
                )
                .padding(-Jetons.Focus.decalage)
        }
    }
}

// MARK: - Carte d un resultat

/// Une vignette de resultat et son titre.
public struct VueDeCarteDeResultat<Vignette: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @State private var survolee = false

    private let serie: MangaDistant
    private let ouvrir: (() -> Void)?
    private let vignette: () -> Vignette

    public init(
        serie: MangaDistant,
        ouvrir: (() -> Void)?,
        @ViewBuilder vignette: @escaping () -> Vignette
    ) {
        self.serie = serie
        self.ouvrir = ouvrir
        self.vignette = vignette
    }

    public var body: some View {
        carte
            .frame(width: Jetons.Recherche.largeurDeVignette)
            .scaleEffect(survolee ? Jetons.Mouvement.echelleDeCarteAuSurvol : 1)
            .onHover { survolee = $0 }
            .animation(animation, value: survolee)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(serie.titre)
    }

    @ViewBuilder
    private var carte: some View {
        if let ouvrir {
            Button(action: ouvrir) { contenu }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        } else {
            contenu
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Jetons.Recherche.gouttiereApresLaVignette) {
            couverture

            Text(serie.titre)
                .style(Jetons.Recherche.titreDeResultat)
                .foregroundStyle(palette.textes.primary.couleur)
                .lineLimit(Jetons.Recherche.lignesDeTitre)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var couverture: some View {
        vignette()
            .frame(
                width: Jetons.Recherche.largeurDeVignette,
                height: Jetons.Recherche.hauteurDeVignette
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Jetons.Recherche.rayonDeVignette,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survolDeCarte.animation
    }
}

// MARK: - Ligne d erreur d une source

/// Ligne discrete qui prend la place d une rangee dont la source a echoue.
///
/// Hauteur 52, rayon 12, fond `surface.card`, glyphe d avertissement, texte qui
/// nomme la source, lien Reessayer. Elle ne bloque pas les autres rangees : ce
/// n est qu une rangee de plus dans la meme pile.
public struct VueDeLigneDErreurDeSource: View {
    @Environment(\.palette) private var palette
    @FocusState private var lienFocalise: Bool

    private let texte: String
    private let libelleDeReprise: String
    private let reessayer: () -> Void

    public init(texte: String, libelleDeReprise: String, reessayer: @escaping () -> Void) {
        self.texte = texte
        self.libelleDeReprise = libelleDeReprise
        self.reessayer = reessayer
    }

    public var body: some View {
        HStack(spacing: Jetons.Recherche.ecartDansLaLigneDErreur) {
            glyphe

            Text(texte)
                .style(Jetons.Recherche.texteDeLigneDErreur)
                .foregroundStyle(palette.textes.secondary.couleur)
                .lineLimit(1)

            Spacer(minLength: Jetons.Recherche.ecartDansLaLigneDErreur)

            lien
        }
        .padding(.horizontal, Jetons.Recherche.margeDeLigneDErreur)
        .frame(height: Jetons.Recherche.hauteurDeLigneDErreur)
        .frame(maxWidth: .infinity)
        .background(fond)
        .accessibilityElement(children: .contain)
    }

    private var glyphe: some View {
        Image(systemName: Jetons.Icone.erreurDeContenu)
            .font(.system(size: Jetons.Recherche.tailleDuGlypheDErreur))
            .foregroundStyle(palette.semantiques.warning.couleur)
            .accessibilityHidden(true)
    }

    /// Lien de reprise, qui ne relance que cette source.
    ///
    /// L etiquette d accessibilite reprend le texte de la ligne, pour que
    /// `Reessayer` lu seul dise ce qui sera relance.
    private var lien: some View {
        Button(libelleDeReprise, action: reessayer)
            .buttonStyle(BoutonDiscret(style: Jetons.Recherche.lienToutVoir))
            .focused($lienFocalise)
            .focusEffectDisabled()
            .overlay(contourDeFocus)
            .accessibilityLabel("\(libelleDeReprise) \(texte)")
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if lienFocalise {
            RoundedRectangle(cornerRadius: Jetons.Rayon.ongletActif, style: .continuous)
                .strokeBorder(
                    palette.semantiques.focusRing.couleur,
                    lineWidth: Jetons.Focus.epaisseur
                )
                .padding(-Jetons.Focus.decalage)
        }
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Recherche.rayonDeLigneDErreur, style: .continuous)
            .fill(palette.surfaces.card.couleur)
    }
}

// MARK: - Squelettes d une rangee

/// Squelettes aux dimensions exactes des vignettes attendues, section 4.10.
struct SquelettesDeRangee: View {
    var body: some View {
        HStack(alignment: .top, spacing: Jetons.Recherche.gouttiereEntreVignettes) {
            ForEach(0..<Jetons.Recherche.nombreDeSquelettesParRangee, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Jetons.Recherche.gouttiereApresLaVignette) {
                    VueDeSquelette()
                        .frame(
                            width: Jetons.Recherche.largeurDeVignette,
                            height: Jetons.Recherche.hauteurDeVignette
                        )

                    VueDeSquelette()
                        .frame(
                            width: Jetons.Recherche.largeurDeVignette,
                            height: Jetons.Recherche.hauteurDuTitreDeResultat
                        )
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
}
