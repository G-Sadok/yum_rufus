import Testing
@testable import Core

//
// Couvre le troisieme critere de la fonctionnalite du cote du modele : le moteur
// dans le nuage est explicitement opt in.
//
// Le critere se decide ici, et nulle part ailleurs. L acteur de traduction lit
// `moteurEffectif`, la mention du lecteur lit `sortDeLAppareil`, la ligne de
// reglages lit `attendUnConsentement`. Si ces trois reponses sont fausses, aucun
// test de couche superieure ne le rattrapera, et l application enverra du texte
// a un service sans que personne ne l ait demande.
//
// La suite verifie donc les quatre combinaisons du couple moteur et accord, pas
// seulement celle qui marche.
//

struct ReglagesDeTraductionTests {
    // MARK: Le choix de menu ne suffit pas

    @Test("Livre par defaut, la traduction est inactive et reste sur l appareil")
    func lesReglagesLivresRestentSurLAppareil() {
        let reglages = ReglagesDeTraduction.parDefaut

        #expect(reglages.actif == false)
        #expect(reglages.moteur == .surLAppareil)
        #expect(reglages.consentementAuNuage == false)
        #expect(reglages.sortDeLAppareil == false)
        #expect(reglages.exigeLeReseau == false)
    }

    @Test("Le moteur distant choisi sans accord retombe sur l appareil")
    func leMoteurDistantSansAccordRetombeSurLAppareil() {
        let reglages = ReglagesDeTraduction(
            actif: true,
            moteur: .dansLeNuage,
            consentementAuNuage: false
        )

        #expect(reglages.moteur == .dansLeNuage)
        #expect(reglages.moteurEffectif == .surLAppareil)
        #expect(reglages.attendUnConsentement)
        #expect(reglages.sortDeLAppareil == false)
        #expect(reglages.exigeLeReseau == false)
    }

    @Test("Le moteur distant accepte sort reellement de l appareil")
    func leMoteurDistantAccepteSortDeLAppareil() {
        let reglages = ReglagesDeTraduction(
            actif: true,
            moteur: .dansLeNuage,
            consentementAuNuage: true
        )

        #expect(reglages.moteurEffectif == .dansLeNuage)
        #expect(reglages.attendUnConsentement == false)
        #expect(reglages.sortDeLAppareil)
        #expect(reglages.exigeLeReseau)
    }

    @Test("Un accord donne sans avoir choisi le nuage ne fait rien sortir")
    func lAccordSeulNeFaitRienSortir() {
        let reglages = ReglagesDeTraduction(
            actif: true,
            moteur: .surLAppareil,
            consentementAuNuage: true
        )

        #expect(reglages.moteurEffectif == .surLAppareil)
        #expect(reglages.attendUnConsentement == false)
        #expect(reglages.sortDeLAppareil == false)
    }

    @Test("Interrupteur coupe, rien ne sort meme avec le nuage accepte")
    func linterrupteurCoupeFermeLaSortie() {
        let reglages = ReglagesDeTraduction(
            actif: false,
            moteur: .dansLeNuage,
            consentementAuNuage: true
        )

        #expect(reglages.sortDeLAppareil == false)
        #expect(reglages.exigeLeReseau == false)
    }

    // MARK: L accord se donne et se retire

    @Test("Retirer l accord suffit a fermer la sortie, sans toucher au menu")
    func retirerLAccordFermeLaSortie() {
        let accepte = ReglagesDeTraduction(
            actif: true,
            moteur: .dansLeNuage,
            consentementAuNuage: true
        )
        let retire = accepte.sansConsentement()

        #expect(retire.moteur == .dansLeNuage)
        #expect(retire.moteurEffectif == .surLAppareil)
        #expect(retire.sortDeLAppareil == false)
        #expect(retire.avecConsentement() == accepte)
    }

    // MARK: L empreinte de cache

    @Test("L empreinte porte le moteur effectif, pas le moteur choisi")
    func lEmpreintePorteLeMoteurEffectif() {
        let sansAccord = ReglagesDeTraduction(
            actif: true,
            moteur: .dansLeNuage,
            consentementAuNuage: false
        )
        let local = ReglagesDeTraduction(actif: true, moteur: .surLAppareil)
        let avecAccord = sansAccord.avecConsentement()

        #expect(sansAccord.empreinte == local.empreinte)
        #expect(avecAccord.empreinte != local.empreinte)
    }

    @Test("Deux langues cibles ne partagent pas la meme empreinte")
    func deuxLanguesNePartagentPasLEmpreinte() {
        let francais = ReglagesDeTraduction(actif: true, langueCible: .francais)
        let anglais = ReglagesDeTraduction(actif: true, langueCible: .english)

        #expect(francais.empreinte != anglais.empreinte)
    }

    // MARK: Le menu de la section 9

    @Test("Le menu porte les deux valeurs du cahier de developpement, dans l ordre")
    func leMenuPorteLesDeuxValeurs() {
        #expect(
            ChoixDeMoteurDeTraduction.valeursDuDocument == ["Sur l appareil", "IA dans le nuage"]
        )
        #expect(ChoixDeMoteurDeTraduction.parDefaut == .surLAppareil)
    }

    @Test("Seul le moteur distant exige un accord et un reseau")
    func seulLeMoteurDistantExigeAccordEtReseau() {
        #expect(ChoixDeMoteurDeTraduction.surLAppareil.exigeUnConsentement == false)
        #expect(ChoixDeMoteurDeTraduction.surLAppareil.exigeLeReseau == false)
        #expect(ChoixDeMoteurDeTraduction.dansLeNuage.exigeUnConsentement)
        #expect(ChoixDeMoteurDeTraduction.dansLeNuage.exigeLeReseau)
    }

    @Test("La ligne du menu vit dans la section Traduction et se verrouille")
    func laLigneDuMenuEstDansLaSectionTraduction() throws {
        let ligne = try #require(CatalogueDeReglages.ligne(.moteurDeTraduction))

        #expect(ligne.section == .traduction)
        #expect(ligne.variante == .valeurEtMenu)
        #expect(ligne.choix == ChoixDeMoteurDeTraduction.valeursPersistees)
    }

    @Test("Les trois lignes du document gardent leur ordre relatif")
    func lesTroisLignesDuDocumentGardentLeurOrdre() {
        let lignes = CatalogueDeReglages.lignes(de: .traduction).map(\.id)

        #expect(lignes.count == 4)
        #expect(lignes.first == .traduireLesBulles)
        #expect(lignes.last == .policeDeRemplacement)

        let duDocument = lignes.filter { $0 != .moteurDeTraduction }

        #expect(duDocument == [.traduireLesBulles, .langueCible, .policeDeRemplacement])
    }
}
