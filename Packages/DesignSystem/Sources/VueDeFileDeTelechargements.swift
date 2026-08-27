import Core
import SwiftUI

//
// Ecran de suivi de la file, section 4.11 de DESIGN-SPEC.md.
//
// Un panneau de 324, une ligne de 268 par 52 par tache, et un indicateur qui dit
// l etat sans le dire par la seule couleur : la sous ligne le porte aussi, comme
// la section 7 l exige.
//
// La ligne n est pas un bouton. Contrairement a un signet, elle ne mene nulle
// part : ce qu on peut faire dessus, mettre en pause, reprendre, faire passer
// devant, annuler, vit dans le bouton de droite. Une ligne entiere cliquable
// devrait promettre une destination, et la file n en a pas.
//

/// Etat de la zone de contenu de l ecran de suivi.
public enum EtatDeFileDeTelechargements {
    /// File en cours de lecture.
    case chargement

    /// File prete. Un tableau vide donne l etat vide.
    case chargee([TelechargementAffiche])

    /// La file n a pas pu etre lue. L etat est compose par l appelant, qui seul
    /// connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes d une ligne declenchent.
///
/// Aucune de ces fermetures n ecrit en base elle meme. Elles remontent a
/// l ecran, seul a connaitre le magasin.
public struct CommandesDeTelechargements {
    /// Met une ligne en pause.
    public let mettreEnPause: @MainActor (UUID) -> Void

    /// Remet une ligne dans la file.
    public let reprendre: @MainActor (UUID) -> Void

    /// Fait passer une ligne devant les autres.
    public let passerEnPremier: @MainActor (UUID) -> Void

    /// Retire une ligne de la file.
    public let annuler: @MainActor (UUID) -> Void

    /// Ouvre la bibliotheque, action de l etat vide. Nulle quand l ecran ne peut
    /// mener nulle part, auquel cas l etat vide n affiche aucun bouton.
    public let ouvrirLaBibliotheque: (@MainActor () -> Void)?

    public init(
        mettreEnPause: @escaping @MainActor (UUID) -> Void,
        reprendre: @escaping @MainActor (UUID) -> Void,
        passerEnPremier: @escaping @MainActor (UUID) -> Void,
        annuler: @escaping @MainActor (UUID) -> Void,
        ouvrirLaBibliotheque: (@MainActor () -> Void)?
    ) {
        self.mettreEnPause = mettreEnPause
        self.reprendre = reprendre
        self.passerEnPremier = passerEnPremier
        self.annuler = annuler
        self.ouvrirLaBibliotheque = ouvrirLaBibliotheque
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeTelechargements {
        CommandesDeTelechargements(
            mettreEnPause: { _ in },
            reprendre: { _ in },
            passerEnPremier: { _ in },
            annuler: { _ in },
            ouvrirLaBibliotheque: nil
        )
    }
}

/// Ecran de suivi de la file de telechargement.
public struct VueDeFileDeTelechargements: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeFileDeTelechargements
    private let libelles: LibellesDeTelechargements
    private let commandes: CommandesDeTelechargements

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, file ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    public init(
        etat: EtatDeFileDeTelechargements,
        libelles: LibellesDeTelechargements,
        commandes: CommandesDeTelechargements
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
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
            panneau { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(taches):
            if taches.isEmpty {
                VueDEtatDeContenu(etatVide)
            } else {
                panneau { liste(taches) }
            }
        }
    }

    // MARK: Panneau

    /// Panneau de 324, mesure du document.
    private func panneau(@ViewBuilder _ interieur: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                enTete
                interieur()
                description
            }
            .frame(maxWidth: Jetons.Telechargements.largeurDuPanneau)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Jetons.Telechargements.margeVerticale)
        }
    }

    private var enTete: some View {
        Text(libelles.titre)
            .style(Jetons.CarteDeReglages.enTete)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.horizontal, Jetons.Telechargements.retraitDeLigne)
            .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
            .accessibilityAddTraits(.isHeader)
    }

    private var description: some View {
        Text(libelles.description)
            .style(Jetons.CarteDeReglages.description)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Jetons.Telechargements.retraitDeLigne)
            .padding(.top, Jetons.CarteDeReglages.ecartAvantLaDescription)
    }

    // MARK: Liste

    private func liste(_ taches: [TelechargementAffiche]) -> some View {
        VStack(spacing: Jetons.Telechargements.ecartEntreLignes) {
            ForEach(taches) { tache in
                LigneDeTelechargement(tache: tache, libelles: libelles, commandes: commandes)
            }
        }
        .padding(.horizontal, Jetons.Telechargements.retraitDeLigne)
    }

    /// Squelettes aux dimensions exactes des lignes attendues, section 4.10.
    private var squelettes: some View {
        VStack(spacing: Jetons.Telechargements.ecartEntreLignes) {
            ForEach(0..<Jetons.Telechargements.nombreDeSquelettes, id: \.self) { _ in
                VueDeSquelette()
                    .frame(height: Jetons.Telechargements.hauteurDeLigne)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: Jetons.Telechargements.rayonDeLigne,
                            style: .continuous
                        )
                    )
            }
        }
        .padding(.horizontal, Jetons.Telechargements.retraitDeLigne)
    }

    // MARK: Etat vide

    /// Etat vide de la section 4.10.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.IconeDeTelechargement.telechargement,
            titre: libelles.videTitre,
            phrase: libelles.videPhrase,
            action: commandes.ouvrirLaBibliotheque.map { ouvrir in
                ActionDEtat(libelle: libelles.videAction) { ouvrir() }
            }
        )
    }
}

/// Une ligne de la file.
struct LigneDeTelechargement: View {
    @Environment(\.palette) private var palette

    let tache: TelechargementAffiche
    let libelles: LibellesDeTelechargements
    let commandes: CommandesDeTelechargements

    var body: some View {
        HStack(spacing: 0) {
            IndicateurDeTelechargement(tache: tache)
                .frame(
                    width: Jetons.Telechargements.diametreDeLIndicateur,
                    height: Jetons.Telechargements.diametreDeLIndicateur
                )
                .padding(.leading, Jetons.Telechargements.margeAvantLIndicateur)
                .accessibilityHidden(true)

            textes
                .padding(.leading, Jetons.Telechargements.ecartApresLIndicateur)

            options
                .padding(.leading, Jetons.Telechargements.ecartAvantLaCommande)
                .padding(.trailing, Jetons.Telechargements.ecartEntreLesTextes)
        }
        .frame(height: Jetons.Telechargements.hauteurDeLigne)
        .background(palette.surfaces.card.couleur)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Jetons.Telechargements.rayonDeLigne,
                style: .continuous
            )
        )
    }

    private var textes: some View {
        VStack(alignment: .leading, spacing: Jetons.Telechargements.ecartEntreLesTextes) {
            Text(TexteDeTelechargement.titre(de: tache, libelles: libelles))
                .style(Jetons.Telechargements.titre)
                .foregroundStyle(palette.textes.primary.couleur)

            Text(TexteDeTelechargement.sousLigne(de: tache, libelles: libelles))
                .style(Jetons.Telechargements.sousLigne)
                .foregroundStyle(palette.textes.tertiary.couleur)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TexteDeTelechargement.etiquette(de: tache, libelles: libelles))
    }

    /// Menu des commandes de la ligne, section 4.11.
    ///
    /// Pause et reprise ne s affichent jamais ensemble : le libelle propose
    /// l action que l etat courant permet, et lui seul.
    private var options: some View {
        Menu {
            if tache.etat == .enCours || tache.etat == .enAttente {
                Button(libelles.mettreEnPause) { commandes.mettreEnPause(tache.id) }
                Button(libelles.passerEnPremier) { commandes.passerEnPremier(tache.id) }
            }

            if tache.etat == .suspendu || tache.etat == .echoue {
                Button(libelles.reprendre) { commandes.reprendre(tache.id) }
            }

            if tache.etat != .termine {
                Button(libelles.annuler, role: .destructive) { commandes.annuler(tache.id) }
            }
        } label: {
            Image(systemName: Jetons.IconeDeTelechargement.options)
                .font(.system(size: Jetons.Telechargements.tailleDuSymbole))
                .foregroundStyle(palette.textes.secondary.couleur)
                .frame(
                    width: Jetons.Telechargements.coteDeLaCommande,
                    height: Jetons.Telechargements.coteDeLaCommande
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(libelles.options)
    }
}

/// Indicateur d etat d une ligne, tableau de la section 4.11.
struct IndicateurDeTelechargement: View {
    @Environment(\.palette) private var palette

    let tache: TelechargementAffiche

    var body: some View {
        switch tache.etat {
        case .termine:
            Circle()
                .fill(palette.semantiques.success.couleur)

        case .enCours:
            anneauDAvancement

        default:
            Circle()
                .strokeBorder(
                    palette.textes.quaternary.couleur,
                    lineWidth: Jetons.Telechargements.epaisseurEnAttente
                )
        }
    }

    /// Anneau en accent de 2.5, tirets 50 sur 25, borne a l avancement reel.
    ///
    /// Le tour complet reste dessine en dessous, en trace faible : sans lui, une
    /// tache a peine commencee ne montrerait presque rien, et rien ne
    /// distinguerait une ligne qui demarre d une ligne sans indicateur.
    private var anneauDAvancement: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    palette.textes.quaternary.couleur,
                    lineWidth: Jetons.Telechargements.epaisseurEnAttente
                )

            Circle()
                .trim(from: 0, to: tache.progression)
                .stroke(
                    palette.semantiques.accent.couleur,
                    style: StrokeStyle(
                        lineWidth: Jetons.Telechargements.epaisseurEnCours,
                        lineCap: .round,
                        dash: [
                            Jetons.Telechargements.tiret,
                            Jetons.Telechargements.videEntreTirets,
                        ]
                    )
                )
                .rotationEffect(.degrees(-90))
                .padding(Jetons.Telechargements.epaisseurEnCours / 2)
        }
    }
}
