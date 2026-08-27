import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Banniere de reactivation, regle de degradation de la section 10 du cahier de
// developpement.
//
// La banniere n est pas dessinee par DESIGN-SPEC.md. Le document n en dessine
// qu une, celle de la section 5.5, et cette suite verifie que la nouvelle en
// reprend exactement le gabarit au lieu d en inventer un second : meme rayon,
// meme contour, memes roles de texte. Une valeur qui divergerait ici serait une
// forme de plus dans un produit dont la these veut que l interface disparaisse.
//
// Les textes sont lus dans le catalogue de chaines de l application, jamais dans
// une constante de test. Ils ne viennent pas du document, ils sont donc juges
// sur les regles d ecriture de la section 6 : pas de tiret cadratin, pas de
// point d exclamation, et le meme mot pour la meme action que la ligne de
// reglages qui mene au meme endroit.
//

/// Materiel partage par la suite de la banniere.
enum MaterielDeBanniereDeReactivation {
    /// Libelles pris dans le catalogue de chaines de l application.
    static func libellesDuCatalogue() throws -> LibellesDeBanniereDeReactivation {
        let catalogue = try CatalogueDeChaines.charger()
        let titre = try valeur(catalogue, "banniere.reactivation.titre")
        let expiration = try valeur(catalogue, "banniere.reactivation.apresExpiration")
        let sansAbonnement = try valeur(catalogue, "banniere.reactivation.sansAbonnement")
        let bouton = try valeur(catalogue, "reglages.ligne.abonnement.passerAPremium")

        return LibellesDeBanniereDeReactivation(
            titre: titre,
            phraseApresExpiration: expiration,
            phraseSansAbonnement: sansAbonnement,
            passerAPremium: bouton
        )
    }

    /// Valeur d une cle du catalogue, ou echec du test si elle manque.
    static func valeur(_ catalogue: [String: String], _ cle: String) throws -> String {
        try #require(catalogue[cle], "Le catalogue de chaines ne porte pas \(cle)")
    }
}

/// Le gabarit repris de la banniere de la section 5.5.
struct GabaritDeLaBanniereDeReactivationTests {
    @Test("La banniere reprend le gabarit chiffre de la section 5.5")
    func leGabaritEstCeluiDuDocument() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "banniere en haut de colonne, rayon 12")
        )

        #expect(ligne.contains("contour 1 px `warning`"))
        #expect(ligne.contains("titre en `headline`"))
        #expect(ligne.contains("phrase en `footnote`"))

        #expect(Jetons.BanniereDeReglages.rayon == 12)
        #expect(Jetons.BanniereDeReglages.epaisseurDuContour == 1)
        #expect(Jetons.BanniereDeReglages.titre == Jetons.Typo.headline)
        #expect(Jetons.BanniereDeReglages.phrase == Jetons.Typo.footnote)
    }

    @Test("La couronne de la banniere est celle du reste du produit")
    func laCouronneEstLaMeme() {
        #expect(Jetons.Icone.premium == Jetons.MurPremium.couronne)
    }
}

/// Ce que la banniere dit, et quand elle le dit.
struct TextesDeLaBanniereDeReactivationTests {
    @Test("Une source premium expiree porte une banniere qui nomme la source et la date")
    func laBanniereApresExpiration() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        let banniere = try #require(
            TexteDeLaBanniereDeReactivation.banniere(
                pour: AccesAUneSource(type: .komga, selon: .expire(le: .distantPast)),
                nomDeLaSource: "Komga serveur maison",
                dateDeFin: "1 fevrier",
                libelles: libelles
            )
        )

        #expect(banniere.titre.contains("Komga serveur maison"))
        #expect(banniere.phrase.contains("1 fevrier"))
        #expect(banniere.libelleDuBouton == libelles.passerAPremium)
    }

    @Test("Une source premium jamais achetee porte l autre phrase, sans date")
    func laBanniereSansAbonnement() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        let banniere = try #require(
            TexteDeLaBanniereDeReactivation.banniere(
                pour: AccesAUneSource(type: .opds, selon: .gratuit),
                nomDeLaSource: "Catalogue OPDS",
                dateDeFin: "1 fevrier",
                libelles: libelles
            )
        )

        #expect(banniere.phrase == libelles.phraseSansAbonnement)
        #expect(banniere.phrase.contains("1 fevrier") == false)
    }

    @Test("Une source dont l abonnement court ne porte aucune banniere")
    func aucuneBanniereAvecAbonnement() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        let banniere = TexteDeLaBanniereDeReactivation.banniere(
            pour: AccesAUneSource(type: .komga, selon: .definitif),
            nomDeLaSource: "Komga serveur maison",
            dateDeFin: "1 fevrier",
            libelles: libelles
        )

        #expect(banniere == nil)
    }

    @Test("Une source gratuite ne porte aucune banniere, meme sans abonnement")
    func aucuneBanniereSurUneSourceGratuite() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        let banniere = TexteDeLaBanniereDeReactivation.banniere(
            pour: AccesAUneSource(type: .webdav, selon: .gratuit),
            nomDeLaSource: "Partage WebDAV",
            dateDeFin: "1 fevrier",
            libelles: libelles
        )

        #expect(banniere == nil)
    }

    @Test("La phrase d expiration nomme ce qui reste avant de proposer la sortie")
    func laPhraseNommeCeQuiReste() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        #expect(libelles.phraseApresExpiration.contains("intacts"))
        #expect(libelles.phraseApresExpiration.contains("Premium"))
        #expect(libelles.phraseApresExpiration.contains("%@"))
        #expect(libelles.titre.contains("%@"))
    }

    @Test("Le bouton reprend le libelle de la ligne de reglages qui mene au mur")
    func leBoutonReprendLeLibelleDesReglages() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()

        #expect(libelles.passerAPremium == "Passer a Premium")
    }

    @Test("Aucun texte de la banniere ne rompt les regles d ecriture de la section 6")
    func lesTextesSuiventLesReglesDEcriture() throws {
        let libelles = try MaterielDeBanniereDeReactivation.libellesDuCatalogue()
        let tiretCadratin = "\u{2014}"

        let textes = [
            libelles.titre,
            libelles.phraseApresExpiration,
            libelles.phraseSansAbonnement,
            libelles.passerAPremium,
        ]

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }
}
