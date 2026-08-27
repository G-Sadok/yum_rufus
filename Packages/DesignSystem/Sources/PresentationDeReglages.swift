import Core

//
// Etat et commandes de l ecran Reglages, section 5.5 de DESIGN-SPEC.md.
//
// L ecran Reglages n a pas d etat vide au sens de la section 4.10. Sur une
// installation neuve la colonne est complete, seules les valeurs disent
// l absence. Il n a que deux etats de contenu, le chargement et le charge, plus
// une banniere qui peut se poser au dessus des deux sans les remplacer.
//

/// Etat de la colonne de reglages.
public enum EtatDeReglages: Sendable {
    /// Les valeurs ne sont pas encore lues. Les en tetes restent lisibles et
    /// les lignes deviennent des squelettes de 52.
    case chargement

    /// Valeurs reelles, defauts du catalogue compris.
    case chargee(PresentationDeReglages)
}

/// Ce que l ecran affiche une fois les valeurs lues.
public struct PresentationDeReglages: Sendable, Equatable {
    /// Valeurs de tous les reglages.
    public let reglages: ReglagesDeLApplication

    /// Textes des lignes qui montrent un etat plutot qu un choix.
    ///
    /// Y figurent les lignes en lecture seule, Version et Dernier envoi, et les
    /// lignes de navigation qui affichent un decompte, comme `Aucun prereglage`
    /// ou `Aucun service connecte`. Ces textes viennent du catalogue de chaines
    /// de l application, deja composes.
    public let valeursAffichees: [IdentifiantDeReglage: String]

    /// Etat de l abonnement.
    ///
    /// L ecran porte l etat entier et non un booleen, parce que la couronne
    /// n est pas la seule chose qui en depend : la section Abonnement dit ce
    /// qui court, et la degradation de la section 10 distingue une expiration
    /// d une installation qui n a jamais rien achete.
    public let abonnement: EtatDePremium

    public init(
        reglages: ReglagesDeLApplication,
        valeursAffichees: [IdentifiantDeReglage: String] = [:],
        abonnement: EtatDePremium = .gratuit
    ) {
        self.reglages = reglages
        self.valeursAffichees = valeursAffichees
        self.abonnement = abonnement
    }

    /// Vrai quand les fonctions de la matrice premium sont ouvertes.
    ///
    /// Les lignes premium reprennent alors leur forme ordinaire : la couronne
    /// tombe, le controle revient, et le clic regle au lieu d ouvrir le mur.
    public var premiumActif: Bool {
        abonnement.donneAccesAuxFonctionsPremium
    }

    /// Forme premium a appliquer a une ligne, nulle quand elle n en porte pas
    /// ou quand l abonnement la debloque.
    ///
    /// La reponse vient de la matrice de la section 10, pas du catalogue de
    /// lignes. Le tableau de la section 5.5 ne marque d une couronne que deux
    /// lignes sur les dix sept que la matrice place derriere l abonnement, et
    /// la regle 0.1 tranche : le texte du cahier des charges est normatif.
    public func formePremium(de ligne: LigneDeReglage) -> FormeDeLignePremium? {
        MatriceDeVerrouillage.formePremium(de: ligne, selon: abonnement)
    }
}

/// Banniere posee en haut de la colonne, section 5.5.
///
/// Elle ne remplace jamais la colonne. Une synchronisation en echec n empeche
/// pas de changer de theme.
public struct BanniereDErreurDeReglages {
    /// Titre en `headline`.
    public let titre: String
    /// Phrase en `footnote`, qui nomme la cause et indique la sortie.
    public let phrase: String
    /// Bouton Reessayer.
    public let reessayer: ActionDEtat
    /// Bouton Ouvrir les reglages du systeme.
    public let ouvrirLesReglagesDuSysteme: ActionDEtat

    public init(
        titre: String,
        phrase: String,
        reessayer: ActionDEtat,
        ouvrirLesReglagesDuSysteme: ActionDEtat
    ) {
        self.titre = titre
        self.phrase = phrase
        self.reessayer = reessayer
        self.ouvrirLesReglagesDuSysteme = ouvrirLesReglagesDuSysteme
    }
}

/// Ce que les lignes declenchent.
///
/// Aucune de ces fermetures n ecrit en base elle meme. Elles remontent a
/// l ecran, seul a connaitre le magasin.
public struct CommandesDeReglages {
    /// Bascule un interrupteur.
    public let basculer: (IdentifiantDeReglage, Bool) -> Void
    /// Retient un cas de menu, passe sous sa representation persistee.
    public let choisir: (IdentifiantDeReglage, String) -> Void
    /// Deplace un curseur.
    public let regler: (IdentifiantDeReglage, Double) -> Void
    /// Change la valeur d un compteur.
    public let compter: (IdentifiantDeReglage, Int) -> Void
    /// Ouvre l ecran d une ligne de navigation, ou le mur premium.
    public let ouvrir: (IdentifiantDeReglage) -> Void

    public init(
        basculer: @escaping (IdentifiantDeReglage, Bool) -> Void,
        choisir: @escaping (IdentifiantDeReglage, String) -> Void,
        regler: @escaping (IdentifiantDeReglage, Double) -> Void,
        compter: @escaping (IdentifiantDeReglage, Int) -> Void,
        ouvrir: @escaping (IdentifiantDeReglage) -> Void
    ) {
        self.basculer = basculer
        self.choisir = choisir
        self.regler = regler
        self.compter = compter
        self.ouvrir = ouvrir
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeReglages {
        CommandesDeReglages(
            basculer: { _, _ in },
            choisir: { _, _ in },
            regler: { _, _ in },
            compter: { _, _ in },
            ouvrir: { _ in }
        )
    }
}
