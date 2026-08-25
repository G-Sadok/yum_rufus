import Core
import Foundation
import SwiftUI

//
// Ecran Historique, section 5.2 de DESIGN-SPEC.md.
//
// Liste groupee par jour, en tete collant portant la date en `headline`,
// vignettes, suppression unitaire, effacement global confirme par une modale
// courte.
//
// Le regroupement lui meme n est pas fait ici : il vient de Core, avec le
// calendrier de l utilisateur, parce qu il se teste et que minuit ne se
// verifie pas a l oeil dans une vue.
//

/// Etat de la zone de contenu de l historique, regle 5 de la section 0.
public enum EtatDeListeDHistorique {
    /// Entrees en cours de lecture.
    case chargement

    /// Liste prete. Un tableau vide donne l etat vide du tableau 6.3.
    case chargee([JourneeDHistorique])

    /// L historique n a pas pu etre lu. L etat est compose par l appelant, qui
    /// seul connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes de l historique declenchent.
public struct CommandesDHistorique {
    /// Rouvre un chapitre dans le lecteur, nulle tant qu aucun lecteur ne peut
    /// l accueillir.
    public let ouvrir: (@MainActor (UUID) -> Void)?
    /// Retire une entree de l historique.
    public let supprimer: @MainActor (UUID) -> Void
    /// Referme la modale d effacement sans rien effacer.
    public let annulerLEffacement: @MainActor () -> Void
    /// Efface tout l historique.
    public let confirmerLEffacement: @MainActor () -> Void

    public init(
        ouvrir: (@MainActor (UUID) -> Void)?,
        supprimer: @escaping @MainActor (UUID) -> Void,
        annulerLEffacement: @escaping @MainActor () -> Void,
        confirmerLEffacement: @escaping @MainActor () -> Void
    ) {
        self.ouvrir = ouvrir
        self.supprimer = supprimer
        self.annulerLEffacement = annulerLEffacement
        self.confirmerLEffacement = confirmerLEffacement
    }
}

/// Ecran Historique.
public struct VueDHistorique<Vignette: View>: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeListeDHistorique
    private let etatVide: EtatDeContenu
    private let effacementDemande: Bool
    private let libelles: LibellesDHistorique
    private let commandes: CommandesDHistorique
    private let vignette: (EntreeDHistorique) -> Vignette

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: etat de la zone de contenu.
    ///   - etatVide: etat vide compose par l appelant, tableau 6.3.
    ///   - effacementDemande: vrai quand la modale de confirmation est ouverte.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - commandes: ce que declenchent les actions de la liste.
    ///   - vignette: couverture d une serie, fournie par l appelant.
    public init(
        etat: EtatDeListeDHistorique,
        etatVide: EtatDeContenu,
        effacementDemande: Bool,
        libelles: LibellesDHistorique,
        commandes: CommandesDHistorique,
        @ViewBuilder vignette: @escaping (EntreeDHistorique) -> Vignette
    ) {
        self.etat = etat
        self.etatVide = etatVide
        self.effacementDemande = effacementDemande
        self.libelles = libelles
        self.commandes = commandes
        self.vignette = vignette
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modaleCourte(presentee: effacementDemande, contenu: confirmation)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            squelettes

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(journees):
            if journees.isEmpty {
                VueDEtatDeContenu(etatVide)
            } else {
                liste(journees)
            }
        }
    }

    // MARK: Liste

    private func liste(_ journees: [JourneeDHistorique]) -> some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: Jetons.Historique.ecartEntreEntrees,
                pinnedViews: [.sectionHeaders]
            ) {
                ForEach(Array(journees.enumerated()), id: \.element.id) { rang, journee in
                    Section {
                        ForEach(journee.entrees) { entree in
                            ligne(entree)
                        }
                    } header: {
                        enTete(journee, estLaPremiere: rang == 0)
                    }
                }
            }
            .padding(.bottom, Jetons.Historique.margeBasse)
            .frame(maxWidth: Jetons.Contenu.largeurMaximale)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Jetons.Contenu.margeLaterale)
        }
    }

    @MainActor
    private func ligne(_ entree: EntreeDHistorique) -> some View {
        VueDeLigneDHistorique(
            entree: entree,
            libelles: libelles,
            ouvrir: commandes.ouvrir.map { ouvrir in { ouvrir(entree.chapitreId) } },
            supprimer: { commandes.supprimer(entree.id) },
            vignette: { vignette(entree) }
        )
    }

    /// En tete collant d une journee.
    ///
    /// Le fond est opaque et prend la couleur de la zone de contenu : un en
    /// tete transparent laisserait defiler les entrees sous la date.
    private func enTete(_ journee: JourneeDHistorique, estLaPremiere: Bool) -> some View {
        Text(TexteDHistorique.enTete(de: journee, libelles: libelles))
            .style(Jetons.Historique.enTeteDeJour)
            .foregroundStyle(palette.textes.primary.couleur)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Jetons.Historique.hauteurDEnTete, alignment: .bottom)
            .padding(.top, estLaPremiere ? 0 : Jetons.Historique.margeAvantEnTete)
            .background(palette.surfaces.canvas.couleur)
            .accessibilityAddTraits(.isHeader)
    }

    /// Squelettes aux dimensions exactes des entrees attendues, section 4.10.
    private var squelettes: some View {
        VStack(spacing: Jetons.Historique.ecartEntreEntrees) {
            ForEach(0..<Self.nombreDeSquelettes, id: \.self) { _ in
                VueDeSquelette()
                    .frame(height: Jetons.Historique.hauteurDEntree)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Jetons.Contenu.margeLaterale)
        .padding(.top, Jetons.Historique.margeAvantEnTete)
        .frame(maxWidth: Jetons.Contenu.largeurMaximale)
        .frame(maxWidth: .infinity)
    }

    /// Nombre de squelettes affiches pendant le chargement.
    ///
    /// Le document ne le chiffre pas. Cinq entrees de 80 occupent la hauteur
    /// utile d une fenetre de reference sans promettre une longueur de liste
    /// que la base n a pas encore rendue.
    private static var nombreDeSquelettes: Int {
        5
    }

    // MARK: Effacement global

    /// Modale de confirmation de l effacement, section 4.8.
    ///
    /// La propriete est isolee au fil principal pour la meme raison que les
    /// commandes : les deux actions partent d un geste rendu la, et touchent un
    /// etat qui y vit.
    @MainActor
    private var confirmation: ContenuDeModaleCourte {
        ContenuDeModaleCourte(
            titre: libelles.confirmationTitre,
            description: libelles.confirmationDescription,
            annuler: ActionDEtat(libelle: libelles.confirmationAnnuler) {
                commandes.annulerLEffacement()
            },
            confirmer: ActionDEtat(libelle: libelles.confirmationEffacer) {
                commandes.confirmerLEffacement()
            },
            confirmationEstDestructive: true
        )
    }
}
