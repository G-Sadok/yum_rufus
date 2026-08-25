//
// Lignes des sections 13 a 17 de l ecran Reglages, section 5.5 de
// DESIGN-SPEC.md.
//
// Ces cinq sections sont presque entierement faites de lignes de navigation.
// Deux lignes seulement montrent une valeur, Dernier envoi et Version, et
// aucune des deux n est un choix : elles disent un etat que l ecran calcule.
//

extension CatalogueDeReglages {
    /// Sections Sauvegarde et restauration, iCloud, Stockage, Assistance et
    /// A propos.
    static let lignesDesSectionsTreizeADixSept: [LigneDeReglage] =
        sauvegarde + iCloud + stockage + assistance + aPropos

    /// 13. Sauvegarde et restauration.
    private static let sauvegarde: [LigneDeReglage] = [
        .navigation(.sauvegarderMaintenant, .sauvegardeEtRestauration),
        .menu(.sauvegardeAutomatique, .sauvegardeEtRestauration, SauvegardeAutomatique.self),
        .navigation(.restaurerDepuisUnFichier, .sauvegardeEtRestauration),
    ]

    /// 14. iCloud.
    ///
    /// Les deux interrupteurs de synchronisation sont inactifs sur une
    /// installation neuve, comme l etat vide de la section 5.5 l impose.
    /// `Dernier envoi` affiche `Jamais` tant que rien n est parti.
    private static let iCloud: [LigneDeReglage] = [
        .interrupteur(.synchroniserLaProgression, .iCloud, actifParDefaut: false),
        .interrupteur(.synchroniserLaBibliotheque, .iCloud, actifParDefaut: false),
        .valeurEnLectureSeule(.dernierEnvoi, .iCloud),
    ]

    /// 15. Stockage.
    private static let stockage: [LigneDeReglage] = [
        .navigation(.detailDuStockage, .stockage),
        .navigation(.viderLeCacheDImages, .stockage),
        .navigation(.supprimerTousLesTelechargements, .stockage),
    ]

    /// 16. Assistance.
    private static let assistance: [LigneDeReglage] = [
        .navigation(.aide, .assistance),
        .navigation(.signalerUnBug, .assistance),
        .navigation(.statistiquesDeLecture, .assistance),
    ]

    /// 17. A propos.
    ///
    /// La section se termine par une note en `caption`, posee sous la carte par
    /// la vue. Elle n est pas une ligne.
    private static let aPropos: [LigneDeReglage] = [
        .valeurEnLectureSeule(.version, .aPropos),
        .navigation(.nouveautes, .aPropos),
        .navigation(.mentionsLegales, .aPropos),
    ]
}
