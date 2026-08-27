import Core
import Foundation

//
// Textes de la gestion des prereglages, sous ecran de la section 5.5 de
// DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// Le resume d une ligne n est pas compose par l application non plus. Il l est
// par `TexteDePrereglage`, a partir des libelles de menu que l ecran Reglages
// emploie deja : un prereglage en `Sepia` doit dire `Sepia`, le mot que
// l utilisateur a choisi au menu Fond du lecteur, et pas une seconde
// formulation pour la meme valeur.
//

/// Textes de l ecran de gestion des prereglages.
public struct LibellesDePrereglages: Sendable, Equatable {
    /// Titre de l ecran, celui de la section 7 de la section 5.5.
    public let titre: String

    /// Action qui capture l etat de lecture courant, section 9 du cahier de
    /// developpement.
    public let enregistrerLActuel: String

    /// Description posee sous la carte, section 9 du cahier de developpement.
    public let description: String

    /// Etiquette d accessibilite du bouton d options d une ligne.
    public let options: String

    /// Commande d application d un prereglage.
    public let appliquer: String

    /// Commande de renommage.
    public let renommer: String

    /// Commande de remplacement du contenu par l etat courant.
    public let remplacerParLActuel: String

    /// Commande de suppression.
    public let supprimer: String

    /// Titre de l etat vide, tableau 6.3.
    public let videTitre: String

    /// Phrase de l etat vide, qui dit quoi faire.
    public let videPhrase: String

    /// Libelle des valeurs de menu, pour composer le resume d une ligne.
    ///
    /// Ce sont les memes que ceux de l ecran Reglages, indexes par la
    /// representation persistee du choix.
    public let valeursDeMenu: [String: String]

    public init(
        titre: String,
        enregistrerLActuel: String,
        description: String,
        options: String,
        appliquer: String,
        renommer: String,
        remplacerParLActuel: String,
        supprimer: String,
        videTitre: String,
        videPhrase: String,
        valeursDeMenu: [String: String]
    ) {
        self.titre = titre
        self.enregistrerLActuel = enregistrerLActuel
        self.description = description
        self.options = options
        self.appliquer = appliquer
        self.renommer = renommer
        self.remplacerParLActuel = remplacerParLActuel
        self.supprimer = supprimer
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.valeursDeMenu = valeursDeMenu
    }

    /// Libelle d une valeur de menu.
    ///
    /// Une valeur sans libelle retombe sur sa representation persistee. Le cas
    /// signale un trou dans le catalogue, et la suite de tests le detecte avant
    /// qu il n arrive a l ecran.
    public func valeur(_ brute: String) -> String {
        valeursDeMenu[brute] ?? brute
    }
}

/// Assemblage des textes d une ligne de prereglage.
public enum TexteDePrereglage {
    /// Resume de ce qu un prereglage capture, pose sous son nom.
    ///
    /// Le resume nomme le sens applique, la mise en page et la teinte, dans
    /// l ordre ou l ecran Reglages les range. Les filtres n y figurent pas :
    /// huit valeurs chiffrees ne se lisent pas d un coup d oeil sous un nom, et
    /// la ligne les porterait au prix de sa lisibilite.
    ///
    /// Le sens indique est celui qui s applique, mise en page comprise. Ecrire
    /// le sens choisi tromperait sur un prereglage en defilement continu, ou le
    /// menu garde un sens horizontal que le moteur n emploie pas.
    /// Les fragments sont assembles avec le separateur du document, celui que
    /// la ligne de chapitre emploie deja entre deux fragments d une meme ligne.
    /// C est une convention typographique, pas un mot : elle ne passe donc pas
    /// par le catalogue de chaines.
    public static func resume(
        de contenu: ContenuDePrereglage,
        libelles: LibellesDePrereglages
    ) -> String {
        TexteDeChapitre.joindre([
            libelles.valeur(contenu.sensApplique.rawValue),
            libelles.valeur(contenu.miseEnPage.rawValue),
            libelles.valeur(contenu.fond.rawValue),
        ])
    }
}

/// Un prereglage tel que la liste l affiche.
///
/// La vue ne relit jamais la colonne JSON elle meme. L ecran lui passe un
/// contenu deja decode, ou rien du tout quand la colonne est abimee : une ligne
/// sans resume reste applicable et surtout supprimable, ce qu une vue qui
/// echouerait a la lecture ne permettrait pas.
public struct PrereglageAffiche: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let nom: String
    public let contenu: ContenuDePrereglage?

    public init(id: UUID, nom: String, contenu: ContenuDePrereglage?) {
        self.id = id
        self.nom = nom
        self.contenu = contenu
    }

    /// Construit la ligne a partir du prereglage persiste.
    ///
    /// Une colonne illisible donne une ligne sans resume plutot qu une erreur :
    /// l ecran de gestion est precisement l endroit ou l utilisateur peut se
    /// debarrasser d un prereglage abime.
    public init(_ prereglage: PrereglageLecture) {
        id = prereglage.id
        nom = prereglage.nom
        contenu = try? prereglage.contenu()
    }
}
