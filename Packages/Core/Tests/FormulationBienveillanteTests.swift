import Testing
@testable import Core

//
// Troisieme critere de F059 : aucune formulation culpabilisante dans les
// textes.
//
// Cette suite ne verifie pas les libelles, c est le role de la suite de la
// couche vue, qui les lit dans le catalogue. Elle verifie l instrument :
// qu il attrape bien ce qu il doit attraper, et qu il n accuse pas un texte
// irreprochable. Un controle qui laisserait tout passer rendrait le critere de
// l ecran vert sans rien prouver.
//

struct FormulationBienveillanteTests {
    @Test("Une phrase qui juge la journee est refusee")
    func phraseQuiJuge() {
        #expect(FormulationBienveillante.estBienveillante("Objectif rate") == false)
        #expect(FormulationBienveillante.estBienveillante("Vous avez lu trop peu aujourd hui") == false)
        #expect(FormulationBienveillante.estBienveillante("Echec de la journee") == false)
    }

    @Test("Une phrase qui prescrit un comportement est refusee")
    func phraseQuiPrescrit() {
        #expect(FormulationBienveillante.estBienveillante("Vous devriez lire un chapitre") == false)
        #expect(FormulationBienveillante.estBienveillante("Il faut lire pour garder la serie") == false)
        #expect(FormulationBienveillante.estBienveillante("N oubliez pas votre lecture") == false)
    }

    @Test("Une phrase qui dramatise la serie est refusee")
    func phraseQuiDramatise() {
        #expect(FormulationBienveillante.estBienveillante("Serie perdue") == false)
        #expect(FormulationBienveillante.estBienveillante("Votre serie est brisee") == false)
    }

    @Test("Une phrase qui dit seulement ce qui a ete lu est acceptee")
    func phraseNeutre() {
        #expect(FormulationBienveillante.estBienveillante("3 sur 5 chapitres"))
        #expect(FormulationBienveillante.estBienveillante("La serie commence a la prochaine lecture"))
        #expect(FormulationBienveillante.estBienveillante("Les sept derniers jours"))
        #expect(
            FormulationBienveillante.estBienveillante(
                "Un jour compte quand l objectif est atteint. Sans objectif, un chapitre suffit."
            )
        )
    }

    @Test("La comparaison se fait mot a mot, un mot proscrit cache dans un autre ne compte pas")
    func comparaisonMotAMot() {
        // `rate` est proscrit, `separateur` le contient et n a rien a se
        // reprocher. Une recherche de sous chaine accuserait le second.
        #expect(FormulationBienveillante.estBienveillante("Le separateur de la carte"))
        #expect(FormulationBienveillante.estBienveillante("Chapitre rate") == false)
    }

    @Test("La comparaison ignore la casse et les accents")
    func comparaisonSansAccent() {
        #expect(FormulationBienveillante.estBienveillante("ECHEC") == false)
        #expect(FormulationBienveillante.estBienveillante("Echoue") == false)
    }

    @Test("L apostrophe ne masque pas une tournure proscrite")
    func apostropheTransparente() {
        #expect(FormulationBienveillante.estBienveillante("N'oubliez pas de lire") == false)
    }

    @Test("Les deux regles d ecriture de la section 6 sont verifiees au meme endroit")
    func reglesDEcriture() {
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        #expect(FormulationBienveillante.estBienveillante("Bravo pour cette lecture !") == false)
        #expect(FormulationBienveillante.estBienveillante("Aujourd hui \(tiretCadratin) 3 chapitres") == false)
    }

    @Test("La liste couvre les trois familles de tournures")
    func listeComplete() {
        #expect(FormulationBienveillante.jugementsProscrits.isEmpty == false)
        #expect(FormulationBienveillante.injonctionsProscrites.isEmpty == false)
        #expect(FormulationBienveillante.dramatisationsProscrites.isEmpty == false)

        let total = FormulationBienveillante.jugementsProscrits.count
            + FormulationBienveillante.injonctionsProscrites.count
            + FormulationBienveillante.dramatisationsProscrites.count

        #expect(FormulationBienveillante.tournuresProscrites.count == total)
    }

    @Test("Le detail des tournures trouvees nomme celle qui a bloque")
    func detailDesTournures() {
        let trouvees = FormulationBienveillante.tournuresTrouvees(dans: "Serie perdue, vous devriez lire")

        #expect(trouvees.contains("perdue"))
        #expect(trouvees.contains("vous devriez"))
    }
}
