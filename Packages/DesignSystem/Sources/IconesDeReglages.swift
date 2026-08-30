import Core

//
// Icones des lignes de reglage, section 5.5 de DESIGN-SPEC.md.
//
// Le tableau 1.10 ne nomme que quinze symboles, ceux que le document cite
// explicitement. Les autres lignes reprennent le symbole que le systeme emploie
// pour la meme action, comme le font deja la coquille et la fiche de serie.
// Aucun symbole n est invente, aucun n est pris hors de SF Symbols.
//

extension Jetons {
    /// Symbole pose a gauche de chaque ligne de reglage.
    public enum IconeDeReglage {
        /// Symbole de la ligne demandee.
        public static func pour(_ identifiant: IdentifiantDeReglage) -> String {
            parIdentifiant[identifiant] ?? Icone.reglages
        }

        /// Couronne posee a droite d une fonction verrouillee.
        public static let couronne = Icone.premium

        /// Chevron simple d une ligne de navigation.
        ///
        /// La variante directionnelle et non `chevron.right` : elle pointe a
        /// droite dans une interface de gauche a droite, comme le demande la
        /// section 4.1, et se retourne d elle meme dans une interface de droite
        /// a gauche. Section 13 du cahier de developpement.
        public static let chevronDeNavigation = "chevron.forward"

        /// Chevron double d une ligne a menu.
        public static let chevronDeMenu = "chevron.up.chevron.down"

        /// Chevron du haut d un compteur.
        public static let chevronDAugmentation = "chevron.up"

        /// Chevron du bas d un compteur.
        public static let chevronDeDiminution = "chevron.down"

        private static let parIdentifiant: [IdentifiantDeReglage: String] =
            abonnementEtConfidentialite
                .merging(generalEtBibliotheque) { premier, _ in premier }
                .merging(traductionEtLecteur) { premier, _ in premier }
                .merging(comportementEtSuivis) { premier, _ in premier }
                .merging(servicesEtAPropos) { premier, _ in premier }

        private static let abonnementEtConfidentialite: [IdentifiantDeReglage: String] = [
            .passerAPremium: Icone.premium,
            .restaurerLesAchats: "arrow.clockwise",
            .incognito: Icone.incognito,
            .verrouillageDeLApp: Icone.verrouillage,
        ]

        private static let generalEtBibliotheque: [IdentifiantDeReglage: String] = [
            .langue: "globe",
            .apparence: "circle.lefthalf.filled",
            .theme: "paintpalette",
            .notificationsDeNouveauxChapitres: "bell",
            .trierPar: "arrow.up.arrow.down",
            .ordreDeTri: "arrow.up",
            .grouperParCategorie: "square.grid.2x2",
        ]

        private static let traductionEtLecteur: [IdentifiantDeReglage: String] = [
            .traduireLesBulles: "character.bubble",
            .moteurDeTraduction: "cpu",
            .langueCible: "text.bubble",
            .policeDeRemplacement: "textformat",
            .sensDeLecture: Icone.sensDeLecture,
            .miseEnPage: Icone.miseEnPage,
            .fondDuLecteur: "rectangle.fill",
            .rognerLesBords: Icone.rognerLesBords,
            .prereglages: "slider.horizontal.3",
            .appliquerAuChapitreSuivant: "arrow.right.circle",
        ]

        private static let comportementEtSuivis: [IdentifiantDeReglage: String] = [
            .tourneDePageAnimee: "book",
            .garderLEcranAllume: "lightbulb",
            .tournerAvecLesTouchesDeVolume: "speaker.wave.2",
            .pagesGardeesEnMemoire: "memorychip",
            .luminositeDuLecteur: Icone.luminosite,
            .marquerLuALaDernierePage: "checkmark.circle",
            .supprimerApresLecture: "trash",
            .mettreAJourAuLancement: "arrow.triangle.2.circlepath",
            .activerLePontNavigateur: "arrow.left.arrow.right",
            .extensionSafari: Icone.parcourir,
            .ouvrirLesLiensDansLApplication: "link",
            .servicesDeSuivi: "person.2",
            .envoyerLaProgression: "arrow.up.circle",
            .confirmerAvantDEnvoyer: "hand.raised",
        ]

        private static let servicesEtAPropos: [IdentifiantDeReglage: String] = [
            .qualiteDeTelechargement: Icone.telechargement,
            .enWiFiSeulement: "wifi",
            .chapitresALAvance: "square.stack",
            .emplacementDesTelechargements: "folder",
            .sauvegarderMaintenant: Icone.sauvegarde,
            .sauvegardeAutomatique: "clock.arrow.circlepath",
            .restaurerDepuisUnFichier: "square.and.arrow.down",
            .synchroniserLaProgression: Icone.iCloud,
            .synchroniserLaBibliotheque: "icloud.and.arrow.up",
            .dernierEnvoi: Icone.historique,
            .detailDuStockage: "internaldrive",
            .viderLeCacheDImages: "photo",
            .supprimerTousLesTelechargements: "trash",
            .aide: Icone.aide,
            .signalerUnBug: Icone.signalerUnBug,
            .statistiquesDeLecture: "chart.bar",
            .revoirLaPremiereOuverture: "hand.wave",
            .version: "info.circle",
            .nouveautes: "sparkles",
            .mentionsLegales: "doc.text",
        ]
    }
}
