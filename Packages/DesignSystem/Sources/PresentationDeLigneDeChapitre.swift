import Core
import Foundation

//
// Presentation d une ligne de chapitre, tableau 4.5 de DESIGN-SPEC.md.
//
// Le tableau donne quatre lignes d etat : Non lu, Lu, En cours, Telecharge.
// Chacune fixe un fond, une couleur de titre, une graisse, une couleur de sous
// ligne et une marque de droite. Traduire ce tableau ici plutot que dans le
// corps de la vue a deux effets : la vue ne porte plus une cascade de
// conditions, et la suite de tests peut verifier que les quatre etats se
// distinguent reellement les uns des autres.
//

/// Fond d une ligne de chapitre, tableau 4.5.
public enum FondDeLigneDeChapitre: String, Sendable, Equatable, CaseIterable {
    /// `surface.card`, reserve au chapitre non lu.
    case carte

    /// Transparent, pour un chapitre lu ou en cours.
    case transparent
}

/// Marque posee a droite d une ligne de chapitre, tableau 4.5.
public enum MarqueDeLigneDeChapitre: String, Sendable, Equatable, CaseIterable {
    /// Pastille pleine de 12 en `accent`, chapitre non lu.
    case pastille

    /// Filet de 3 en `accent` a 60 pour cent sur le bord inferieur, chapitre en
    /// cours.
    case filetDeProgression

    /// Aucune marque, chapitre lu.
    case aucune
}

/// Rendu d une ligne de chapitre pour un etat donne.
public struct PresentationDeLigneDeChapitre: Sendable, Equatable {
    /// Etat represente.
    public let etat: EtatDeLigneDeChapitre

    /// Fond de la ligne.
    public let fond: FondDeLigneDeChapitre

    /// Style du titre, graisse comprise.
    public let styleDuTitre: StyleTypographique

    /// Marque de droite.
    public let marque: MarqueDeLigneDeChapitre

    /// Vrai quand la ligne porte l icone `arrow.down.circle`.
    public let porteLIconeDeTelechargement: Bool

    /// Presentation de l etat demande.
    ///
    /// Le telechargement ajoute l icone et ne change rien d autre : le tableau
    /// 4.5 renvoie explicitement au fond et au titre de l etat de lecture.
    public init(_ etat: EtatDeLigneDeChapitre) {
        self.etat = etat
        porteLIconeDeTelechargement = etat.estTelecharge

        switch etat.lecture {
        case .nonLu:
            fond = .carte
            styleDuTitre = Jetons.LigneDeChapitre.titre.enGraisse(.semiGrasse)
            marque = .pastille

        case .lu:
            fond = .transparent
            styleDuTitre = Jetons.LigneDeChapitre.titre.enGraisse(.normale)
            marque = .aucune

        case .enCours:
            fond = .transparent
            styleDuTitre = Jetons.LigneDeChapitre.titre.enGraisse(.normale)
            marque = .filetDeProgression
        }
    }

    /// Role de couleur du titre, resolu par la palette au moment du rendu.
    ///
    /// Un chapitre non lu porte `text.primary`, les deux autres `text.tertiary`.
    public var couleurDuTitre: RoleDeCouleurDeTexte {
        etat.lecture == .nonLu ? .primary : .tertiary
    }

    /// Role de couleur de la sous ligne.
    ///
    /// `text.quaternary` pour un chapitre deja lu, c est l un des quatre usages
    /// que la section 7 autorise pour ce jeton a 3.1:1. Le chapitre non lu et le
    /// chapitre en cours portent une information que rien ne repete ailleurs,
    /// ils restent donc en `text.tertiary`.
    public var couleurDeLaSousLigne: RoleDeCouleurDeTexte {
        etat.lecture == .lu ? .quaternary : .tertiary
    }
}

/// Un role de couleur de texte du tableau 1.2, choisi sans connaitre la palette.
public enum RoleDeCouleurDeTexte: String, Sendable, Equatable, CaseIterable {
    case primary
    case secondary
    case tertiary
    case quaternary

    /// Couleur du role dans la palette donnee.
    public func couleur(dans palette: Palette) -> CouleurHexadecimale {
        switch self {
        case .primary: palette.textes.primary
        case .secondary: palette.textes.secondary
        case .tertiary: palette.textes.tertiary
        case .quaternary: palette.textes.quaternary
        }
    }
}
