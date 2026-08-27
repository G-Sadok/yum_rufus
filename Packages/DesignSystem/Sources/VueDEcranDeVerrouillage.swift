import Core
import SwiftUI

//
// Ecran de verrouillage de l application, section 11 du cahier de developpement.
//
// DESIGN-SPEC.md ne le dessine pas. Il n en nomme que le glyphe, `lock`, au
// tableau 1.10. L ecran est donc compose avec ce que le document dessine deja,
// le bloc d etat de contenu de la section 4.10, plutot qu invente : glyphe,
// titre en `title1`, phrase, action en dessous, le tout centre.
//
// Deux etats seulement, et ils correspondent a deux des trois etats de la
// section 4.10. L attente est un etat vide, une invitation a agir : le produit
// n a rien a montrer tant que l utilisateur ne s est pas identifie. L echec est
// un etat d erreur, qui nomme sa cause et porte sa sortie. Il n y a pas d etat
// de chargement : la feuille du systeme couvre elle meme le temps de
// l authentification.
//
// Le fond est opaque et couvre tout. C est le sens meme du verrou : une
// application verrouillee dont on distingue la bibliotheque en transparence ne
// protege rien, ni du regard par dessus l epaule, ni de l apercu que le systeme
// prend au moment du passage en arriere plan.
//

/// Ce que l ecran de verrouillage affiche.
public enum EtatDeLEcranDeVerrouillage: Sendable, Equatable {
    /// L application attend une authentification.
    case attente

    /// L authentification a echoue, avec sa cause.
    case echec(ErreurDeVerrouillage)
}

/// Textes de l ecran de verrouillage.
///
/// Aucun mot n est ecrit ici. Le paquet sait ou poser un libelle, l application
/// sait lequel c est.
public struct LibellesDeVerrouillage: Sendable, Equatable {
    /// Titre de l ecran.
    public let titre: String

    /// Phrase qui dit pourquoi l application est fermee.
    public let phrase: String

    /// Libelle du bouton qui relance l authentification.
    public let deverrouiller: String

    /// Titre de l etat d echec.
    public let echecTitre: String

    /// Phrase de l echec d authentification.
    public let echecPhrase: String

    /// Phrase de l appareil qui n a ni biometrie ni code.
    public let aucunMoyenPhrase: String

    /// Raison montree par la feuille du systeme.
    public let raisonDuSysteme: String

    public init(
        titre: String,
        phrase: String,
        deverrouiller: String,
        echecTitre: String,
        echecPhrase: String,
        aucunMoyenPhrase: String,
        raisonDuSysteme: String
    ) {
        self.titre = titre
        self.phrase = phrase
        self.deverrouiller = deverrouiller
        self.echecTitre = echecTitre
        self.echecPhrase = echecPhrase
        self.aucunMoyenPhrase = aucunMoyenPhrase
        self.raisonDuSysteme = raisonDuSysteme
    }
}

/// Composition de l ecran de verrouillage a partir de son etat.
public enum ContenuDeLEcranDeVerrouillage {
    /// Etat de contenu de la section 4.10 correspondant a cet etat de verrou.
    ///
    /// Un renoncement ne produit pas d erreur. La section 6 interdit d insister,
    /// et un message d echec apres un geste volontaire se lit comme une
    /// insistance : l ecran revient simplement a son attente.
    ///
    /// - Parameters:
    ///   - etat: attente ou echec.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - deverrouiller: relance de l authentification.
    public static func etatDeContenu(
        pour etat: EtatDeLEcranDeVerrouillage,
        libelles: LibellesDeVerrouillage,
        deverrouiller: @escaping () -> Void
    ) -> EtatDeContenu {
        let action = ActionDEtat(libelle: libelles.deverrouiller, action: deverrouiller)

        guard case let .echec(erreur) = etat, let phrase = phrase(de: erreur, libelles: libelles)
        else {
            return .vide(
                symbole: Jetons.EcranDeVerrouillage.glyphe,
                titre: libelles.titre,
                phrase: libelles.phrase,
                action: action
            )
        }

        return .erreur(
            titre: libelles.echecTitre,
            phrase: phrase,
            reessayer: action,
            repli: nil
        )
    }

    /// Phrase d une erreur, nulle quand l erreur ne s affiche pas.
    private static func phrase(
        de erreur: ErreurDeVerrouillage,
        libelles: LibellesDeVerrouillage
    ) -> String? {
        switch erreur {
        case .echecDeLAuthentification: libelles.echecPhrase
        case .aucunMoyenDisponible: libelles.aucunMoyenPhrase
        case .annuleParLUtilisateur: nil
        }
    }
}

/// Ecran opaque pose sur toute l application quand le verrou est ferme.
public struct VueDEcranDeVerrouillage: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeLEcranDeVerrouillage
    private let libelles: LibellesDeVerrouillage
    private let deverrouiller: () -> Void

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: attente ou echec.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - deverrouiller: relance de l authentification.
    public init(
        etat: EtatDeLEcranDeVerrouillage,
        libelles: LibellesDeVerrouillage,
        deverrouiller: @escaping () -> Void
    ) {
        self.etat = etat
        self.libelles = libelles
        self.deverrouiller = deverrouiller
    }

    public var body: some View {
        ZStack {
            palette.surfaces.window.couleur
                .ignoresSafeArea()

            VueDEtatDeContenu(
                ContenuDeLEcranDeVerrouillage.etatDeContenu(
                    pour: etat,
                    libelles: libelles,
                    deverrouiller: deverrouiller
                )
            )
        }
    }
}

extension View {
    /// Pose l ecran de verrouillage au dessus de cette vue quand le verrou est
    /// ferme.
    ///
    /// Le modificateur prend l etat du verrou de `Core`, jamais un booleen
    /// compose sur place. C est la regle des trente secondes qui decide, et elle
    /// n a qu une seule ecriture dans le produit.
    ///
    /// - Parameters:
    ///   - verrou: etat du verrou.
    ///   - ecran: attente ou echec de la derniere tentative.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - deverrouiller: relance de l authentification.
    public func verrouillageDeLApp(
        _ verrou: EtatDeVerrouillage,
        ecran: EtatDeLEcranDeVerrouillage,
        libelles: LibellesDeVerrouillage,
        deverrouiller: @escaping () -> Void
    ) -> some View {
        overlay {
            if verrou.demandeUneAuthentification {
                VueDEcranDeVerrouillage(
                    etat: ecran,
                    libelles: libelles,
                    deverrouiller: deverrouiller
                )
            }
        }
    }
}
