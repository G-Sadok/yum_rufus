import Core
import SwiftUI

//
// Gestion des prereglages de lecture, sous ecran de la section 5.5 de
// DESIGN-SPEC.md.
//
// Gabarit colonne 580, quatre etats. Une carte porte la liste, une ligne par
// prereglage, nom en `body` et resume en `footnote`. La ligne entiere applique
// le prereglage : c est l action principale de l ecran, et le second critere de
// la fonctionnalite veut qu elle tienne en un geste. Le renommage, le
// remplacement et la suppression vivent dans un menu, derriere le bouton
// d options.
//
// Aucun aplat d accent dans la liste. La section 5.5 reserve l accent a ce sur
// quoi on peut agir, et ici tout est actionnable : le teindre en accent ne
// distinguerait plus rien.
//

/// Etat de la zone de contenu de la gestion des prereglages.
public enum EtatDeGestionDesPrereglages {
    /// Liste en cours de lecture.
    case chargement

    /// Liste prete. Un tableau vide donne l etat vide.
    case chargee([PrereglageAffiche])

    /// La liste n a pas pu etre lue. L etat est compose par l appelant, qui
    /// seul connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes de l ecran declenchent.
///
/// Aucune de ces fermetures n ecrit en base elle meme. Elles remontent a
/// l ecran, seul a connaitre le magasin.
public struct CommandesDePrereglages {
    /// Capture l etat de lecture courant sous un nouveau nom.
    public let enregistrerLActuel: @MainActor () -> Void
    /// Applique un prereglage.
    public let appliquer: @MainActor (UUID) -> Void
    /// Ouvre le renommage d un prereglage.
    public let renommer: @MainActor (UUID) -> Void
    /// Remplace ce qu un prereglage capture par l etat courant.
    public let remplacerParLActuel: @MainActor (UUID) -> Void
    /// Supprime un prereglage.
    public let supprimer: @MainActor (UUID) -> Void

    public init(
        enregistrerLActuel: @escaping @MainActor () -> Void,
        appliquer: @escaping @MainActor (UUID) -> Void,
        renommer: @escaping @MainActor (UUID) -> Void,
        remplacerParLActuel: @escaping @MainActor (UUID) -> Void,
        supprimer: @escaping @MainActor (UUID) -> Void
    ) {
        self.enregistrerLActuel = enregistrerLActuel
        self.appliquer = appliquer
        self.renommer = renommer
        self.remplacerParLActuel = remplacerParLActuel
        self.supprimer = supprimer
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDePrereglages {
        CommandesDePrereglages(
            enregistrerLActuel: {},
            appliquer: { _ in },
            renommer: { _ in },
            remplacerParLActuel: { _ in },
            supprimer: { _ in }
        )
    }
}

/// Ecran de gestion des prereglages de lecture.
public struct VueDeGestionDesPrereglages: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeGestionDesPrereglages
    private let libelles: LibellesDePrereglages
    private let commandes: CommandesDePrereglages

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, liste ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes et le bouton declenchent.
    public init(
        etat: EtatDeGestionDesPrereglages,
        libelles: LibellesDePrereglages,
        commandes: CommandesDePrereglages
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
            colonne { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(prereglages):
            if prereglages.isEmpty {
                VueDEtatDeContenu(etatVide)
            } else {
                colonne { liste(prereglages) }
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
                boutonDEnregistrement
            }
            .frame(maxWidth: Jetons.Prereglages.largeurDeColonne)
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

    /// Action qui capture l etat de lecture courant, section 9 du cahier de
    /// developpement.
    private var boutonDEnregistrement: some View {
        Button(libelles.enregistrerLActuel) {
            commandes.enregistrerLActuel()
        }
        .buttonStyle(
            BoutonPrincipal(
                hauteur: Jetons.Bouton.hauteurEnContenu,
                rayon: Jetons.Bouton.rayonEnContenu
            )
        )
        .padding(.top, Jetons.CarteDeReglages.espaceEntreSections)
    }

    // MARK: Liste

    private func liste(_ prereglages: [PrereglageAffiche]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(prereglages.enumerated()), id: \.element.id) { rang, prereglage in
                LigneDePrereglage(
                    prereglage: prereglage,
                    libelles: libelles,
                    commandes: commandes
                )

                if rang < prereglages.count - 1 {
                    separateur
                }
            }
        }
        .background(palette.surfaces.card.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.Prereglages.rayon, style: .continuous))
    }

    /// Filet encastre de 20 a gauche, affleurant a droite, section 4.2.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.Prereglages.epaisseurDuSeparateur)
            .padding(.leading, Jetons.Prereglages.encastrementDuSeparateur)
            .accessibilityHidden(true)
    }

    /// Squelettes aux dimensions exactes des lignes attendues, section 4.10.
    private var squelettes: some View {
        VueDeSquelette()
            .frame(
                height: Jetons.Prereglages.hauteurDeLigne
                    * Double(Jetons.Prereglages.nombreDeSquelettes)
            )
    }

    // MARK: Etat vide

    /// Etat vide de la section 4.10, celui que la section 5.5 nomme
    /// `Aucun prereglage` sur une installation neuve.
    ///
    /// Il porte l action d enregistrement, comme la section 4.10 y invite : une
    /// liste vide est une invitation a agir, pas un constat.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Prereglages.symbole,
            titre: libelles.videTitre,
            phrase: libelles.videPhrase,
            action: ActionDEtat(libelle: libelles.enregistrerLActuel) {
                commandes.enregistrerLActuel()
            }
        )
    }
}

/// Une ligne de la liste des prereglages.
///
/// La ligne entiere est le bouton qui applique le prereglage. Le bouton
/// d options est pose par dessus, dans un `HStack`, et non dans le bouton :
/// imbriquer deux boutons rendrait le menu inatteignable au clavier.
struct LigneDePrereglage: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let prereglage: PrereglageAffiche
    let libelles: LibellesDePrereglages
    let commandes: CommandesDePrereglages

    var body: some View {
        HStack(spacing: Jetons.Prereglages.ecartAvantLesOptions) {
            application
            options
        }
        .padding(.horizontal, Jetons.Prereglages.margeLaterale)
        .frame(minHeight: Jetons.Prereglages.hauteurDeLigne)
        .contourDeFocus(focalisee, rayonDeLElement: 0)
    }

    /// Bouton qui applique le prereglage, toute la largeur du texte.
    private var application: some View {
        Button {
            commandes.appliquer(prereglage.id)
        } label: {
            texte
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focalisee)
        .accessibilityLabel(etiquette)
        .accessibilityHint(libelles.appliquer)
    }

    private var texte: some View {
        VStack(alignment: .leading, spacing: Jetons.Prereglages.ecartApresLeNom) {
            Text(prereglage.nom)
                .style(Jetons.Prereglages.nom)
                .foregroundStyle(palette.textes.primary.couleur)

            if let resume {
                Text(resume)
                    .style(Jetons.Prereglages.resume)
                    .foregroundStyle(palette.textes.tertiary.couleur)
            }
        }
        .lineLimit(1)
    }

    /// Menu des commandes de gestion, section 4.1.
    private var options: some View {
        Menu {
            Button(libelles.appliquer) { commandes.appliquer(prereglage.id) }
            Button(libelles.renommer) { commandes.renommer(prereglage.id) }
            Button(libelles.remplacerParLActuel) {
                commandes.remplacerParLActuel(prereglage.id)
            }
            Button(libelles.supprimer, role: .destructive) {
                commandes.supprimer(prereglage.id)
            }
        } label: {
            // Le menu porte deja son etiquette, le symbole ne la double pas.
            Image(systemName: Jetons.Prereglages.symboleDOptions)
                .font(.system(size: Jetons.Prereglages.tailleDuSymboleDOptions))
                .foregroundStyle(palette.textes.secondary.couleur)
                .accessibilityHidden(true)
                .frame(
                    width: Jetons.Prereglages.coteDuBoutonDOptions,
                    height: Jetons.Prereglages.coteDuBoutonDOptions
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(libelles.options)
    }

    /// Resume de ce que le prereglage capture, absent quand sa colonne est
    /// abimee.
    private var resume: String? {
        guard let contenu = prereglage.contenu else {
            return nil
        }

        return TexteDePrereglage.resume(de: contenu, libelles: libelles)
    }

    /// Etiquette lue par VoiceOver, qui porte le nom et le resume.
    private var etiquette: String {
        TexteDeChapitre.joindre([prereglage.nom, resume ?? ""])
    }
}
