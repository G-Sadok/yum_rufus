import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Textes et commandes du mur premium.
//
// Les mesures de la feuille sont couvertes par `MurPremiumDansLaVueTests`, qui
// porte aussi le materiel partage. Ce fichier ci couvre ce que la feuille dit et
// ce qu elle offre.
//
// Chaque libelle est lu dans le catalogue de chaines de l application, jamais
// dans une constante de test, et compare a la cellule du tableau 5.9, 6.4, 6.5
// ou 6.8 qui l ecrit.
//
// Deux criteres d acceptation se jouent ici. La restauration doit etre
// accessible depuis le mur : elle est verifiee sur la liste des commandes que la
// feuille rend, celle la meme que la vue parcourt pour poser ses boutons. Et le
// mur ne doit jamais surgir pendant la lecture : le modificateur de presentation
// ne prend pas un booleen mais une demande, dont la garde de `Core` decide.
//

/// Textes du mur, compares aux tableaux 5.9, 6.4, 6.5 et 6.8.
struct TextesDuMurPremiumTests {
    @Test("Le titre et le sous titre sont ceux de la section 5.9")
    func leTitreEtLeSousTitreViennentDuDocument() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        #expect(libelles.titre == "Premium")
        #expect(libelles.sousTitre == "Debloquez toutes les fonctions avancees")
    }

    @Test("Les cinq avantages sont ceux du document, dans son ordre")
    func lesCinqAvantagesSontDansLOrdreDuDocument() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()
        let attendus = try MaterielDuMurPremium.avantagesDuDocument()

        #expect(attendus.count == AvantagePremium.allCases.count)

        for (avantage, attendu) in zip(AvantagePremium.allCases, attendus) {
            #expect(libelles.libelle(de: avantage) == attendu, "\(avantage.rawValue)")
        }
    }

    @Test("Le bouton principal reprend le libelle du tableau 6.5 quand l essai est ouvert")
    func leBoutonPrincipalAnnonceLEssai() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        let cellule = try MaterielDuMurPremium.cellule(
            entete: ["Contexte", "Libelle"],
            premiereCellule: "Mur premium",
            rang: 1
        )

        #expect(cellule == "Essayer 7 jours gratuitement / Plus tard")
        #expect(cellule.contains(libelles.commencerLEssai))
        #expect(cellule.contains(libelles.plusTard))

        let avecEssai = TexteDuMurPremium.boutonPrincipal(
            pour: MaterielDuMurPremium.offre(),
            libelles: libelles
        )

        #expect(avecEssai == libelles.commencerLEssai)
    }

    @Test("Le bouton ne promet plus sept jours quand l essai est deja consomme")
    func leBoutonNePrometPlusLEssaiConsomme() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        let sansEssai = TexteDuMurPremium.boutonPrincipal(
            pour: MaterielDuMurPremium.offre(essaiDisponible: false),
            libelles: libelles
        )

        #expect(sansEssai == libelles.sAbonner)
        #expect(sansEssai != libelles.commencerLEssai)
        #expect(MaterielDuMurPremium.offre(essaiDisponible: false).essai == nil)
    }

    @Test("La mention de prix composee redonne la phrase du tableau 6.8")
    func laMentionDePrixRedonneLaPhraseDuDocument() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        let cellule = try MaterielDuMurPremium.cellule(
            entete: ["Emplacement", "Texte"],
            premiereCellule: "Sous le bouton du mur premium",
            rang: 1
        )

        let composee = TexteDuMurPremium.mentionDePrix(
            pour: MaterielDuMurPremium.offre(),
            libelles: libelles
        )

        #expect(composee == cellule)
        #expect(
            libelles.mentionDePrix.contains("3,99") == false,
            "Le tarif vient de la boutique, jamais du catalogue"
        )
    }

    @Test("L etat d erreur porte le titre, la phrase et les actions du tableau 6.4")
    func lEtatDErreurVientDuTableau64() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()
        let entete = ["Ecran", "Titre", "Phrase", "Actions"]

        let titre = try MaterielDuMurPremium.cellule(
            entete: entete,
            premiereCellule: "Mur premium",
            rang: 1
        )
        let phrase = try MaterielDuMurPremium.cellule(
            entete: entete,
            premiereCellule: "Mur premium",
            rang: 2
        )
        let actions = try MaterielDuMurPremium.cellule(
            entete: entete,
            premiereCellule: "Mur premium",
            rang: 3
        )

        #expect(libelles.erreurTitre == titre)
        #expect(libelles.erreurPhrase == phrase)
        #expect(actions == "Plus tard / Reessayer")

        let capsules = TexteDuMurPremium.commandesDePied(dans: .erreur)

        #expect(capsules == [.plusTard, .reessayer], "L ordre est celui du document")
        #expect(TexteDuMurPremium.libelle(de: .reessayer, libelles: libelles) == libelles.reessayer)
    }

    @Test("Les libelles du mur suivent les regles d ecriture de la section 6")
    func reglesDEcriture() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        let textes = [
            libelles.titre,
            libelles.sousTitre,
            libelles.commencerLEssai,
            libelles.sAbonner,
            libelles.mentionDePrix,
            libelles.plusTard,
            libelles.restaurerLesAchats,
            libelles.erreurTitre,
            libelles.erreurPhrase,
            libelles.reessayer,
            libelles.etiquetteDeLaCouronne,
        ] + AvantagePremium.allCases.map { libelles.libelle(de: $0) }

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }
}

/// La restauration et la garde, les deux criteres qui se jouent a l ecran.
struct CommandesDuMurPremiumTests {
    @Test("La restauration des achats est offerte par la feuille chargee")
    func laRestaurationEstOfferteParLaFeuille() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()
        let etat = EtatDuMurPremium.chargee(MaterielDuMurPremium.offre())

        #expect(TexteDuMurPremium.commandes(dans: etat).contains(.restaurer))
        #expect(TexteDuMurPremium.commandesDePied(dans: etat).contains(.restaurer))

        let libelle = TexteDuMurPremium.libelle(de: .restaurer, libelles: libelles)

        #expect(libelle == "Restaurer les achats")
    }

    @Test("Le mur nomme la restauration comme la ligne de reglages qui fait de meme")
    func laRestaurationPorteLeMemeMotQueLesReglages() throws {
        let libelles = try MaterielDuMurPremium.libellesDuCatalogue()

        let cellule = try #require(
            try SpecificationDeDesign.ligne(contenant: "Restaurer les achats")
        )

        #expect(cellule.contains("navigation"), "Ligne 1.2 de la section 5.5")
        #expect(cellule.contains(libelles.restaurerLesAchats))
    }

    @Test("La feuille en chargement n offre aucune commande, elle montre des squelettes")
    func laFeuilleEnChargementNOffreRien() {
        #expect(TexteDuMurPremium.commandes(dans: .chargement).isEmpty)
        #expect(Jetons.MurPremium.hauteurDesSquelettes > 0)
        #expect(
            Jetons.MurPremium.hauteurDesSquelettes < Jetons.MurPremium.hauteurDeReference,
            "Les squelettes tiennent dans la feuille, marges comprises"
        )
    }

    @Test("Le mur ne se presente que sur une demande acceptee par la garde")
    func leMurNeSePresenteQueSurDemandeAcceptee() {
        let pendantLaLecture = DemandeDuMurPremium(
            origine: .ligneDAbonnementDesReglages,
            declencheur: .actionDeLUtilisateur,
            lectureEnCours: true
        )
        let automatique = DemandeDuMurPremium(
            origine: .appelDeLaBarreLaterale,
            declencheur: .evenementDeLApplication,
            lectureEnCours: false
        )
        let depuisLeLecteur = DemandeDuMurPremium(
            origine: .panneauDeFiltresDuLecteur,
            declencheur: .actionDeLUtilisateur,
            lectureEnCours: true
        )

        #expect(pendantLaLecture.estAcceptee == false)
        #expect(automatique.estAcceptee == false)
        #expect(depuisLeLecteur.estAcceptee)
    }
}
