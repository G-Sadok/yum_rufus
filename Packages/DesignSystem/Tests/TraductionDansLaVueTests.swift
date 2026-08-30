import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Traduction des bulles, section 8 du cahier de developpement.
//
// Cette suite ferme le premier critere de la fonctionnalite la ou il se joue
// reellement : avec la police que le produit pose a l ecran, et non avec une
// mesure de test dont on connaissait la reponse d avance.
//
// La difference n est pas theorique. `MiseEnPageDeBulleTests` prouve que
// l algorithme ne deborde jamais pour une mesure donnee. Il ne prouve rien sur
// la police du systeme, dont la chasse varie d un caractere a l autre et dont
// les lignes presque pleines sont exactement le cas ou un calcul approche se
// trompe. Ici, la mesure employee est celle du rendu, et les assertions portent
// sur les memes bulles que celles que le lecteur affichera.
//
// Le reste de la suite verifie ce que le paquet a le droit de decider : rien
// d invente hors des jetons du document, et aucun mot ecrit dans le code.
//

/// Materiel partage par la suite de la traduction.
enum MaterielDeTraduction {
    /// Mesure reelle, celle que la surimpression emploie.
    static let mesure = MesureDeTexteDuSysteme(graisse: Jetons.Traduction.graisse)

    /// Valeur d une cle du catalogue, ou echec du test si elle manque.
    static func valeur(_ catalogue: [String: String], _ cle: String) throws -> String {
        try #require(catalogue[cle], "Le catalogue de chaines ne porte pas \(cle)")
    }

    /// Libelles de la traduction, pris dans le catalogue de l application.
    static func libelles() throws -> LibellesDeTraduction {
        let catalogue = try CatalogueDeChaines.charger()

        return try LibellesDeTraduction(
            titreDuNuage: valeur(catalogue, "traduction.nuage.titre"),
            phraseDuNuage: valeur(catalogue, "traduction.nuage.phrase"),
            etiquetteDuNuage: valeur(catalogue, "traduction.nuage.etiquette")
        )
    }

    /// Bulle traduite occupant la part demandee de la planche.
    static func traduction(
        largeur: Double,
        hauteur: Double,
        texte: String
    ) throws -> TraductionDeBulle {
        let cadre = try #require(
            CaseDePage(abscisse: 0.1, ordonnee: 0.1, largeur: largeur, hauteur: hauteur)
        )
        let bulle = try #require(BulleDeTexte(cadre: cadre, texte: "original"))

        return TraductionDeBulle(
            bulle: bulle,
            texteTraduit: texte,
            langueCible: .francais,
            moteur: .surLAppareil
        )
    }

    /// Textes de longueurs tres differentes, du cri au monologue.
    ///
    /// Les trois cas qui cassent une mise en page de bulle : le mot seul, la
    /// phrase courante, et le pave qui ne rentrera jamais.
    static let textes = [
        "Non",
        "Je ne te laisserai pas partir seul cette fois",
        String(repeating: "Ce que tu dis ne change rien a ce qui arrive ici. ", count: 8),
    ]
}

/// Le texte traduit ne deborde pas, mesure avec la police du rendu.
struct SurimpressionSansDebordementTests {
    /// Verifie qu une composition tient dans sa bulle, ligne par ligne.
    private func verifier(
        _ composition: TexteDeBulleMisEnPage,
        _ localisation: SourceLocation = #_sourceLocation
    ) {
        for ligne in composition.lignes {
            let largeur = MaterielDeTraduction.mesure.largeur(
                de: ligne,
                corps: composition.corps
            )

            #expect(
                largeur <= composition.largeurUtile,
                "la ligne \(ligne) deborde en largeur",
                sourceLocation: localisation
            )
        }

        #expect(
            composition.hauteurDuBloc <= composition.hauteurUtile,
            "le bloc deborde en hauteur",
            sourceLocation: localisation
        )
        #expect(
            composition.corps >= Jetons.Traduction.corpsMinimal,
            "le corps passe sous le plancher de lisibilite",
            sourceLocation: localisation
        )
    }

    @Test("Aucune bulle ne deborde, quelles que soient sa taille et son texte")
    func aucuneBulleNeDeborde() throws {
        let planches = [(600.0, 900.0), (900.0, 1350.0), (320.0, 480.0)]
        let parts = [(0.5, 0.3), (0.3, 0.12), (0.14, 0.06)]

        for (largeurDePlanche, hauteurDePlanche) in planches {
            for (part, hauteur) in parts {
                for texte in MaterielDeTraduction.textes {
                    let traduction = try MaterielDeTraduction.traduction(
                        largeur: part,
                        hauteur: hauteur,
                        texte: texte
                    )

                    let bulles = SurimpressionDeTraduction.composer(
                        [traduction],
                        largeur: largeurDePlanche,
                        hauteur: hauteurDePlanche,
                        mesure: MaterielDeTraduction.mesure
                    )

                    let bulle = try #require(bulles.first)

                    verifier(bulle.composition)
                }
            }
        }
    }

    @Test("Une bulle spacieuse ecrit au corps du texte courant")
    func laBulleSpacieuseEcritAuCorpsCourant() throws {
        let traduction = try MaterielDeTraduction.traduction(
            largeur: 0.6,
            hauteur: 0.3,
            texte: "Merci"
        )

        let bulles = SurimpressionDeTraduction.composer(
            [traduction],
            largeur: 900,
            hauteur: 1350,
            mesure: MaterielDeTraduction.mesure
        )
        let bulle = try #require(bulles.first)

        #expect(bulle.composition.corps == Jetons.Traduction.corpsMaximal)
        #expect(bulle.composition.estTronque == false)
    }

    @Test("Une bulle deja dans la langue cible ne recoit aucune surimpression")
    func laBulleInchangeeNestPasRecouverte() throws {
        let cadre = try #require(
            CaseDePage(abscisse: 0.1, ordonnee: 0.1, largeur: 0.4, hauteur: 0.2)
        )
        let bulle = try #require(BulleDeTexte(cadre: cadre, texte: "deja en francais"))
        let traduction = TraductionDeBulle(
            bulle: bulle,
            texteTraduit: "deja en francais",
            langueCible: .francais,
            moteur: .surLAppareil
        )

        let composees = SurimpressionDeTraduction.composer(
            [traduction],
            largeur: 900,
            hauteur: 1350,
            mesure: MaterielDeTraduction.mesure
        )
        let composee = try #require(composees.first)

        #expect(composee.traduction.estInchangee)
        #expect(composee.meriteUneSurimpression == false)
    }

    @Test("Le cadre en points suit la taille de la planche affichee")
    func leCadreSuitLaTailleDeLaPlanche() throws {
        let traduction = try MaterielDeTraduction.traduction(
            largeur: 0.4,
            hauteur: 0.2,
            texte: "Attention"
        )
        let cadre = traduction.bulle.cadreEnPoints(largeur: 1000, hauteur: 2000)

        #expect(cadre.abscisse == 100)
        #expect(cadre.ordonnee == 200)
        #expect(cadre.largeur == 400)
        #expect(cadre.hauteur == 400)
        #expect(cadre.estVide == false)
    }
}

/// Rien n est invente hors des jetons que le document pose.
struct GabaritDeLaTraductionTests {
    @Test("Le gabarit prend le haut et le bas de l echelle de la section 1.5")
    func leGabaritPrendLesDeuxBoutsDeLEchelle() {
        #expect(Jetons.Traduction.corpsMaximal == Jetons.Typo.body.taille)
        #expect(Jetons.Traduction.corpsMinimal == Jetons.Typo.caption.taille)
        #expect(Jetons.Traduction.gabarit.corpsMaximal == Jetons.Traduction.corpsMaximal)
        #expect(Jetons.Traduction.gabarit.corpsMinimal == Jetons.Traduction.corpsMinimal)
    }

    @Test("Aucun corps essaye ne sort de l echelle du document")
    func aucunCorpsNeSortDeLEchelle() {
        let corps = Jetons.Traduction.gabarit.corpsEssayes

        #expect(corps.isEmpty == false)
        #expect(corps.allSatisfy { $0 >= Jetons.Typo.caption.taille })
        #expect(corps.allSatisfy { $0 <= Jetons.Typo.body.taille })
    }

    @Test("Chaque mesure de la surimpression vient d une echelle du document")
    func lesMesuresViennentDesEchelles() {
        #expect(Jetons.Rayon.echelle.contains(Jetons.Traduction.rayon))
        #expect(Jetons.Espace.echelle.contains(Jetons.Traduction.margeInterne))
        #expect(Jetons.Espace.echelle.contains(Jetons.Traduction.rayonDeFlou))
    }

    @Test("Le voile reprend l opacite du seul voile que le document donne")
    func leVoileReprendCeluiDuDocument() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Couverture floutee a 40 px de rayon")
        )

        #expect(ligne.contains("55 pour cent"))
        #expect(Jetons.Traduction.opaciteDuVoile == Jetons.FicheDeSerie.opaciteDuVoile)
    }

    @Test("La graisse du texte traduit est la graisse normale")
    func laGraisseEstLaNormale() {
        // La section 1.5 reserve la graisse 600 a cinq cas nommes, et une bulle
        // traduite n en fait pas partie.
        #expect(Jetons.Traduction.graisse == .normale)
    }
}

/// La mention du moteur distant, et quand elle parait.
struct MentionDeTraductionTests {
    @Test("La mention parait des que du texte sort de l appareil")
    func laMentionParaitQuandLeTexteSort() throws {
        let libelles = try MaterielDeTraduction.libelles()
        let reglages = ReglagesDeTraduction(
            actif: true,
            moteur: .dansLeNuage,
            consentementAuNuage: true
        )

        let mention = try #require(
            TexteDeLaMentionDeTraduction.mention(pour: reglages, libelles: libelles)
        )

        #expect(mention.titre == libelles.titreDuNuage)
        #expect(mention.phrase == libelles.phraseDuNuage)
    }

    @Test("Aucune mention tant que rien ne sort de l appareil")
    func aucuneMentionQuandRienNeSort() throws {
        let libelles = try MaterielDeTraduction.libelles()

        let cas = [
            ReglagesDeTraduction.parDefaut,
            ReglagesDeTraduction.arme,
            ReglagesDeTraduction(actif: true, moteur: .dansLeNuage, consentementAuNuage: false),
            ReglagesDeTraduction(actif: false, moteur: .dansLeNuage, consentementAuNuage: true),
        ]

        for reglages in cas {
            #expect(
                TexteDeLaMentionDeTraduction.mention(pour: reglages, libelles: libelles) == nil,
                "\(reglages)"
            )
        }
    }

    @Test("La mention ne se ferme jamais")
    func laMentionNeSeFermeJamais() throws {
        let libelles = try MaterielDeTraduction.libelles()
        let mention = try #require(
            TexteDeLaMentionDeTraduction.mention(
                pour: ReglagesDeTraduction(
                    actif: true,
                    moteur: .dansLeNuage,
                    consentementAuNuage: true
                ),
                libelles: libelles
            )
        )

        #expect(mention.peutEtreFermee == false)
    }

    @Test("La mention reprend le gabarit de la banniere du mode incognito")
    func laMentionReprendLeGabaritDeLIncognito() {
        // Les deux disent la meme chose de la meme facon, un etat de session qui
        // change ce que l application fait des donnees. Deux formes distinctes
        // apprendraient deux vocabulaires visuels pour une seule idee.
        #expect(Jetons.Traduction.glypheDuNuage == Jetons.Icone.iCloud)
        #expect(Jetons.BanniereDIncognito.rayon == Jetons.Rayon.carte)
    }

    @Test("Les textes de la mention suivent les regles d ecriture de la section 6")
    func lesTextesSuiventLesReglesDEcriture() throws {
        let libelles = try MaterielDeTraduction.libelles()
        let tiretCadratin = "\u{2014}"

        for texte in [libelles.titreDuNuage, libelles.phraseDuNuage, libelles.etiquetteDuNuage] {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    @Test("L etiquette d accessibilite porte l information du glyphe")
    func lEtiquettePorteLInformation() throws {
        let libelles = try MaterielDeTraduction.libelles()

        // Section 7 : aucune information transmise par le seul glyphe.
        // L etiquette dit le moteur employe et ce qu il fait sortir.
        #expect(libelles.etiquetteDuNuage.contains("nuage"))
        #expect(libelles.etiquetteDuNuage.contains("distant"))
    }

    @Test("Le titre de la mention reprend le nom du moteur du menu")
    func leTitreReprendLeNomDuMoteur() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let valeurDuMenu = try MaterielDeTraduction.valeur(
            catalogue,
            "reglages.valeur.dansLeNuage"
        )
        let libelles = try MaterielDeTraduction.libelles()

        #expect(valeurDuMenu == ChoixDeMoteurDeTraduction.dansLeNuage.valeurDuDocument)
        #expect(libelles.titreDuNuage.contains("nuage"))
    }
}

/// Les libelles de la section Traduction des reglages.
struct LibellesDeLaTraductionTests {
    @Test("Chaque ligne de la section Traduction porte son libelle au catalogue")
    func chaqueLignePorteSonLibelle() throws {
        let catalogue = try CatalogueDeChaines.charger()

        for ligne in CatalogueDeReglages.lignes(de: .traduction) {
            let cle = "reglages.ligne.\(ligne.id.rawValue)"
            let libelle = try MaterielDeTraduction.valeur(catalogue, cle)

            #expect(libelle.isEmpty == false, "\(cle)")
        }
    }

    @Test("Chaque valeur du menu Moteur de traduction porte son libelle")
    func chaqueValeurDuMenuPorteSonLibelle() throws {
        let catalogue = try CatalogueDeChaines.charger()

        for choix in ChoixDeMoteurDeTraduction.allCases {
            let libelle = try MaterielDeTraduction.valeur(
                catalogue,
                "reglages.valeur.\(choix.rawValue)"
            )

            #expect(libelle == choix.valeurDuDocument)
        }
    }

    @Test("La description de la carte Traduction annonce ce que le nuage coute")
    func laDescriptionAnnonceLeCoutDuNuage() throws {
        let catalogue = try CatalogueDeChaines.charger()
        let description = try MaterielDeTraduction.valeur(
            catalogue,
            "reglages.description.traduction"
        )

        // Cahier de developpement, section 9. La description est le premier
        // endroit ou l utilisateur apprend que le second choix sort de
        // l appareil et se paie.
        #expect(description.contains("gratuite et privee"))
        #expect(description.contains("credits"))
    }

    @Test("La ligne du moteur porte un symbole de SF Symbols")
    func laLignePorteUnSymbole() {
        let symbole = Jetons.IconeDeReglage.pour(.moteurDeTraduction)

        #expect(symbole.isEmpty == false)
        #expect(symbole != Jetons.Icone.reglages)
    }
}
