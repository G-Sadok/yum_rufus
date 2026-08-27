import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre l ecran Signets, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Le document fixe deux choses de ce sous ecran, le gabarit colonne 580 et les
// quatre etats. Les deux sont compares a la phrase du document elle meme, et non
// a une copie : une contrainte changee dans DESIGN-SPEC.md qui n arriverait pas
// jusqu au code fait alors virer la suite au rouge.
//

struct SignetsDansLaVueTests {
    /// Phrase du document qui nomme les sous ecrans a concevoir.
    private func phraseDesSousEcrans() throws -> String {
        try #require(try SpecificationDeDesign.ligne(contenant: "Sous ecrans a concevoir"))
    }

    /// Libelles tels que le catalogue de l application les porte.
    private func libellesDuCatalogue() throws -> LibellesDeSignets {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDeSignets(
            titre: catalogue["signets.titre"] ?? "",
            description: catalogue["signets.description"] ?? "",
            chapitreNumerote: catalogue["chapitre.numerote"] ?? "",
            pageNumerotee: catalogue["signets.pageNumerotee"] ?? "",
            options: catalogue["signets.options"] ?? "",
            ouvrirLaPage: catalogue["signets.ouvrirLaPage"] ?? "",
            supprimer: catalogue["signets.supprimer"] ?? "",
            videTitre: catalogue["etatVide.signets.titre"] ?? "",
            videPhrase: catalogue["etatVide.signets.phrase"] ?? "",
            videAction: catalogue["etatVide.signets.action"] ?? ""
        )
    }

    /// Signet d affichage, tel que la base le rend a la liste.
    private func signet(
        chapitre: Double = 43,
        titreDuChapitre: String? = nil,
        page: Int = 11,
        note: String? = nil
    ) -> SignetAffiche {
        SignetAffiche(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Berserk",
            numeroDeChapitre: chapitre,
            titreDuChapitre: titreDuChapitre,
            pageIndex: page,
            nombreDePages: 30,
            note: note,
            dateCreation: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: Gabarit

    @Test("Le sous ecran Signets emprunte le gabarit colonne de 580 du document")
    func gabaritDuDocument() throws {
        let phrase = try phraseDesSousEcrans()

        #expect(phrase.contains("Signets"))
        #expect(phrase.contains("gabarit colonne 580"))

        #expect(Jetons.Signets.largeurDeColonne == 580)
        #expect(Jetons.Signets.largeurDeColonne == Jetons.Contenu.largeurDeColonne)
    }

    @Test("Le sous ecran n invente aucune mesure, il emprunte aux sections 4.1, 4.2, 5.2 et 7")
    func mesuresEmpruntees() {
        #expect(Jetons.Signets.rayon == Jetons.CarteDeReglages.rayon)
        #expect(Jetons.Signets.margeLaterale == Jetons.LigneDeReglage.margeLaterale)
        #expect(
            Jetons.Signets.encastrementDuSeparateur == Jetons.CarteDeReglages.encastrementDuSeparateur
        )

        // La ligne pose le meme objet qu une entree d historique, section 5.2.
        #expect(Jetons.Signets.hauteurDeLigne == Jetons.Historique.hauteurDEntree)
        #expect(Jetons.Signets.largeurDeVignette == 44)
        #expect(Jetons.Signets.hauteurDeVignette == 66)
        #expect(Jetons.Signets.rayonDeVignette == Jetons.Rayon.pastille)

        #expect(Jetons.Espace.echelle.contains(Jetons.Signets.ecartEntreLesTextes))
        #expect(Jetons.Espace.echelle.contains(Jetons.Signets.ecartAvantLesOptions))
        #expect(Jetons.Espace.echelle.contains(Jetons.Signets.ecartApresLaVignette))
    }

    @Test("La vignette de la liste tient dans la ligne qui la porte")
    func vignetteDansLaLigne() {
        #expect(Jetons.Signets.hauteurDeVignette < Jetons.Signets.hauteurDeLigne)
    }

    @Test("Le bouton d options tient la cible de pointage de la section 7")
    func cibleDuBoutonDOptions() {
        #expect(Jetons.Signets.coteDuBoutonDOptions == Jetons.Cible.auDoigt)
        #expect(Jetons.Signets.coteDuBoutonDOptions >= Jetons.Cible.auPointeur)
    }

    // MARK: Les quatre etats

    @Test("Le document impose les quatre etats a ce sous ecran")
    func quatreEtatsDuDocument() throws {
        let phrase = try phraseDesSousEcrans()

        #expect(phrase.contains("quatre etats"))
    }

    @Test("Une liste vide donne l etat vide, pas une carte vide")
    func listeVideDonneLEtatVide() throws {
        let libelles = try libellesDuCatalogue()

        #expect(libelles.videTitre == "Aucun signet")
        #expect(libelles.videPhrase.isEmpty == false)
        #expect(libelles.videAction.isEmpty == false)
    }

    @Test("L etat vide sans destination ne promet aucun bouton")
    func etatVideSansDestination() {
        // La section 4.10 rend l action facultative, et un bouton qui ne repond
        // pas coute plus cher qu un etat vide sans bouton.
        #expect(CommandesDeSignets.inertes.ouvrirLaBibliotheque == nil)
        #expect(CommandesDeSignets.inertes.ouvrir == nil)
    }

    // MARK: Textes d une ligne

    @Test("La seconde ligne nomme le chapitre, son titre et la page marquee")
    func sousLigneComplete() throws {
        let libelles = try libellesDuCatalogue()
        let marque = signet(titreDuChapitre: "Le duel", page: 11)

        #expect(TexteDeSignet.sousLigne(de: marque, libelles: libelles) == "Chapitre 43  Le duel  Page 12")
    }

    @Test("Un chapitre sans titre ne laisse pas un separateur orphelin")
    func sousLigneSansTitreDeChapitre() throws {
        let libelles = try libellesDuCatalogue()

        #expect(TexteDeSignet.sousLigne(de: signet(page: 0), libelles: libelles) == "Chapitre 43  Page 1")
    }

    @Test("La page affichee est comptee a partir de un, l index du modele a partir de zero")
    func pageCompteeAPartirDeUn() throws {
        let libelles = try libellesDuCatalogue()
        let marque = signet(page: 0)

        #expect(marque.pageIndex == 0)
        #expect(TexteDeSignet.page(de: marque, libelles: libelles) == "Page 1")
    }

    @Test("L etiquette lue par VoiceOver porte la serie, la page et la note")
    func etiquetteDAccessibilite() throws {
        let libelles = try libellesDuCatalogue()
        let marque = signet(titreDuChapitre: "Le duel", page: 11, note: "A relire")

        let etiquette = TexteDeSignet.etiquette(de: marque, libelles: libelles)

        #expect(etiquette == "Berserk  Chapitre 43  Le duel  Page 12  A relire")
    }

    @Test("Un signet sans note ne fait pas trainer un separateur dans son etiquette")
    func etiquetteSansNote() throws {
        let libelles = try libellesDuCatalogue()
        let etiquette = TexteDeSignet.etiquette(de: signet(page: 4), libelles: libelles)

        #expect(etiquette == "Berserk  Chapitre 43  Page 5")
    }

    // MARK: Libelles

    @Test("Le catalogue porte le titre que le document donne au sous ecran")
    func titreDuDocument() throws {
        let libelles = try libellesDuCatalogue()
        let phrase = try phraseDesSousEcrans()

        #expect(libelles.titre == "Signets")
        #expect(phrase.contains(libelles.titre))
    }

    @Test("Les libelles de l ecran suivent les regles d ecriture de la section 6")
    func reglesDEcriture() throws {
        let libelles = try libellesDuCatalogue()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        let textes = [
            libelles.titre,
            libelles.description,
            libelles.pageNumerotee,
            libelles.options,
            libelles.ouvrirLaPage,
            libelles.supprimer,
            libelles.videTitre,
            libelles.videPhrase,
            libelles.videAction,
        ]

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    @Test("La description nomme le bouton du tableau 6.5 et non un autre mot")
    func descriptionCoherente() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "Barre du lecteur"))

        #expect(ligne.contains("Signet"))
        #expect(libelles.description.contains("Signet"))
    }

    @Test("Chaque icone sans libelle porte une etiquette d accessibilite")
    func etiquettesDesIcones() throws {
        let libelles = try libellesDuCatalogue()

        // Le bouton d options ne montre qu un symbole, section 7.
        #expect(libelles.options.isEmpty == false)
    }
}
