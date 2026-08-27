import Foundation
import Testing
@testable import Core

//
// Mode incognito, section 11 du cahier de developpement.
//
// La phrase du document est lue sur le disque et non recopiee ici. Les trois
// familles d ecriture qu elle nomme doivent se retrouver dans la liste bloquee,
// et une famille retiree du document doit faire virer la suite au rouge.
//

/// Ce que la session suspend, et ce qu elle laisse passer.
struct EcrituresSuspenduesParLIncognitoTests {
    /// Phrase de la section 11 qui definit le mode incognito.
    private func phraseDuDocument() throws -> String {
        try #require(
            try CahierDeDeveloppement.ligne(contenant: "Mode incognito :"),
            "La section 11 ne definit plus le mode incognito"
        )
    }

    @Test("Les trois familles nommees par la section 11 sont bien suspendues")
    func lesFamillesDuDocumentSontSuspendues() throws {
        let phrase = try phraseDuDocument()

        #expect(phrase.contains("aucune ecriture dans l historique"))
        #expect(phrase.contains("aucune mise a jour de progression"))
        #expect(phrase.contains("aucune synchronisation vers les suivis"))

        let session = SessionIncognito.demarree(le: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(session.autorise(.historiqueDeLecture) == false)
        #expect(session.autorise(.positionDeLecture) == false)
        #expect(session.autorise(.synchronisationVersLesSuivis) == false)
    }

    @Test("Le marquage automatique et le rang de la serie sont des traces de lecture")
    func lesEffetsDeBordDeLaLectureSontSuspendus() {
        let session = SessionIncognito.demarree(le: .distantPast)

        // Les deux partent dans la meme transaction que la position. Les laisser
        // passer laisserait la grille dire ce que l historique tait.
        #expect(session.autorise(.marquageDUnChapitreLu) == false)
        #expect(session.autorise(.dateDeDerniereLectureDeLaSerie) == false)
        #expect(session.autorise(.statistiquesDeLecture) == false)
    }

    @Test("Une ecriture qui ne trace aucune lecture continue de partir")
    func lesEcrituresSansTraceContinuent() {
        let session = SessionIncognito.demarree(le: .distantPast)

        // Sans cette ligne, l interrupteur qui coupe le mode incognito ne
        // pourrait pas s enregistrer, et la session ne pourrait plus finir.
        #expect(session.autorise(.reglagesDeLApplication))
        #expect(session.autorise(.bibliotheque))
        #expect(session.autorise(.signets))
        #expect(session.autorise(.telechargements))
        #expect(session.autorise(.categories))
        #expect(session.autorise(.sourcesConfigurees))
        #expect(session.autorise(.cacheDImages))
    }

    @Test("Hors session, aucune ecriture n est suspendue")
    func horsSessionToutPasse() {
        let session = SessionIncognito.inactive

        #expect(session.estActive == false)
        #expect(session.ecrituresSuspendues.isEmpty)

        for ecriture in EcritureDeSession.allCases {
            #expect(session.autorise(ecriture), "\(ecriture.rawValue)")
        }
    }

    @Test("La session suspend exactement les traces de lecture, ni plus ni moins")
    func laSessionSuspendExactementLesTraces() {
        let session = SessionIncognito.demarree(le: .distantPast)

        #expect(session.ecrituresSuspendues == Set(EcritureDeSession.tracesDeLecture))

        for ecriture in EcritureDeSession.allCases {
            #expect(
                session.autorise(ecriture) == (ecriture.laisseUneTraceDeLecture == false),
                "\(ecriture.rawValue)"
            )
        }
    }

    @Test("Chaque ecriture du produit est classee dans une famille et une seule")
    func chaqueEcritureEstClassee() {
        let tracees = EcritureDeSession.allCases.filter(\.laisseUneTraceDeLecture)
        let libres = EcritureDeSession.allCases.filter { $0.laisseUneTraceDeLecture == false }

        #expect(tracees.isEmpty == false)
        #expect(libres.isEmpty == false)
        #expect(tracees.count + libres.count == EcritureDeSession.allCases.count)
        #expect(Set(tracees).isDisjoint(with: Set(libres)))
    }
}

/// Debut et fin d une session.
struct CycleDeLaSessionIncognitoTests {
    @Test("Une session demarree porte sa date de debut")
    func laSessionPorteSaDate() {
        let debut = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SessionIncognito.inactive

        session.demarrer(le: debut)

        #expect(session.estActive)
        #expect(session.demarreeLe == debut)
    }

    @Test("Redemarrer une session en cours ne recule pas sa date de debut")
    func redemarrerNeReculePasLaDate() {
        let debut = Date(timeIntervalSince1970: 1_700_000_000)
        var session = SessionIncognito.demarree(le: debut)

        session.demarrer(le: debut.addingTimeInterval(600))

        #expect(session.demarreeLe == debut)
    }

    @Test("L arret rouvre toutes les ecritures")
    func lArretRouvreLesEcritures() {
        var session = SessionIncognito.demarree(le: .distantPast)

        session.arreter()

        #expect(session.estActive == false)
        #expect(session.autorise(.historiqueDeLecture))
        #expect(session.autorise(.positionDeLecture))
    }
}

/// Permanence de la banniere, critere de la section 11.
struct BanniereDIncognitoPermanenteTests {
    @Test("Aucun evenement de l application ne termine la session")
    func aucunEvenementNeTermineLaSession() {
        for evenement in EvenementDeSession.allCases {
            #expect(evenement.termineLaSession == false, "\(evenement)")
        }
    }

    @Test("La banniere reste visible apres toute la suite des evenements possibles")
    func laBanniereResteVisibleTouteLaSession() {
        let debut = Date(timeIntervalSince1970: 1_700_000_000)
        let session = SessionIncognito.demarree(le: debut)

        // Toute la vie de l application, dans le desordre et en boucle : cinq
        // tours de chaque evenement connu, y compris le passage en arriere plan
        // et le verrouillage, qui sont les deux ruptures les plus credibles.
        let vie = (0..<5).flatMap { _ in EvenementDeSession.allCases }
        let apres = session.apres(vie)

        #expect(apres.porteLaBanniere)
        #expect(apres == session, "La session ne doit pas bouger d un evenement a l autre")
        #expect(apres.demarreeLe == debut)
    }

    @Test("Chaque evenement pris seul laisse la banniere en place")
    func chaqueEvenementLaisseLaBanniere() {
        let session = SessionIncognito.demarree(le: .distantPast)

        for evenement in EvenementDeSession.allCases {
            #expect(session.apres(evenement).porteLaBanniere, "\(evenement)")
        }
    }

    @Test("Hors session, aucune banniere")
    func horsSessionAucuneBanniere() {
        #expect(SessionIncognito.inactive.porteLaBanniere == false)
    }

    @Test("Seul l arret explicite retire la banniere")
    func seulLArretRetireLaBanniere() {
        var session = SessionIncognito.demarree(le: .distantPast)

        session = session.apres(EvenementDeSession.allCases)
        #expect(session.porteLaBanniere)

        session.arreter()
        #expect(session.porteLaBanniere == false)
    }
}

/// Le registre partage, qui porte l etat pour les couches qui ecrivent.
struct RegistreDIncognitoTests {
    @Test("Le registre neuf est inactif")
    func leRegistreNeufEstInactif() {
        let registre = RegistreDIncognito()

        #expect(registre.estActif == false)
        #expect(registre.autorise(.historiqueDeLecture))
    }

    @Test("Le registre suit le debut et la fin de session")
    func leRegistreSuitLaSession() {
        let registre = RegistreDIncognito()

        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(registre.estActif)
        #expect(registre.autorise(.positionDeLecture) == false)
        #expect(registre.autorise(.reglagesDeLApplication))

        registre.arreter()

        #expect(registre.estActif == false)
        #expect(registre.autorise(.positionDeLecture))
    }

    @Test("Le registre supporte les acces concurrents")
    func leRegistreSupporteLaConcurrence() async {
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        // Deux cents lectures depuis autant de taches. Le test ne verifie pas
        // une valeur, il verifie qu aucune lecture ne casse pendant qu une autre
        // tache tient le verrou.
        await withTaskGroup(of: Bool.self) { groupe in
            for _ in 0..<200 {
                groupe.addTask { registre.autorise(.historiqueDeLecture) }
            }

            for await autorise in groupe {
                #expect(autorise == false)
            }
        }
    }
}
