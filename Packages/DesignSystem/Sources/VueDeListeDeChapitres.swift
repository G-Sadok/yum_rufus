import Core
import Foundation
import SwiftUI

//
// Liste des chapitres de la fiche de serie, sections 5.6 et 4.5 de
// DESIGN-SPEC.md.
//
// Resume repliable, filet, en tete portant le compteur et les trois actions,
// puis les lignes. Les quatre etats de la section 5.6 ne touchent que cette
// zone : l en tete de la fiche reste intact dans tous les cas, c est la vue de
// fiche qui les assemble dans cet ordre.
//

/// Etat de la zone de liste, section 5.6.
public enum EtatDeListeDeChapitres {
    /// Chapitres en cours de lecture.
    case chargement

    /// Liste prete. Le cas vide se lit dans la fiche elle meme.
    case chargee(FicheDeSerie)

    /// La source n a pas rendu la liste. L etat est deja compose par
    /// l appelant, qui seul connait le nom de la source et l heure de la
    /// derniere tentative.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes de la liste declenchent.
///
/// Comme les actions de l en tete, les fermetures sont isolees au fil
/// principal : elles partent d un geste rendu la, et touchent un etat qui y vit.
public struct CommandesDeListeDeChapitres {
    /// Ouvre le menu de filtre.
    public let filtrer: @MainActor () -> Void
    /// Ouvre le menu de tri.
    public let trier: @MainActor () -> Void
    /// Marque tous les chapitres de la serie comme lus.
    public let toutMarquerLu: @MainActor () -> Void
    /// Ouvre un chapitre dans le lecteur.
    public let ouvrir: @MainActor (UUID) -> Void
    /// Ajoute ou retire un chapitre de la selection multiple.
    public let basculerLaSelection: @MainActor (UUID) -> Void
    /// Etend la selection depuis son ancre jusqu au chapitre designe.
    public let etendreLaSelection: @MainActor (UUID) -> Void
    /// Execute une action de la barre de selection.
    public let executer: @MainActor (ActionDeSelectionDeChapitres) -> Void
    /// Vide la selection et referme la barre.
    public let viderLaSelection: @MainActor () -> Void

    public init(
        filtrer: @escaping @MainActor () -> Void,
        trier: @escaping @MainActor () -> Void,
        toutMarquerLu: @escaping @MainActor () -> Void,
        ouvrir: @escaping @MainActor (UUID) -> Void,
        basculerLaSelection: @escaping @MainActor (UUID) -> Void,
        etendreLaSelection: @escaping @MainActor (UUID) -> Void,
        executer: @escaping @MainActor (ActionDeSelectionDeChapitres) -> Void,
        viderLaSelection: @escaping @MainActor () -> Void
    ) {
        self.filtrer = filtrer
        self.trier = trier
        self.toutMarquerLu = toutMarquerLu
        self.ouvrir = ouvrir
        self.basculerLaSelection = basculerLaSelection
        self.etendreLaSelection = etendreLaSelection
        self.executer = executer
        self.viderLaSelection = viderLaSelection
    }
}

/// Corps de la fiche de serie : resume, en tete de liste, chapitres.
public struct VueDeListeDeChapitres: View {
    @Environment(\.palette) private var palette
    @State private var resumeDeplie = false

    private let etat: EtatDeListeDeChapitres
    private let resume: String?
    private let etatVide: EtatDeContenu
    private let libelles: LibellesDeFicheDeSerie
    private let selection: SelectionDeChapitres
    private let commandes: CommandesDeListeDeChapitres

    /// Construit le corps de la fiche.
    ///
    /// - Parameters:
    ///   - etat: etat de la zone de liste.
    ///   - resume: resume de la serie, absent quand la source n en donne aucun.
    ///   - etatVide: etat vide compose par l appelant, tableau 6.3.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - selection: chapitres retenus par la selection multiple.
    ///   - commandes: ce que declenchent les actions de la liste.
    public init(
        etat: EtatDeListeDeChapitres,
        resume: String?,
        etatVide: EtatDeContenu,
        libelles: LibellesDeFicheDeSerie,
        selection: SelectionDeChapitres,
        commandes: CommandesDeListeDeChapitres
    ) {
        self.etat = etat
        self.resume = resume
        self.etatVide = etatVide
        self.libelles = libelles
        self.selection = selection
        self.commandes = commandes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Jetons.FicheDeSerie.ecartDansLeCorps) {
            resumeDeLaSerie
            filet
            enTeteDeListe
            corps
        }
        .frame(maxWidth: Jetons.Contenu.largeurDeColonne)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { barreDeSelection }
    }

    // MARK: Resume

    @ViewBuilder
    private var resumeDeLaSerie: some View {
        if let resume, !resume.isEmpty {
            VStack(alignment: .leading, spacing: Jetons.Espace.x2) {
                Text(resume)
                    .style(Jetons.FicheDeSerie.resume)
                    .foregroundStyle(palette.textes.secondary.couleur)
                    .lineLimit(resumeDeplie ? nil : Jetons.FicheDeSerie.lignesDeResume)
                    .fixedSize(horizontal: false, vertical: true)

                Button(libelles.libelleDeLaBascule(resumeDeplie: resumeDeplie)) {
                    resumeDeplie.toggle()
                }
                .buttonStyle(.plain)
                .style(Jetons.FicheDeSerie.basculeDuResume)
                .foregroundStyle(couleurDAction)
            }
        }
    }

    private var filet: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.Fenetre.epaisseurDuFilet)
            .accessibilityHidden(true)
    }

    // MARK: En tete de liste

    private var enTeteDeListe: some View {
        HStack(spacing: Jetons.FicheDeSerie.ecartEntreActions) {
            // Chiffres tabulaires : le compteur change en place quand le filtre
            // change, section 1.5.
            Text(String(format: libelles.compteurDeChapitres, nombreAffiche))
                .style(Jetons.FicheDeSerie.compteurDeChapitres, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer(minLength: 0)

            actionDeListe(libelles.filtrer, commandes.filtrer)
            actionDeListe(libelles.trier, commandes.trier)
            actionDeListe(libelles.toutMarquerLu, commandes.toutMarquerLu)
        }
    }

    private func actionDeListe(_ libelle: String, _ action: @escaping @MainActor () -> Void) -> some View {
        Button(libelle, action: action)
            .buttonStyle(.plain)
            .style(Jetons.FicheDeSerie.actionDeListe)
            .foregroundStyle(couleurDAction)
    }

    /// Le corps de la fiche est en gabarit colonne sur `surface.canvas`,
    /// section 5.6. `accent.text` y tient le seuil dans les quatre themes, la
    /// derivation le laisse donc inchange, mais elle garantit qu il en ira de
    /// meme si la surface change.
    private var couleurDAction: Color {
        palette.lisible(palette.semantiques.accentText, sur: [palette.surfaces.canvas]).couleur
    }

    /// Nombre annonce par l en tete.
    ///
    /// C est le nombre de lignes reellement affichees. Une liste qui annonce
    /// 248 chapitres en n en montrant que douze, filtre oblige, ferait douter
    /// du filtre autant que du compteur.
    private var nombreAffiche: Int {
        guard case let .chargee(fiche) = etat else {
            return 0
        }

        return fiche.chapitres.count
    }

    // MARK: Corps

    @ViewBuilder
    private var corps: some View {
        switch etat {
        case .chargement:
            squelettes

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(fiche):
            if fiche.estSansChapitre {
                VueDEtatDeContenu(etatVide)
            } else {
                lignes(de: fiche)
            }
        }
    }

    private func lignes(de fiche: FicheDeSerie) -> some View {
        LazyVStack(spacing: Jetons.LigneDeChapitre.ecartEntreLignes) {
            ForEach(fiche.chapitres) { chapitre in
                VueDeLigneDeChapitre(
                    chapitre: chapitre,
                    libelles: libelles.chapitres,
                    estSelectionnee: selection.contient(chapitre.id)
                ) {
                    commandes.ouvrir(chapitre.id)
                }
                .contextMenu { menu(de: chapitre) }
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        commandes.basculerLaSelection(chapitre.id)
                    }
                )
            }
        }
    }

    /// Menu contextuel d une ligne.
    ///
    /// Il porte les deux gestes de selection que le document decrit sans leur
    /// donner d equivalent visible : le clic maintenu et le Cmd clic. Les
    /// exposer ici les rend atteignables au clavier et par VoiceOver.
    @ViewBuilder
    private func menu(de chapitre: ChapitreDeFiche) -> some View {
        Button(libelles.selection.selectionner) {
            commandes.basculerLaSelection(chapitre.id)
        }

        Button(libelles.selection.etendreLaSelection) {
            commandes.etendreLaSelection(chapitre.id)
        }
        .disabled(selection.ancre == nil)
    }

    /// Squelettes de 56, dimensions exactes des lignes attendues, section 5.6.
    private var squelettes: some View {
        VStack(spacing: Jetons.LigneDeChapitre.ecartEntreLignes) {
            ForEach(0..<Self.nombreDeSquelettes, id: \.self) { _ in
                VueDeSquelette()
                    .frame(height: Jetons.LigneDeChapitre.hauteur)
            }
        }
    }

    /// Nombre de squelettes affiches pendant le chargement.
    ///
    /// Le document ne le chiffre pas. Quatre est le nombre de lignes que le
    /// wireframe 04 dessine, et il suffit a occuper la zone sans promettre une
    /// longueur de liste que la source n a pas encore annoncee.
    private static let nombreDeSquelettes = 4

    // MARK: Selection multiple

    private var barreDeSelection: some View {
        VueDeBarreDeSelection(
            selection: selection,
            libelles: libelles.selection,
            executer: commandes.executer,
            fermer: commandes.viderLaSelection
        )
        .padding(.bottom, Jetons.BarreDeSelection.margeBasse)
    }
}
