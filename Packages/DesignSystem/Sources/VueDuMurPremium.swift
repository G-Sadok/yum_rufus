import Core
import SwiftUI

//
// Mur premium, section 5.9 de DESIGN-SPEC.md.
//
// Feuille de 360 par 420, rayon 16, elevation 2 sur voile. Couronne, titre, sous
// titre, cinq avantages, bouton, mention de prix.
//
// Trois choses que cet ecran ne fait pas, et chacune est une decision.
//
// Il ne se presente jamais seul. Le modificateur de presentation prend une
// demande, pas un booleen, et la garde de `Core` tranche. C est ce qui tient la
// regle de la section 10 : le mur ne surgit jamais pendant la lecture.
//
// Il n affiche aucun compte a rebours, la section 5.9 l interdit. La date de fin
// d essai existe dans le modele pour fermer l acces, pas pour defiler a l ecran.
//
// Il ne cache pas la restauration. La section 10 du cahier de developpement la
// veut accessible depuis le mur, et un utilisateur qui a deja paye doit pouvoir
// reprendre son acces sans passer par une feuille d achat.
//

/// Etat de la feuille du mur premium.
public enum EtatDuMurPremium {
    /// Tarifs en cours de lecture. La section 5.9 montre la meme feuille en
    /// squelettes pour cet etat comme pour l etat vide.
    case chargement

    /// Tarifs lus, offre prete.
    case chargee(OffrePremium)

    /// La boutique n a pas repondu.
    case erreur
}

/// Ce que les commandes du mur declenchent.
public struct CommandesDuMurPremium {
    /// Lance l achat du produit mis en avant.
    public let acheter: @MainActor () -> Void

    /// Relit le compte et rend l acces deja paye.
    public let restaurer: @MainActor () -> Void

    /// Referme la feuille sans rien acheter.
    public let plusTard: @MainActor () -> Void

    /// Redemande les tarifs apres un echec.
    public let reessayer: @MainActor () -> Void

    public init(
        acheter: @escaping @MainActor () -> Void,
        restaurer: @escaping @MainActor () -> Void,
        plusTard: @escaping @MainActor () -> Void,
        reessayer: @escaping @MainActor () -> Void
    ) {
        self.acheter = acheter
        self.restaurer = restaurer
        self.plusTard = plusTard
        self.reessayer = reessayer
    }

    /// Commandes inertes, pour un apercu ou une feuille en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDuMurPremium {
        CommandesDuMurPremium(acheter: {}, restaurer: {}, plusTard: {}, reessayer: {})
    }
}

/// Feuille du mur premium, section 5.9.
public struct VueDuMurPremium: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDuMurPremium
    private let libelles: LibellesDuMurPremium
    private let commandes: CommandesDuMurPremium

    /// Construit la feuille.
    ///
    /// - Parameters:
    ///   - etat: chargement, offre ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les boutons declenchent.
    public init(
        etat: EtatDuMurPremium,
        libelles: LibellesDuMurPremium,
        commandes: CommandesDuMurPremium
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .padding(Jetons.MurPremium.marge)
            .frame(maxWidth: Jetons.MurPremium.largeur)
            .frame(minHeight: Jetons.MurPremium.hauteurDeReference)
            .background(fond)
            .elevation(
                Jetons.MurPremium.elevation,
                rayon: Jetons.MurPremium.rayon,
                palette: palette
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            squelettes

        case let .chargee(offre):
            offreComplete(offre)

        case .erreur:
            echecDeLaBoutique
        }
    }

    // MARK: Feuille

    /// Fond et contour de la section 5.9, tous deux chiffres par le document.
    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.MurPremium.rayon, style: .continuous)
            .fill(Jetons.MurPremium.fond.couleur)
            .overlay {
                RoundedRectangle(cornerRadius: Jetons.MurPremium.rayon, style: .continuous)
                    .strokeBorder(
                        Jetons.MurPremium.contour.couleur,
                        lineWidth: Jetons.MurPremium.epaisseurDuContour
                    )
            }
    }

    private func offreComplete(_ offre: OffrePremium) -> some View {
        VStack(spacing: 0) {
            couronne
            titre
            sousTitre
            avantages
            bouton(offre)
            mentionDePrix(offre)
            pied
        }
        .multilineTextAlignment(.center)
    }

    private var couronne: some View {
        Image(systemName: Jetons.MurPremium.couronne)
            .font(.system(size: Jetons.MurPremium.hauteurDeLaCouronne))
            .foregroundStyle(palette.semantiques.accent.couleur)
            .frame(
                width: Jetons.MurPremium.largeurDeLaCouronne,
                height: Jetons.MurPremium.hauteurDeLaCouronne
            )
            .padding(.bottom, Jetons.MurPremium.ecartApresLaCouronne)
            .accessibilityLabel(libelles.etiquetteDeLaCouronne)
    }

    private var titre: some View {
        Text(libelles.titre)
            .style(Jetons.MurPremium.titre)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.bottom, Jetons.MurPremium.ecartApresLeTitre)
            .accessibilityAddTraits(.isHeader)
    }

    private var sousTitre: some View {
        Text(libelles.sousTitre)
            .style(Jetons.MurPremium.sousTitre)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, Jetons.MurPremium.ecartAvantLesAvantages)
    }

    /// Les cinq avantages, dans l ordre de la section 5.9.
    private var avantages: some View {
        VStack(alignment: .leading, spacing: Jetons.MurPremium.interligneDesAvantages) {
            ForEach(AvantagePremium.allCases) { avantage in
                LigneDAvantagePremium(avantage: avantage, libelles: libelles)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Jetons.MurPremium.ecartAvantLeBouton)
    }

    private func bouton(_ offre: OffrePremium) -> some View {
        Button(
            TexteDuMurPremium.boutonPrincipal(pour: offre, libelles: libelles),
            action: commandes.acheter
        )
        .buttonStyle(
            BoutonPrincipal(
                hauteur: Jetons.MurPremium.hauteurDuBouton,
                rayon: Jetons.MurPremium.rayonDuBouton
            )
        )
        .frame(maxWidth: Jetons.MurPremium.largeurDuBouton)
        .keyboardShortcut(.defaultAction)
    }

    private func mentionDePrix(_ offre: OffrePremium) -> some View {
        Text(TexteDuMurPremium.mentionDePrix(pour: offre, libelles: libelles))
            .style(Jetons.MurPremium.mentionDePrix)
            .foregroundStyle(palette.textes.quaternary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Jetons.MurPremium.ecartApresLeBouton)
    }

    /// Restauration et sortie, les deux commandes qui ne vendent rien.
    ///
    /// La restauration est obligatoire et vit ici plutot que dans un menu : un
    /// utilisateur qui a deja paye rencontre le mur avant tout le reste.
    ///
    /// Le pied se construit en parcourant la liste des commandes offertes, celle
    /// que la suite de tests interroge. Un bouton retire de l ecran disparait
    /// donc aussi de la liste, et l inverse est vrai.
    private var pied: some View {
        HStack(spacing: Jetons.MurPremium.ecartEntreLesCommandesDePied) {
            ForEach(TexteDuMurPremium.commandesDePied(dans: etat)) { commande in
                Button(
                    TexteDuMurPremium.libelle(de: commande, libelles: libelles),
                    action: action(de: commande)
                )
                .buttonStyle(BoutonDiscret(style: Jetons.Typo.callout))
                .keyboardShortcut(raccourci(de: commande))
            }
        }
        .padding(.top, Jetons.MurPremium.ecartAvantLePied)
    }

    /// Travail declenche par une commande.
    private func action(de commande: CommandeDuMurPremium) -> @MainActor () -> Void {
        switch commande {
        case .acheter: commandes.acheter
        case .restaurer: commandes.restaurer
        case .plusTard: commandes.plusTard
        case .reessayer: commandes.reessayer
        }
    }

    /// Raccourci clavier d une commande, nul quand elle n en a pas.
    ///
    /// La touche d echappement referme la feuille, comme pour toute modale de la
    /// section 4.8.
    private func raccourci(de commande: CommandeDuMurPremium) -> KeyboardShortcut? {
        commande == .plusTard ? .cancelAction : nil
    }

    // MARK: Etats

    /// Etats vide et chargement, la meme feuille en squelettes, section 5.9.
    private var squelettes: some View {
        VueDeSquelette()
            .frame(
                maxWidth: .infinity,
                minHeight: Jetons.MurPremium.hauteurDesSquelettes
            )
            .clipShape(
                RoundedRectangle(cornerRadius: Jetons.MurPremium.rayon, style: .continuous)
            )
    }

    /// Etat d erreur, tableau 6.4, avec ses deux capsules.
    private var echecDeLaBoutique: some View {
        VStack(spacing: 0) {
            Image(systemName: Jetons.Icone.erreurDeContenu)
                .font(.system(size: Jetons.EtatDeContenu.tailleDuGlyphe, weight: .light))
                .foregroundStyle(palette.semantiques.warning.couleur)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeGlyphe)
                .accessibilityHidden(true)

            Text(libelles.erreurTitre)
                .style(Jetons.MurPremium.titre)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeTitre)
                .accessibilityAddTraits(.isHeader)

            Text(libelles.erreurPhrase)
                .style(Jetons.Typo.callout)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)

            capsules
                .padding(.top, Jetons.EtatDeContenu.ecartAvantLAction)
        }
        .multilineTextAlignment(.center)
    }

    /// Plus tard et Reessayer, dans l ordre du tableau 6.4.
    private var capsules: some View {
        HStack(spacing: Jetons.MurPremium.ecartEntreLesCommandesDePied) {
            ForEach(TexteDuMurPremium.commandesDePied(dans: etat)) { commande in
                Button(
                    TexteDuMurPremium.libelle(de: commande, libelles: libelles),
                    action: action(de: commande)
                )
                .buttonStyle(capsule)
                .frame(width: Jetons.MurPremium.largeurDeCapsule)
                .keyboardShortcut(raccourci(de: commande))
            }
        }
    }

    private var capsule: BoutonSecondaire {
        BoutonSecondaire(
            hauteur: Jetons.MurPremium.hauteurDeCapsule,
            rayon: Jetons.MurPremium.rayonDeCapsule
        )
    }
}

/// Une ligne d avantage, coche puis libelle, section 5.9.
struct LigneDAvantagePremium: View {
    @Environment(\.palette) private var palette

    let avantage: AvantagePremium
    let libelles: LibellesDuMurPremium

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Jetons.MurPremium.gouttiereApresLaCoche) {
            Image(systemName: Jetons.MurPremium.coche)
                .font(.system(size: Jetons.MurPremium.tailleDeLaCoche))
                .foregroundStyle(palette.semantiques.accent.couleur)
                .accessibilityHidden(true)

            Text(libelles.libelle(de: avantage))
                .style(Jetons.MurPremium.avantage)
                .foregroundStyle(palette.textes.secondary.couleur)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TexteDuMurPremium.etiquette(de: avantage, libelles: libelles))
    }
}
