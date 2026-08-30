import Core
import Testing

//
// Couvre le parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md.
//
// Trois choses sont verifiees ici, et ce sont les trois criteres de la
// fonctionnalite : le parcours ne depasse pas trois etapes, chaque etape ne pose
// qu une decision, et le rejeu depuis l ecran Reglages repart de la premiere
// etape sans effacer ce qui a deja ete choisi.
//
// Le poids visuel des deux boutons de la troisieme etape est verifie cote
// DesignSystem, la ou vivent les jetons qui le decident.
//

struct ParcoursDePremiereOuvertureTests {
    // MARK: Trois etapes au maximum

    @Test("Le parcours compte exactement trois etapes")
    func troisEtapes() {
        #expect(EtapeDePremiereOuverture.allCases.count == 3)
        #expect(
            EtapeDePremiereOuverture.allCases.count
                <= ParcoursDePremiereOuverture.nombreMaximalDEtapes
        )
    }

    @Test("Les etapes sont rangees dans l ordre de la section 5.10")
    func ordreDesEtapes() {
        #expect(
            EtapeDePremiereOuverture.allCases.map(\.nomDuDocument)
                == ["Sens de lecture", "Premiere source", "Essai premium"]
        )
        #expect(EtapeDePremiereOuverture.allCases.map(\.rang) == [1, 2, 3])
    }

    @Test("Un parcours mene de bout en bout ne traverse jamais plus de trois etapes")
    func parcoursCompletBorne() {
        var parcours = ParcoursDePremiereOuverture()
        parcours.ouvrirAuLancement()

        var traversees: [EtapeDePremiereOuverture] = []

        while let etape = parcours.etape {
            traversees.append(etape)

            guard let commande = parcours.commandes.first else { break }

            parcours.executer(commande)

            #expect(traversees.count <= ParcoursDePremiereOuverture.nombreMaximalDEtapes)
        }

        #expect(traversees == EtapeDePremiereOuverture.allCases)
        #expect(parcours.estOuvert == false)
        #expect(parcours.dejaFait)
    }

    // MARK: Une decision par etape

    @Test("Chaque etape pose une decision, et chaque decision appartient a une etape")
    func uneDecisionParEtape() {
        let decisions = EtapeDePremiereOuverture.allCases.map(\.decision)

        #expect(Set(decisions).count == EtapeDePremiereOuverture.allCases.count)
        #expect(Set(decisions) == Set(DecisionDePremiereOuverture.allCases))
    }

    @Test("Aucune etape n offre deux facons d avancer, sauf la reponse a l essai")
    func commandesParEtape() {
        #expect(ParcoursDePremiereOuverture.commandes(de: .sensDeLecture) == [.continuer])
        #expect(ParcoursDePremiereOuverture.commandes(de: .premiereSource) == [.passer])
        #expect(
            ParcoursDePremiereOuverture.commandes(
                de: .premiereSource,
                source: .connectee(.komga, series: 12)
            ) == [.continuer]
        )
        // Les deux boutons de la troisieme etape sont les deux reponses a une
        // seule question, pas deux decisions.
        #expect(
            ParcoursDePremiereOuverture.commandes(de: .essaiPremium)
                == [.commencerLEssai, .plusTard]
        )
    }

    @Test("Les quatre commandes du tableau 6.5 sont toutes atteignables, et il n en existe pas d autre")
    func quatreCommandes() {
        let offertes = EtapeDePremiereOuverture.allCases.flatMap { etape in
            ParcoursDePremiereOuverture.commandes(de: etape)
                + ParcoursDePremiereOuverture.commandes(
                    de: etape,
                    source: .connectee(.fichiersLocaux, series: 1)
                )
        }

        #expect(Set(offertes) == Set(CommandeDePremiereOuverture.allCases))
        #expect(CommandeDePremiereOuverture.allCases.count == 4)
    }

    @Test("Une commande que l etape n offre pas est refusee")
    func commandeRefusee() {
        var parcours = ParcoursDePremiereOuverture()
        parcours.ouvrirAuLancement()

        let appliquee = parcours.executer(.commencerLEssai)

        #expect(appliquee == false)
        #expect(parcours.etape == .sensDeLecture)
        #expect(parcours.essaiDemande == false)
    }

    // MARK: Decisions

    @Test("Choisir un sens ne fait pas avancer l etape")
    func choixDuSens() {
        var parcours = ParcoursDePremiereOuverture()
        parcours.ouvrirAuLancement()

        parcours.choisirLeSens(.gaucheDroite)

        #expect(parcours.sens == .gaucheDroite)
        #expect(parcours.etape == .sensDeLecture)
    }

    @Test("La deuxieme etape connait les quatre etats d une source")
    func etatsDeLaSource() {
        var parcours = ParcoursDePremiereOuverture()
        parcours.ouvrirAuLancement()
        parcours.executer(.continuer)

        #expect(parcours.source == .rien)
        #expect(parcours.commandes == [.passer])

        parcours.noterLaSource(.connexion(.komga))
        #expect(parcours.commandes == [.passer])

        parcours.noterLaSource(.injoignable(.komga))
        #expect(parcours.commandes == [.passer])

        parcours.noterLaSource(.connectee(.komga, series: 218))
        #expect(parcours.commandes == [.continuer])
        #expect(parcours.source.type == .komga)
    }

    @Test("Les trois sources mises en avant sont celles de la section 5.10, avec les libelles du menu")
    func sourcesMisesEnAvant() {
        #expect(
            ParcoursDePremiereOuverture.sourcesMisesEnAvant == [.fichiersLocaux, .komga, .opds]
        )
        #expect(
            ParcoursDePremiereOuverture.entreesMisesEnAvant.map(\.nomDuDocument)
                == [
                    "Parcourir un dossier local",
                    "Ajouter un serveur Komga",
                    "Ajouter un catalogue OPDS",
                ]
        )
        // Le lien de la section 5.10 renvoie vers les douze types de sources.
        #expect(MenuDAjoutDeSource.entrees.count == 12)
    }

    @Test("Prendre l essai le note, le refuser ne le note pas")
    func reponseALEssai() {
        var accepte = ParcoursDePremiereOuverture()
        accepte.ouvrirAuLancement()
        accepte.executer(.continuer)
        accepte.executer(.passer)
        accepte.executer(.commencerLEssai)

        #expect(accepte.essaiDemande)
        #expect(accepte.dejaFait)

        var refuse = ParcoursDePremiereOuverture()
        refuse.ouvrirAuLancement()
        refuse.executer(.continuer)
        refuse.executer(.passer)
        refuse.executer(.plusTard)

        #expect(refuse.essaiDemande == false)
        #expect(refuse.dejaFait)
    }

    // MARK: Ouverture et rejeu

    @Test("Le parcours ne s ouvre qu une fois au lancement")
    func ouvertureUnique() {
        var neuf = ParcoursDePremiereOuverture()
        let premiereOuverture = neuf.ouvrirAuLancement()
        let seconde = neuf.ouvrirAuLancement()

        #expect(premiereOuverture)
        #expect(seconde == false, "Le parcours etait deja a l ecran")

        var connu = ParcoursDePremiereOuverture(dejaFait: true)
        let ouvertureRefusee = connu.ouvrirAuLancement()

        #expect(ouvertureRefusee == false)
        #expect(connu.estOuvert == false)
    }

    @Test("Le rejeu depuis les reglages rouvre le parcours a la premiere etape")
    func rejeuDepuisLesReglages() {
        var parcours = ParcoursDePremiereOuverture(dejaFait: true)
        parcours.choisirLeSens(.gaucheDroite)

        parcours.rejouer()

        #expect(parcours.estOuvert)
        #expect(parcours.etape == .sensDeLecture)
        // Revoir le parcours ne coute pas le reglage deja pose.
        #expect(parcours.sens == .gaucheDroite)
    }

    @Test("La ligne de rejeu existe dans le catalogue des reglages, sans couronne")
    func ligneDeRejeuDansLesReglages() throws {
        let ligne = try #require(CatalogueDeReglages.ligne(.revoirLaPremiereOuverture))

        #expect(ligne.section == .assistance)
        #expect(ligne.variante == .navigation)
        #expect(ligne.ouvreLeMurPremium == false)
        #expect(
            MatriceDeVerrouillage.estVerrouillee(.revoirLaPremiereOuverture, selon: .gratuit)
                == false
        )
    }
}
