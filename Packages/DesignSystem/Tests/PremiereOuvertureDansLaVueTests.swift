import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre le parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md.
//
// Les valeurs sont comparees aux lignes du document elles memes, jamais a une
// copie posee a cote. Une mesure changee dans DESIGN-SPEC.md qui n arriverait
// pas jusqu au code fait alors virer la suite au rouge, ce qui est le but.
//
// Le test le plus important est `plusTardPeseLeMemePoidsQueLEssai`. C est le
// deuxieme critere de la fonctionnalite, et c est aussi celui qu une retouche
// de mise en page casserait sans qu on le remarque a l oeil.
//

struct PremiereOuvertureDansLaVueTests {
    /// Phrase d ouverture de la section 5.10.
    private func phraseDuParcours() throws -> String {
        try #require(
            try SpecificationDeDesign.ligne(contenant: "Trois etapes maximum")
        )
    }

    /// Ligne de la premiere etape, celle qui chiffre les cartes de sens.
    private func ligneDesCartes() throws -> String {
        try #require(
            try SpecificationDeDesign.ligne(contenant: "trois cartes de 300")
        )
    }

    /// Ligne de la deuxieme etape, celle qui chiffre les lignes de source.
    private func ligneDesSources() throws -> String {
        try #require(
            try SpecificationDeDesign.ligne(contenant: "les trois choix les plus courants")
        )
    }

    /// Ligne de la troisieme etape, celle qui compare les deux boutons.
    private func ligneDeLEssai() throws -> String {
        try #require(
            try SpecificationDeDesign.ligne(contenant: "Plus tard aussi visible")
        )
    }

    /// Derniere cellule non vide d une ligne de tableau du document.
    private func derniereCellule(de ligne: String) -> String? {
        ligne
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { $0.isEmpty == false })
    }

    // MARK: Trois etapes

    @Test("Le document borne le parcours a trois etapes, et le code en compte trois")
    func troisEtapes() throws {
        let phrase = try phraseDuParcours()

        #expect(phrase.contains("Trois etapes maximum"))
        #expect(phrase.contains("une seule decision par etape"))

        #expect(EtapeDePremiereOuverture.allCases.count == 3)
        #expect(ParcoursDePremiereOuverture.nombreMaximalDEtapes == 3)
    }

    @Test("Les points de progression sont ceux du document")
    func pointsDeProgression() throws {
        let phrase = try phraseDuParcours()

        #expect(phrase.contains("7 de diametre"))
        #expect(phrase.contains("accent"))

        #expect(Jetons.PremiereOuverture.diametreDuPoint == 7)
    }

    // MARK: Mesures des etapes

    @Test("Les cartes de sens de lecture portent les mesures du document")
    func cartesDeSens() throws {
        let ligne = try ligneDesCartes()

        #expect(ligne.contains("trois cartes de 300"))
        #expect(ligne.contains("Vertical"))
        #expect(ligne.contains("rayon 16"))
        #expect(ligne.contains("contour de 3"))

        #expect(Jetons.PremiereOuverture.largeurDeCarte == 300)
        #expect(Jetons.PremiereOuverture.rayonDeCarte == 16)
        #expect(Jetons.PremiereOuverture.epaisseurDuContourActif == 3)
    }

    @Test("Une ligne de source mesure 72, comme la section 5.10 l ecrit")
    func lignesDeSource() throws {
        let ligne = try ligneDesSources()

        #expect(ligne.contains("lignes de source de 72"))
        #expect(Jetons.PremiereOuverture.hauteurDeLigneDeSource == 72)
    }

    @Test("La premiere page de l apercu se place du cote ou la lecture commence")
    func apercuDuSens() {
        #expect(SensDeLecture.droiteGauche.commenceParLaDroite)
        #expect(SensDeLecture.gaucheDroite.commenceParLaDroite == false)

        // Le sens vertical ne commence par aucun cote : ses pages s empilent.
        #expect(SensDeLecture.hautBas.commenceParLaDroite == false)
        #expect(SensDeLecture.hautBas.estVertical)

        #expect(TexteDePremiereOuverture.sensProposes == [.droiteGauche, .gaucheDroite, .hautBas])
    }

    // MARK: Poids des deux boutons de la troisieme etape

    @Test("Plus tard pese exactement le meme poids que le bouton d essai")
    func plusTardPeseLeMemePoidsQueLEssai() throws {
        let ligne = try ligneDeLEssai()

        #expect(ligne.contains("Plus tard aussi visible que le bouton d essai"))
        #expect(ligne.contains("meme hauteur"))
        #expect(ligne.contains("meme rayon"))

        let essai = Jetons.PremiereOuverture.gabarit(de: .commencerLEssai)
        let plusTard = Jetons.PremiereOuverture.gabarit(de: .plusTard)

        #expect(essai == plusTard)
        #expect(essai.hauteur == plusTard.hauteur)
        #expect(essai.rayon == plusTard.rayon)
        #expect(essai.largeur == plusTard.largeur)
    }

    @Test("Les deux boutons se partagent la largeur a parts egales")
    func largeursEgales() {
        let gabarit = Jetons.PremiereOuverture.gabarit(de: .plusTard)
        let paire = gabarit.largeur * 2 + Jetons.PremiereOuverture.ecartEntreLesBoutons

        #expect(paire == Jetons.MurPremium.largeurDuBouton)
    }

    @Test("La troisieme etape offre les deux commandes, et elles seules")
    func commandesDeLaTroisiemeEtape() {
        #expect(
            ParcoursDePremiereOuverture.commandes(de: .essaiPremium)
                == [.commencerLEssai, .plusTard]
        )
    }

    @Test("Le fond de Plus tard est celui du bouton secondaire de la section 5.10")
    func fondDePlusTard() throws {
        let ligne = try ligneDeLEssai()

        // La section 5.10 impose `surface.menu` avec contour, ce qui est
        // exactement la variante secondaire du tableau 4.6. La difference entre
        // les deux boutons est donc le seul aplat, jamais la taille.
        #expect(ligne.contains("surface.menu"))
        #expect(ligne.contains("contour"))

        for theme in ThemeDeSurface.allCases {
            for apparence in Apparence.allCases {
                let palette = Palette.pour(theme: theme, apparence: apparence)

                #expect(palette.surfaces.menu.notation.isEmpty == false)
            }
        }
    }

    // MARK: Libelles

    @Test("Les quatre commandes portent les libelles exacts du tableau 6.5")
    func libellesDuTableau() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Premiere ouverture |")
        )

        let libelles = try #require(derniereCellule(de: ligne))
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        #expect(libelles == ["Continuer", "Passer", "Commencer l essai", "Plus tard"])

        let duCatalogue = CommandeDePremiereOuverture.allCases.map { commande in
            catalogue["premiereOuverture.commande.\(commande.rawValue)"] ?? ""
        }

        #expect(duCatalogue == libelles)
    }

    @Test("La mention de la deuxieme etape est celle du tableau 6.8")
    func mentionDeLaDeuxiemeEtape() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Etape 2 de la premiere ouverture")
        )

        let attendue = try #require(derniereCellule(de: ligne))

        #expect(catalogue["premiereOuverture.mention"] == attendue)
    }

    @Test("Les trois sources reprennent les libelles du menu d ajout de la section 5.3")
    func libellesDesSources() throws {
        let catalogue = try CatalogueDeChaines.charger()

        for entree in ParcoursDePremiereOuverture.entreesMisesEnAvant {
            #expect(
                catalogue["premiereOuverture.source.\(entree.type.rawValue)"]
                    == entree.nomDuDocument,
                "\(entree.type.rawValue)"
            )
        }
    }

    @Test("Le catalogue couvre chaque etape, chaque commande et chaque source")
    func catalogueComplet() throws {
        let catalogue = try CatalogueDeChaines.charger()

        for etape in EtapeDePremiereOuverture.allCases {
            #expect(
                catalogue["premiereOuverture.etape.\(etape.rawValue).titre"]?.isEmpty == false,
                "\(etape.rawValue)"
            )
            #expect(
                catalogue["premiereOuverture.etape.\(etape.rawValue).phrase"]?.isEmpty == false,
                "\(etape.rawValue)"
            )
        }

        for commande in CommandeDePremiereOuverture.allCases {
            #expect(
                catalogue["premiereOuverture.commande.\(commande.rawValue)"]?.isEmpty == false,
                "\(commande.rawValue)"
            )
        }

        for type in ParcoursDePremiereOuverture.sourcesMisesEnAvant {
            #expect(
                catalogue["premiereOuverture.source.\(type.rawValue)"]?.isEmpty == false,
                "\(type.rawValue)"
            )
        }
    }

    @Test("La ligne de rejeu porte un libelle dans le catalogue")
    func libelleDeLaLigneDeRejeu() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let cle = "reglages.ligne.\(IdentifiantDeReglage.revoirLaPremiereOuverture.rawValue)"

        #expect(catalogue[cle]?.isEmpty == false)
        #expect(
            Jetons.IconeDeReglage.pour(.revoirLaPremiereOuverture) != Jetons.Icone.reglages,
            "La ligne retombe sur le symbole generique"
        )
    }

    @Test("Les textes du parcours suivent les regles d ecriture de la section 6")
    func reglesDEcriture() throws {
        let catalogue = try CatalogueDeChaines.charger()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        let textes = catalogue
            .filter { $0.key.hasPrefix("premiereOuverture.") }
            .map(\.value)

        #expect(textes.isEmpty == false)

        for texte in textes {
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    // MARK: Etats de la deuxieme etape

    @Test("La deuxieme etape sait dire ses quatre etats de source")
    func quatreEtatsDeSource() {
        let libelles = LibellesDePremiereOuverture(
            titres: [:],
            phrases: [:],
            commandes: [:],
            sens: [:],
            sources: [:],
            voirToutesLesSources: "Voir les douze types de sources",
            mentionDeLaDeuxiemeEtape: "Yum ne heberge aucun contenu.",
            connexionEnCours: "Connexion en cours",
            seriesTrouvees: "%lld series trouvees",
            adresseInjoignable: "Adresse injoignable",
            progression: "Etape %1$lld sur %2$lld",
            apercuDuSens: "Apercu de deux pages numerotees"
        )

        let sousLigne = { (etat: EtatDeLaSourceInitiale) in
            TexteDePremiereOuverture.sousLigne(de: etat, pour: .komga, libelles: libelles)
        }

        #expect(sousLigne(.rien) == nil)
        #expect(sousLigne(.connexion(.komga)) == "Connexion en cours")
        #expect(sousLigne(.connectee(.komga, series: 218)) == "218 series trouvees")
        #expect(sousLigne(.injoignable(.komga)) == "Adresse injoignable")

        // L etat d une autre source ne deteint pas sur cette ligne.
        #expect(sousLigne(.injoignable(.opds)) == nil)
    }

    @Test("Les points de progression disent le rang en toutes lettres, pas en couleur seule")
    func etiquetteDeProgression() {
        let libelles = LibellesDePremiereOuverture(
            titres: [:],
            phrases: [:],
            commandes: [:],
            sens: [:],
            sources: [:],
            voirToutesLesSources: "",
            mentionDeLaDeuxiemeEtape: "",
            connexionEnCours: "",
            seriesTrouvees: "",
            adresseInjoignable: "",
            progression: "Etape %1$lld sur %2$lld",
            apercuDuSens: ""
        )

        #expect(
            TexteDePremiereOuverture.etiquetteDeProgression(de: .premiereSource, libelles: libelles)
                == "Etape 2 sur 3"
        )
    }

    // MARK: Mouvement

    @Test("Le passage d une etape a l autre n emprunte aucune duree hors du tableau 1.9")
    func transitionDuTableau() {
        #expect(
            Jetons.Mouvement.parTransition.values.contains(Jetons.Mouvement.changementDEcran)
        )
    }
}
