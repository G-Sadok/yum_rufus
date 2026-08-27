import Core
import DesignSystem

//
// Libelles du mur premium, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDeStockage.duCatalogue` : le paquet DesignSystem sait
// quel libelle va ou, l application sait lequel c est.
//
// La table des avantages est indexee par la representation persistee de
// `AvantagePremium`, celle que l enumeration ecrit. Passer par elle plutot que
// par le cas Swift garde le catalogue lisible sans le lier a l ordre de
// l enumeration, alors meme que cet ordre est celui de l ecran.
//

extension LibellesDuMurPremium {
    /// Textes du mur premium.
    static var duCatalogue: LibellesDuMurPremium {
        LibellesDuMurPremium(
            titre: Chaines.MurPremium.titre,
            sousTitre: Chaines.MurPremium.sousTitre,
            avantages: avantagesDuCatalogue,
            commencerLEssai: Chaines.MurPremium.commencerLEssai,
            sAbonner: Chaines.MurPremium.sAbonner,
            mentionDePrix: Chaines.MurPremium.mentionDePrix,
            plusTard: Chaines.MurPremium.plusTard,
            restaurerLesAchats: Chaines.MurPremium.restaurerLesAchats,
            erreurTitre: Chaines.MurPremium.erreurTitre,
            erreurPhrase: Chaines.MurPremium.erreurPhrase,
            reessayer: Chaines.MurPremium.reessayer,
            etiquetteDeLaCouronne: Chaines.MurPremium.couronne
        )
    }

    /// Libelle de chaque avantage, liste de la section 5.9.
    private static var avantagesDuCatalogue: [String: String] {
        [
            AvantagePremium.traductionEtColorisation.rawValue:
                Chaines.MurPremium.avantageTraductionEtColorisation,
            AvantagePremium.serveurs.rawValue:
                Chaines.MurPremium.avantageServeurs,
            AvantagePremium.suivis.rawValue:
                Chaines.MurPremium.avantageSuivis,
            AvantagePremium.telechargements.rawValue:
                Chaines.MurPremium.avantageTelechargements,
            AvantagePremium.sauvegardeEtSynchronisation.rawValue:
                Chaines.MurPremium.avantageSauvegardeEtSynchronisation,
        ]
    }
}
