//
// Lignes des sections 7 a 12 de l ecran Reglages, section 5.5 de
// DESIGN-SPEC.md.
//
// Ces sections ne sont pas dessinees par le wireframe 05. Leurs libelles et
// leurs types viennent du tableau de la section 5.5, leurs valeurs par defaut
// de la section 9 du cahier de developpement quand il en donne une, et de
// l etat vide de la section 5.5 quand il n en donne pas : sur une installation
// neuve, les valeurs disent l absence.
//

extension CatalogueDeReglages {
    /// Sections Prereglages de lecture, Comportement du lecteur, Bibliotheque,
    /// Pont navigateur, Suivis et Telechargements.
    static let lignesDesSectionsSeptADouze: [LigneDeReglage] =
        prereglages + comportementDuLecteur + bibliothequeComportement
            + pontNavigateur + suivis + telechargements

    /// 7. Prereglages de lecture.
    ///
    /// La premiere ligne mene a la gestion des prereglages. Elle affiche leur
    /// nombre, ou `Aucun prereglage` sur une installation neuve. Ce nombre est
    /// compte par l ecran, il n est pas un reglage.
    private static let prereglages: [LigneDeReglage] = [
        .navigation(.prereglages, .prereglagesDeLecture),
        .interrupteur(.appliquerAuChapitreSuivant, .prereglagesDeLecture, actifParDefaut: false),
    ]

    /// 8. Comportement du lecteur.
    ///
    /// La tourne de page animee est active par defaut, comme la section 1.9
    /// l implique en la declarant desactivable par reglage. Le reglage systeme
    /// Reduire les animations reste prioritaire sur elle.
    ///
    /// Les deux dernieres lignes ne figurent pas au tableau de la section 5.5
    /// de DESIGN-SPEC.md, qui resume la section. Elles viennent de l inventaire
    /// complet de la section 9 du cahier de developpement, qui les place apres
    /// la luminosite : les ajouter en fin de section respecte donc les deux
    /// documents a la fois, l ordre du tableau comme celui de l inventaire.
    private static let comportementDuLecteur: [LigneDeReglage] = [
        .interrupteur(.tourneDePageAnimee, .comportementDuLecteur, actifParDefaut: true),
        .interrupteur(.garderLEcranAllume, .comportementDuLecteur, actifParDefaut: false),
        .interrupteur(.tournerAvecLesTouchesDeVolume, .comportementDuLecteur, actifParDefaut: false),
        .compteur(
            .pagesGardeesEnMemoire,
            .comportementDuLecteur,
            defaut: Int(bornesDeMemoire.maximum),
            bornes: bornesDeMemoire
        ),
        .curseur(.luminositeDuLecteur, .comportementDuLecteur, defaut: 100, bornes: .pourcentage),
        .menu(.zonesDeToucher, .comportementDuLecteur, DispositionDeZones.self),
        .interrupteur(.inverserLesZones, .comportementDuLecteur, actifParDefaut: false),
    ]

    /// Bornes du nombre de pages gardees en memoire.
    ///
    /// Le maximum est le plafond du cache memoire de la section 6.1 du cahier
    /// de developpement, six pages. Le laisser depasser ferait mentir le
    /// reglage : le cache purgerait aussitot ce que l utilisateur croit avoir
    /// demande. Le minimum est deux, la page affichee et sa voisine, sans quoi
    /// la precharge n aurait plus de place ou vivre.
    private static let bornesDeMemoire = BornesDeReglage(minimum: 2, maximum: 6, pas: 1)

    /// 9. Bibliotheque, comportement.
    ///
    /// Marquer lu a la derniere page est actif par defaut : c est le geste que
    /// l utilisateur attend d un lecteur, et le laisser inactif obligerait a
    /// marquer chaque chapitre a la main.
    private static let bibliothequeComportement: [LigneDeReglage] = [
        .interrupteur(.marquerLuALaDernierePage, .bibliothequeComportement, actifParDefaut: true),
        .menu(.supprimerApresLecture, .bibliothequeComportement, SuppressionApresLecture.self),
        .interrupteur(.mettreAJourAuLancement, .bibliothequeComportement, actifParDefaut: false),
    ]

    /// 10. Pont navigateur.
    private static let pontNavigateur: [LigneDeReglage] = [
        .navigation(.extensionSafari, .pontNavigateur),
        .interrupteur(.ouvrirLesLiensDansLApplication, .pontNavigateur, actifParDefaut: false),
    ]

    /// 11. Suivis.
    ///
    /// La confirmation avant envoi est active par defaut. Envoyer sans
    /// confirmation une progression de lecture vers un service tiers est une
    /// sortie de donnees, et une sortie de donnees ne se fait pas en silence
    /// sur une installation neuve.
    private static let suivis: [LigneDeReglage] = [
        .navigation(.servicesDeSuivi, .suivis),
        .interrupteur(.envoyerLaProgression, .suivis, actifParDefaut: false),
        .interrupteur(.confirmerAvantDEnvoyer, .suivis, actifParDefaut: true),
    ]

    /// 12. Telechargements.
    ///
    /// Le Wi-Fi seul est actif par defaut, pour la meme raison : un
    /// telechargement de chapitres sur reseau cellulaire ne se declenche pas
    /// sans que l utilisateur l ait demande.
    private static let telechargements: [LigneDeReglage] = [
        .menu(.qualiteDeTelechargement, .telechargements, QualiteDeTelechargement.self),
        .interrupteur(.enWiFiSeulement, .telechargements, actifParDefaut: true),
        .compteur(.chapitresALAvance, .telechargements, defaut: 0, bornes: bornesDAvance),
        .navigation(.emplacementDesTelechargements, .telechargements),
    ]

    /// Bornes du nombre de chapitres telecharges d avance.
    ///
    /// Zero desactive la precharge, ce que l etat vide de la section 5.5
    /// attend d une installation neuve. Le maximum reprend le plafond de
    /// telechargements simultanes du sous ecran de la section 9 du cahier de
    /// developpement, cinq, pour qu une file d avance ne puisse pas depasser ce
    /// que la file de telechargement sait traiter.
    private static let bornesDAvance = BornesDeReglage(minimum: 0, maximum: 5, pas: 1)
}
