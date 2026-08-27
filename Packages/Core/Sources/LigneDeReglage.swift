//
// LigneDeReglage
//
// Une ligne du tableau de la section 5.5 de DESIGN-SPEC.md, et sa cle de
// persistance.
//
// La representation textuelle d un identifiant est la cle ecrite en base. Elle
// est prefixee par la section, pour qu une meme notion reglee a deux endroits,
// comme le tri et le comportement de la bibliotheque, ne se marche pas dessus.
// Renommer un cas Swift ne doit jamais changer cette chaine.
//

/// Identifiant stable d une ligne de reglage.
public enum IdentifiantDeReglage: String, Sendable, Codable, CaseIterable, Hashable {
    // 1. Abonnement
    case passerAPremium = "abonnement.passerAPremium"
    case restaurerLesAchats = "abonnement.restaurerLesAchats"

    // 2. Confidentialite
    case incognito = "confidentialite.incognito"
    case verrouillageDeLApp = "confidentialite.verrouillageDeLApp"

    // 3. General
    case langue = "general.langue"
    case apparence = "general.apparence"
    case theme = "general.theme"
    case notificationsDeNouveauxChapitres = "general.notificationsDeNouveauxChapitres"

    // 4. Bibliotheque, tri
    case trierPar = "bibliothequeTri.trierPar"
    case ordreDeTri = "bibliothequeTri.ordre"
    case grouperParCategorie = "bibliothequeTri.grouperParCategorie"

    // 5. Traduction
    case traduireLesBulles = "traduction.traduireLesBulles"
    case langueCible = "traduction.langueCible"
    case policeDeRemplacement = "traduction.policeDeRemplacement"

    // 6. Lecteur
    case sensDeLecture = "lecteur.sensDeLecture"
    case miseEnPage = "lecteur.miseEnPage"
    case fondDuLecteur = "lecteur.fondDuLecteur"
    case rognerLesBords = "lecteur.rognerLesBords"

    // 7. Prereglages de lecture
    case prereglages = "prereglagesDeLecture.prereglages"
    case appliquerAuChapitreSuivant = "prereglagesDeLecture.appliquerAuChapitreSuivant"

    // 8. Comportement du lecteur
    case tourneDePageAnimee = "comportementDuLecteur.tourneDePageAnimee"
    case garderLEcranAllume = "comportementDuLecteur.garderLEcranAllume"
    case tournerAvecLesTouchesDeVolume = "comportementDuLecteur.tournerAvecLesTouchesDeVolume"
    case pagesGardeesEnMemoire = "comportementDuLecteur.pagesGardeesEnMemoire"
    case luminositeDuLecteur = "comportementDuLecteur.luminositeDuLecteur"
    case zonesDeToucher = "comportementDuLecteur.zonesDeToucher"
    case inverserLesZones = "comportementDuLecteur.inverserLesZones"

    // 9. Bibliotheque, comportement
    case marquerLuALaDernierePage = "bibliothequeComportement.marquerLuALaDernierePage"
    case supprimerApresLecture = "bibliothequeComportement.supprimerApresLecture"
    case mettreAJourAuLancement = "bibliothequeComportement.mettreAJourAuLancement"

    // 10. Pont navigateur
    case extensionSafari = "pontNavigateur.extensionSafari"
    case ouvrirLesLiensDansLApplication = "pontNavigateur.ouvrirLesLiensDansLApplication"

    // 11. Suivis
    case servicesDeSuivi = "suivis.services"
    case envoyerLaProgression = "suivis.envoyerLaProgression"
    case confirmerAvantDEnvoyer = "suivis.confirmerAvantDEnvoyer"

    // 12. Telechargements
    case qualiteDeTelechargement = "telechargements.qualite"
    case enWiFiSeulement = "telechargements.enWiFiSeulement"
    case chapitresALAvance = "telechargements.chapitresALAvance"
    case emplacementDesTelechargements = "telechargements.emplacement"

    // 13. Sauvegarde et restauration
    case sauvegarderMaintenant = "sauvegardeEtRestauration.sauvegarderMaintenant"
    case sauvegardeAutomatique = "sauvegardeEtRestauration.sauvegardeAutomatique"
    case restaurerDepuisUnFichier = "sauvegardeEtRestauration.restaurerDepuisUnFichier"

    // 14. iCloud
    case synchroniserLaProgression = "iCloud.synchroniserLaProgression"
    case synchroniserLaBibliotheque = "iCloud.synchroniserLaBibliotheque"
    case dernierEnvoi = "iCloud.dernierEnvoi"

    // 15. Stockage
    case detailDuStockage = "stockage.detail"
    case viderLeCacheDImages = "stockage.viderLeCacheDImages"
    case supprimerTousLesTelechargements = "stockage.supprimerTousLesTelechargements"

    // 16. Assistance
    case aide = "assistance.aide"
    case signalerUnBug = "assistance.signalerUnBug"
    case statistiquesDeLecture = "assistance.statistiquesDeLecture"

    // 17. A propos
    case version = "aPropos.version"
    case nouveautes = "aPropos.nouveautes"
    case mentionsLegales = "aPropos.mentionsLegales"
}

/// Une ligne de reglage telle que le tableau de la section 5.5 la decrit.
public struct LigneDeReglage: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant stable, aussi cle de persistance et cle de libelle.
    public let id: IdentifiantDeReglage

    /// Section qui porte la ligne.
    public let section: SectionDeReglages

    /// Variante de la section 4.1.
    public let variante: VarianteDeLigneDeReglage

    /// Forme premium, nulle pour une ligne ordinaire.
    public let premium: FormeDeLignePremium?

    /// Valeur appliquee tant que l utilisateur n a rien choisi.
    ///
    /// Elle donne aussi le type attendu a la relecture depuis la base.
    public let valeurParDefaut: ValeurDeReglage

    /// Representations persistees des choix d un menu, dans l ordre du menu.
    ///
    /// Vide pour toute ligne qui n ouvre aucun menu, y compris une ligne
    /// `valeurEtMenu` en lecture seule comme Version ou Dernier envoi. La vue
    /// n y pose alors aucun chevron : la section 4.1 interdit un chevron double
    /// qui n ouvre rien.
    public let choix: [String]

    /// Bornes d un curseur ou d un compteur, nulles pour les autres variantes.
    public let bornes: BornesDeReglage?

    public init(
        id: IdentifiantDeReglage,
        section: SectionDeReglages,
        variante: VarianteDeLigneDeReglage,
        premium: FormeDeLignePremium? = nil,
        valeurParDefaut: ValeurDeReglage = .aucune,
        choix: [String] = [],
        bornes: BornesDeReglage? = nil
    ) {
        self.id = id
        self.section = section
        self.variante = variante
        self.premium = premium
        self.valeurParDefaut = valeurParDefaut
        self.choix = choix
        self.bornes = bornes
    }

    /// Vrai quand la ligne ecrit une valeur en base.
    public var estPersistee: Bool {
        valeurParDefaut.estPersistee
    }

    /// Vrai quand la ligne montre une valeur sans permettre de la changer.
    public var estEnLectureSeule: Bool {
        variante == .valeurEtMenu && choix.isEmpty
    }

    /// Vrai quand le clic ouvre le mur premium au lieu du reglage.
    public var ouvreLeMurPremium: Bool {
        premium != nil
    }
}
