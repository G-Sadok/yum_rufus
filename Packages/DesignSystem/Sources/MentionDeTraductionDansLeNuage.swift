import Core
import SwiftUI

//
// Mention du moteur de traduction dans le nuage, section 8 du cahier de
// developpement.
//
// La section 8 tient en une phrase : tout tourne sur l appareil, aucune image ne
// quitte l appareil sauf si l utilisateur choisit explicitement le moteur de
// traduction dans le nuage. Une promesse pareille ne vaut que si l exception se
// voit. Un utilisateur qui a accepte le moteur distant il y a trois semaines
// doit pouvoir constater, sur la page qu il lit, que du texte part vers un
// service.
//
// La mention emprunte tout son gabarit a la banniere du mode incognito, et ce
// n est pas une economie : les deux disent la meme chose de la meme facon, un
// etat de session qui change ce que l application fait de vos donnees. Leur
// donner deux formes apprendrait a l utilisateur deux vocabulaires visuels pour
// une seule idee.
//
// Elle ne se ferme pas, pour la meme raison que celle du mode incognito : c est
// sa presence qui porte l information. Elle disparait quand le moteur distant
// cesse d etre employe, et seulement alors.
//

/// Ce que la mention de traduction distante dit, une fois les textes composes.
public struct MentionDeTraductionDansLeNuage: Sendable, Equatable {
    /// Titre en `headline`, qui nomme le moteur employe.
    public let titre: String

    /// Phrase en `footnote`, qui dit ce qui sort de l appareil.
    public let phrase: String

    public init(titre: String, phrase: String) {
        self.titre = titre
        self.phrase = phrase
    }

    /// Vrai quand l utilisateur peut faire disparaitre la mention.
    ///
    /// La reponse est toujours fausse. Elle existe pour que la suite de tests le
    /// verifie plutot que de le supposer, et pour qu un bouton de fermeture
    /// ajoute un jour ait a mentir ici avant de passer.
    public var peutEtreFermee: Bool {
        false
    }
}

/// Textes de la mention de traduction distante.
///
/// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
/// sait lequel c est.
public struct LibellesDeTraduction: Sendable, Equatable {
    /// Titre de la mention, qui nomme le moteur.
    public let titreDuNuage: String

    /// Phrase de la mention, qui dit ce qui sort de l appareil.
    public let phraseDuNuage: String

    /// Etiquette d accessibilite de la mention entiere.
    public let etiquetteDuNuage: String

    public init(titreDuNuage: String, phraseDuNuage: String, etiquetteDuNuage: String) {
        self.titreDuNuage = titreDuNuage
        self.phraseDuNuage = phraseDuNuage
        self.etiquetteDuNuage = etiquetteDuNuage
    }
}

/// Assemblage de la mention a partir des reglages.
public enum TexteDeLaMentionDeTraduction {
    /// Mention a afficher, nulle quand rien ne sort de l appareil.
    ///
    /// La condition est `sortDeLAppareil`, jamais le moteur choisi dans le menu.
    /// Un moteur distant choisi mais pas encore accepte ne fait rien sortir, et
    /// afficher la mention dans ce cas apprendrait a l utilisateur a ne plus la
    /// croire.
    ///
    /// - Parameters:
    ///   - reglages: reglages de la section Traduction.
    ///   - libelles: textes pris dans le catalogue de chaines.
    public static func mention(
        pour reglages: ReglagesDeTraduction,
        libelles: LibellesDeTraduction
    ) -> MentionDeTraductionDansLeNuage? {
        guard reglages.sortDeLAppareil else { return nil }

        return MentionDeTraductionDansLeNuage(
            titre: libelles.titreDuNuage,
            phrase: libelles.phraseDuNuage
        )
    }
}

/// Mention posee dans le lecteur tant que le moteur distant traduit.
public struct VueDeMentionDeTraduction: View {
    @Environment(\.palette) private var palette

    private let mention: MentionDeTraductionDansLeNuage
    private let etiquette: String

    /// Construit la mention.
    ///
    /// Aucune action n est prise en parametre, et c est voulu : la mention ne se
    /// ferme pas.
    ///
    /// - Parameters:
    ///   - mention: textes deja composes.
    ///   - etiquette: etiquette d accessibilite de la mention entiere.
    public init(mention: MentionDeTraductionDansLeNuage, etiquette: String) {
        self.mention = mention
        self.etiquette = etiquette
    }

    public var body: some View {
        HStack(spacing: Jetons.BanniereDIncognito.ecartInterne) {
            glyphe

            Text(mention.titre)
                .style(Jetons.BanniereDIncognito.titre)
                .foregroundStyle(palette.textes.primary.couleur)

            Text(mention.phrase)
                .style(Jetons.BanniereDIncognito.phrase)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Jetons.BanniereDIncognito.remplissage)
        .background(fond)
        .overlay(contour)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiquette)
    }

    /// Glyphe du nuage, masque aux lecteurs d ecran.
    ///
    /// L etiquette de la mention porte deja l information, et la section 7
    /// interdit de la transmettre par le seul glyphe.
    private var glyphe: some View {
        Image(systemName: Jetons.Traduction.glypheDuNuage)
            .font(.system(size: Jetons.BanniereDIncognito.tailleDuGlyphe))
            .foregroundStyle(palette.textes.secondary.couleur)
            .accessibilityHidden(true)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BanniereDIncognito.rayon, style: .continuous)
            .fill(palette.surfaces.card.couleur)
    }

    private var contour: some View {
        RoundedRectangle(cornerRadius: Jetons.BanniereDIncognito.rayon, style: .continuous)
            .strokeBorder(
                palette.semantiques.border.couleur,
                lineWidth: Jetons.BanniereDIncognito.epaisseurDuContour
            )
    }
}

extension View {
    /// Pose la mention de traduction distante au dessus de cette vue.
    ///
    /// - Parameters:
    ///   - mention: mention composee, nulle quand rien ne sort de l appareil.
    ///   - etiquette: etiquette d accessibilite de la mention.
    public func mentionDeTraduction(
        _ mention: MentionDeTraductionDansLeNuage?,
        etiquette: String
    ) -> some View {
        overlay(alignment: .top) {
            if let mention {
                VueDeMentionDeTraduction(mention: mention, etiquette: etiquette)
                    .padding(Jetons.BanniereDIncognito.marge)
            }
        }
    }
}
