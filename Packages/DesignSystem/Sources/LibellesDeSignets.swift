import Core
import Foundation

//
// Textes de l ecran Signets, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// La seconde ligne d une entree est composee ici plutot que par l application,
// comme celle d une ligne de chapitre : elle depend du signet, un chapitre sans
// titre ne composant pas la meme ligne qu un chapitre qui en porte un.
//

/// Textes de l ecran de consultation des signets.
public struct LibellesDeSignets: Sendable, Equatable {
    /// Titre de l ecran.
    public let titre: String

    /// Description posee sous la carte, qui dit ou se posent les signets.
    public let description: String

    /// Motif du chapitre, `Chapitre %@`.
    public let chapitreNumerote: String

    /// Motif de la page marquee, `Page %lld`.
    public let pageNumerotee: String

    /// Etiquette d accessibilite du bouton d options d une ligne.
    public let options: String

    /// Commande qui ouvre la page marquee.
    public let ouvrirLaPage: String

    /// Commande de suppression d un signet.
    public let supprimer: String

    /// Titre de l etat vide.
    public let videTitre: String

    /// Phrase de l etat vide, qui dit quoi faire.
    public let videPhrase: String

    /// Libelle de l action de l etat vide.
    public let videAction: String

    public init(
        titre: String,
        description: String,
        chapitreNumerote: String,
        pageNumerotee: String,
        options: String,
        ouvrirLaPage: String,
        supprimer: String,
        videTitre: String,
        videPhrase: String,
        videAction: String
    ) {
        self.titre = titre
        self.description = description
        self.chapitreNumerote = chapitreNumerote
        self.pageNumerotee = pageNumerotee
        self.options = options
        self.ouvrirLaPage = ouvrirLaPage
        self.supprimer = supprimer
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.videAction = videAction
    }
}

/// Assemblage des textes d une ligne de signet.
public enum TexteDeSignet {
    /// Chapitre marque, `Chapitre 43  Le titre du chapitre`.
    ///
    /// Le titre du chapitre est facultatif. Le fragment se reduit alors a
    /// `Chapitre 43`, jamais a un separateur suivi de rien.
    public static func chapitre(de signet: SignetAffiche, libelles: LibellesDeSignets) -> String {
        let numerote = String(
            format: libelles.chapitreNumerote,
            TexteDeChapitre.numero(signet.numeroDeChapitre)
        )

        guard let titre = signet.titreDuChapitre, !titre.isEmpty else {
            return numerote
        }

        return TexteDeChapitre.joindre([numerote, titre])
    }

    /// Page marquee, `Page 12`.
    ///
    /// Le numero affiche est l index augmente de un. Le modele indexe les pages
    /// a partir de zero, l utilisateur les compte a partir de un, et le compteur
    /// de la barre inferieure du lecteur affiche deja la seconde forme.
    public static func page(de signet: SignetAffiche, libelles: LibellesDeSignets) -> String {
        String(format: libelles.pageNumerotee, signet.pageIndex + 1)
    }

    /// Seconde ligne d une entree, `Chapitre 43  Le titre  Page 12`.
    public static func sousLigne(de signet: SignetAffiche, libelles: LibellesDeSignets) -> String {
        TexteDeChapitre.joindre([chapitre(de: signet, libelles: libelles), page(de: signet, libelles: libelles)])
    }

    /// Etiquette lue par VoiceOver, qui porte tout ce que la ligne montre.
    ///
    /// La note en fait partie : elle est la seule information de la ligne que
    /// l utilisateur a lui meme ecrite, et la passer sous silence priverait la
    /// lecture vocale de ce qui distingue deux signets d un meme chapitre.
    public static func etiquette(de signet: SignetAffiche, libelles: LibellesDeSignets) -> String {
        TexteDeChapitre.joindre([
            signet.titreDeLaSerie,
            sousLigne(de: signet, libelles: libelles),
            signet.note ?? "",
        ])
    }
}
