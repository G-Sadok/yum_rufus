//
// ReglagesDeLApplication
//
// Etat complet des reglages a un instant donne.
//
// La structure ne porte que ce que l utilisateur a change. Tout le reste vient
// du catalogue au moment de la lecture, ce qui garantit qu une valeur lue est
// toujours definie et toujours du bon type, meme juste apres l ajout d une
// ligne au catalogue.
//

/// Valeurs de tous les reglages, defauts compris.
public struct ReglagesDeLApplication: Sendable, Equatable, Hashable {
    private var valeurs: [IdentifiantDeReglage: ValeurDeReglage]

    /// Construit un etat a partir des seules valeurs ecrites en base.
    public init(_ valeurs: [IdentifiantDeReglage: ValeurDeReglage] = [:]) {
        self.valeurs = valeurs
    }

    /// Etat d une installation neuve, ou rien n a jamais ete change.
    public static let parDefaut = ReglagesDeLApplication()

    /// Valeurs ecrites en base, sans les defauts.
    public var valeursEcrites: [IdentifiantDeReglage: ValeurDeReglage] {
        valeurs
    }

    /// Valeur d un reglage, celle du catalogue tant que rien ne l a remplacee.
    ///
    /// Une valeur ecrite dont le type ne correspond plus a celui du catalogue
    /// est ignoree. Le cas arrive apres un changement de variante : la ligne
    /// repart de son defaut plutot que de rendre un type que l appelant ne sait
    /// pas lire.
    public subscript(identifiant: IdentifiantDeReglage) -> ValeurDeReglage {
        get {
            let defaut = CatalogueDeReglages.valeurParDefaut(de: identifiant)

            guard let ecrite = valeurs[identifiant],
                  Self.memeType(ecrite, defaut)
            else {
                return defaut
            }

            return ecrite
        }
        set {
            valeurs[identifiant] = newValue
        }
    }

    /// Etat d un interrupteur.
    public func booleen(_ identifiant: IdentifiantDeReglage) -> Bool {
        guard case let .booleen(actif) = self[identifiant] else {
            return false
        }

        return actif
    }

    /// Cas de menu, ramene au defaut du catalogue quand la valeur ecrite ne
    /// correspond a aucun cas connu.
    public func choix<Choix: ChoixDeReglage>(
        _ identifiant: IdentifiantDeReglage,
        comme type: Choix.Type = Choix.self
    ) -> Choix {
        guard case let .choix(brut) = self[identifiant],
              let valeur = Choix(rawValue: brut)
        else {
            return Choix.parDefaut
        }

        return valeur
    }

    /// Valeur d un compteur, contrainte a ses bornes.
    public func compteur(_ identifiant: IdentifiantDeReglage) -> Int {
        guard case let .compteur(valeur) = self[identifiant] else {
            return 0
        }

        guard let bornes = CatalogueDeReglages.ligne(identifiant)?.bornes else {
            return valeur
        }

        return Int(bornes.contraindre(Double(valeur)))
    }

    /// Valeur d un curseur, contrainte a ses bornes.
    public func curseur(_ identifiant: IdentifiantDeReglage) -> Double {
        guard case let .curseur(valeur) = self[identifiant] else {
            return 0
        }

        guard let bornes = CatalogueDeReglages.ligne(identifiant)?.bornes else {
            return valeur
        }

        return bornes.contraindre(valeur)
    }

    /// Remplace la valeur d un reglage.
    public mutating func definir(_ valeur: ValeurDeReglage, pour identifiant: IdentifiantDeReglage) {
        valeurs[identifiant] = valeur
    }

    /// Vrai quand deux valeurs portent la meme forme, quel que soit leur
    /// contenu.
    private static func memeType(_ premiere: ValeurDeReglage, _ seconde: ValeurDeReglage) -> Bool {
        switch (premiere, seconde) {
        case (.booleen, .booleen), (.choix, .choix), (.compteur, .compteur),
             (.curseur, .curseur), (.aucune, .aucune):
            true
        default:
            false
        }
    }
}
