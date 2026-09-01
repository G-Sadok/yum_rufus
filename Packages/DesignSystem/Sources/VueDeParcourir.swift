import Core
import SwiftUI

//
// VueDeParcourir
//
// L ecran Parcourir de la section 5.3 : la liste des sources installees, et le
// menu qui en ajoute.
//
// Le menu porte les douze entrees dans l ordre impose, avec le separateur apres
// la premiere. Cet ordre n est pas decoratif : il place les sources les plus
// courantes en tete, et le transfert Wi-Fi a part parce qu il n installe rien,
// il ouvre une reception temporaire.
//
// L ecran sans source ne montre pas une liste vide mais un etat vide qui dit
// quoi faire. Une liste vide laisse l utilisateur chercher le bouton ; l etat
// vide le lui donne.
//

/// Ce que l ecran Parcourir affiche.
///
/// Non `Sendable`, comme `EtatDeContenu` qu il porte.
public enum EtatDeParcourir {
    /// Les sources ne sont pas encore lues.
    case chargement

    /// Sources installees, eventuellement aucune.
    case chargee([SourceAffichee])

    /// Echec nomme, avec sa sortie.
    case erreur(EtatDeContenu)
}

/// Une source telle que la liste la montre.
public struct SourceAffichee: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let nom: String
    public let type: TypeDeSource

    public init(id: UUID, nom: String, type: TypeDeSource) {
        self.id = id
        self.nom = nom
        self.type = type
    }
}

/// Textes de l ecran, pris dans le catalogue de l application.
public struct LibellesDeParcourir: Sendable, Equatable {
    public let ajouter: String
    public let compteur: String
    public let videTitre: String
    public let videPhrase: String

    /// Libelle de chaque entree du menu, par type de source.
    public let entreesDuMenu: [TypeDeSource: String]

    public init(
        ajouter: String,
        compteur: String,
        videTitre: String,
        videPhrase: String,
        entreesDuMenu: [TypeDeSource: String]
    ) {
        self.ajouter = ajouter
        self.compteur = compteur
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.entreesDuMenu = entreesDuMenu
    }

    /// Libelle d une entree, celui du document quand le catalogue est muet.
    public func libelle(de entree: EntreeDuMenuDAjout) -> String {
        entreesDuMenu[entree.type] ?? entree.nomDuDocument
    }
}

/// Ce que l ecran declenche.
public struct CommandesDeParcourir {
    public let ajouter: @MainActor (TypeDeSource) -> Void
    public let ouvrir: @MainActor (UUID) -> Void
    public let supprimer: @MainActor (UUID) -> Void

    public init(
        ajouter: @escaping @MainActor (TypeDeSource) -> Void,
        ouvrir: @escaping @MainActor (UUID) -> Void,
        supprimer: @escaping @MainActor (UUID) -> Void
    ) {
        self.ajouter = ajouter
        self.ouvrir = ouvrir
        self.supprimer = supprimer
    }
}

/// Ecran Parcourir, section 5.3.
public struct VueDeParcourir: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeParcourir
    private let libelles: LibellesDeParcourir
    private let commandes: CommandesDeParcourir

    public init(
        etat: EtatDeParcourir,
        libelles: LibellesDeParcourir,
        commandes: CommandesDeParcourir
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            ProgressView()
                .controlSize(.large)

        case let .chargee(sources) where sources.isEmpty:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.Icone.parcourir,
                    titre: libelles.videTitre,
                    phrase: libelles.videPhrase,
                    action: nil
                )
            )

        case let .chargee(sources):
            liste(sources)

        case let .erreur(contenu):
            VueDEtatDeContenu(contenu)
        }
    }

    private func liste(_ sources: [SourceAffichee]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(sources.count) \(libelles.compteur)")
                .style(Jetons.Parcourir.compteur)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.horizontal, Jetons.Parcourir.margeLaterale)
                .padding(.vertical, Jetons.Espace.x3)

            List {
                ForEach(sources) { source in
                    Button {
                        commandes.ouvrir(source.id)
                    } label: {
                        HStack(spacing: Jetons.Espace.x4) {
                            Text(source.nom)
                                .style(Jetons.Parcourir.nom)
                                .foregroundStyle(palette.textes.primary.couleur)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            commandes.supprimer(source.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(libelles.supprimer)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
