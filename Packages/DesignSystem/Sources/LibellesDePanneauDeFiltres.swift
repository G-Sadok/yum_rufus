import Core

//
// Textes du panneau de filtres, sections 5.7 et 6.5 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// Les huit libelles de lignes sont nommes par la section 5.7 elle meme, qui
// enumere les cinq curseurs puis les trois interrupteurs. Le titre du panneau
// est celui de l action qui l ouvre, `Filtres`, au tableau 6.5 : la meme action
// porte le meme mot du bouton jusqu au panneau, comme la section 6 l impose.
//

/// Textes du panneau de filtres, pris dans le catalogue de chaines.
public struct LibellesDePanneauDeFiltres: Sendable, Equatable {
    /// Titre du panneau, celui de l action de la barre du lecteur.
    public let titre: String

    /// Libelle de chacun des cinq curseurs, section 5.7.
    public let libellesDeFiltre: [FiltreDImage: String]

    /// Libelle de chacun des trois interrupteurs, section 5.7.
    public let libellesDeTraitement: [TraitementDImage: String]

    /// Etiquette d accessibilite de la couronne d un traitement verrouille.
    public let etiquetteDeLaCouronne: String

    public init(
        titre: String,
        libellesDeFiltre: [FiltreDImage: String],
        libellesDeTraitement: [TraitementDImage: String],
        etiquetteDeLaCouronne: String
    ) {
        self.titre = titre
        self.libellesDeFiltre = libellesDeFiltre
        self.libellesDeTraitement = libellesDeTraitement
        self.etiquetteDeLaCouronne = etiquetteDeLaCouronne
    }

    /// Libelle d un curseur.
    ///
    /// Un libelle manquant rend une chaine vide. Le cas signale un trou dans le
    /// catalogue, et la suite de tests le detecte avant qu il n arrive a
    /// l ecran.
    public func libelle(de filtre: FiltreDImage) -> String {
        libellesDeFiltre[filtre] ?? ""
    }

    /// Libelle d un interrupteur.
    public func libelle(de traitement: TraitementDImage) -> String {
        libellesDeTraitement[traitement] ?? ""
    }
}

/// Ce que les lignes du panneau declenchent.
///
/// Aucune de ces fermetures n applique le filtre elle meme. Elles remontent au
/// lecteur, seul a detenir la page visible et la chaine de traitement.
public struct CommandesDePanneauDeFiltres {
    /// Deplace un curseur.
    public let regler: (FiltreDImage, Double) -> Void

    /// Arme ou desarme un interrupteur.
    public let basculer: (TraitementDImage, Bool) -> Void

    /// Ouvre le mur premium, depuis la couronne d un traitement verrouille.
    public let ouvrirLeMurPremium: () -> Void

    public init(
        regler: @escaping (FiltreDImage, Double) -> Void,
        basculer: @escaping (TraitementDImage, Bool) -> Void,
        ouvrirLeMurPremium: @escaping () -> Void
    ) {
        self.regler = regler
        self.basculer = basculer
        self.ouvrirLeMurPremium = ouvrirLeMurPremium
    }

    /// Commandes inertes, pour un apercu ou un panneau en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDePanneauDeFiltres {
        CommandesDePanneauDeFiltres(
            regler: { _, _ in },
            basculer: { _, _ in },
            ouvrirLeMurPremium: {}
        )
    }
}
