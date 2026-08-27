import Core
import SwiftUI

//
// Banniere de reactivation, regle de degradation de la section 10 du cahier de
// developpement.
//
// Le document exige qu une source premium passee en lecture seule affiche une
// banniere expliquant comment la reactiver. Il ne dessine pas cette banniere.
// DESIGN-SPEC.md n en dessine qu une seule, celle de la section 5.5 : rayon 12,
// contour 1 px `warning`, titre en `headline`, phrase en `footnote`, boutons en
// dessous, et le reste de la colonne reste utilisable.
//
// Le gabarit est donc repris tel quel plutot qu invente. Deux formes de banniere
// dans un produit dont la these veut que l interface disparaisse en feraient une
// de trop, et la regle 4 de la section 0 impose d ailleurs de composer avec les
// jetons existants avant d en creer.
//
// Une seule difference avec la banniere d erreur, et elle est voulue. Un seul
// bouton, celui qui mene au mur. La banniere n annonce pas une panne a reessayer,
// elle annonce un etat stable que l utilisateur peut changer quand il veut.
//
// Le bouton porte le libelle de la ligne de reglages qui fait la meme chose,
// `Passer a Premium`. Le meme mot pour la meme action d un bout a l autre du
// parcours, regle d ecriture de la section 6.
//

/// Ce que la banniere de reactivation dit, une fois les textes composes.
///
/// La banniere ne compose rien elle meme. Le nom de la source et la date de fin
/// d abonnement sont des valeurs reelles, et le tableau 6.4 exige qu une phrase
/// qui nomme quelque chose nomme la vraie valeur. L application les insere dans
/// les motifs du catalogue de chaines, ce paquet ne fait que les poser.
public struct BanniereDeReactivation: Sendable, Equatable {
    /// Titre en `headline`, qui nomme la source concernee.
    public let titre: String

    /// Phrase en `footnote`, qui dit ce qui reste intact et comment reprendre.
    public let phrase: String

    /// Libelle du bouton qui ouvre le mur premium.
    public let libelleDuBouton: String

    public init(titre: String, phrase: String, libelleDuBouton: String) {
        self.titre = titre
        self.phrase = phrase
        self.libelleDuBouton = libelleDuBouton
    }
}

/// Textes de la banniere de reactivation.
///
/// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
/// sait lequel c est.
public struct LibellesDeBanniereDeReactivation: Sendable, Equatable {
    /// Motif du titre, avec le nom de la source.
    public let titre: String

    /// Motif de la phrase quand un abonnement a couru puis s est arrete, avec
    /// la date de fin.
    public let phraseApresExpiration: String

    /// Phrase quand aucun abonnement n a jamais ete pris.
    public let phraseSansAbonnement: String

    /// Libelle du bouton qui ouvre le mur.
    public let passerAPremium: String

    public init(
        titre: String,
        phraseApresExpiration: String,
        phraseSansAbonnement: String,
        passerAPremium: String
    ) {
        self.titre = titre
        self.phraseApresExpiration = phraseApresExpiration
        self.phraseSansAbonnement = phraseSansAbonnement
        self.passerAPremium = passerAPremium
    }
}

/// Assemblage des textes de la banniere.
public enum TexteDeLaBanniereDeReactivation {
    /// Banniere composee pour une source, nulle quand la source n en porte pas.
    ///
    /// La date est rendue par l appelant plutot que formatee ici : un format de
    /// date depend de la langue et du calendrier de l utilisateur, ce que ce
    /// paquet n a pas a decider.
    ///
    /// - Parameters:
    ///   - acces: acces rendu par la matrice pour cette source.
    ///   - nomDeLaSource: nom que l utilisateur a donne a sa source.
    ///   - dateDeFin: date de fin d abonnement deja mise en forme.
    ///   - libelles: textes pris dans le catalogue de chaines.
    public static func banniere(
        pour acces: AccesAUneSource,
        nomDeLaSource: String,
        dateDeFin: String,
        libelles: LibellesDeBanniereDeReactivation
    ) -> BanniereDeReactivation? {
        guard let motif = acces.motifDeLaBanniere else {
            return nil
        }

        let phrase = switch motif {
        case .abonnementExpire:
            String(format: libelles.phraseApresExpiration, dateDeFin)

        case .aucunAbonnement:
            libelles.phraseSansAbonnement
        }

        return BanniereDeReactivation(
            titre: String(format: libelles.titre, nomDeLaSource),
            phrase: phrase,
            libelleDuBouton: libelles.passerAPremium
        )
    }
}

/// Banniere posee au dessus d une source premium passee en lecture seule.
///
/// Elle ne remplace jamais le contenu. La source reste consultable, ses
/// chapitres telecharges restent lisibles, et c est exactement ce que la
/// banniere annonce.
public struct VueDeBanniereDeReactivation: View {
    @Environment(\.palette) private var palette

    private let banniere: BanniereDeReactivation
    private let ouvrirLeMurPremium: () -> Void

    /// Construit la banniere.
    ///
    /// - Parameters:
    ///   - banniere: textes deja composes.
    ///   - ouvrirLeMurPremium: ce que le bouton declenche. Le mur reste le seul
    ///     point d entree vers l achat, section 10.
    public init(
        banniere: BanniereDeReactivation,
        ouvrirLeMurPremium: @escaping () -> Void
    ) {
        self.banniere = banniere
        self.ouvrirLeMurPremium = ouvrirLeMurPremium
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            enTete
                .padding(.bottom, Jetons.BanniereDeReglages.ecartApresLeTitre)

            Text(banniere.phrase)
                .style(Jetons.BanniereDeReglages.phrase)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)

            bouton
                .padding(.top, Jetons.BanniereDeReglages.ecartAvantLesBoutons)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Jetons.BanniereDeReglages.remplissage)
        .background(
            RoundedRectangle(cornerRadius: Jetons.BanniereDeReglages.rayon, style: .continuous)
                .fill(palette.surfaces.card.couleur)
        )
        .overlay(contour)
    }

    /// Couronne et titre sur la meme ligne.
    ///
    /// La couronne dit la meme chose que dans les reglages et dans le panneau de
    /// filtres, une fonction tenue par l abonnement. Elle est masquee aux
    /// lecteurs d ecran : le titre porte deja l information, et la section 7
    /// interdit de transmettre quoi que ce soit par le seul glyphe.
    private var enTete: some View {
        HStack(spacing: Jetons.BanniereDeReglages.ecartEntreLesBoutons) {
            Image(systemName: Jetons.Icone.premium)
                .foregroundStyle(palette.semantiques.accent.couleur)
                .accessibilityHidden(true)

            Text(banniere.titre)
                .style(Jetons.BanniereDeReglages.titre)
                .foregroundStyle(palette.textes.primary.couleur)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bouton: some View {
        Button(banniere.libelleDuBouton, action: ouvrirLeMurPremium)
            .buttonStyle(
                BoutonSecondaire(
                    hauteur: Jetons.Bouton.hauteurEnEtat,
                    rayon: Jetons.Bouton.rayonEnEtat
                )
            )
    }

    private var contour: some View {
        RoundedRectangle(cornerRadius: Jetons.BanniereDeReglages.rayon, style: .continuous)
            .strokeBorder(
                palette.semantiques.warning.couleur,
                lineWidth: Jetons.BanniereDeReglages.epaisseurDuContour
            )
    }
}
