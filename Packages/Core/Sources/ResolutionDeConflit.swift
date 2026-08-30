import Foundation

//
// ResolutionDeConflit
//
// La regle qui decide, quand deux appareils ont modifie la meme chose, lequel
// des deux etats survit.
//
// Elle est ecrite ici, en entier, et nulle part ailleurs. Le moteur, le journal
// et l applicateur l appellent tous les trois : une regle recopiee a trois
// endroits donnerait un journal qui garde une version, un applicateur qui en
// ecrit une autre, et deux appareils qui ne convergent jamais.
//
// La regle en trois lignes, dans cet ordre, et c est la documentation que le
// critere d acceptation demande.
//
// 1. L horodatage le plus recent gagne. C est la regle utile : le dernier
//    geste de l utilisateur est celui qu il attend de retrouver.
// 2. A horodatage egal, l identifiant d appareil le plus grand gagne, au sens
//    de la comparaison lexicographique. Cette ligne n a aucun sens metier et
//    ce n est pas ce qu on lui demande : elle existe pour que la reponse ne
//    depende pas de l ordre d arrivee. Sans elle, deux appareils qui recoivent
//    les memes deux versions dans deux ordres differents en gardent chacun une
//    autre, et la divergence est definitive puisque plus rien ne bouge.
// 3. A horodatage et appareil egaux, la charge la plus grande gagne, comparee
//    octet par octet. Le cas suppose deux ecritures distinctes du meme
//    appareil dans la meme milliseconde. Il est rare, il n est pas impossible,
//    et le laisser sans reponse rendrait la regle non deterministe pile la ou
//    on affirme qu elle l est.
//
// Ce que la regle ne fait pas, volontairement : elle ne fusionne rien. Une
// position de lecture n a pas de fusion sensee, la moyenne de deux pages
// n existe pas. Le choix est donc entre deux etats complets, jamais entre
// leurs champs.
//

/// Ce qui a departage deux versions du meme objet.
///
/// La raison est rendue avec le gagnant plutot que perdue dans le calcul. Elle
/// sert au diagnostic, ou la seule question posee est de savoir pourquoi cet
/// appareil la montre cette page la, et elle rend la regle testable ligne par
/// ligne au lieu de globalement.
public enum ArbitrageDeConflit: String, Sendable, Equatable, Hashable {
    /// Les deux versions sont identiques, le choix ne change rien.
    case versionsIdentiques

    /// Un horodatage est plus recent que l autre.
    case parHorodatage

    /// Horodatages egaux, departage par identifiant d appareil.
    case parAppareil

    /// Horodatage et appareil egaux, departage par le contenu.
    case parCharge
}

/// Le gagnant d un conflit et ce qui l a designe.
public struct IssueDeConflit: Sendable, Equatable {
    /// Version qui survit.
    public let changement: ChangementSynchronise

    /// Ligne de la regle qui a tranche.
    public let arbitrage: ArbitrageDeConflit

    public init(changement: ChangementSynchronise, arbitrage: ArbitrageDeConflit) {
        self.changement = changement
        self.arbitrage = arbitrage
    }
}

/// Resolution de conflit par horodatage, section 2.2 du cahier de
/// developpement.
public enum ResolutionDeConflit {
    /// Version qui survit entre deux versions du meme objet.
    ///
    /// Les deux arguments jouent le meme role : la fonction est commutative, et
    /// la suite de tests le verifie. Un appelant n a donc pas a savoir lequel
    /// est le local et lequel est le distant, ce qui evite la question de
    /// savoir de quel cote se trouve le biais.
    public static func gagnant(
        _ premier: ChangementSynchronise,
        _ second: ChangementSynchronise
    ) -> IssueDeConflit {
        guard premier != second else {
            return IssueDeConflit(changement: premier, arbitrage: .versionsIdentiques)
        }

        if premier.horodatage != second.horodatage {
            let gagnant = premier.horodatage > second.horodatage ? premier : second

            return IssueDeConflit(changement: gagnant, arbitrage: .parHorodatage)
        }

        if premier.appareil != second.appareil {
            let gagnant = premier.appareil > second.appareil ? premier : second

            return IssueDeConflit(changement: gagnant, arbitrage: .parAppareil)
        }

        let gagnant = comparerLesCharges(premier, second) ? premier : second

        return IssueDeConflit(changement: gagnant, arbitrage: .parCharge)
    }

    /// Etat retenu pour chaque cle, a partir de deux ensembles de changements.
    ///
    /// Le resultat ne depend ni de l ordre des deux ensembles ni de l ordre a
    /// l interieur de chacun. C est ce qui fait converger deux appareils qui
    /// recoivent les memes lignes dans le desordre, ce qui est le cas normal
    /// avec CloudKit : rien ne garantit l ordre de livraison d une zone.
    public static func fusion(
        _ premier: [ChangementSynchronise],
        _ second: [ChangementSynchronise]
    ) -> [ChangementSynchronise] {
        var journal = JournalDeChangements(premier)
        journal.consigner(second)

        return journal.changements
    }

    /// Vrai quand la charge du premier passe avant celle du second.
    ///
    /// La comparaison est faite octet par octet, le plus court perdant a
    /// prefixe egal. Elle ne veut rien dire pour un humain, et n a pas a en
    /// vouloir dire : sa seule propriete utile est d etre totale et stable
    /// entre appareils, la ou une comparaison de dictionnaires dependrait de
    /// l ordre de hachage du processus.
    private static func comparerLesCharges(
        _ premier: ChangementSynchronise,
        _ second: ChangementSynchronise
    ) -> Bool {
        for (octetPremier, octetSecond) in zip(premier.charge, second.charge)
            where octetPremier != octetSecond {
            return octetPremier > octetSecond
        }

        return premier.charge.count > second.charge.count
    }
}
