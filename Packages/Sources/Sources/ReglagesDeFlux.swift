import Foundation

//
// ReglagesDeFlux
//
// Ce qui gouverne la lecture en flux d un fichier distant.
//
// Les quatre valeurs vivent ensemble parce qu elles se compensent : baisser la
// taille de bloc sans baisser le plafond ne change rien, et augmenter les
// tentatives sans attente rend la reprise inutile. Les regler une par une a
// l appel disperserait cet equilibre chez chaque appelant, et la premiere
// fonctionnalite qui aurait besoin d en changer une seule en oublierait deux.
//

/// Ce qui gouverne la lecture en flux d un fichier distant.
public struct ReglagesDeFlux: Sendable {
    /// Taille d un bloc, en octets.
    ///
    /// Un demi mega octet est un compromis entre deux couts opposes. Un bloc
    /// plus petit multiplie les allers retours, chacun payant la latence du
    /// partage, qui domine largement le debit sur un reseau domestique. Un bloc
    /// plus grand rapatrie des octets que personne ne lira : l index central
    /// d un CBZ tient dans quelques dizaines de kilo octets, et le lire par
    /// blocs de quatre mega octets couterait cent fois son poids.
    public var tailleDeBloc: Int

    /// Plafond memoire du tampon, en octets.
    ///
    /// Trente deux mega octets, soit largement de quoi tenir l index central et
    /// la plus grosse page d un chapitre reel. Le plafond n est pas un objectif
    /// mais une borne : la section 12 accorde quatre cents mega octets a toute
    /// la lecture, cache d images compris, et un tampon de transport qui en
    /// prendrait la moitie ferait tomber le budget avant la premiere page.
    public var plafond: Int

    /// Nombre total de tentatives pour une meme plage, premiere comprise.
    ///
    /// Trois, et seulement pour les pannes que `ErreurReseau.estTemporaire`
    /// reconnait comme telles. Un refus d identifiants rejoue serait la
    /// meilleure facon de faire bloquer le compte de l utilisateur.
    public var essais: Int

    /// Pause entre deux tentatives, en fonction du numero de la tentative qui
    /// vient d echouer.
    ///
    /// Injectee plutot que fixee pour que les tests de reprise ne paient pas une
    /// attente reelle par cas, et pour qu une file de precharge puisse imposer
    /// sa propre politique sans reecrire le tampon.
    public var attendre: @Sendable (Int) async throws -> Void

    public init(
        tailleDeBloc: Int = 512 * 1024,
        plafond: Int = 32 * 1024 * 1024,
        essais: Int = 3,
        attendre: @escaping @Sendable (Int) async throws -> Void = ReglagesDeFlux.attenteCroissante
    ) {
        self.tailleDeBloc = max(1, tailleDeBloc)
        self.plafond = max(self.tailleDeBloc, plafond)
        self.essais = max(1, essais)
        self.attendre = attendre
    }

    /// Les reglages retenus pour un partage reseau domestique.
    public static let parDefaut = ReglagesDeFlux()

    /// Attente croissante avec le rang de la tentative.
    public static let attenteCroissante: @Sendable (Int) async throws -> Void = { tentative in
        try await Task.sleep(for: .milliseconds(250 * tentative))
    }
}
