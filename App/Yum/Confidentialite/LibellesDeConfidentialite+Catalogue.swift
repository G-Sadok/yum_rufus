import DesignSystem

//
// Libelles de la confidentialite, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDuMurPremium.duCatalogue` : le paquet DesignSystem sait
// quel libelle va ou, l application sait lequel c est.
//

extension LibellesDIncognito {
    /// Textes de la banniere du mode incognito.
    static var duCatalogue: LibellesDIncognito {
        LibellesDIncognito(
            titre: Chaines.Incognito.titre,
            phrase: Chaines.Incognito.phrase,
            etiquetteDAccessibilite: Chaines.Incognito.etiquette
        )
    }
}

extension LibellesDeVerrouillage {
    /// Textes de l ecran de verrouillage.
    static var duCatalogue: LibellesDeVerrouillage {
        LibellesDeVerrouillage(
            titre: Chaines.Verrouillage.titre,
            phrase: Chaines.Verrouillage.phrase,
            deverrouiller: Chaines.Verrouillage.deverrouiller,
            echecTitre: Chaines.Verrouillage.echecTitre,
            echecPhrase: Chaines.Verrouillage.echecPhrase,
            aucunMoyenPhrase: Chaines.Verrouillage.aucunMoyenPhrase,
            raisonDuSysteme: Chaines.Verrouillage.raison
        )
    }
}
