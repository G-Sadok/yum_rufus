import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Banniere du mode incognito et ecran de verrouillage, section 11 du cahier de
// developpement.
//
// DESIGN-SPEC.md ne dessine ni l une ni l autre. Il n en nomme que les glyphes,
// au tableau 1.10. Cette suite verifie donc deux choses : que rien n a ete
// invente, chaque valeur venant d un jeton que le document pose ailleurs, et que
// les textes du catalogue suivent les regles d ecriture de la section 6.
//
// La permanence de la banniere est verifiee dans `Core`, ou elle se decide.
// Ici, on verifie que la vue n offre aucun moyen de la contredire.
//

/// Materiel partage par la suite de la confidentialite.
enum MaterielDeConfidentialite {
    /// Valeur d une cle du catalogue, ou echec du test si elle manque.
    static func valeur(_ catalogue: [String: String], _ cle: String) throws -> String {
        try #require(catalogue[cle], "Le catalogue de chaines ne porte pas \(cle)")
    }

    /// Libelles de la banniere, pris dans le catalogue de l application.
    static func libellesDIncognito() throws -> LibellesDIncognito {
        let catalogue = try CatalogueDeChaines.charger()

        return try LibellesDIncognito(
            titre: valeur(catalogue, "reglages.ligne.confidentialite.incognito"),
            phrase: valeur(catalogue, "incognito.banniere.phrase"),
            etiquetteDAccessibilite: valeur(catalogue, "incognito.banniere.etiquette")
        )
    }

    /// Libelles de l ecran de verrouillage, pris dans le catalogue.
    static func libellesDeVerrouillage() throws -> LibellesDeVerrouillage {
        let catalogue = try CatalogueDeChaines.charger()

        return try LibellesDeVerrouillage(
            titre: valeur(catalogue, "reglages.ligne.confidentialite.verrouillageDeLApp"),
            phrase: valeur(catalogue, "verrouillage.phrase"),
            deverrouiller: valeur(catalogue, "verrouillage.deverrouiller"),
            echecTitre: valeur(catalogue, "verrouillage.echec.titre"),
            echecPhrase: valeur(catalogue, "verrouillage.echec.phrase"),
            aucunMoyenPhrase: valeur(catalogue, "verrouillage.aucunMoyen.phrase"),
            raisonDuSysteme: valeur(catalogue, "verrouillage.raison")
        )
    }

    /// Session incognito en cours, pour composer une banniere.
    static var sessionEnCours: SessionIncognito {
        .demarree(le: Date(timeIntervalSince1970: 1_700_000_000))
    }

    /// Vrai quand le texte respecte les regles d ecriture de la section 6.
    static func suitLesReglesDEcriture(_ texte: String) -> Bool {
        let tiretCadratin = "\u{2014}"

        return texte.isEmpty == false
            && texte.contains("!") == false
            && texte.contains(tiretCadratin) == false
    }
}

/// Le gabarit, repris et non invente.
struct GabaritDeLaConfidentialiteTests {
    @Test("La banniere du mode incognito reprend le gabarit de la section 5.5")
    func laBanniereReprendLeGabaritDuDocument() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "banniere en haut de colonne, rayon 12")
        )

        #expect(ligne.contains("contour 1 px `warning`"))
        #expect(ligne.contains("titre en `headline`"))
        #expect(ligne.contains("phrase en `footnote`"))

        #expect(Jetons.BanniereDIncognito.rayon == Jetons.BanniereDeReglages.rayon)
        #expect(
            Jetons.BanniereDIncognito.epaisseurDuContour
                == Jetons.BanniereDeReglages.epaisseurDuContour
        )
        #expect(Jetons.BanniereDIncognito.titre == Jetons.BanniereDeReglages.titre)
        #expect(Jetons.BanniereDIncognito.phrase == Jetons.BanniereDeReglages.phrase)
    }

    @Test("Chaque mesure de la banniere vient d une echelle du document")
    func lesMesuresViennentDesEchelles() {
        #expect(Jetons.Rayon.echelle.contains(Jetons.BanniereDIncognito.rayon))
        #expect(Jetons.Espace.echelle.contains(Jetons.BanniereDIncognito.remplissage))
        #expect(Jetons.Espace.echelle.contains(Jetons.BanniereDIncognito.ecartInterne))
        #expect(Jetons.Espace.echelle.contains(Jetons.BanniereDIncognito.marge))
        #expect(Jetons.BanniereDIncognito.tailleDuGlyphe == Jetons.Icone.tailleEnBarreDOutils)
    }

    @Test("Les deux glyphes sont ceux du tableau 1.10")
    func lesGlyphesSontCeuxDuDocument() throws {
        let incognito = try #require(try SpecificationDeDesign.ligne(contenant: "| Incognito |"))
        let verrou = try #require(try SpecificationDeDesign.ligne(contenant: "| Verrouillage |"))

        #expect(incognito.contains(Jetons.Icone.incognito))
        #expect(verrou.contains(Jetons.Icone.verrouillage))
        #expect(Jetons.EcranDeVerrouillage.glyphe == Jetons.Icone.verrouillage)
        #expect(Jetons.EcranDeVerrouillage.glypheDEchec == Jetons.Icone.erreurDeContenu)
    }
}

/// Ce que la banniere dit, et quand elle le dit.
struct BanniereDIncognitoDansLaVueTests {
    @Test("La banniere parait des qu une session court")
    func laBanniereParaitAvecLaSession() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()

        let banniere = try #require(
            TexteDeLaBanniereDIncognito.banniere(
                pour: MaterielDeConfidentialite.sessionEnCours,
                libelles: libelles
            )
        )

        #expect(banniere.titre == libelles.titre)
        #expect(banniere.phrase == libelles.phrase)
    }

    @Test("Hors session, aucune banniere n est composee")
    func horsSessionAucuneBanniere() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()

        #expect(
            TexteDeLaBanniereDIncognito.banniere(pour: .inactive, libelles: libelles) == nil
        )
    }

    @Test("La banniere ne se ferme jamais, quel que soit l evenement")
    func laBanniereNeSeFermeJamais() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()
        var session = MaterielDeConfidentialite.sessionEnCours

        for evenement in EvenementDeSession.allCases {
            session = session.apres(evenement)

            let banniere = try #require(
                TexteDeLaBanniereDIncognito.banniere(pour: session, libelles: libelles),
                "La banniere a disparu apres \(evenement)"
            )

            #expect(banniere.peutEtreFermee == false)
        }
    }

    @Test("Le titre de la banniere est le libelle de la ligne de reglages")
    func leTitreEstCeluiDesReglages() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()

        #expect(libelles.titre == "Incognito")
    }

    @Test("La phrase de la banniere reprend les mots du tableau 6.8")
    func laPhraseReprendLesMotsDuDocument() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()
        let description = try #require(
            try SpecificationDeDesign.ligne(contenant: "Sous la carte Confidentialite")
        )

        #expect(description.contains("l activite de lecture n est pas enregistree"))
        #expect(libelles.phrase.contains("activite de lecture n est pas enregistree"))
    }

    @Test("Les textes de la banniere suivent les regles d ecriture de la section 6")
    func lesTextesDeLaBanniereSuiventLesRegles() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()

        for texte in [libelles.titre, libelles.phrase, libelles.etiquetteDAccessibilite] {
            #expect(MaterielDeConfidentialite.suitLesReglesDEcriture(texte), "\(texte)")
        }
    }

    @Test("L etiquette d accessibilite porte l information du glyphe")
    func lEtiquettePorteLInformation() throws {
        let libelles = try MaterielDeConfidentialite.libellesDIncognito()

        // Section 7 : aucune information transmise par la couleur ni par le seul
        // glyphe. L etiquette dit le mode et ce qu il change.
        #expect(libelles.etiquetteDAccessibilite.contains("incognito"))
        #expect(libelles.etiquetteDAccessibilite.contains("enregistree"))
    }
}

/// Les etats de l ecran de verrouillage.
struct EcranDeVerrouillageDansLaVueTests {
    /// Etat de contenu compose pour cet etat de verrou.
    private func contenu(
        _ etat: EtatDeLEcranDeVerrouillage,
        libelles: LibellesDeVerrouillage
    ) -> EtatDeContenu {
        ContenuDeLEcranDeVerrouillage.etatDeContenu(
            pour: etat,
            libelles: libelles,
            deverrouiller: {}
        )
    }

    @Test("L attente est un etat vide, qui invite a agir")
    func lAttenteEstUnEtatVide() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()

        guard case let .vide(symbole, titre, phrase, action) = contenu(.attente, libelles: libelles)
        else {
            Issue.record("L attente doit se rendre en etat vide, section 4.10")

            return
        }

        #expect(symbole == Jetons.Icone.verrouillage)
        #expect(titre == libelles.titre)
        #expect(phrase == libelles.phrase)
        #expect(action?.libelle == libelles.deverrouiller)
    }

    @Test("Un echec d identification nomme sa cause et porte sa sortie")
    func lEchecNommeSaCause() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()
        let etat = contenu(.echec(.echecDeLAuthentification), libelles: libelles)

        guard case let .erreur(titre, phrase, reessayer, repli) = etat else {
            Issue.record("Un echec doit se rendre en etat d erreur, tableau 6.4")

            return
        }

        #expect(titre == libelles.echecTitre)
        #expect(phrase == libelles.echecPhrase)
        #expect(reessayer.libelle == libelles.deverrouiller)
        #expect(repli == nil)
    }

    @Test("Un appareil sans biometrie ni code dit comment en ajouter un")
    func lAppareilSansMoyenDitLaSortie() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()
        let etat = contenu(.echec(.aucunMoyenDisponible), libelles: libelles)

        guard case let .erreur(_, phrase, _, _) = etat else {
            Issue.record("L absence de moyen doit se rendre en etat d erreur")

            return
        }

        #expect(phrase == libelles.aucunMoyenPhrase)
        #expect(phrase.contains("reglages du systeme"))
    }

    @Test("Un renoncement ne produit aucun message")
    func leRenoncementNeDitRien() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()
        let etat = contenu(.echec(.annuleParLUtilisateur), libelles: libelles)

        // La section 6 interdit d insister. Un message d echec apres un geste
        // volontaire se lirait comme une insistance : l ecran revient a son
        // attente.
        guard case .vide = etat else {
            Issue.record("Un renoncement ne doit pas produire d etat d erreur")

            return
        }
    }

    @Test("L ecran ne parait que lorsque le verrou est ferme")
    func lEcranNeParaitQueVerrouille() {
        #expect(EtatDeVerrouillage.verrouille.demandeUneAuthentification)
        #expect(EtatDeVerrouillage.ouvert.demandeUneAuthentification == false)
    }

    @Test("Le titre de l ecran est le libelle de la ligne de reglages")
    func leTitreEstCeluiDesReglages() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()

        #expect(libelles.titre == "Verrouillage de l app")
    }

    @Test("Les textes de l ecran suivent les regles d ecriture de la section 6")
    func lesTextesDeLEcranSuiventLesRegles() throws {
        let libelles = try MaterielDeConfidentialite.libellesDeVerrouillage()

        let textes = [
            libelles.titre,
            libelles.phrase,
            libelles.deverrouiller,
            libelles.echecTitre,
            libelles.echecPhrase,
            libelles.aucunMoyenPhrase,
            libelles.raisonDuSysteme,
        ]

        for texte in textes {
            #expect(MaterielDeConfidentialite.suitLesReglesDEcriture(texte), "\(texte)")
        }
    }
}
