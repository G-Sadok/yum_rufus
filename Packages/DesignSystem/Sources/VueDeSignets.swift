import Core
import SwiftUI

//
// Ecran Signets, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Gabarit colonne 580, quatre etats. Une carte porte la liste, une ligne par
// signet : vignette de la page marquee, serie, chapitre et page, note quand elle
// existe.
//
// La ligne entiere ouvre la page marquee. C est l action principale de l ecran
// et son critere : un signet sert a revenir a une page, en un geste. La
// suppression vit dans le menu d options, derriere le meme bouton que la gestion
// des prereglages, pour que deux sous ecrans voisins ne rangent pas leurs
// commandes a deux endroits differents.
//
// Aucun aplat d accent dans la liste. La section 5.5 reserve l accent a ce sur
// quoi on peut agir, et ici toute la liste est actionnable.
//

/// Etat de la zone de contenu de l ecran Signets.
public enum EtatDeListeDeSignets {
    /// Liste en cours de lecture.
    case chargement

    /// Liste prete. Un tableau vide donne l etat vide.
    case chargee([SignetAffiche])

    /// La liste n a pas pu etre lue. L etat est compose par l appelant, qui seul
    /// connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes de l ecran declenchent.
///
/// Aucune de ces fermetures n ecrit en base elle meme. Elles remontent a
/// l ecran, seul a connaitre le magasin.
public struct CommandesDeSignets {
    /// Ouvre la page marquee dans le lecteur, nulle tant qu aucun lecteur ne
    /// peut l accueillir.
    public let ouvrir: (@MainActor (UUID) -> Void)?

    /// Supprime un signet.
    public let supprimer: @MainActor (UUID) -> Void

    /// Ouvre la bibliotheque, action de l etat vide. Nulle quand l ecran ne
    /// peut mener nulle part, auquel cas l etat vide n affiche aucun bouton.
    public let ouvrirLaBibliotheque: (@MainActor () -> Void)?

    public init(
        ouvrir: (@MainActor (UUID) -> Void)?,
        supprimer: @escaping @MainActor (UUID) -> Void,
        ouvrirLaBibliotheque: (@MainActor () -> Void)?
    ) {
        self.ouvrir = ouvrir
        self.supprimer = supprimer
        self.ouvrirLaBibliotheque = ouvrirLaBibliotheque
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeSignets {
        CommandesDeSignets(ouvrir: nil, supprimer: { _ in }, ouvrirLaBibliotheque: nil)
    }
}

/// Ecran de consultation des signets.
public struct VueDeSignets<Vignette: View>: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeListeDeSignets
    private let libelles: LibellesDeSignets
    private let commandes: CommandesDeSignets
    private let vignette: (SignetAffiche) -> Vignette

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, liste ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    ///   - vignette: image de la page marquee, fournie par l appelant.
    public init(
        etat: EtatDeListeDeSignets,
        libelles: LibellesDeSignets,
        commandes: CommandesDeSignets,
        @ViewBuilder vignette: @escaping (SignetAffiche) -> Vignette
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
        self.vignette = vignette
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surfaces.canvas.couleur)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            colonne { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(signets):
            if signets.isEmpty {
                VueDEtatDeContenu(etatVide)
            } else {
                colonne { liste(signets) }
            }
        }
    }

    // MARK: Colonne

    /// Gabarit colonne 580, celui de l ecran Reglages dont ce sous ecran part.
    private func colonne(@ViewBuilder _ interieur: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                enTete
                interieur()
                description
            }
            .frame(maxWidth: Jetons.Signets.largeurDeColonne)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Jetons.Contenu.margeLaterale)
            .padding(.vertical, Jetons.CarteDeReglages.margeVerticale)
        }
    }

    private var enTete: some View {
        Text(libelles.titre)
            .style(Jetons.CarteDeReglages.enTete)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
            .accessibilityAddTraits(.isHeader)
    }

    private var description: some View {
        Text(libelles.description)
            .style(Jetons.CarteDeReglages.description)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Jetons.CarteDeReglages.ecartAvantLaDescription)
    }

    // MARK: Liste

    private func liste(_ signets: [SignetAffiche]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(signets.enumerated()), id: \.element.id) { rang, signet in
                LigneDeSignet(
                    signet: signet,
                    libelles: libelles,
                    commandes: commandes,
                    vignette: { vignette(signet) }
                )

                if rang < signets.count - 1 {
                    separateur
                }
            }
        }
        .background(palette.surfaces.card.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.Signets.rayon, style: .continuous))
    }

    /// Filet encastre de 20 a gauche, affleurant a droite, section 4.2.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.Signets.epaisseurDuSeparateur)
            .padding(.leading, Jetons.Signets.encastrementDuSeparateur)
            .accessibilityHidden(true)
    }

    /// Squelettes aux dimensions exactes des lignes attendues, section 4.10.
    private var squelettes: some View {
        VueDeSquelette()
            .frame(
                height: Jetons.Signets.hauteurDeLigne * Double(Jetons.Signets.nombreDeSquelettes)
            )
    }

    // MARK: Etat vide

    /// Etat vide de la section 4.10.
    ///
    /// Il porte l action seulement quand l appelant sait ou elle mene. Un bouton
    /// qui ne repond pas coute plus cher qu un etat vide sans bouton, et la
    /// section 4.10 rend l action facultative.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Signets.symbole,
            titre: libelles.videTitre,
            phrase: libelles.videPhrase,
            action: commandes.ouvrirLaBibliotheque.map { ouvrir in
                ActionDEtat(libelle: libelles.videAction) { ouvrir() }
            }
        )
    }
}

/// Une ligne de la liste des signets.
///
/// La ligne entiere est le bouton qui ouvre la page marquee. Le bouton d options
/// est pose a cote dans un `HStack`, et non dedans : imbriquer deux boutons
/// rendrait le menu inatteignable au clavier.
struct LigneDeSignet<Vignette: View>: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let signet: SignetAffiche
    let libelles: LibellesDeSignets
    let commandes: CommandesDeSignets
    let vignette: () -> Vignette

    var body: some View {
        HStack(spacing: Jetons.Signets.ecartAvantLesOptions) {
            saut
            options
        }
        .padding(.horizontal, Jetons.Signets.margeLaterale)
        .frame(minHeight: Jetons.Signets.hauteurDeLigne)
        .contourDeFocus(focalisee, rayonDeLElement: 0)
    }

    /// Bouton qui ouvre la page marquee, toute la largeur de la ligne.
    ///
    /// Sans lecteur pour l accueillir, la ligne n est pas un bouton et ne promet
    /// rien : le contenu reste lisible, la commande de suppression reste au
    /// menu.
    @ViewBuilder
    private var saut: some View {
        if let ouvrir = commandes.ouvrir {
            Button {
                ouvrir(signet.id)
            } label: {
                contenu
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focalisee)
            .accessibilityLabel(TexteDeSignet.etiquette(de: signet, libelles: libelles))
            .accessibilityHint(libelles.ouvrirLaPage)
        } else {
            contenu
                .accessibilityElement(children: .combine)
                .accessibilityLabel(TexteDeSignet.etiquette(de: signet, libelles: libelles))
        }
    }

    private var contenu: some View {
        HStack(spacing: Jetons.Signets.ecartApresLaVignette) {
            page

            VStack(alignment: .leading, spacing: Jetons.Signets.ecartEntreLesTextes) {
                Text(signet.titreDeLaSerie)
                    .style(Jetons.Signets.titreDeSerie)
                    .foregroundStyle(palette.textes.primary.couleur)

                Text(TexteDeSignet.sousLigne(de: signet, libelles: libelles))
                    .style(Jetons.Signets.chapitreEtPage)
                    .foregroundStyle(palette.textes.tertiary.couleur)

                if let note = signet.note {
                    Text(note)
                        .style(Jetons.Signets.note)
                        .foregroundStyle(palette.textes.quaternary.couleur)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Vignette de la page marquee, 44 par 66.
    private var page: some View {
        vignette()
            .frame(
                width: Jetons.Signets.largeurDeVignette,
                height: Jetons.Signets.hauteurDeVignette
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Jetons.Signets.rayonDeVignette,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    /// Menu des commandes de la ligne, section 4.1.
    private var options: some View {
        Menu {
            if let ouvrir = commandes.ouvrir {
                Button(libelles.ouvrirLaPage) { ouvrir(signet.id) }
            }

            Button(libelles.supprimer, role: .destructive) {
                commandes.supprimer(signet.id)
            }
        } label: {
            // Le menu porte deja son etiquette, le symbole ne la double pas.
            Image(systemName: Jetons.Signets.symboleDOptions)
                .font(.system(size: Jetons.Signets.tailleDuSymboleDOptions))
                .foregroundStyle(palette.textes.secondary.couleur)
                .accessibilityHidden(true)
                .frame(
                    width: Jetons.Signets.coteDuBoutonDOptions,
                    height: Jetons.Signets.coteDuBoutonDOptions
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(libelles.options)
    }
}
