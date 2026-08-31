//
// Lignes des sections 1 a 6 de l ecran Reglages, section 5.5 de DESIGN-SPEC.md.
//
// Les quatre premieres sections et la sixieme ont leur contenu impose par le
// wireframe 05. Rien n y est interprete.
//

extension CatalogueDeReglages {
    /// Sections Abonnement, Confidentialite, General, Bibliotheque, Traduction
    /// et Lecteur.
    static let lignesDesSectionsUnASix: [LigneDeReglage] =
        confidentialite + general + bibliothequeTri + traduction + lecteur

    /// 1. Confidentialite.
    private static let confidentialite: [LigneDeReglage] = [
        .interrupteur(.incognito, .confidentialite, actifParDefaut: false),
        .interrupteur(.verrouillageDeLApp, .confidentialite, actifParDefaut: false),
    ]

    /// 3. General.
    private static let general: [LigneDeReglage] = [
        .menu(.langue, .general, ChoixDeLangue.self),
        .menu(.apparence, .general, ChoixDApparence.self),
        .menu(.theme, .general, ChoixDeTheme.self),
        .interrupteur(.notificationsDeNouveauxChapitres, .general, actifParDefaut: false),
    ]

    /// 4. Bibliotheque, tri.
    ///
    /// Le critere et le sens du tri existent deja dans le modele, poses par la
    /// grille de la section 5.1. La section 5.5 ne les redefinit pas, elle leur
    /// donne un endroit ou se regler.
    private static let bibliothequeTri: [LigneDeReglage] = [
        .menu(
            .trierPar,
            .bibliothequeTri,
            choix: CritereDeTri.allCases.map(\.rawValue),
            defaut: TriDeBibliotheque.defaut.critere.rawValue
        ),
        .menu(
            .ordreDeTri,
            .bibliothequeTri,
            choix: OrdreDeTri.allCases.map(\.rawValue),
            defaut: TriDeBibliotheque.defaut.ordre.rawValue
        ),
        .interrupteur(.grouperParCategorie, .bibliothequeTri, actifParDefaut: false),
    ]

    /// 5. Traduction.
    ///
    /// Quatre lignes la ou la section 5.5 en dessine trois. La quatrieme,
    /// `Moteur de traduction`, vient de l inventaire de la section 9 du cahier
    /// de developpement, qui la decrit comme un menu a deux valeurs livre sur
    /// `Sur l appareil` et dont le second choix est reserve a l abonnement.
    /// L arbitrage de la section 0.1 de DESIGN-SPEC.md donne le cahier des
    /// charges normatif sur ce que le document ne fixe pas, et il ne fixe pas
    /// le moyen de choisir le moteur alors que la section 8 fait de ce choix la
    /// seule porte par laquelle une donnee quitte l appareil. Sans cette ligne,
    /// la porte serait ouverte sans que rien ne la commande.
    ///
    /// Elle est posee en deuxieme position : l interrupteur arme la fonction,
    /// le moteur dit ou le travail se fait, la langue dit vers quoi traduire, la
    /// police dit avec quoi l ecrire. Les trois lignes du document gardent leur
    /// ordre relatif.
    private static let traduction: [LigneDeReglage] = [
        .interrupteur(.traduireLesBulles, .traduction, actifParDefaut: false),
        .menu(.moteurDeTraduction, .traduction, ChoixDeMoteurDeTraduction.self),
        .menu(.langueCible, .traduction, ChoixDeLangue.self),
        .navigation(.policeDeRemplacement, .traduction),
    ]

    /// 6. Lecteur.
    ///
    /// Le menu du sens de lecture ne propose que les deux sens horizontaux du
    /// tableau 6.7. Le sens vertical vient de la mise en page `continuVertical`,
    /// et non d un choix concurrent qui pourrait la contredire.
    private static let lecteur: [LigneDeReglage] = [
        .menu(
            .sensDeLecture,
            .lecteur,
            choix: SensDeLecture.choixDuMenuDeReglages.map(\.rawValue),
            defaut: SensDeLecture.parDefaut.rawValue
        ),
        .menu(.miseEnPage, .lecteur, MiseEnPage.self),
        .menu(.fondDuLecteur, .lecteur, ChoixDeFondDuLecteur.self),
        .interrupteur(.rognerLesBords, .lecteur, actifParDefaut: false),
    ]
}
