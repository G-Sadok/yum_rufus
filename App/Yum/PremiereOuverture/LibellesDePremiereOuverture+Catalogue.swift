import Core
import DesignSystem

//
// Libelles du parcours de premiere ouverture, pris dans le catalogue de
// chaines.
//
// Meme role que `LibellesDuMurPremium.duCatalogue` : le paquet DesignSystem
// sait quel libelle va ou, l application sait lequel c est.
//
// Les tables sont indexees par la representation persistee des enumerations et
// non par le cas Swift. Le catalogue reste alors lisible sans dependre de
// l ordre de declaration, alors meme que cet ordre est celui de l ecran.
//

extension LibellesDePremiereOuverture {
    /// Textes du parcours de premiere ouverture.
    static var duCatalogue: LibellesDePremiereOuverture {
        LibellesDePremiereOuverture(
            titres: titresDuCatalogue,
            phrases: phrasesDuCatalogue,
            commandes: commandesDuCatalogue,
            sens: sensDuCatalogue,
            sources: sourcesDuCatalogue,
            voirToutesLesSources: Chaines.PremiereOuverture.voirToutesLesSources,
            mentionDeLaDeuxiemeEtape: Chaines.PremiereOuverture.mention,
            connexionEnCours: Chaines.PremiereOuverture.connexionEnCours,
            seriesTrouvees: Chaines.PremiereOuverture.seriesTrouvees,
            adresseInjoignable: Chaines.PremiereOuverture.adresseInjoignable,
            progression: Chaines.PremiereOuverture.progression,
            apercuDuSens: Chaines.PremiereOuverture.apercuDuSens
        )
    }

    private static var titresDuCatalogue: [String: String] {
        [
            EtapeDePremiereOuverture.sensDeLecture.rawValue:
                Chaines.PremiereOuverture.sensDeLectureTitre,
            EtapeDePremiereOuverture.premiereSource.rawValue:
                Chaines.PremiereOuverture.premiereSourceTitre,
        ]
    }

    private static var phrasesDuCatalogue: [String: String] {
        [
            EtapeDePremiereOuverture.sensDeLecture.rawValue:
                Chaines.PremiereOuverture.sensDeLecturePhrase,
            EtapeDePremiereOuverture.premiereSource.rawValue:
                Chaines.PremiereOuverture.premiereSourcePhrase,
        ]
    }

    /// Les quatre commandes du tableau 6.5.
    private static var commandesDuCatalogue: [String: String] {
        [
            CommandeDePremiereOuverture.continuer.rawValue: Chaines.PremiereOuverture.continuer,
            CommandeDePremiereOuverture.passer.rawValue: Chaines.PremiereOuverture.passer,
        ]
    }

    /// Les deux sens du menu de reglages, tableau 6.7.
    private static var sensDuCatalogue: [String: String] {
        [
            SensDeLecture.droiteGauche.rawValue: Chaines.PremiereOuverture.sensDroiteGauche,
            SensDeLecture.gaucheDroite.rawValue: Chaines.PremiereOuverture.sensGaucheDroite,
        ]
    }

    /// Les trois sources mises en avant, libelles du menu de la section 5.3.
    private static var sourcesDuCatalogue: [String: String] {
        [
            TypeDeSource.fichiersLocaux.rawValue: Chaines.PremiereOuverture.sourceFichiersLocaux,
            TypeDeSource.komga.rawValue: Chaines.PremiereOuverture.sourceKomga,
            TypeDeSource.opds.rawValue: Chaines.PremiereOuverture.sourceOpds,
        ]
    }
}
