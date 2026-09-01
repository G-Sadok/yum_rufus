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
// Le sens haut bas ne pagine pas, il deroule. Une image par page dans une pile
// paresseuse, et non une seule longue image : la limite de texture de 16384
// pixels frappe une image, pas une pile, et un chapitre de webtoon la depasse
// sans prevenir. L echec serait silencieux et toucherait les series les plus
// lues.
//

/// Ce que le lecteur affiche.
///
/// Non `Sendable`, comme `EtatDeContenu` qu il porte : ces etats vivent sur le
/// fil principal, la ou les vues les lisent, et rien ne les fait voyager.
public enum EtatDeLecteur {
    /// Les pages ne sont pas encore lues.
    case chargement

    /// Page affichee, avec sa position dans le chapitre.
    case page(ImageDeLecteur, position: PositionDansLeChapitre)

    /// Chapitre deroule d un seul defilement, sens haut bas.
    ///
    /// Les pages ne sont pas portees ici : la pile les demande une par une a
    /// mesure qu elles approchent, et les tenir toutes en memoire couterait le
    /// chapitre entier decode alors que trois pages sont visibles.
    case defilement(nombreDePages: Int, position: PositionDansLeChapitre)

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

    /// Traduit un appui sur la surface de lecture.
    ///
    /// Les deux valeurs sont des parts de la largeur et de la hauteur, mesurees
    /// depuis le bord gauche et depuis le bord haut, quel que soit le sens de
    /// lecture. La traduction en zones vit dans l application : elle depend du
    /// sens, de la disposition choisie et de l option Inverser les zones, que
    /// le systeme de design ne voit pas.
    ///
    /// Rend vrai quand l appui a tourne une page. Faux, il bascule les barres :
    /// c est la bande du milieu, et c est aussi ce qui se passe quand les zones
    /// sont desactivees.
    public let appuyer: @MainActor (Double, Double) -> Bool

    public init(
        pageSuivante: @escaping @MainActor () -> Void,
        pagePrecedente: @escaping @MainActor () -> Void,
        fermer: @escaping @MainActor () -> Void,
        appuyer: @escaping @MainActor (Double, Double) -> Bool = { _, _ in false }
    ) {
        self.pageSuivante = pageSuivante
        self.pagePrecedente = pagePrecedente
        self.fermer = fermer
        self.appuyer = appuyer
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
    private let pageAuRang: @MainActor (Int) -> ImageDeLecteur?
    private let pageAtteinte: @MainActor (Int) -> Void

    /// Construit le lecteur.
    ///
    /// - Parameters:
    ///   - etat: chargement, page, defilement ou erreur.
    ///   - fond: fond choisi par l utilisateur.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - commandes: ce que le lecteur declenche.
    ///   - pageAuRang: page deja decodee, nulle tant qu elle ne l est pas.
    ///     Employee par le seul defilement continu. La fonction est appelee
    ///     pendant le rendu et ne decode rien : le decodage vit dans
    ///     l application, hors du fil principal.
    ///   - pageAtteinte: signale la page qui vient d apparaitre, pour que la
    ///     progression suive le defilement comme elle suit la pagination.
    public init(
        etat: EtatDeLecteur,
        fond: FondDeLecteur = .defaut,
        sens: SensDeLecture = .parDefaut,
        libelles: LibellesDeLecteur,
        commandes: CommandesDeLecteur,
        pageAuRang: @escaping @MainActor (Int) -> ImageDeLecteur? = { _ in nil },
        pageAtteinte: @escaping @MainActor (Int) -> Void = { _ in }
    ) {
        self.etat = etat
        self.fond = fond
        self.sens = sens
        self.libelles = libelles
        self.commandes = commandes
        self.pageAuRang = pageAuRang
        self.pageAtteinte = pageAtteinte
    }

    public var body: some View {
        GeometryReader { cadre in
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
            .onTapGesture { point in
                appuyer(point, dans: cadre.size)
            }
        }
        .gesture(balayage)
        .focusable()
        .onKeyPress(.rightArrow) { avancerVersLaDroite() }
        .onKeyPress(.leftArrow) { avancerVersLaGauche() }
        .onKeyPress(.space) { commandes.pageSuivante()
            return .handled
        }
        .onKeyPress(.escape) { commandes.fermer()
            return .handled
        }
    }

    /// Traite un appui : une page tournee, ou les barres qui apparaissent.
    ///
    /// Les coordonnees partent en parts de la surface et non en points. La
    /// traduction depend du sens de lecture et de la disposition choisie, que
    /// l application connait et que le systeme de design ne voit pas.
    private func appuyer(_ point: CGPoint, dans taille: CGSize) {
        let abscisse = taille.width > 0 ? point.x / taille.width : 0.5
        let ordonnee = taille.height > 0 ? point.y / taille.height : 0.5

        if commandes.appuyer(Double(abscisse), Double(ordonnee)) == false {
            basculerLesBarres()
        }
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
                .scaledToFit()
                // La page n est jamais agrandie au dela de sa definition : une
                // planche etiree est floue, et c est le premier defaut qu un
                // lecteur de manga se voit reprocher.
                .frame(maxWidth: CGFloat(page.largeur), maxHeight: CGFloat(page.hauteur))

        case let .defilement(nombre, _):
            ruban(nombre)

        case let .erreur(contenu):
            VueDEtatDeContenu(contenu)
        }
    }

    // MARK: Defilement continu

    /// Le chapitre deroule, une page par element de la pile.
    ///
    /// La pile est paresseuse : elle ne construit que ce qui approche de
    /// l ecran, et l application ne decode que ce que la pile demande. Un
    /// chapitre de deux cents pages ne coute donc pas deux cents pages
    /// decodees.
    private func ruban(_ nombre: Int) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Jetons.Lecteur.ecartEntrePagesDefilees) {
                ForEach(0..<nombre, id: \.self) { rang in
                    planche(auRang: rang)
                        .onAppear { pageAtteinte(rang) }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Une page du ruban, ou la place qu elle occupera.
    @ViewBuilder
    private func planche(auRang rang: Int) -> some View {
        if let page = pageAuRang(rang) {
            Image(decorative: page.image, scale: 1)
                .resizable()
                .aspectRatio(CGFloat(page.largeur) / CGFloat(max(1, page.hauteur)), contentMode: .fit)
                .frame(maxWidth: CGFloat(page.largeur))
        } else {
            // La place est reservee avant que la page arrive. Sans elle, le
            // ruban se replierait sur lui meme et le defilement sauterait a
            // chaque page decodee.
            Color.clear
                .aspectRatio(Jetons.Lecteur.ratioDePageAttendue, contentMode: .fit)
        }
    }

    // MARK: Barres

    private var barres: some View {
        VStack(spacing: 0) {
            barreSuperieure

            Spacer()

            if let position = positionCourante {
                barreInferieure(position)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Position affichee en bas, quelle que soit la mise en page.
    private var positionCourante: PositionDansLeChapitre? {
        switch etat {
        case let .page(_, position): position
        case let .defilement(_, position): position
        case .chargement, .erreur: nil
        }
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
