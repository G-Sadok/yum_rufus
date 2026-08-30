import Testing
@testable import Core

//
// Deuxieme critere de F059 : l objectif quotidien est configurable de 1 a 20
// chapitres.
//
// Les deux bornes sont lues dans le cahier de developpement lui meme, pas
// recopiees ici. Une plage changee dans le document et pas dans le code fait
// alors virer la suite au rouge, ce qui est le seul moyen que le critere reste
// vrai apres coup.
//

struct ObjectifQuotidienTests {
    /// Ligne de l inventaire de la section 9 qui decrit le reglage.
    private func ligneDuCahier() throws -> String {
        try #require(try CahierDeDeveloppement.ligne(contenant: "| Objectif quotidien |"))
    }

    // MARK: Les bornes viennent du document

    @Test("Le cahier decrit un compteur desactivable, de 1 a 20 chapitres")
    func borneDuDocument() throws {
        let ligne = try ligneDuCahier()

        #expect(ligne.contains("compteur"))
        #expect(ligne.contains("Desactive"))
        #expect(ligne.contains("1 a 20 chapitres"))
    }

    @Test("Les bornes du code sont celles du document")
    func bornesDuCode() throws {
        let ligne = try ligneDuCahier()

        #expect(ligne.contains("\(ObjectifQuotidien.minimum) a \(ObjectifQuotidien.maximum) chapitres"))
        #expect(ObjectifQuotidien.bornes.minimum == 1)
        #expect(ObjectifQuotidien.bornes.maximum == 20)
        #expect(ObjectifQuotidien.bornes.pas == 1)
    }

    @Test("Les vingt valeurs de la plage sont toutes atteignables")
    func toutesLesValeursSontAtteignables() {
        for vise in ObjectifQuotidien.minimum...ObjectifQuotidien.maximum {
            #expect(ObjectifQuotidien(chapitresParJour: vise).chapitresParJour == vise)
            #expect(ObjectifQuotidien(compteur: vise).chapitresParJour == vise)
        }
    }

    @Test("Une valeur hors bornes est ramenee, jamais refusee")
    func lesValeursHorsBornesSontRamenees() {
        #expect(ObjectifQuotidien(chapitresParJour: 0).chapitresParJour == 1)
        #expect(ObjectifQuotidien(chapitresParJour: -5).chapitresParJour == 1)
        #expect(ObjectifQuotidien(chapitresParJour: 21).chapitresParJour == 20)
        #expect(ObjectifQuotidien(chapitresParJour: 400).chapitresParJour == 20)
    }

    // MARK: Le cran desactive

    @Test("La valeur livree est Desactive")
    func valeurLivree() {
        #expect(ObjectifQuotidien.desactive.estActif == false)
        #expect(ObjectifQuotidien.desactive.chapitresParJour == nil)
    }

    @Test("Le compteur porte un cran de plus que l objectif, et c est l extinction")
    func cranDExtinction() {
        #expect(ObjectifQuotidien.bornesDuCompteur.minimum == 0)
        #expect(ObjectifQuotidien.bornesDuCompteur.maximum == 20)

        #expect(ObjectifQuotidien(compteur: 0).estActif == false)
        #expect(ObjectifQuotidien(compteur: -1).estActif == false)
        #expect(ObjectifQuotidien.desactive.compteur == 0)
        #expect(ObjectifQuotidien(chapitresParJour: 7).compteur == 7)
    }

    @Test("Le cran zero n est pas un objectif de zero chapitre")
    func zeroNEstPasUnObjectif() {
        let eteint = ObjectifQuotidien(compteur: 0)

        // Un objectif de zero serait atteint sans rien lire, et la serie de
        // jours compterait toutes les journees, y compris celles sans lecture.
        #expect(eteint.estAtteint(chapitresLus: 0) == false)
        #expect(eteint.journeeComptee(chapitresLus: 0) == false)
    }

    // MARK: Ce que l objectif decide

    @Test("Un objectif est atteint des que le compte l egale")
    func objectifAtteint() {
        let objectif = ObjectifQuotidien(chapitresParJour: 3)

        #expect(objectif.estAtteint(chapitresLus: 2) == false)
        #expect(objectif.estAtteint(chapitresLus: 3))
        #expect(objectif.estAtteint(chapitresLus: 9))
    }

    @Test("Sans objectif, un chapitre suffit a faire compter la journee")
    func journeeCompteeSansObjectif() {
        let eteint = ObjectifQuotidien.desactive

        #expect(eteint.journeeComptee(chapitresLus: 0) == false)
        #expect(eteint.journeeComptee(chapitresLus: 1))
    }

    @Test("Avec objectif, la journee compte quand l objectif est atteint")
    func journeeCompteeAvecObjectif() {
        let objectif = ObjectifQuotidien(chapitresParJour: 4)

        #expect(objectif.journeeComptee(chapitresLus: 3) == false)
        #expect(objectif.journeeComptee(chapitresLus: 4))
    }

    @Test("La part de l objectif reste entre zero et un")
    func partBornee() {
        let objectif = ObjectifQuotidien(chapitresParJour: 4)

        #expect(objectif.part(chapitresLus: 0) == 0)
        #expect(objectif.part(chapitresLus: 2) == 0.5)
        #expect(objectif.part(chapitresLus: 4) == 1)
        #expect(objectif.part(chapitresLus: 40) == 1)
        #expect(objectif.part(chapitresLus: -3) == 0)
    }

    @Test("Sans objectif, la part dit seulement si la journee est entamee")
    func partSansObjectif() {
        #expect(ObjectifQuotidien.desactive.part(chapitresLus: 0) == 0)
        #expect(ObjectifQuotidien.desactive.part(chapitresLus: 1) == 1)
    }
}
