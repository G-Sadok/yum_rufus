import Foundation

//
// FicheDeSerie
//
// Ce que l ecran de la section 5.6 de DESIGN-SPEC.md a besoin de savoir, en une
// seule lecture.
//
// La fiche porte deux listes de chapitres et non une : celle que l utilisateur
// voit, filtree et triee, et le compte de tout ce que la serie contient. Le
// bouton principal se decide sur la seconde. Un filtre `Non lus` qui ferait
// dire `Tout est lu` a une serie a peine commencee serait un mensonge affiche
// en gros au milieu de la banniere.
//

/// Contenu complet de la fiche d une serie.
public struct FicheDeSerie: Sendable, Equatable {
    /// Serie affichee, avec ses metadonnees.
    public let serie: Manga

    /// Nom de la source qui expose la serie, affiche par la ligne d etat.
    public let nomDeLaSource: String

    /// Chapitres affiches, filtres et tries selon `reglage`.
    public let chapitres: [ChapitreDeFiche]

    /// Nombre de chapitres de la serie, filtre non applique.
    public let nombreDeChapitres: Int

    /// Filtre et tri persistes pour cette serie.
    public let reglage: ReglageDeListeDeChapitres

    /// Action du bouton principal, calculee sur toute la serie.
    public let actionPrincipale: ActionPrincipaleDeFiche

    public init(
        serie: Manga,
        nomDeLaSource: String,
        chapitres: [ChapitreDeFiche],
        nombreDeChapitres: Int,
        reglage: ReglageDeListeDeChapitres,
        actionPrincipale: ActionPrincipaleDeFiche
    ) {
        self.serie = serie
        self.nomDeLaSource = nomDeLaSource
        self.chapitres = chapitres
        self.nombreDeChapitres = nombreDeChapitres
        self.reglage = reglage
        self.actionPrincipale = actionPrincipale
    }

    /// Assemble la fiche a partir de tous les chapitres de la serie.
    ///
    /// C est le seul chemin de construction employe par le paquet Storage, et
    /// il garantit l invariant : le filtre ne touche que `chapitres`, jamais
    /// `nombreDeChapitres` ni `actionPrincipale`.
    public init(
        serie: Manga,
        nomDeLaSource: String,
        tousLesChapitres: [ChapitreDeFiche],
        reglage: ReglageDeListeDeChapitres
    ) {
        self.init(
            serie: serie,
            nomDeLaSource: nomDeLaSource,
            chapitres: reglage.appliquer(a: tousLesChapitres),
            nombreDeChapitres: tousLesChapitres.count,
            reglage: reglage,
            actionPrincipale: ActionPrincipaleDeFiche.pour(chapitres: tousLesChapitres)
        )
    }

    /// Vrai quand la serie n expose aucun chapitre.
    ///
    /// C est l etat vide de la section 5.6, celui qui invite a suivre la serie.
    /// Une liste videe par un filtre n est pas cet etat la : la serie a des
    /// chapitres, l utilisateur en a simplement masque une partie.
    public var estSansChapitre: Bool {
        nombreDeChapitres == 0
    }

    /// Vrai quand le filtre courant ne laisse rien passer.
    public var filtreNeRetientRien: Bool {
        chapitres.isEmpty && nombreDeChapitres > 0
    }
}
