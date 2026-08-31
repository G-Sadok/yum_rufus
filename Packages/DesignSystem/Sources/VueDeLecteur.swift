import Core
import SwiftUI

//
// VueDeLecteur
//
// Le lecteur pagine de la section 5.7, coeur du produit.
//
// La these du document veut que l interface disparaisse. Les barres sont donc
// masquees par defaut : elles arrivent au tap central et se retirent apres
// trois secondes. Tout le reste de l ecran est la planche, sur le fond que
// l utilisateur a choisi.
//
// La page est posee telle que la chaine d images l a decodee, ajustee a
// l ecran sans jamais etre agrandie au dela de sa definition. Une page
// etiree au dela de ce que le fichier contient serait floue, et un lecteur de
// manga se juge sur ce point avant tout autre.
//

/// Ce que le lecteur affiche.
public enum EtatDeLecteur: Sendable {
    /// Les pages ne sont pas encore lues.
    case chargement

    /// Page affichee, avec sa position dans le chapitre.
    case page(ImageDeLecteur, position: PositionDansLeChapitre)

    /// Echec nomme, avec sa sortie.
    case erreur(EtatDeContenu)
}

/// Une page prete a poser, independante de la chaine qui l a produite.
public struct ImageDeLecteur: Sendable {
    public let image: CGImage
    public let largeur: Int
    public let hauteur: Int

    public init(image: CGImage, largeur: Int, hauteur: Int) {
        self.image = image
        self.largeur = largeur
        self.hauteur = hauteur
    }
}

/// Ou l on en est dans le chapitre.
public struct PositionDansLeChapitre: Sendable, Equatable {
    public let numero: Int
    public let total: Int

    public init(numero: Int, total: Int) {
        self.numero = numero
        self.total = total
    }

    /// Compteur du document, format `42 / 220`, chiffres tabulaires.
    public var compteur: String {
        "\(numero) / \(total)"
    }
}

/// Ce que le lecteur declenche.
public struct CommandesDeLecteur {
    public let pageSuivante: @MainActor () -> Void
    public let pagePrecedente: @MainActor () -> Void
    public let fermer: @MainActor () -> Void

    public init(
        pageSuivante: @escaping @MainActor () -> Void,
        pagePrecedente: @escaping @MainActor () -> Void,
        fermer: @escaping @MainActor () -> Void
    ) {
        self.pageSuivante = pageSuivante
        self.pagePrecedente = pagePrecedente
        self.fermer = fermer
    }
}

/// Textes du lecteur, pris dans le catalogue de l application.
public struct LibellesDeLecteur: Sendable, Equatable {
    public let titre: String
    public let sousTitre: String
    public let fermer: String
    public let pagePrecedente: String
    public let pageSuivante: String

    public init(
        titre: String,
        sousTitre: String,
        fermer: String,
        pagePrecedente: String,
        pageSuivante: String
    ) {
        self.titre = titre
        self.sousTitre = sousTitre
        self.fermer = fermer
        self.pagePrecedente = pagePrecedente
        self.pageSuivante = pageSuivante
    }
}

/// Lecteur pagine, section 5.7.
public struct VueDeLecteur: View {
    @Environment(\.palette) private var palette

    @State private var barresVisibles = true
    @State private var derniereActivite = Date()

    private let etat: EtatDeLecteur
    private let fond: FondDeLecteur
    private let sens: SensDeLecture
    private let libelles: LibellesDeLecteur
    private let commandes: CommandesDeLecteur

    public init(
        etat: EtatDeLecteur,
        fond: FondDeLecteur = .defaut,
        sens: SensDeLecture = .parDefaut,
        libelles: LibellesDeLecteur,
        commandes: CommandesDeLecteur
    ) {
        self.etat = etat
        self.fond = fond
        self.sens = sens
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        ZStack {
            fond.couleur.couleur
                .ignoresSafeArea()

            planche

            if barresVisibles {
                barres
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { basculerLesBarres() }
        .gesture(balayage)
        .focusable()
        .onKeyPress(.rightArrow) { avancerVersLaDroite() }
        .onKeyPress(.leftArrow) { avancerVersLaGauche() }
        .onKeyPress(.space) { commandes.pageSuivante(); return .handled }
        .onKeyPress(.escape) { commandes.fermer(); return .handled }
    }

    // MARK: Planche

    @ViewBuilder
    private var planche: some View {
        switch etat {
        case .chargement:
            ProgressView()
                .controlSize(.large)

        case let .page(page, _):
            Image(decorative: page.image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // La page n est jamais agrandie au dela de sa definition : une
                // planche etiree est floue, et c est le premier defaut qu un
                // lecteur de manga se voit reprocher.
                .frame(maxWidth: CGFloat(page.largeur), maxHeight: CGFloat(page.hauteur))

        case let .erreur(contenu):
            VueDEtatDeContenu(contenu)
        }
    }

    // MARK: Barres

    @ViewBuilder
    private var barres: some View {
        VStack(spacing: 0) {
            barreSuperieure

            Spacer()

            if case let .page(_, position) = etat {
                barreInferieure(position)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var barreSuperieure: some View {
        HStack(spacing: Jetons.Espace.x4) {
            Button(action: commandes.fermer) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Jetons.Lecteur.tailleDuChevron, weight: .medium))
                    .foregroundStyle(palette.textes.primary.couleur)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(libelles.fermer)

            VStack(alignment: .leading, spacing: 0) {
                Text(libelles.titre)
                    .style(Jetons.Lecteur.titre)
                    .foregroundStyle(palette.textes.primary.couleur)

                Text(libelles.sousTitre)
                    .style(Jetons.Lecteur.sousTitre)
                    .foregroundStyle(palette.textes.tertiary.couleur)
            }

            Spacer()
        }
        .padding(.horizontal, Jetons.Espace.x5)
        .frame(height: Jetons.Lecteur.hauteurDeLaBarreSuperieure)
        .background(palette.surfaces.window.couleur.opacity(Jetons.Lecteur.opaciteDesBarres))
    }

    private func barreInferieure(_ position: PositionDansLeChapitre) -> some View {
        HStack {
            Text(position.compteur)
                .style(Jetons.Lecteur.compteur)
                .monospacedDigit()
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer()
        }
        .padding(.horizontal, Jetons.Lecteur.margeDuCompteur)
        .frame(height: Jetons.Lecteur.hauteurDeLaBarreInferieure)
        .background(palette.surfaces.window.couleur.opacity(Jetons.Lecteur.opaciteDesBarres))
    }

    // MARK: Gestes

    /// Le balayage suit le sens de lecture, jamais la direction de l interface.
    private var balayage: some Gesture {
        DragGesture(minimumDistance: Jetons.Lecteur.distanceDeBalayage)
            .onEnded { geste in
                if geste.translation.width < 0 {
                    avancerVersLaGauche()
                } else if geste.translation.width > 0 {
                    avancerVersLaDroite()
                }
            }
    }

    /// Aller vers la droite avance en lecture japonaise, recule autrement.
    @discardableResult
    private func avancerVersLaDroite() -> KeyPress.Result {
        if sens.commenceParLaDroite {
            commandes.pagePrecedente()
        } else {
            commandes.pageSuivante()
        }

        return .handled
    }

    @discardableResult
    private func avancerVersLaGauche() -> KeyPress.Result {
        if sens.commenceParLaDroite {
            commandes.pageSuivante()
        } else {
            commandes.pagePrecedente()
        }

        return .handled
    }

    private func basculerLesBarres() {
        withAnimation(.easeInOut(duration: Jetons.Lecteur.dureeDeTransition)) {
            barresVisibles.toggle()
        }
    }
}
