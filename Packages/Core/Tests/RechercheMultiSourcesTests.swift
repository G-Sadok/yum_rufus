import Core
import Foundation
import Testing

/// Couvre les deux premiers criteres de l ecran Rechercher, section 5.4 de
/// DESIGN-SPEC.md.
///
/// Les deux se verifient sans rendu, parce que les deux sont des proprietes du
/// modele et non de la vue. Une source lente ne retient que sa rangee, et une
/// source en echec ne pose qu une ligne d erreur a sa place.
struct RechercheMultiSourcesTests {
    // MARK: Premier critere

    @Test("Une source lente n empeche pas l affichage des autres")
    func sourceLente() async {
        let registre = RegistreDeSources()
        let rapide = SourceID()
        let lente = SourceID()

        await registre.inscrire(
            SourceDeTest(id: rapide, nom: "Rapide", series: .suiteDeTest(2))
        )
        await registre.inscrire(
            SourceDeTest(
                id: lente,
                nom: "Lente",
                series: .suiteDeTest(2),
                delaiAvantReponse: EcranDeRechercheDeTest.attenteDeLaSourceLente
            )
        )

        var etat = await EcranDeRechercheDeTest.etatInitial(registre)
        var premiereReponse: SourceID?

        for await resultat in await registre.rechercherAuFilDeLEau(
            EcranDeRechercheDeTest.requete()
        ) {
            etat.appliquer(resultat)

            guard premiereReponse == nil else {
                continue
            }

            premiereReponse = resultat.source

            // Au moment precis ou la premiere reponse arrive, la rangee rapide
            // est deja affichable et la lente attend encore la sienne.
            #expect(etat.groupe(rapide)?.porteDesResultats == true)
            #expect(etat.groupe(lente)?.estEnChargement == true)
            #expect(etat.estTerminee == false)
        }

        #expect(premiereReponse == rapide, "La source sans attente repond la premiere")
        #expect(etat.estTerminee)
        #expect(etat.groupe(lente)?.porteDesResultats == true)
    }

    @Test("Le flux rend une reponse par source, sans en perdre aucune")
    func fluxComplet() async {
        let registre = RegistreDeSources()

        for rang in 0..<4 {
            await registre.inscrire(SourceDeTest(nom: "Source \(rang)", series: .suiteDeTest(2)))
        }

        var recues: [SourceID] = []

        for await resultat in await registre.rechercherAuFilDeLEau(
            EcranDeRechercheDeTest.requete()
        ) {
            recues.append(resultat.source)
        }

        #expect(recues.count == 4)
        #expect(Set(recues).count == 4, "Aucune source ne repond deux fois")
    }

    @Test("Le flux n interroge que les sources qui declarent la recherche")
    func sourcesSansRecherche() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Chercheuse", series: .suiteDeTest(2)))
        await registre.inscrire(SourceDeTest(nom: "Muette au catalogue", capacites: []))

        let interrogees = await registre.sourcesInterrogeesParUneRecherche()

        #expect(interrogees.map(\.nom) == ["Chercheuse"])

        var recues = 0

        for await _ in await registre.rechercherAuFilDeLEau(EcranDeRechercheDeTest.requete()) {
            recues += 1
        }

        #expect(recues == 1)
    }

    // MARK: Deuxieme critere

    @Test("Une source en erreur laisse une ligne discrete et les autres intactes")
    func sourceEnErreur() async {
        let registre = RegistreDeSources()
        let saine = SourceID()
        let cassee = SourceID()

        await registre.inscrire(SourceDeTest(id: saine, nom: "Saine", series: .suiteDeTest(2)))
        await registre.inscrire(
            SourceDeTest(id: cassee, nom: "Cassee", panne: .transport(.cannotFindHost))
        )

        let etat = await EcranDeRechercheDeTest.rechercher(registre)

        #expect(etat.groupe(saine)?.porteDesResultats == true)
        #expect(etat.groupe(cassee)?.erreur != nil)
        #expect(etat.groupe(cassee)?.erreur?.causeCourte == .injoignable)
        #expect(etat.groupesEnEchec.map(\.source) == [cassee])
        #expect(etat.toutesLesSourcesOntEchoue == false)
        #expect(etat.groupes.count == 2, "La rangee en echec garde sa place dans l ordre")
    }

    @Test("Une source muette devient une ligne d erreur au bout du delai")
    func sourceMuette() async {
        let registre = RegistreDeSources(delaiMaximal: EcranDeRechercheDeTest.delaiCourt)
        let muette = SourceID()

        await registre.inscrire(SourceDeTest(nom: "Saine", series: .suiteDeTest(2)))
        await registre.inscrire(SourceDeTest(id: muette, nom: "Muette", panne: .muette))

        let etat = await EcranDeRechercheDeTest.rechercher(registre)

        #expect(etat.groupe(muette)?.erreur?.causeCourte == .delaiDepasse)
        #expect(etat.estTerminee)
    }

    @Test("Toutes les sources en echec basculent l ecran sur son erreur globale")
    func toutesEnEchec() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Une", panne: .transport(.cannotFindHost)))
        await registre.inscrire(SourceDeTest(nom: "Deux", panne: .quelconque))

        let etat = await EcranDeRechercheDeTest.rechercher(registre)

        #expect(etat.toutesLesSourcesOntEchoue)
        #expect(etat.groupesEnEchec.count == 2)
        #expect(etat.aucunResultat == false, "Un echec n est pas une absence de resultat")
    }

    @Test("Le lien Reessayer relance la seule source qui a echoue")
    func reprisePourUneSeuleSource() async {
        let registre = RegistreDeSources(delaiMaximal: EcranDeRechercheDeTest.delaiCourt)
        let saine = SourceID()
        let cassee = SourceID()

        await registre.inscrire(SourceDeTest(id: saine, nom: "Saine", series: .suiteDeTest(2)))
        await registre.inscrire(SourceDeTest(id: cassee, nom: "Cassee", panne: .muette))

        var etat = await EcranDeRechercheDeTest.rechercher(registre)

        #expect(etat.groupe(cassee)?.erreur != nil)

        // La source est remplacee par une source qui repond, comme le ferait un
        // serveur revenu en ligne entre deux essais.
        await registre.inscrire(SourceDeTest(id: cassee, nom: "Cassee", series: .suiteDeTest(2)))

        etat.remettreEnChargement(cassee)

        #expect(etat.groupe(cassee)?.estEnChargement == true)
        #expect(etat.estTerminee == false)
        #expect(etat.groupe(saine)?.porteDesResultats == true, "Les autres rangees ne bougent pas")

        let reprise = await registre.rechercher(
            EcranDeRechercheDeTest.requete(),
            dans: cassee
        )

        if let reprise {
            etat.appliquer(reprise)
        }

        #expect(reprise != nil)
        #expect(etat.groupe(cassee)?.porteDesResultats == true)
        #expect(etat.estTerminee)
    }

    @Test("Reessayer une source retiree du registre ne rend rien")
    func repriseDUneSourceRetiree() async {
        let registre = RegistreDeSources()

        #expect(
            await registre.rechercher(EcranDeRechercheDeTest.requete(), dans: SourceID()) == nil
        )
    }

    @Test("Les quatre formes courtes couvrent les echecs affichables")
    func formesCourtesDEchec() {
        #expect(ErreurDeSource.reseau(.delaiDepasse, source: "S").causeCourte == .delaiDepasse)
        #expect(ErreurDeSource.reseau(.serveurIntrouvable, source: "S").causeCourte == .injoignable)
        #expect(ErreurDeSource.reseau(.horsLigne, source: "S").causeCourte == .injoignable)
        #expect(
            ErreurDeSource.reseau(.authentificationRefusee, source: "S").causeCourte == .accesRefuse
        )
        #expect(ErreurDeSource.reseau(.accesRefuse, source: "S").causeCourte == .accesRefuse)
        #expect(ErreurDeSource.reseau(.reponseIllisible, source: "S").causeCourte == .echec)
        #expect(ErreurDeSource.sourceInjoignable(source: "S").causeCourte == .injoignable)
        #expect(ErreurDeSource.accesAuDossierPerdu(source: "S").causeCourte == .injoignable)
        #expect(ErreurDeSource.echecInattendu(source: "S", raison: "X").causeCourte == .echec)
    }
}
