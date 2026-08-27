import Core
import Testing

//
// Couvre le troisieme critere de la fonctionnalite : le tutoriel apparait une
// seule fois et dure quatre secondes.
//
// L instant etant un argument, la duree se verifie exactement, sans attente et
// sans horloge. Un test qui dormirait quatre secondes ne prouverait rien de
// plus et ralentirait toute la suite.
//

struct TutorielDeZonesTests {
    // MARK: Duree

    @Test("Le tutoriel dure quatre secondes, section 5.7")
    func dureeDeQuatreSecondes() {
        #expect(TutorielDeZones.duree == 4)
    }

    @Test("Les zones restent visibles jusqu a la quatrieme seconde")
    func visibleAvantLEcheance() {
        var tutoriel = TutorielDeZones()
        tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 10)

        for instant in [10.0, 11.0, 13.0, 13.999] {
            let echue = tutoriel.doitSeMasquer(a: instant)
            let retire = tutoriel.masquerSiEcoule(a: instant)

            #expect(echue == false, "Instant \(instant)")
            #expect(retire == false, "Instant \(instant)")
            #expect(tutoriel.estAffiche, "Instant \(instant)")
        }
    }

    @Test("Les zones disparaissent des la quatrieme seconde revolue")
    func retraitALEcheance() {
        var tutoriel = TutorielDeZones()
        tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 10)

        #expect(tutoriel.doitSeMasquer(a: 14))

        let retire = tutoriel.masquerSiEcoule(a: 14)

        #expect(retire)
        #expect(tutoriel.estAffiche == false)
    }

    @Test("Un second retrait ne signale rien de plus")
    func retraitIdempotent() {
        var tutoriel = TutorielDeZones()
        tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)
        tutoriel.masquerSiEcoule(a: 4)

        let secondRetrait = tutoriel.masquerSiEcoule(a: 100)

        #expect(secondRetrait == false)
        #expect(tutoriel.estAffiche == false)
    }

    // MARK: Une seule fois

    @Test("Le tutoriel n apparait qu a la premiere ouverture du lecteur")
    func uneSeuleApparition() {
        var tutoriel = TutorielDeZones()
        let premiere = tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)

        #expect(premiere)
        #expect(tutoriel.estAffiche)

        tutoriel.masquerSiEcoule(a: TutorielDeZones.duree)

        for ouverture in 1...5 {
            let revient = tutoriel.ouvrirLeLecteur(
                disposition: .standard,
                instant: Double(ouverture) * 100
            )

            #expect(revient == false, "Ouverture \(ouverture)")
            #expect(tutoriel.estAffiche == false, "Ouverture \(ouverture)")
        }
    }

    @Test("Un tutoriel deja vu sur cette installation ne revient jamais")
    func dejaVuPersiste() {
        var tutoriel = TutorielDeZones(dejaVu: true)
        let apparait = tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)

        #expect(apparait == false)
        #expect(tutoriel.estAffiche == false)
        #expect(tutoriel.zones(disposition: .standard, sens: .droiteGauche).isEmpty)
    }

    @Test("Le drapeau est pose des l apparition, avant meme la fin des quatre secondes")
    func drapeauPoseALApparition() {
        var tutoriel = TutorielDeZones()

        #expect(tutoriel.dejaVu == false)

        tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)

        // L application peut se fermer pendant le tutoriel. Le drapeau doit
        // deja etre a vrai a cet instant, sinon le tutoriel revient au
        // lancement suivant.
        #expect(tutoriel.dejaVu)
    }

    @Test("Une disposition sans zone active ne consomme pas le tutoriel")
    func dispositionDesactivee() {
        var tutoriel = TutorielDeZones()
        let sansZones = tutoriel.ouvrirLeLecteur(disposition: .desactive, instant: 0)

        #expect(sansZones == false)
        #expect(tutoriel.dejaVu == false)
        #expect(tutoriel.estAffiche == false)

        // L utilisateur active les zones plus tard : le tutoriel l attend.
        let avecZones = tutoriel.ouvrirLeLecteur(disposition: .kindle, instant: 50)

        #expect(avecZones)
        #expect(tutoriel.estAffiche)
    }

    // MARK: Zones montrees

    @Test("Hors tutoriel, aucune zone n est visible", arguments: DispositionDeZones.allCases)
    func aucuneZoneHorsTutoriel(disposition: DispositionDeZones) {
        let tutoriel = TutorielDeZones()

        #expect(tutoriel.zones(disposition: disposition, sens: .droiteGauche).isEmpty)
    }

    @Test("Pendant le tutoriel, les zones montrees sont celles de la disposition reglee")
    func zonesMontrees() {
        var tutoriel = TutorielDeZones()
        tutoriel.ouvrirLeLecteur(disposition: .bord, instant: 0)

        let montrees = tutoriel.zones(disposition: .bord, sens: .droiteGauche, zonesInversees: true)

        #expect(montrees == DispositionDeZones.bord.zones(sens: .droiteGauche, zonesInversees: true))
        #expect(montrees.contains { $0.role.navigue })
    }

    @Test("Les zones redeviennent invisibles apres les quatre secondes")
    func zonesRetireesApresLaDuree() {
        var tutoriel = TutorielDeZones()
        tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)
        tutoriel.masquerSiEcoule(a: TutorielDeZones.duree)

        #expect(tutoriel.zones(disposition: .standard, sens: .gaucheDroite).isEmpty)
    }
}
