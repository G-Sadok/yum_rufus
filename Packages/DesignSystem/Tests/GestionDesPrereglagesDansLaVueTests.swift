import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre la gestion des prereglages, sous ecran de la section 5.5 de
// DESIGN-SPEC.md.
//
// Le document fixe deux choses de ce sous ecran, le gabarit colonne 580 et les
// quatre etats. Les deux sont compares a la phrase du document elle meme, et
// non a une copie : une contrainte changee dans DESIGN-SPEC.md qui n arriverait
// pas jusqu au code fait alors virer la suite au rouge.
//

struct GestionDesPrereglagesDansLaVueTests {
    /// Phrase du document qui nomme les sous ecrans a concevoir.
    private func phraseDesSousEcrans() throws -> String {
        try #require(try SpecificationDeDesign.ligne(contenant: "Sous ecrans a concevoir"))
    }

    /// Libelles tels que le catalogue de l application les porte.
    private func libellesDuCatalogue() throws -> LibellesDePrereglages {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDePrereglages(
            titre: catalogue["prereglages.titre"] ?? "",
            enregistrerLActuel: catalogue["prereglages.enregistrerLActuel"] ?? "",
            description: catalogue["prereglages.description"] ?? "",
            options: catalogue["prereglages.options"] ?? "",
            appliquer: catalogue["prereglages.appliquer"] ?? "",
            renommer: catalogue["prereglages.renommer"] ?? "",
            remplacerParLActuel: catalogue["prereglages.remplacerParLActuel"] ?? "",
            supprimer: catalogue["prereglages.supprimer"] ?? "",
            videTitre: catalogue["reglages.aucunPrereglage"] ?? "",
            videPhrase: catalogue["etatVide.prereglages.phrase"] ?? "",
            valeursDeMenu: Self.valeursDeMenu(catalogue)
        )
    }

    /// Libelles de valeur de menu dont le resume d une ligne a besoin.
    ///
    /// Ce sont ceux de l ecran Reglages, sous les memes cles : un prereglage en
    /// `Sepia` doit dire le mot que l utilisateur a choisi au menu Fond du
    /// lecteur, pas une seconde formulation pour la meme valeur.
    private static func valeursDeMenu(_ catalogue: [String: String]) -> [String: String] {
        let brutes = SensDeLecture.allCases.map(\.rawValue)
            + MiseEnPage.allCases.map(\.rawValue)
            + ChoixDeFondDuLecteur.allCases.map(\.rawValue)

        return brutes.reduce(into: [String: String]()) { table, brute in
            table[brute] = catalogue["reglages.valeur.\(brute)"]
        }
    }

    // MARK: Gabarit

    @Test("Le sous ecran emprunte le gabarit colonne de 580 du document")
    func gabaritDuDocument() throws {
        let phrase = try phraseDesSousEcrans()

        #expect(phrase.contains("Gestion des prereglages"))
        #expect(phrase.contains("gabarit colonne 580"))

        #expect(Jetons.Prereglages.largeurDeColonne == 580)
        #expect(Jetons.Prereglages.largeurDeColonne == Jetons.Contenu.largeurDeColonne)
    }

    @Test("Le sous ecran n emprunte aucune mesure hors des sections 4.1, 4.2 et 7")
    func mesuresEmpruntees() {
        #expect(Jetons.Prereglages.rayon == Jetons.CarteDeReglages.rayon)
        #expect(Jetons.Prereglages.hauteurDeLigne == Jetons.LigneDeReglage.hauteurAvecDescription)
        #expect(Jetons.Prereglages.margeLaterale == Jetons.LigneDeReglage.margeLaterale)
        #expect(
            Jetons.Prereglages.encastrementDuSeparateur
                == Jetons.CarteDeReglages.encastrementDuSeparateur
        )
        #expect(Jetons.Espace.echelle.contains(Jetons.Prereglages.ecartApresLeNom))
        #expect(Jetons.Espace.echelle.contains(Jetons.Prereglages.ecartAvantLesOptions))
    }

    @Test("Le bouton d options tient la cible de pointage de la section 7")
    func cibleDuBoutonDOptions() {
        #expect(Jetons.Prereglages.coteDuBoutonDOptions == Jetons.Cible.auDoigt)
        #expect(Jetons.Prereglages.coteDuBoutonDOptions >= Jetons.Cible.auPointeur)
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

        #expect(libelles.videTitre == "Aucun prereglage")
        #expect(libelles.videPhrase.isEmpty == false)

        // L etat vide de la section 4.10 porte une action : une liste vide est
        // une invitation a agir, pas un constat.
        #expect(libelles.enregistrerLActuel.isEmpty == false)
    }

    @Test("Le titre de l etat vide est celui que la section 5.5 pose deja")
    func titreDeLEtatVideRepris() throws {
        let libelles = try libellesDuCatalogue()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "installation neuve"))

        // Le meme mot pour la meme chose du debut a la fin d un parcours,
        // regle d ecriture de la section 6.
        #expect(ligne.contains(libelles.videTitre))
    }

    // MARK: Resume d une ligne

    @Test("Le resume nomme le sens applique, la mise en page et la teinte")
    func resumeDUneLigne() throws {
        let libelles = try libellesDuCatalogue()
        let contenu = ContenuDePrereglage(
            sens: .gaucheDroite,
            miseEnPage: .doublePage,
            fond: .sepia
        )

        let resume = TexteDePrereglage.resume(de: contenu, libelles: libelles)

        #expect(resume == "Gauche a droite  Double page  Sepia")
    }

    @Test("Le resume d un prereglage vertical dit Vertical, pas le sens du menu")
    func resumeDUnPrereglageVertical() throws {
        let libelles = try libellesDuCatalogue()
        let contenu = ContenuDePrereglage(sens: .droiteGauche, miseEnPage: .continuVertical)

        let resume = TexteDePrereglage.resume(de: contenu, libelles: libelles)

        // Le menu garde un sens horizontal, le moteur lit de haut en bas.
        // Ecrire le sens du menu tromperait sur ce que le prereglage fait.
        #expect(resume.hasPrefix("Vertical"))
        #expect(resume.contains("Droite a gauche") == false)
    }

    @Test("Le catalogue nomme toutes les valeurs qu un resume peut porter")
    func valeursDeMenuCompletes() throws {
        let libelles = try libellesDuCatalogue()

        for sens in SensDeLecture.allCases {
            #expect(libelles.valeur(sens.rawValue) == sens.valeurDuDocument, "\(sens.rawValue)")
        }

        for miseEnPage in MiseEnPage.allCases {
            #expect(
                libelles.valeur(miseEnPage.rawValue) == miseEnPage.valeurDuDocument,
                "\(miseEnPage.rawValue)"
            )
        }

        for fond in ChoixDeFondDuLecteur.allCases {
            #expect(libelles.valeur(fond.rawValue) == fond.valeurDuDocument, "\(fond.rawValue)")
        }
    }

    @Test("Une colonne abimee donne une ligne sans resume, pas un ecran en erreur")
    func ligneSansResume() {
        let abime = PrereglageLecture(nom: "Abime", donneesReglages: Data([0xAA, 0xBB]))
        let affiche = PrereglageAffiche(abime)

        #expect(affiche.nom == "Abime")
        #expect(affiche.contenu == nil)
        #expect(affiche.id == abime.id)
    }

    // MARK: Libelles

    @Test("Le catalogue porte les libelles nommes par le cahier de developpement")
    func libellesDuCahier() throws {
        let libelles = try libellesDuCatalogue()

        #expect(libelles.titre == "Prereglages de lecture")
        #expect(libelles.enregistrerLActuel == "Enregistrer l actuel comme prereglage")
        #expect(
            libelles.description == "Un prereglage capture tous les reglages de lecture ci"
                + " dessous, le sens, les filtres, la teinte et les traitements IA, puis les"
                + " reapplique en une seule action."
        )
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
            libelles.enregistrerLActuel,
            libelles.description,
            libelles.options,
            libelles.appliquer,
            libelles.renommer,
            libelles.remplacerParLActuel,
            libelles.supprimer,
            libelles.videTitre,
            libelles.videPhrase,
        ]

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    @Test("Chaque icone sans libelle porte une etiquette d accessibilite")
    func etiquettesDAccessibilite() throws {
        let libelles = try libellesDuCatalogue()

        // Le bouton d options ne montre qu un symbole, section 7.
        #expect(libelles.options.isEmpty == false)
    }
}
