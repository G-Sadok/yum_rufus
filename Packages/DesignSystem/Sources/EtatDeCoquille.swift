import Core
import Observation

//
// Etat de la coquille : destination courante, forme de la navigation, repli de
// la barre laterale.
//
// Le repli est un etat, pas un calcul de vue. Une vue qui le deduirait de sa
// largeur perdrait le choix de l utilisateur a chaque redimensionnement.
//

/// Etat de la navigation principale.
///
/// Un seul objet pour les trois formes de navigation. La barre laterale, la
/// barre laterale repliee et la barre d onglets lisent et ecrivent le meme
/// etat, ce qui garantit que la destination survit a une rotation d iPad.
@MainActor
@Observable
public final class EtatDeCoquille {
    /// Destination affichee.
    public private(set) var destination: DestinationPrincipale

    /// Forme courante de la navigation, imposee par le gabarit.
    public private(set) var presentation: PresentationDeNavigation

    /// Vrai quand la barre laterale est repliee sur ses icones.
    public private(set) var barreLateraleRepliee: Bool

    /// Contexte a partir duquel la presentation a ete resolue.
    public private(set) var contexte: ContexteDeCoquille

    public init(
        destination: DestinationPrincipale = .defaut,
        contexte: ContexteDeCoquille = .bureau
    ) {
        let presentation = PresentationDeNavigation.pour(contexte)
        self.destination = destination
        self.contexte = contexte
        self.presentation = presentation
        barreLateraleRepliee = presentation.barreLateraleRepliee
    }

    /// Largeur que la barre laterale doit occuper, section 2.2.
    public var largeurDeLaBarreLaterale: Double {
        barreLateraleRepliee ? Jetons.BarreLaterale.largeurRepliee : Jetons.BarreLaterale.largeur
    }

    /// Ouvre une destination.
    public func selectionner(_ destination: DestinationPrincipale) {
        self.destination = destination
    }

    /// Replie ou deploie la barre laterale.
    ///
    /// Sans effet quand la navigation est une barre d onglets, qui n a pas de
    /// barre laterale a replier.
    public func basculerLeRepliDeLaBarreLaterale() {
        guard !presentation.estUneBarreDOnglets else { return }
        barreLateraleRepliee.toggle()
    }

    /// Applique le gabarit courant.
    ///
    /// Le repli reprend la valeur imposee par la nouvelle presentation : une
    /// rotation d iPad du paysage vers le portrait replie la barre, le retour au
    /// paysage la redeploie. Le choix manuel de l utilisateur vaut jusqu au
    /// prochain changement de gabarit, pas au dela.
    public func sAdapter(a contexte: ContexteDeCoquille) {
        guard contexte != self.contexte else { return }
        self.contexte = contexte
        presentation = PresentationDeNavigation.pour(contexte)
        barreLateraleRepliee = presentation.barreLateraleRepliee
    }

    /// Descend d une entree dans la navigation, sans bouclage.
    public func allerALaDestinationSuivante() {
        guard let suivante = destination.suivante else { return }
        destination = suivante
    }

    /// Remonte d une entree dans la navigation, sans bouclage.
    public func allerALaDestinationPrecedente() {
        guard let precedente = destination.precedente else { return }
        destination = precedente
    }
}
