import Foundation

//
// Textes de l ecran de fin de serie, section 7.4 du cahier de developpement.
//
// La section 6 de DESIGN-SPEC ne donne pas ces trois libelles, l ecran n etant
// dessine ni par le texte ni par les wireframes. Ils suivent donc ses regles
// d ecriture : voix active, le bouton dit ce qui se passe, la phrase indique la
// sortie, aucun point d exclamation.
//
// Le titre annonce une fin de serie et non une fin de chapitre. C est la seule
// chose que l utilisateur ne peut pas deviner de lui meme : arriver au bas d un
// chapitre ressemble a arriver au bas de n importe quel autre, et sans cet ecran
// la lecture s arreterait sans que rien ne dise pourquoi.
//
// Le libelle de retour est celui du tableau 6.4, `Revenir a la fiche`, deja
// employe par l erreur du lecteur webtoon. Le meme mot pour la meme action.
//

/// Motifs de texte de l ecran de fin de serie, pris dans le catalogue.
public struct LibellesDeFinDeSerie: Sendable, Equatable {
    /// Titre de l ecran, `Vous avez fini cette serie`.
    public let titre: String

    /// Phrase qui suit le titre, avec le numero du dernier chapitre en `%@`.
    public let phrase: String

    /// Phrase employee quand le numero du dernier chapitre est inconnu.
    public let phraseSansNumero: String

    /// Libelle du bouton de retour, `Revenir a la fiche`.
    public let revenirALaFiche: String

    public init(
        titre: String,
        phrase: String,
        phraseSansNumero: String,
        revenirALaFiche: String
    ) {
        self.titre = titre
        self.phrase = phrase
        self.phraseSansNumero = phraseSansNumero
        self.revenirALaFiche = revenirALaFiche
    }
}

/// Assemblage des textes de l ecran de fin de serie.
public enum TexteDeFinDeSerie {
    /// Phrase de l ecran, qui nomme le dernier chapitre lu quand il est connu.
    ///
    /// Une serie ouverte sans sa liste de chapitres n a pas de dernier numero a
    /// citer. La regle de fin de section 6.4 vaut ici aussi : plutot qu un trou
    /// dans la phrase, une phrase sans trou.
    public static func phrase(
        dernierChapitre numero: Double?,
        libelles: LibellesDeFinDeSerie
    ) -> String {
        guard let numero else {
            return libelles.phraseSansNumero
        }

        return String(format: libelles.phrase, TexteDeChapitre.numero(numero))
    }
}
