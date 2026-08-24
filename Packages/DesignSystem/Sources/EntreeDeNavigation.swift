import Core

//
// Une entree de la navigation principale, prete a etre affichee.
//
// Le libelle vient du catalogue de chaines de l application. Le symbole vient
// du tableau 1.10, donc du systeme de design, jamais de l appelant.
//

/// Une entree de la barre laterale ou de la barre d onglets.
public struct EntreeDeNavigation: Identifiable, Sendable, Equatable {
    /// Destination ouverte par l entree.
    public let destination: DestinationPrincipale

    /// Libelle affiche, pris dans le catalogue de chaines.
    public let libelle: String

    public init(destination: DestinationPrincipale, libelle: String) {
        self.destination = destination
        self.libelle = libelle
    }

    public var id: DestinationPrincipale {
        destination
    }

    /// Symbole SF Symbols de l entree, tableau 1.10.
    public var symbole: String {
        Jetons.icone(de: destination)
    }
}

/// Bloc d appel a l abonnement, cale en bas de la barre laterale, section 2.2.
public struct AppelPremium: Sendable, Equatable {
    /// Titre, en accent, graisse 600.
    public let titre: String
    /// Sous titre, en `text.tertiary`.
    public let sousTitre: String

    public init(titre: String, sousTitre: String) {
        self.titre = titre
        self.sousTitre = sousTitre
    }
}
