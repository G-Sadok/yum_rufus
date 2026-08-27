import Core
import SwiftUI

//
// Banniere du mode incognito, section 11 du cahier de developpement.
//
// Le document exige que la banniere reste visible pendant toute la session. La
// permanence n est pas une propriete de la vue, c est une propriete de la
// session : `SessionIncognito.porteLaBanniere` la porte, et `Core` la teste
// contre toute la suite des evenements de l application. Ce fichier ne fait que
// poser a l ecran ce que la session a decide.
//
// La banniere ne porte donc aucun bouton de fermeture, et `peutEtreFermee` le
// dit explicitement plutot que de le laisser deviner par l absence de closure.
// Une banniere que l on peut faire disparaitre ne prouve plus rien : c est
// justement sa presence qui dit a l utilisateur que ce qu il lit n est pas
// enregistre.
//

/// Ce que la banniere du mode incognito dit, une fois les textes composes.
public struct BanniereDIncognito: Sendable, Equatable {
    /// Titre en `headline`, qui nomme le mode.
    public let titre: String

    /// Phrase en `footnote`, qui dit ce qui n est pas enregistre.
    public let phrase: String

    public init(titre: String, phrase: String) {
        self.titre = titre
        self.phrase = phrase
    }

    /// Vrai quand l utilisateur peut faire disparaitre la banniere.
    ///
    /// La reponse est toujours fausse, et c est le critere de la section 11.
    /// Elle existe pour que la suite de tests le verifie plutot que de le
    /// supposer, et pour qu un bouton de fermeture ajoute un jour ait a mentir
    /// ici avant de passer.
    public var peutEtreFermee: Bool {
        false
    }
}

/// Textes de la banniere du mode incognito.
///
/// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
/// sait lequel c est.
public struct LibellesDIncognito: Sendable, Equatable {
    /// Titre, qui nomme le mode.
    public let titre: String

    /// Phrase, qui dit ce qui n est pas enregistre.
    public let phrase: String

    /// Etiquette d accessibilite de la banniere entiere.
    public let etiquetteDAccessibilite: String

    public init(titre: String, phrase: String, etiquetteDAccessibilite: String) {
        self.titre = titre
        self.phrase = phrase
        self.etiquetteDAccessibilite = etiquetteDAccessibilite
    }
}

/// Assemblage de la banniere a partir de la session.
public enum TexteDeLaBanniereDIncognito {
    /// Banniere de la session, nulle quand aucune session ne court.
    ///
    /// - Parameters:
    ///   - session: session incognito au moment de la question.
    ///   - libelles: textes pris dans le catalogue de chaines.
    public static func banniere(
        pour session: SessionIncognito,
        libelles: LibellesDIncognito
    ) -> BanniereDIncognito? {
        guard session.porteLaBanniere else {
            return nil
        }

        return BanniereDIncognito(titre: libelles.titre, phrase: libelles.phrase)
    }
}

/// Banniere posee en haut de l application pendant toute une session incognito.
///
/// Elle ne remplace jamais le contenu et ne coupe jamais un geste : elle se pose
/// au dessus, sur une seule ligne, et laisse tout le reste utilisable.
public struct VueDeBanniereDIncognito: View {
    @Environment(\.palette) private var palette

    private let banniere: BanniereDIncognito
    private let etiquette: String

    /// Construit la banniere.
    ///
    /// Aucune action n est prise en parametre, et c est voulu : la banniere ne
    /// se ferme pas, section 11.
    ///
    /// - Parameters:
    ///   - banniere: textes deja composes.
    ///   - etiquette: etiquette d accessibilite de la banniere entiere.
    public init(banniere: BanniereDIncognito, etiquette: String) {
        self.banniere = banniere
        self.etiquette = etiquette
    }

    public var body: some View {
        HStack(spacing: Jetons.BanniereDIncognito.ecartInterne) {
            glyphe

            Text(banniere.titre)
                .style(Jetons.BanniereDIncognito.titre)
                .foregroundStyle(palette.textes.primary.couleur)

            Text(banniere.phrase)
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

    /// Glyphe `eye.slash` du tableau 1.10.
    ///
    /// Masque aux lecteurs d ecran : l etiquette de la banniere porte deja
    /// l information, et la section 7 interdit de la transmettre par le seul
    /// glyphe.
    private var glyphe: some View {
        Image(systemName: Jetons.Icone.incognito)
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
    /// Pose la banniere du mode incognito au dessus de cette vue.
    ///
    /// Le modificateur prend la banniere composee, jamais un indicateur de
    /// visibilite. C est la session qui decide, et elle ne change d avis pour
    /// aucun evenement de l application : il n existe donc aucun appel qui
    /// retire la banniere en cours de session.
    ///
    /// - Parameters:
    ///   - banniere: banniere composee, nulle quand aucune session ne court.
    ///   - etiquette: etiquette d accessibilite de la banniere.
    public func banniereDIncognito(
        _ banniere: BanniereDIncognito?,
        etiquette: String
    ) -> some View {
        overlay(alignment: .top) {
            if let banniere {
                VueDeBanniereDIncognito(banniere: banniere, etiquette: etiquette)
                    .padding(Jetons.BanniereDIncognito.marge)
            }
        }
    }
}
