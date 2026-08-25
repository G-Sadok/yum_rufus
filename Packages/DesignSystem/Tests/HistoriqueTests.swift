import Core
import DesignSystem
import Foundation
import Testing

/// Verifie l ecran Historique contre les sections 5.2, 4.8, 6.3, 6.4 et 6.5 de
/// DESIGN-SPEC.md.
///
/// Comme les autres suites de ce paquet, aucune valeur ni aucun libelle du
/// document n est recopie ici : les tests lisent DESIGN-SPEC.md et le catalogue
/// de chaines sur disque, et comparent le code a la source.
struct HistoriqueTests {
    // MARK: Dimensions de la section 5.2

    /// Tableau de la section 5.2, reconnu a sa premiere propriete.
    static func tableauDeLHistorique() throws -> [String: String] {
        let tableau = try #require(
            try LectureDeTableaux.tableauDeProprietes(contenantLaPropriete: "Hauteur d entree"),
            "Le tableau de la section 5.2 doit exister"
        )

        return LectureDeTableaux.valeursParPropriete(tableau)
    }

    @Test("L entree reprend les dimensions de la section 5.2")
    func dimensionsDeLEntree() throws {
        let valeurs = try Self.tableauDeLHistorique()

        #expect(
            Jetons.Historique.hauteurDEntree
                == LectureDeTableaux.premierNombre(valeurs["Hauteur d entree"])
        )

        // `44 par 66, rayon 6` donne la largeur, la hauteur, puis le rayon.
        let vignette = LectureDeTableaux.nombres(dans: valeurs["Vignette"])

        #expect(vignette.count == 3, "Le document chiffre largeur, hauteur et rayon")
        #expect(Jetons.Historique.largeurDeVignette == vignette.first)
        #expect(Jetons.Historique.hauteurDeVignette == vignette.dropFirst().first)
        #expect(Jetons.Historique.rayonDeVignette == vignette.last)

        #expect(
            Jetons.Historique.coteDuBoutonDeSuppression
                == LectureDeTableaux.premierNombre(valeurs["Suppression"])
        )
    }

    @Test("Les trois roles de texte de l entree sont ceux de la section 5.2")
    func rolesDeTexteDeLEntree() throws {
        let valeurs = try Self.tableauDeLHistorique()

        #expect(Jetons.Historique.titreDeSerie.taille == Jetons.Typo.body.taille)
        #expect(
            Jetons.Historique.titreDeSerie.graisse == .semiGrasse,
            "Le document ecrit : \(valeurs["Titre de serie"] ?? "")"
        )
        #expect(Jetons.Historique.chapitre == Jetons.Typo.footnote)
        #expect(Jetons.Historique.heure == Jetons.Typo.footnote)
        #expect(Jetons.Historique.enTeteDeJour == Jetons.Typo.headline)
    }

    @Test("Le regroupement par jour et l en tete collant sont bien ce que la section 5.2 demande")
    func laSectionDemandeUnEnTeteCollant() throws {
        let phrase = try #require(
            try SpecificationDeDesign.ligne(contenant: "Regroupement par jour"),
            "La section 5.2 doit demander le regroupement par jour"
        )

        #expect(phrase.contains("en tete collant"))
        #expect(phrase.contains("headline"), "L en tete porte la date en headline")
    }

    // MARK: Modale courte, section 4.8

    @Test("La modale courte reprend les dimensions de la section 4.8")
    func dimensionsDeLaModale() throws {
        let tableau = try #require(
            try LectureDeTableaux.tableauDeProprietes(contenantLaPropriete: "Hauteur, cas de reference")
                .flatMap { LectureDeTableaux.valeursParPropriete($0) },
            "Un tableau Propriete Valeur doit porter la hauteur de reference"
        )

        // Le premier tableau qui porte cette propriete est celui de la modale,
        // la section 4.8 precedant la feuille de configuration et le mur
        // premium.
        #expect(Jetons.Modale.largeur == LectureDeTableaux.premierNombre(tableau["Largeur"]))
        #expect(
            Jetons.Modale.hauteurDeReference
                == LectureDeTableaux.premierNombre(tableau["Hauteur, cas de reference"])
        )
        #expect(Jetons.Modale.rayon == LectureDeTableaux.premierNombre(tableau["Rayon"]))

        // `deux capsules de 150 par 34, rayon 17, gouttiere 16`.
        let boutons = LectureDeTableaux.nombres(dans: tableau["Boutons"])

        #expect(boutons.count == 4, "Largeur, hauteur, rayon et gouttiere")
        #expect(Jetons.Modale.largeurDeBouton == boutons.first)
        #expect(Jetons.Modale.hauteurDeBouton == boutons.dropFirst().first)
        #expect(Jetons.Modale.rayonDeBouton == boutons.dropFirst(2).first)
        #expect(Jetons.Modale.gouttiereEntreBoutons == boutons.last)
    }

    @Test("La confirmation se pose a droite, comme la section 4.8 l impose")
    func laConfirmationEstADroite() throws {
        let tableau = try #require(
            try LectureDeTableaux.tableauDeProprietes(contenantLaPropriete: "Confirmation")
                .flatMap { LectureDeTableaux.valeursParPropriete($0) }
        )

        #expect(tableau["Confirmation"] == "a droite")

        // La vue pose Annuler puis la confirmation, dans cet ordre. Le test ne
        // peut pas lire une disposition SwiftUI : il verifie que le contenu
        // distingue bien les deux roles, que la vue rend dans l ordre du
        // document.
        let contenu = ContenuDeModaleCourte(
            titre: "titre",
            description: "description",
            annuler: ActionDEtat(libelle: "annuler") {},
            confirmer: ActionDEtat(libelle: "confirmer") {},
            confirmationEstDestructive: true
        )

        #expect(contenu.annuler.libelle != contenu.confirmer.libelle)
        #expect(contenu.confirmationEstDestructive)
    }

    // MARK: Libelles imposes

    /// Libelles de la langue source du catalogue de l application.
    static func catalogue() throws -> [String: String] {
        try CatalogueDeChaines.charger()
    }

    /// Ligne du tableau 6.3 ou 6.4 qui porte l ecran demande.
    static func ligneDuTableau(_ entetes: [String], ecran: String) throws -> [String] {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: entetes).first,
            "Le tableau \(entetes) doit exister"
        )

        return try #require(
            tableau.lignes.first { $0[0] == ecran },
            "Le tableau doit porter la ligne \(ecran)"
        )
    }

    @Test("L etat vide de l historique affiche le texte impose par le tableau 6.3")
    func etatVideAuMotPres() throws {
        let ligne = try Self.ligneDuTableau(
            ["Ecran", "Titre", "Phrase", "Action"],
            ecran: "Historique"
        )
        let catalogue = try Self.catalogue()

        #expect(catalogue["etatVide.historique.titre"] == ligne[1])
        #expect(catalogue["etatVide.historique.phrase"] == ligne[2])
        #expect(catalogue["etatVide.historique.action"] == ligne[3])
    }

    @Test("L erreur de l historique affiche le texte impose par le tableau 6.4")
    func erreurAuMotPres() throws {
        let ligne = try Self.ligneDuTableau(
            ["Ecran", "Titre", "Phrase", "Actions"],
            ecran: "Historique"
        )
        let catalogue = try Self.catalogue()

        #expect(catalogue["erreur.historique.titre"] == ligne[1])
        #expect(catalogue["erreur.historique.phrase"] == ligne[2])
        #expect(catalogue["erreur.historique.repartirDeZero"] == ligne[3])
    }

    @Test("La commande d effacement porte le libelle du tableau 6.5")
    func libelleDeLEffacement() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Contexte", "Libelle"]).first,
            "Le tableau 6.5 doit exister"
        )

        let libelle = try #require(
            tableau.lignes.first { $0[0] == "Historique" }?[1],
            "Le tableau 6.5 doit porter la commande de l historique"
        )
        let catalogue = try Self.catalogue()

        #expect(catalogue["historique.effacer"] == libelle)
        #expect(
            catalogue["historique.confirmation.titre"] == libelle,
            "La modale reprend le libelle de la commande qui l ouvre"
        )
    }

    @Test("Aucun libelle de l historique ne porte de point d exclamation")
    func aucunPointDExclamation() throws {
        let catalogue = try Self.catalogue()
            .filter { $0.key.hasPrefix("historique.") || $0.key.hasPrefix("erreur.historique.") }

        #expect(catalogue.isEmpty == false, "Le catalogue doit porter les libelles de l ecran")
        #expect(catalogue.values.allSatisfy { $0.contains("!") == false })
    }

    // MARK: Composition des textes

    @Test("Les deux jours les plus recents portent un nom, les autres leur date")
    func enTeteDesJournees() throws {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))

        let libelles = LibellesDHistorique(
            chapitreNumerote: "Chapitre %@",
            aujourdHui: "Aujourd hui",
            hier: "Hier",
            supprimerLEntree: "Retirer",
            effacerLHistorique: "Effacer",
            confirmationTitre: "Effacer",
            confirmationDescription: "Description",
            confirmationAnnuler: "Annuler",
            confirmationEffacer: "Effacer"
        )

        let maintenant = try #require(
            DateComponents(
                calendar: calendrier,
                timeZone: calendrier.timeZone,
                year: 2026,
                month: 8,
                day: 25,
                hour: 14
            ).date
        )

        let jour = { (decalage: Int) in
            calendrier.date(
                byAdding: .day,
                value: decalage,
                to: calendrier.startOfDay(for: maintenant)
            ) ?? maintenant
        }

        let enTete = { (decalage: Int) in
            TexteDHistorique.enTete(
                de: JourneeDHistorique(debutDuJour: jour(decalage), entrees: []),
                libelles: libelles,
                calendrier: calendrier,
                locale: Locale(identifier: "fr_FR"),
                maintenant: maintenant
            )
        }

        #expect(enTete(0) == libelles.aujourdHui)
        #expect(enTete(-1) == libelles.hier)
        #expect(enTete(-2).contains("2026"), "Au dela d hier, l en tete porte la date")
    }

    @Test("Le chapitre d une entree se reduit au numero quand la source n a pas de titre")
    func chapitreSansTitre() {
        let libelles = LibellesDHistorique(
            chapitreNumerote: "Chapitre %@",
            aujourdHui: "Aujourd hui",
            hier: "Hier",
            supprimerLEntree: "Retirer",
            effacerLHistorique: "Effacer",
            confirmationTitre: "Effacer",
            confirmationDescription: "Description",
            confirmationAnnuler: "Annuler",
            confirmationEffacer: "Effacer"
        )

        let sansTitre = EntreeDHistorique(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Serie",
            numeroDeChapitre: 43,
            dateLecture: Date()
        )

        let avecTitre = EntreeDHistorique(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Serie",
            numeroDeChapitre: 43,
            titreDuChapitre: "Le titre du chapitre",
            dateLecture: Date()
        )

        #expect(TexteDHistorique.chapitre(de: sansTitre, libelles: libelles) == "Chapitre 43")
        #expect(
            TexteDHistorique.chapitre(de: avecTitre, libelles: libelles)
                == "Chapitre 43\(TexteDeChapitre.separateur)Le titre du chapitre"
        )
    }
}
