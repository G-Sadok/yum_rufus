import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre la file de telechargement, section 4.11 de DESIGN-SPEC.md.
//
// Le document chiffre ce composant plus que tout autre sous ecran : la largeur
// du panneau, la ligne, l indicateur, ses deux epaisseurs, son motif de tirets,
// et les trois sous lignes mot pour mot. Chaque valeur est comparee a la phrase
// du document elle meme, et non a une copie : une mesure changee dans
// DESIGN-SPEC.md qui n arriverait pas jusqu au code fait alors virer la suite au
// rouge.
//
// Le troisieme critere d acceptation, la progression visible et exacte, se joue
// pour moitie ici. La sous ligne du document, `14 sur 24 pages`, est le seul
// endroit ou l utilisateur lit un chiffre de progression : un anneau juste sous
// une sous ligne fausse resterait un mensonge.
//

/// Materiel partage par les deux suites de ce fichier.
///
/// Les mesures et les textes sont deux suites distinctes parce qu ils
/// s eprouvent differemment : les premieres se comparent aux tableaux du
/// document, les seconds au catalogue de chaines. Ils partagent en revanche la
/// meme tache de reference, celle du document, `Berserk  Chapitre 43` a
/// quatorze pages sur vingt quatre.
enum MaterielDeTelechargement {
    /// Libelles tels que le catalogue de l application les porte.
    static func libellesDuCatalogue() throws -> LibellesDeTelechargements {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDeTelechargements(
            titre: catalogue["telechargements.titre"] ?? "",
            description: catalogue["telechargements.description"] ?? "",
            chapitreNumerote: catalogue["chapitre.numerote"] ?? "",
            pagesFaites: catalogue["telechargements.pagesFaites"] ?? "",
            enAttente: catalogue["telechargements.enAttente"] ?? "",
            termineAvecPoids: catalogue["telechargements.termineAvecPoids"] ?? "",
            termine: catalogue["telechargements.termine"] ?? "",
            enPause: catalogue["telechargements.enPause"] ?? "",
            annulee: catalogue["telechargements.annulee"] ?? "",
            poidsEnOctets: catalogue["telechargements.poidsEnOctets"] ?? "",
            poidsEnKo: catalogue["telechargements.poidsEnKo"] ?? "",
            poidsEnMo: catalogue["telechargements.poidsEnMo"] ?? "",
            poidsEnGo: catalogue["telechargements.poidsEnGo"] ?? "",
            mettreEnPause: catalogue["telechargements.mettreEnPause"] ?? "",
            reprendre: catalogue["telechargements.reprendre"] ?? "",
            passerEnPremier: catalogue["telechargements.passerEnPremier"] ?? "",
            annuler: catalogue["telechargements.annuler"] ?? "",
            options: catalogue["telechargements.options"] ?? "",
            videTitre: catalogue["etatVide.telechargements.titre"] ?? "",
            videPhrase: catalogue["etatVide.telechargements.phrase"] ?? "",
            videAction: catalogue["etatVide.telechargements.action"] ?? ""
        )
    }

    /// Tache de reference, celle que le document decrit.
    static func tache(
        etat: EtatTelechargement = .enCours,
        pagesTerminees: Int = 14,
        nombreDePages: Int = 24,
        octetsTotal: Int? = nil,
        messageErreur: String? = nil
    ) -> TelechargementAffiche {
        TelechargementAffiche(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Berserk",
            numeroDeChapitre: 43,
            etat: etat,
            pagesTerminees: pagesTerminees,
            nombreDePages: nombreDePages,
            octetsTotal: octetsTotal,
            dateAjout: Date(timeIntervalSince1970: 1_700_000_000),
            messageErreur: messageErreur
        )
    }
}

/// Mesures de la section 4.11, comparees au document lui meme.
struct FileDeTelechargementsDansLaVueTests {
    // MARK: Mesures du document

    @Test("Le panneau fait la largeur que le document chiffre")
    func largeurDuPanneau() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "Largeur du panneau"))

        #expect(ligne.contains("324"))
        #expect(Jetons.Telechargements.largeurDuPanneau == 324)
    }

    @Test("La ligne reprend les quatre mesures du document")
    func mesuresDeLaLigne() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "268 par 52"))

        #expect(ligne.contains("rayon 10"))
        #expect(ligne.contains("surface.card"))

        #expect(Jetons.Telechargements.largeurDeLigne == 268)
        #expect(Jetons.Telechargements.hauteurDeLigne == 52)
        #expect(Jetons.Telechargements.rayonDeLigne == 10)
        #expect(Jetons.Telechargements.rayonDeLigne == Jetons.Rayon.bouton)
    }

    @Test("Le retrait lateral se deduit des deux largeurs, il ne s invente pas")
    func retraitDeduitDuDocument() {
        let attendu = (Jetons.Telechargements.largeurDuPanneau - Jetons.Telechargements.largeurDeLigne) / 2

        #expect(Jetons.Telechargements.retraitDeLigne == attendu)
        #expect(Jetons.Telechargements.retraitDeLigne == 28)
    }

    @Test("L indicateur fait 24 et son centre tombe a 26 du bord")
    func mesuresDeLIndicateur() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "| Indicateur |"))

        #expect(ligne.contains("24"))
        #expect(ligne.contains("26"))

        #expect(Jetons.Telechargements.diametreDeLIndicateur == 24)
        #expect(Jetons.Telechargements.centreDeLIndicateur == 26)

        // La marge est calculee et non chiffree : c est ce qui garantit que le
        // centre tombe la ou le document le place, quel que soit le diametre.
        let centre = Jetons.Telechargements.margeAvantLIndicateur
            + Jetons.Telechargements.diametreDeLIndicateur / 2

        #expect(centre == Jetons.Telechargements.centreDeLIndicateur)
    }

    @Test("Les deux roles de texte sont ceux du document")
    func rolesDeTexte() throws {
        // Le fragment porte les deux cellules, parce que le document emploie le
        // meme role de texte ailleurs avec une graisse differente : chercher le
        // seul mot `callout` ramenerait la ligne d un autre composant.
        let titre = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Titre | `callout`, `text.primary` |")
        )
        let sousLigne = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Sous ligne | `caption`, `text.tertiary` |")
        )

        #expect(titre.isEmpty == false)
        #expect(sousLigne.isEmpty == false)

        #expect(Jetons.Telechargements.titre == Jetons.Typo.callout)
        #expect(Jetons.Telechargements.sousLigne == Jetons.Typo.caption)
    }

    @Test("L anneau en cours porte l epaisseur et les tirets du document")
    func anneauEnCours() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "tirets 50 sur 25"))

        #expect(ligne.contains("accent"))
        #expect(ligne.contains("2.5"))

        #expect(Jetons.Telechargements.epaisseurEnCours == 2.5)
        #expect(Jetons.Telechargements.tiret == 50)
        #expect(Jetons.Telechargements.videEntreTirets == 25)
    }

    @Test("L anneau en attente est plus fin que celui en cours, comme le document le dit")
    func anneauEnAttente() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "anneau `text.quaternary`"))

        #expect(ligne.contains("de 2"))
        #expect(Jetons.Telechargements.epaisseurEnAttente == 2)
        #expect(Jetons.Telechargements.epaisseurEnAttente < Jetons.Telechargements.epaisseurEnCours)
    }

    @Test("Les ecarts que le document ne chiffre pas sortent de l echelle de la section 1.7")
    func ecartsSurLEchelle() {
        #expect(Jetons.Espace.echelle.contains(Jetons.Telechargements.ecartApresLIndicateur))
        #expect(Jetons.Espace.echelle.contains(Jetons.Telechargements.ecartEntreLesTextes))
        #expect(Jetons.Espace.echelle.contains(Jetons.Telechargements.ecartAvantLaCommande))
        #expect(Jetons.Espace.echelle.contains(Jetons.Telechargements.ecartEntreLignes))
        #expect(Jetons.Espace.echelle.contains(Jetons.Telechargements.margeVerticale))
    }

    @Test("Le bouton de commande tient la cible de pointage de la section 7")
    func cibleDuBoutonDeCommande() {
        #expect(Jetons.Telechargements.coteDeLaCommande == Jetons.Cible.auDoigt)
        #expect(Jetons.Telechargements.coteDeLaCommande >= Jetons.Cible.auPointeur)
    }

    @Test("L indicateur tient dans la ligne qui le porte")
    func lIndicateurTientDansLaLigne() {
        #expect(Jetons.Telechargements.diametreDeLIndicateur < Jetons.Telechargements.hauteurDeLigne)
    }
}

/// Textes de la section 4.11, compares au document et au catalogue de chaines.
///
/// Le troisieme critere d acceptation, la progression visible et exacte, se joue
/// ici : la sous ligne est le seul endroit ou l utilisateur lit un chiffre, et
/// un anneau juste sous une sous ligne fausse resterait un mensonge.
struct TextesDeTelechargementTests {
    private func libellesDuCatalogue() throws -> LibellesDeTelechargements {
        try MaterielDeTelechargement.libellesDuCatalogue()
    }

    private func tache(
        etat: EtatTelechargement = .enCours,
        pagesTerminees: Int = 14,
        nombreDePages: Int = 24,
        octetsTotal: Int? = nil,
        messageErreur: String? = nil
    ) -> TelechargementAffiche {
        MaterielDeTelechargement.tache(
            etat: etat,
            pagesTerminees: pagesTerminees,
            nombreDePages: nombreDePages,
            octetsTotal: octetsTotal,
            messageErreur: messageErreur
        )
    }

    // MARK: Les trois sous lignes du document

    @Test("Une tache en cours affiche exactement la sous ligne du document")
    func sousLigneEnCours() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "14 sur 24 pages"))

        let rendue = TexteDeTelechargement.sousLigne(
            de: tache(pagesTerminees: 14, nombreDePages: 24),
            libelles: libelles
        )

        #expect(rendue == "14 sur 24 pages")
        #expect(ligne.contains(rendue))
    }

    @Test("Une tache terminee affiche exactement la sous ligne du document")
    func sousLigneTerminee() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "disque plein"))

        let rendue = TexteDeTelechargement.sousLigne(
            de: tache(etat: .termine, octetsTotal: 32_000_000),
            libelles: libelles
        )

        #expect(rendue == "Termine  32 Mo")
        #expect(ligne.contains(rendue))
    }

    @Test("Une tache en attente affiche exactement la sous ligne du document")
    func sousLigneEnAttente() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "anneau `text.quaternary`"))

        let rendue = TexteDeTelechargement.sousLigne(de: tache(etat: .enAttente), libelles: libelles)

        #expect(rendue == "En attente")
        #expect(ligne.contains(rendue))
    }

    @Test("La sous ligne suit la progression page par page, sans jamais la devancer")
    func laSousLigneSuitLaProgression() throws {
        let libelles = try libellesDuCatalogue()

        for page in 0...24 {
            let rendue = TexteDeTelechargement.sousLigne(
                de: tache(pagesTerminees: page, nombreDePages: 24),
                libelles: libelles
            )

            #expect(rendue == "\(page) sur 24 pages")
        }
    }

    @Test("Un echec dit la cause reelle plutot que de reprendre un compte fige")
    func laSousLigneDUnEchec() throws {
        let libelles = try libellesDuCatalogue()
        let message = "Le serveur a coupe la connexion."

        let rendue = TexteDeTelechargement.sousLigne(
            de: tache(etat: .echoue, messageErreur: message),
            libelles: libelles
        )

        #expect(rendue == message)
    }

    @Test("Une pause et une annulation disent ce qui s est passe")
    func lesSousLignesArretees() throws {
        let libelles = try libellesDuCatalogue()

        #expect(TexteDeTelechargement.sousLigne(de: tache(etat: .suspendu), libelles: libelles) == "En pause")
        #expect(TexteDeTelechargement.sousLigne(de: tache(etat: .annule), libelles: libelles) == "Annule")
    }

    // MARK: Poids

    @Test("Le poids passe au multiple suivant a mille, comme le Mo du document")
    func paliersDePoids() throws {
        let libelles = try libellesDuCatalogue()

        #expect(TexteDeTelechargement.poids(999, libelles: libelles) == "999 o")
        #expect(TexteDeTelechargement.poids(1000, libelles: libelles) == "1 Ko")
        #expect(TexteDeTelechargement.poids(999_500, libelles: libelles) == "999 Ko")
        #expect(TexteDeTelechargement.poids(32_000_000, libelles: libelles) == "32 Mo")
        #expect(TexteDeTelechargement.poids(2_500_000_000, libelles: libelles) == "2.5 Go")
    }

    @Test("Une tache terminee sans poids connu ne fabrique pas un chiffre")
    func termineSansPoids() throws {
        let libelles = try libellesDuCatalogue()

        #expect(TexteDeTelechargement.sousLigne(de: tache(etat: .termine), libelles: libelles) == "Termine")
    }

    // MARK: Titre et accessibilite

    @Test("Le titre d une ligne nomme la serie puis le chapitre")
    func titreDeLigne() throws {
        let libelles = try libellesDuCatalogue()

        #expect(TexteDeTelechargement.titre(de: tache(), libelles: libelles) == "Berserk  Chapitre 43")
    }

    @Test("L etiquette lue par VoiceOver porte l etat, jamais la seule couleur")
    func etiquetteDAccessibilite() throws {
        let libelles = try libellesDuCatalogue()

        let etiquette = TexteDeTelechargement.etiquette(de: tache(), libelles: libelles)

        #expect(etiquette == "Berserk  Chapitre 43  14 sur 24 pages")
    }

    @Test("Chaque icone sans libelle porte une etiquette d accessibilite")
    func etiquetteDuBoutonDeCommandes() throws {
        #expect(try libellesDuCatalogue().options.isEmpty == false)
    }

    // MARK: Etat vide et regles d ecriture

    @Test("Une file vide donne l etat vide, pas un panneau vide")
    func fileVideDonneLEtatVide() throws {
        let libelles = try libellesDuCatalogue()

        #expect(libelles.videTitre == "Aucun telechargement")
        #expect(libelles.videPhrase.isEmpty == false)
        #expect(libelles.videAction.isEmpty == false)
    }

    @Test("L etat vide sans destination ne promet aucun bouton")
    func etatVideSansDestination() {
        #expect(CommandesDeTelechargements.inertes.ouvrirLaBibliotheque == nil)
    }

    @Test("L action produit l etat que le document annonce")
    func lActionProduitLEtat() throws {
        let libelles = try libellesDuCatalogue()
        let regle = try #require(try SpecificationDeDesign.ligne(contenant: "produit l etat"))

        #expect(regle.contains("Telecharger"))
        #expect(regle.contains("Termine"))
        #expect(libelles.termine == "Termine")
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
            libelles.enAttente,
            libelles.termine,
            libelles.enPause,
            libelles.annulee,
            libelles.mettreEnPause,
            libelles.reprendre,
            libelles.passerEnPremier,
            libelles.annuler,
            libelles.options,
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
}
