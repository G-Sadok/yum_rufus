//
// ObjectifQuotidien
//
// L objectif de lecture d une journee, inventaire de la section 9 du cahier de
// developpement : compteur, valeur `Desactive` puis 1 a 20 chapitres, livre
// desactive.
//
// Le document ecrit les trois etats d un seul controle : eteint, ou un nombre
// entre un et vingt. Le type le dit de la meme facon, avec un entier optionnel
// plutot qu avec un zero qui voudrait dire deux choses. Un objectif de zero
// chapitre n existe pas, et rien dans le produit ne doit pouvoir l ecrire.
//
// La conversion depuis et vers le compteur de la section 4.1 vit ici, une seule
// fois. Le controle de la vue compte a partir de zero, parce qu il lui faut un
// cran pour l etat `Desactive`, et c est le seul endroit ou zero a un sens.
//

/// Objectif de lecture d une journee, en chapitres.
public struct ObjectifQuotidien: Sendable, Codable, Equatable, Hashable {
    /// Plus petit objectif que l inventaire de la section 9 autorise.
    public static let minimum = 1

    /// Plus grand objectif que l inventaire de la section 9 autorise.
    public static let maximum = 20

    /// Bornes de l objectif lui meme, hors etat desactive.
    public static let bornes = BornesDeReglage(
        minimum: Double(minimum),
        maximum: Double(maximum),
        pas: 1
    )

    /// Bornes du compteur qui le regle, cran `Desactive` compris.
    ///
    /// Le compteur descend un cran plus bas que l objectif, et ce cran est
    /// l extinction. Il ne designe pas un objectif de zero chapitre.
    public static let bornesDuCompteur = BornesDeReglage(
        minimum: Double(minimum - 1),
        maximum: Double(maximum),
        pas: 1
    )

    /// Aucun objectif, valeur livree par le document.
    public static let desactive = ObjectifQuotidien(chapitresParJour: nil)

    /// Nombre de chapitres vises dans la journee, nul quand rien n est vise.
    public let chapitresParJour: Int?

    /// Construit un objectif, ramene entre les bornes quand il en sort.
    ///
    /// Une valeur hors bornes vient forcement d une base ecrite par une autre
    /// version du produit. La ramener vaut mieux que de la refuser : un
    /// objectif de trente chapitres relu tel quel ne serait jamais atteint, et
    /// l ecran afficherait une cible que le compteur ne sait pas reproduire.
    public init(chapitresParJour: Int?) {
        guard let vise = chapitresParJour else {
            self.chapitresParJour = nil
            return
        }

        self.chapitresParJour = min(max(vise, Self.minimum), Self.maximum)
    }

    /// Objectif designe par un cran du compteur de la section 4.1.
    ///
    /// Le cran le plus bas eteint l objectif, les suivants le chiffrent.
    public init(compteur cran: Int) {
        self.init(chapitresParJour: cran < Self.minimum ? nil : cran)
    }

    /// Cran du compteur qui represente cet objectif.
    public var compteur: Int {
        chapitresParJour ?? (Self.minimum - 1)
    }

    /// Vrai quand un objectif est fixe.
    public var estActif: Bool {
        chapitresParJour != nil
    }

    /// Vrai quand la journee decrite atteint l objectif.
    ///
    /// Sans objectif, la question n a pas de reponse utile et la fonction rend
    /// faux. C est `journeeComptee` qui repond a la question de la serie de
    /// jours, et elle ne pose pas la meme.
    public func estAtteint(chapitresLus: Int) -> Bool {
        guard let vise = chapitresParJour else {
            return false
        }

        return chapitresLus >= vise
    }

    /// Vrai quand la journee compte dans la serie de jours consecutifs.
    ///
    /// Sans objectif, un seul chapitre suffit a faire compter la journee. Avec
    /// un objectif, la journee compte quand il est atteint. C est la seule
    /// regle de la serie, et elle est ecrite ici plutot que dans le calcul de
    /// la serie pour qu un changement d objectif n en fasse pas apparaitre une
    /// seconde ailleurs.
    public func journeeComptee(chapitresLus: Int) -> Bool {
        guard let vise = chapitresParJour else {
            return chapitresLus > 0
        }

        return chapitresLus >= vise
    }

    /// Part de l objectif deja faite, entre zero et un.
    ///
    /// Sans objectif, la part vaut un des qu un chapitre est lu : la barre de
    /// l ecran montre alors une journee entamee et non une journee vide, sans
    /// promettre une cible que personne n a fixee.
    public func part(chapitresLus: Int) -> Double {
        guard let vise = chapitresParJour, vise > 0 else {
            return chapitresLus > 0 ? 1 : 0
        }

        return min(Double(max(chapitresLus, 0)) / Double(vise), 1)
    }
}
