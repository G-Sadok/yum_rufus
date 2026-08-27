import Core
import Foundation

//
// Textes des ecrans de stockage, section 15 de la section 5.5 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// Le titre et la sous ligne d un poste sont composes ici plutot que par
// l application, comme ceux d une ligne de la file de telechargement : ils
// dependent de ce que le poste designe, et le laisser a l appelant reviendrait a
// esperer que trois ecrans refassent le meme calcul de la meme facon.
//
// La sous ligne d un poste n est jamais vide, comme la recette de la section 9
// l exige. Un chapitre dit s il est lu, une source dit ce que son cache garde,
// et un poste anonyme dit combien d elements il recouvre.
//

/// Textes des ecrans de gestion du stockage.
public struct LibellesDeStockage: Sendable, Equatable {
    /// Titre de l ecran d ensemble, ligne 15.1 de la section 5.5.
    public let titre: String

    /// Description posee sous la carte, tableau 6.8.
    public let description: String

    /// Libelles des trois categories, indexes par leur representation
    /// persistee.
    public let categories: [String: String]

    /// Motif du chapitre, `Chapitre %@`.
    public let chapitreNumerote: String

    /// Sous ligne d un chapitre deja lu.
    public let chapitreLu: String

    /// Sous ligne d un chapitre pas encore lu.
    public let chapitreNonLu: String

    /// Sous ligne du cache d une source.
    public let cacheDUneSource: String

    /// Motif de la sous ligne d un poste anonyme, `%lld elements`.
    public let elementsAnonymes: String

    /// Titres des postes anonymes, indexes par categorie persistee.
    public let titresAnonymes: [String: String]

    /// Motifs de poids, du plus petit au plus grand.
    public let poids: MotifsDePoids

    /// Commande de suppression, celle de la barre de selection.
    public let supprimer: String

    /// Commande qui vide la categorie entiere.
    public let toutSupprimer: String

    /// Motif du compteur de la barre de selection, `%lld selectionnes`.
    public let compteurDeSelection: String

    /// Fermeture de la barre de selection.
    public let fermerLaSelection: String

    /// Etiquette d accessibilite de la case de selection d un poste.
    public let selectionner: String

    /// Titre de la modale de confirmation, section 4.8.
    public let confirmationTitre: String

    /// Motif de la description de la modale, `%1$lld elements, %2$@`.
    public let confirmationDescription: String

    /// Libelle du bouton qui annule la suppression.
    public let confirmationAnnuler: String

    /// Libelle du bouton qui confirme la suppression.
    public let confirmationSupprimer: String

    /// Titre de l etat vide d un ecran de detail.
    public let videTitre: String

    /// Phrase de l etat vide, qui dit quoi faire.
    public let videPhrase: String

    public init(
        titre: String,
        description: String,
        categories: [String: String],
        chapitreNumerote: String,
        chapitreLu: String,
        chapitreNonLu: String,
        cacheDUneSource: String,
        elementsAnonymes: String,
        titresAnonymes: [String: String],
        poids: MotifsDePoids,
        supprimer: String,
        toutSupprimer: String,
        compteurDeSelection: String,
        fermerLaSelection: String,
        selectionner: String,
        confirmationTitre: String,
        confirmationDescription: String,
        confirmationAnnuler: String,
        confirmationSupprimer: String,
        videTitre: String,
        videPhrase: String
    ) {
        self.titre = titre
        self.description = description
        self.categories = categories
        self.chapitreNumerote = chapitreNumerote
        self.chapitreLu = chapitreLu
        self.chapitreNonLu = chapitreNonLu
        self.cacheDUneSource = cacheDUneSource
        self.elementsAnonymes = elementsAnonymes
        self.titresAnonymes = titresAnonymes
        self.poids = poids
        self.supprimer = supprimer
        self.toutSupprimer = toutSupprimer
        self.compteurDeSelection = compteurDeSelection
        self.fermerLaSelection = fermerLaSelection
        self.selectionner = selectionner
        self.confirmationTitre = confirmationTitre
        self.confirmationDescription = confirmationDescription
        self.confirmationAnnuler = confirmationAnnuler
        self.confirmationSupprimer = confirmationSupprimer
        self.videTitre = videTitre
        self.videPhrase = videPhrase
    }

    /// Libelle d une categorie.
    ///
    /// Une categorie sans libelle retombe sur sa representation persistee. Le
    /// cas signale un trou dans le catalogue, et la suite de tests le detecte
    /// avant qu il n arrive a l ecran.
    public func libelle(de categorie: CategorieDeStockage) -> String {
        categories[categorie.rawValue] ?? categorie.rawValue
    }

    /// Titre du poste anonyme d une categorie.
    public func titreAnonyme(de categorie: CategorieDeStockage) -> String {
        titresAnonymes[categorie.rawValue] ?? categorie.rawValue
    }
}

/// Assemblage des textes des ecrans de stockage.
public enum TexteDeStockage {
    /// Poids affiche d une categorie ou d un poste.
    public static func taille(_ octets: Int, libelles: LibellesDeStockage) -> String {
        TexteDePoids.poids(octets, motifs: libelles.poids)
    }

    /// Titre d un poste, selon ce qu il designe.
    ///
    /// Un chapitre nomme sa serie puis son numero, dans cet ordre. Une liste
    /// melange des series, et l utilisateur y cherche une serie avant d y
    /// chercher un numero, exactement comme dans la file de telechargement.
    public static func titre(
        de poste: PosteDeStockage,
        categorie: CategorieDeStockage,
        libelles: LibellesDeStockage
    ) -> String {
        switch poste.contenu {
        case let .chapitre(chapitre):
            let numerote = String(
                format: libelles.chapitreNumerote,
                TexteDeChapitre.numero(chapitre.numeroDeChapitre)
            )

            return TexteDeChapitre.joindre([chapitre.titreDeLaSerie, numerote])

        case let .source(nom):
            return nom

        case .elementsAnonymes:
            return libelles.titreAnonyme(de: categorie)
        }
    }

    /// Sous ligne d un poste, jamais vide.
    public static func sousLigne(
        de poste: PosteDeStockage,
        libelles: LibellesDeStockage
    ) -> String {
        switch poste.contenu {
        case let .chapitre(chapitre):
            chapitre.estLu ? libelles.chapitreLu : libelles.chapitreNonLu

        case .source:
            libelles.cacheDUneSource

        case let .elementsAnonymes(nombre):
            String(format: libelles.elementsAnonymes, nombre)
        }
    }

    /// Etiquette lue par VoiceOver, qui porte tout ce que la ligne montre.
    ///
    /// La taille en fait partie. Elle est alignee a droite dans la ligne, et une
    /// lecture qui l oublierait laisserait l utilisateur choisir ce qu il
    /// supprime sans savoir ce que cela libere.
    public static func etiquette(
        de poste: PosteDeStockage,
        categorie: CategorieDeStockage,
        libelles: LibellesDeStockage
    ) -> String {
        TexteDeChapitre.joindre([
            titre(de: poste, categorie: categorie, libelles: libelles),
            sousLigne(de: poste, libelles: libelles),
            taille(poste.octets, libelles: libelles),
        ])
    }

    /// Description de la modale de confirmation, section 4.8.
    ///
    /// Elle dit ce qui part et ce que cela libere. Une confirmation qui ne
    /// nomme ni l un ni l autre apprend a confirmer sans lire.
    public static func descriptionDeConfirmation(
        de demande: DemandeDeSuppression,
        libelles: LibellesDeStockage
    ) -> String {
        String(
            format: libelles.confirmationDescription,
            demande.nombreDePostes,
            taille(demande.octets, libelles: libelles)
        )
    }
}
