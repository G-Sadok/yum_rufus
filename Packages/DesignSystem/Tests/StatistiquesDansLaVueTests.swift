import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre l ecran Statistiques de lecture, sous ecran de la section 5.5 de
// DESIGN-SPEC.md, et le troisieme critere de F059.
//
// Le document fixe deux choses de ce sous ecran, le gabarit colonne 580 et les
// quatre etats. Les deux sont compares a la phrase du document elle meme, et non
// a une copie.
//
// Le critere de ton est verifie ici plutot que dans la couche metier, parce que
// c est ici que le catalogue de l application est lisible. Chaque texte de
// l ecran passe par la liste de `FormulationBienveillante`, et le nombre de
// textes verifies est confronte au nombre de champs de la structure : un libelle
// ajoute a l ecran et oublie dans la liste ferait virer la suite au rouge plutot
// que de passer sans etre vu.
//

struct StatistiquesDansLaVueTests {
    /// Phrase du document qui nomme les sous ecrans a concevoir.
    private func phraseDesSousEcrans() throws -> String {
        try #require(try SpecificationDeDesign.ligne(contenant: "Sous ecrans a concevoir"))
    }

    /// Libelles tels que le catalogue de l application les porte.
    private func libellesDuCatalogue() throws -> LibellesDeStatistiques {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDeStatistiques(
            titre: catalogue["reglages.ligne.assistance.statistiquesDeLecture"] ?? "",
            sectionAujourdHui: catalogue["statistiques.section.aujourdHui"] ?? "",
            sectionSerie: catalogue["statistiques.section.serie"] ?? "",
            sectionDerniersJours: catalogue["statistiques.section.derniersJours"] ?? "",
            sectionTotaux: catalogue["statistiques.section.totaux"] ?? "",
            lectureDuJour: catalogue["statistiques.lectureDuJour"] ?? "",
            objectif: catalogue["statistiques.objectif"] ?? "",
            objectifDesactive: catalogue["statistiques.objectifDesactive"] ?? "",
            objectifEnChapitres: catalogue["statistiques.objectifEnChapitres"] ?? "",
            augmenter: catalogue["reglages.augmenter"] ?? "",
            diminuer: catalogue["reglages.diminuer"] ?? "",
            rappel: catalogue["statistiques.rappel"] ?? "",
            descriptionDuRappel: catalogue["statistiques.description.rappel"] ?? "",
            comptePartiel: catalogue["statistiques.comptePartiel"] ?? "",
            compteSimple: catalogue["statistiques.compteSimple"] ?? "",
            serie: catalogue["statistiques.serie"] ?? "",
            serieEnJours: catalogue["statistiques.serieEnJours"] ?? "",
            serieVide: catalogue["statistiques.serieVide"] ?? "",
            descriptionDeLaSerie: catalogue["statistiques.description.serie"] ?? "",
            joursDeLecture: catalogue["statistiques.joursDeLecture"] ?? "",
            compteEnJours: catalogue["statistiques.compteEnJours"] ?? "",
            chapitresLus: catalogue["statistiques.chapitresLus"] ?? "",
            pagesLues: catalogue["statistiques.pagesLues"] ?? "",
            compteEnPages: catalogue["statistiques.compteEnPages"] ?? "",
            videTitre: catalogue["etatVide.statistiques.titre"] ?? "",
            videPhrase: catalogue["etatVide.statistiques.phrase"] ?? "",
            videAction: catalogue["etatVide.statistiques.action"] ?? ""
        )
    }

    private var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendrier
    }

    private var reference: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    // MARK: Gabarit

    @Test("Le sous ecran Statistiques de lecture emprunte le gabarit colonne de 580")
    func gabaritDuDocument() throws {
        let phrase = try phraseDesSousEcrans()

        #expect(phrase.contains("Statistiques de lecture"))
        #expect(phrase.contains("gabarit colonne 580"))

        #expect(Jetons.Statistiques.largeurDeColonne == 580)
        #expect(Jetons.Statistiques.largeurDeColonne == Jetons.Contenu.largeurDeColonne)
    }

    @Test("Le sous ecran n invente aucune mesure, il emprunte aux sections 3, 4.1 et 4.2")
    func mesuresEmpruntees() {
        #expect(Jetons.Statistiques.rayon == Jetons.CarteDeReglages.rayon)
        #expect(Jetons.Statistiques.margeLaterale == Jetons.LigneDeReglage.margeLaterale)
        #expect(Jetons.Statistiques.hauteurDeLigne == Jetons.LigneDeReglage.hauteur)
        #expect(Jetons.Statistiques.hauteurAvecBarre == Jetons.LigneDeReglage.hauteurAvecDescription)
        #expect(
            Jetons.Statistiques.encastrementDuSeparateur == Jetons.CarteDeReglages.encastrementDuSeparateur
        )

        // La barre reprend la hauteur du filet de progression de la section 3,
        // seule barre de progression que le document chiffre.
        #expect(Jetons.Statistiques.hauteurDeLaBarre == 4)

        #expect(Jetons.Espace.echelle.contains(Jetons.Statistiques.ecartAvantLaValeur))
        #expect(Jetons.Espace.echelle.contains(Jetons.Statistiques.ecartAvantLaBarre))
        #expect(Jetons.Espace.echelle.contains(Jetons.Statistiques.ecartDansUneJournee))
    }

    @Test("La hauteur du filet de la section 3 est bien celle que le code reprend")
    func hauteurDuFiletDuDocument() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "| Filet, hauteur |"))
        let chiffre = try #require(
            ligne
                .components(separatedBy: "|")
                .compactMap { SpecificationDeDesign.nombre($0.trimmingCharacters(in: .whitespaces)) }
                .last
        )

        #expect(chiffre == Jetons.Statistiques.hauteurDeLaBarre)
    }

    @Test("Une ligne de journee tient la cible de pointage de la section 7")
    func cibleDUneJournee() {
        #expect(Jetons.Statistiques.hauteurDeJournee >= Jetons.Cible.auPointeur)
    }

    // MARK: Les quatre etats

    @Test("Le document impose les quatre etats a ce sous ecran")
    func quatreEtatsDuDocument() throws {
        #expect(try phraseDesSousEcrans().contains("quatre etats"))
    }

    @Test("Un comptage vide donne l etat vide, pas une carte a zero")
    func comptageVideDonneLEtatVide() throws {
        let libelles = try libellesDuCatalogue()
        let instantane = StatistiquesDeLecture(
            journees: [],
            objectif: .desactive,
            le: reference,
            calendrier: calendrier
        )

        #expect(instantane.estVide)
        #expect(libelles.videTitre == "Aucune lecture comptee")
        #expect(libelles.videPhrase.isEmpty == false)
        #expect(libelles.videAction.isEmpty == false)
    }

    @Test("L etat vide sans destination ne promet aucun bouton")
    func etatVideSansDestination() {
        #expect(CommandesDeStatistiques.inertes.ouvrirLaBibliotheque == nil)
    }

    // MARK: Textes chiffres

    @Test("Avec objectif, le compte du jour dit ou en est la journee")
    func compteAvecObjectif() throws {
        let libelles = try libellesDuCatalogue()
        let journee = JourneeDeLecture(jour: reference, chapitresLus: 3, pagesLues: 60)

        let texte = TexteDeStatistiques.compteDuJour(
            journee,
            objectif: ObjectifQuotidien(chapitresParJour: 5),
            libelles: libelles
        )

        #expect(texte == "3 sur 5 chapitres")
    }

    @Test("Sans objectif, le compte du jour n invente aucune cible")
    func compteSansObjectif() throws {
        let libelles = try libellesDuCatalogue()
        let journee = JourneeDeLecture(jour: reference, chapitresLus: 3)

        let texte = TexteDeStatistiques.compteDuJour(
            journee,
            objectif: .desactive,
            libelles: libelles
        )

        #expect(texte == "3 chapitres")
        #expect(texte.contains("sur") == false)
    }

    @Test("Le compteur montre Desactive a son cran le plus bas, et le nombre au dessus")
    func valeurDuCompteur() throws {
        let libelles = try libellesDuCatalogue()

        #expect(
            TexteDeStatistiques.valeurDeLObjectif(.desactive, libelles: libelles) == "Desactive"
        )
        #expect(
            TexteDeStatistiques.valeurDeLObjectif(
                ObjectifQuotidien(chapitresParJour: 12),
                libelles: libelles
            ) == "12 chapitres"
        )
    }

    @Test("Une serie a zero ne s ecrit pas comme un score")
    func serieAZero() throws {
        let libelles = try libellesDuCatalogue()

        let vide = TexteDeStatistiques.longueurDeLaSerie(0, libelles: libelles)
        #expect(vide == libelles.serieVide)
        #expect(vide.hasPrefix("0") == false)

        #expect(TexteDeStatistiques.longueurDeLaSerie(12, libelles: libelles) == "12 jours")
    }

    @Test("L etiquette d une journee porte le jour et le compte, jamais la seule barre")
    func etiquetteDUneJournee() throws {
        let libelles = try libellesDuCatalogue()
        let journee = JourneeDeLecture(jour: reference, chapitresLus: 2)
        let locale = Locale(identifier: "fr_FR")

        let etiquette = TexteDeStatistiques.etiquetteDeLaJournee(
            journee,
            libelles: libelles,
            locale: locale
        )

        #expect(etiquette.contains("2 chapitres"))
        #expect(etiquette.contains(TexteDeStatistiques.nomDeLaJournee(journee, locale: locale)))
    }

    // MARK: Le troisieme critere de F059

    @Test("Aucun texte de l ecran ne porte de formulation culpabilisante")
    func aucuneFormulationCulpabilisante() throws {
        let libelles = try libellesDuCatalogue()

        for texte in libelles.tousLesTextes {
            #expect(texte.isEmpty == false, "Un libelle manque au catalogue")

            let tournures = FormulationBienveillante.tournuresTrouvees(dans: texte)
            #expect(tournures.isEmpty, "\(texte) porte \(tournures)")
            #expect(FormulationBienveillante.estBienveillante(texte), "\(texte)")
        }
    }

    @Test("La liste des textes verifies couvre tous les champs de la structure")
    func tousLesChampsSontVerifies() throws {
        let libelles = try libellesDuCatalogue()
        let champs = Mirror(reflecting: libelles).children.count

        // Sans cette egalite, un libelle ajoute a l ecran echapperait au
        // controle de ton sans que rien ne le signale.
        #expect(libelles.tousLesTextes.count == champs)
    }

    @Test("Les textes composes passent aussi le controle de ton")
    func textesComposesBienveillants() throws {
        let libelles = try libellesDuCatalogue()
        let journee = JourneeDeLecture(jour: reference, chapitresLus: 0)

        let composes = [
            TexteDeStatistiques.compteDuJour(journee, objectif: .desactive, libelles: libelles),
            TexteDeStatistiques.compteDuJour(
                journee,
                objectif: ObjectifQuotidien(chapitresParJour: 5),
                libelles: libelles
            ),
            TexteDeStatistiques.longueurDeLaSerie(0, libelles: libelles),
            TexteDeStatistiques.compteDeJours(0, libelles: libelles),
            TexteDeStatistiques.compteDePages(0, libelles: libelles),
            TexteDeStatistiques.valeurDeLObjectif(.desactive, libelles: libelles),
        ]

        for texte in composes {
            #expect(FormulationBienveillante.estBienveillante(texte), "\(texte)")
        }
    }

    // MARK: Libelles

    @Test("Le titre est celui de la ligne de reglages qui mene ici")
    func titreDuDocument() throws {
        let libelles = try libellesDuCatalogue()
        let phrase = try phraseDesSousEcrans()

        #expect(libelles.titre == "Statistiques de lecture")
        #expect(phrase.contains(libelles.titre))
    }

    @Test("Le cran desactive porte le mot de l inventaire de la section 9")
    func motDuCahier() throws {
        let libelles = try libellesDuCatalogue()

        #expect(libelles.objectifDesactive == "Desactive")
        #expect(libelles.objectif == "Objectif quotidien")
    }

    @Test("Chaque commande sans libelle porte une etiquette d accessibilite")
    func etiquettesDesIcones() throws {
        let libelles = try libellesDuCatalogue()

        // Les deux chevrons du compteur de la section 4.1 ne montrent qu un
        // symbole, section 7.
        #expect(libelles.augmenter.isEmpty == false)
        #expect(libelles.diminuer.isEmpty == false)
    }

    @Test("Les symboles de l ecran viennent de la table des icones, jamais inventes")
    func symbolesDeLEcran() {
        #expect(Jetons.Statistiques.symbole == Jetons.IconeDeReglage.pour(.statistiquesDeLecture))
        #expect(
            Jetons.Statistiques.symboleDuRappel
                == Jetons.IconeDeReglage.pour(.notificationsDeNouveauxChapitres)
        )
        #expect(Jetons.Statistiques.symboleDesJours == Jetons.Icone.historique)
    }
}
