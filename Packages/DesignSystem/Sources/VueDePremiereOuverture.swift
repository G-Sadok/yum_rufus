import Core
import SwiftUI

//
// Parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md.
//
// Trois etapes, une decision par etape. La vue ne decide ni du nombre d etapes,
// qui vient de `EtapeDePremiereOuverture`, ni de ce que chacune offre, qui vient
// de `ParcoursDePremiereOuverture`. Elle recoit un etat et le dessine. Une
// quatrieme etape ajoutee ici ne compilerait pas.
//
// La troisieme etape pose deux boutons de meme gabarit. Ils sont construits par
// la meme fonction, dans la meme rangee, chacun prenant la moitie de la largeur.
// C est la seule facon de tenir la phrase de la section 5.10 autrement qu en
// promesse : un bouton d essai elargi retrecirait Plus tard, et la suite de
// tests virerait au rouge.
//

/// Ce que les commandes du parcours declenchent.
public struct CommandesDePremiereOuverture {
    /// Retient un sens de lecture, premiere etape.
    public let choisirLeSens: @MainActor (SensDeLecture) -> Void

    /// Ajoute une source mise en avant, deuxieme etape.
    public let ajouterLaSource: @MainActor (TypeDeSource) -> Void

    /// Ouvre la liste complete des types de sources, deuxieme etape.
    public let voirToutesLesSources: @MainActor () -> Void

    /// Execute une commande de l etape affichee.
    public let executer: @MainActor (CommandeDePremiereOuverture) -> Void

    public init(
        choisirLeSens: @escaping @MainActor (SensDeLecture) -> Void,
        ajouterLaSource: @escaping @MainActor (TypeDeSource) -> Void,
        voirToutesLesSources: @escaping @MainActor () -> Void,
        executer: @escaping @MainActor (CommandeDePremiereOuverture) -> Void
    ) {
        self.choisirLeSens = choisirLeSens
        self.ajouterLaSource = ajouterLaSource
        self.voirToutesLesSources = voirToutesLesSources
        self.executer = executer
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDePremiereOuverture {
        CommandesDePremiereOuverture(
            choisirLeSens: { _ in },
            ajouterLaSource: { _ in },
            voirToutesLesSources: {},
            executer: { _ in }
        )
    }
}

/// Ecran du parcours de premiere ouverture, section 5.10.
public struct VueDePremiereOuverture: View {
    @Environment(\.palette) private var palette

    private let etape: EtapeDePremiereOuverture
    private let parcours: ParcoursDePremiereOuverture
    private let libelles: LibellesDePremiereOuverture
    private let commandes: CommandesDePremiereOuverture

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etape: etape affichee.
    ///   - parcours: etat du parcours, qui porte les decisions deja prises.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///     de la troisieme etape. C est la meme offre, donc les memes mots.
    ///   - commandes: ce que les boutons declenchent.
    public init(
        etape: EtapeDePremiereOuverture,
        parcours: ParcoursDePremiereOuverture,
        libelles: LibellesDePremiereOuverture,
        commandes: CommandesDePremiereOuverture
    ) {
        self.etape = etape
        self.parcours = parcours
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        VStack(spacing: 0) {
            PointsDeProgression(etape: etape, libelles: libelles)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: Jetons.PremiereOuverture.ecartAvantLeCorps)

            enTete

            corps
                .padding(.top, Jetons.PremiereOuverture.ecartAvantLeCorps)

            Spacer(minLength: Jetons.PremiereOuverture.ecartAvantLesCommandes)

            RangeeDeCommandes(
                commandes: ParcoursDePremiereOuverture.commandes(
                    de: etape,
                    source: parcours.source
                ),
                libelles: libelles,
                executer: commandes.executer
            )
        }
        .frame(maxWidth: Jetons.PremiereOuverture.largeurDuContenu)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Jetons.PremiereOuverture.marge)
        .background(palette.surfaces.canvas.couleur)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: En tete

    private var enTete: some View {
        VStack(spacing: Jetons.PremiereOuverture.ecartApresLeTitre) {
            Text(libelles.titre(de: etape))
                .style(Jetons.PremiereOuverture.titre)
                .foregroundStyle(palette.textes.primary.couleur)
                .accessibilityAddTraits(.isHeader)

            Text(libelles.phrase(de: etape))
                .style(Jetons.PremiereOuverture.phrase)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: Corps

    @ViewBuilder
    private var corps: some View {
        switch etape {
        case .sensDeLecture:
            cartesDeSens

        case .premiereSource:
            sources
        }
    }

    /// Premiere etape, deux cartes de 300 avec apercu.
    private var cartesDeSens: some View {
        HStack(spacing: Jetons.PremiereOuverture.ecartEntreLesCartes) {
            ForEach(TexteDePremiereOuverture.sensProposes, id: \.self) { sens in
                CarteDeSensDeLecture(
                    sens: sens,
                    choisi: parcours.sens == sens,
                    libelles: libelles
                ) {
                    commandes.choisirLeSens(sens)
                }
            }
        }
    }

    /// Deuxieme etape, trois lignes de source et le lien vers les douze types.
    private var sources: some View {
        VStack(spacing: Jetons.PremiereOuverture.ecartEntreLesLignesDeSource) {
            ForEach(ParcoursDePremiereOuverture.entreesMisesEnAvant) { entree in
                LigneDeSourceInitiale(
                    type: entree.type,
                    etat: parcours.source,
                    libelles: libelles
                ) {
                    commandes.ajouterLaSource(entree.type)
                }
            }

            Button(libelles.voirToutesLesSources, action: commandes.voirToutesLesSources)
                .buttonStyle(BoutonDiscret(style: Jetons.PremiereOuverture.libelleDeSource))

            Text(libelles.mentionDeLaDeuxiemeEtape)
                .style(Jetons.PremiereOuverture.mention)
                .foregroundStyle(palette.textes.quaternary.couleur)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Troisieme etape, la liste des avantages de la section 5.9.
}
