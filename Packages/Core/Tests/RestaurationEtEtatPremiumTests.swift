import Foundation
import Testing
@testable import Core

//
// Restauration, cas limites de l etat, et garde du mur.
//
// Meme materiel et meme methode que `AbonnementPremiumTests`, qui couvre le
// fichier de configuration et l essai de sept jours : les produits viennent de
// `App/Yum.storekit`, l horloge est fournie par le test, et rien n est recopie.
//
// Trois regles se jouent ici et aucune n est evidente. Une restauration qui ne
// trouve rien n est pas un echec. Une panne de boutique ne ferme pas un
// abonnement deja actif. Et un remboursement ferme l acces avant l echeance
// payee, sans rien supprimer d autre.
//

/// La restauration des achats, seule sortie apres une reinstallation.
struct RestaurationDesAchatsTests {
    @Test("Une reinstallation ferme l acces, la restauration le rouvre")
    func laRestaurationRetrouveLAbonnement() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let annuel = try MaterielDAbonnement.produit(CataloguePremium.annuel)

        _ = try await boutique.acheter(annuel)
        await boutique.oublierLesTransactionsLocales()

        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium == false)

        let resultat = try await boutique.restaurer()

        #expect(resultat.aucunAchatTrouve == false)
        #expect(resultat.etat.donneAccesAuxFonctionsPremium)
        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium)
    }

    @Test("Une restauration sans achat repond sans erreur et ne debloque rien")
    func laRestaurationSansAchatNEstPasUneErreur() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))

        let resultat = try await boutique.restaurer()

        #expect(resultat.aucunAchatTrouve)
        #expect(resultat.etat == .gratuit)
        #expect(resultat.refusees.isEmpty)
    }

    @Test("Une transaction non authentifiee ne debloque rien et nomme sa cause")
    func uneTransactionNonAuthentifieeEstEcartee() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.oublierLesTransactionsLocales()
        await boutique.adopter(.signatureInvalide)

        let resultat = try await boutique.restaurer()

        #expect(resultat.aucunAchatTrouve)
        #expect(resultat.etat == .gratuit)
        #expect(resultat.refusees == [.signatureInvalide])
    }

    @Test("Une transaction d un produit etranger est refusee")
    func uneTransactionEtrangereEstRefusee() throws {
        let etrangere = try TransactionPremium(
            identifiant: 9,
            identifiantDeProduit: "com.exemple.autre.abonnement",
            genre: .mensuel,
            acheteeLe: MaterielDAbonnement.date(1, 3)
        )

        let verdict = VerificationDeTransaction.verdict(
            pour: etrangere,
            signatureValide: true
        )

        #expect(verdict == .refusee(.produitInconnu))
        #expect(verdict.transaction == nil)
    }

    @Test("Un achat fait dans une autre application est refuse")
    func unAchatDUneAutreApplicationEstRefuse() throws {
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let transaction = try EssaiPremium.transaction(
            pour: mensuel,
            identifiant: 3,
            debut: MaterielDAbonnement.date(1, 3),
            calendrier: MaterielDAbonnement.calendrier
        )

        let verdict = VerificationDeTransaction.verdict(
            pour: transaction,
            signatureValide: true,
            identifiantDApplication: "com.exemple.autre",
            identifiantAttendu: "com.yum.lecteur"
        )

        #expect(verdict == .refusee(.applicationDifferente))
    }

    @Test("Une transaction sans identifiant d application n est pas refusee pour autant")
    func lAbsenceDIdentifiantNeRefusePas() throws {
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let transaction = try EssaiPremium.transaction(
            pour: mensuel,
            identifiant: 4,
            debut: MaterielDAbonnement.date(1, 3),
            calendrier: MaterielDAbonnement.calendrier
        )

        let verdict = VerificationDeTransaction.verdict(
            pour: transaction,
            signatureValide: true,
            identifiantDApplication: nil,
            identifiantAttendu: "com.yum.lecteur"
        )

        #expect(verdict.transaction == transaction)
    }

    @Test("La boutique injoignable leve une erreur nommee et ne change aucun etat")
    func laBoutiqueInjoignableLeveUneErreurNommee() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.adopter(.injoignable)

        await #expect(throws: ErreurDeBoutique.boutiqueInjoignable) {
            _ = try await boutique.restaurer()
        }

        #expect(
            await boutique.etatCourant().donneAccesAuxFonctionsPremium,
            "Une panne de boutique ne ferme pas un abonnement deja actif"
        )
    }

    @Test("Chaque erreur de boutique nomme sa cause et sa sortie, sans donnee personnelle")
    func chaqueErreurNommeSaCause() {
        let erreurs: [ErreurDeBoutique] = [
            .boutiqueInjoignable,
            .produitIntrouvable(identifiant: CataloguePremium.mensuel),
            .transactionNonVerifiee(motif: .signatureInvalide),
            .transactionNonVerifiee(motif: .produitInconnu),
            .transactionNonVerifiee(motif: .applicationDifferente),
            .achatRefuse,
            .echecInattendu(raison: "URLError"),
        ]

        for erreur in erreurs {
            #expect(erreur.messageUtilisateur.isEmpty == false)
            #expect(erreur.codeDeJournal.isEmpty == false)
            #expect(
                erreur.codeDeJournal.contains(CataloguePremium.mensuel) == false,
                "Le journal ne porte ni identifiant de produit ni donnee de compte"
            )
        }
    }
}

/// Ce que l etat de l abonnement dit dans les cas limites.
struct EtatDePremiumTests {
    @Test("Un remboursement ferme l acces avant l echeance payee")
    func unRemboursementFermeLAcces() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.revoquerTout()

        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium == false)
    }

    @Test("L achat definitif n expire pas et survit a un abonnement termine")
    func lAchatDefinitifNExpirePas() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let definitif = try MaterielDAbonnement.produit(CataloguePremium.definitif)

        _ = try await boutique.acheter(mensuel)
        _ = try await boutique.acheter(definitif)
        await boutique.avancerDe(jours: 400)

        #expect(await boutique.etatCourant() == .definitif)
        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium)
    }

    @Test("Deux abonnements a la fois donnent l echeance la plus lointaine")
    func lEcheanceLaPlusLointaineGagne() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)
        let annuel = try MaterielDAbonnement.produit(CataloguePremium.annuel)

        _ = try await boutique.acheter(mensuel)
        await boutique.avancerDe(jours: 8)
        _ = try await boutique.acheter(annuel)
        await boutique.avancerDe(jours: 60)

        let etat = await boutique.etatCourant()

        #expect(etat.donneAccesAuxFonctionsPremium)

        if case let .abonne(genre, _) = etat {
            #expect(genre == .annuel, "Le passage a l annuel ne doit pas expirer le mois suivant")
        } else {
            Issue.record("L abonnement le plus long doit gouverner l etat")
        }
    }

    @Test("Un renoncement a la feuille de paiement ne change rien et n est pas une erreur")
    func unRenoncementNeChangeRien() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        await boutique.adopter(.annulation)

        #expect(try await boutique.acheter(mensuel) == .annuleParLUtilisateur)
        #expect(await boutique.etatCourant() == .gratuit)
        #expect(await boutique.essaiDisponible(), "Un renoncement ne consomme pas l essai")
    }

    @Test("Une validation en attente n ouvre rien et ne consomme pas l essai")
    func uneValidationEnAttenteNOuvreRien() async throws {
        let boutique = try MaterielDAbonnement.boutique(le: MaterielDAbonnement.date(1, 3))
        let mensuel = try MaterielDAbonnement.produit(CataloguePremium.mensuel)

        await boutique.adopter(.attenteDeValidation)

        #expect(try await boutique.acheter(mensuel) == .enAttenteDeValidation)
        #expect(await boutique.etatCourant().donneAccesAuxFonctionsPremium == false)
        #expect(await boutique.essaiDisponible())
    }
}

/// Le mur ne surgit jamais pendant la lecture.
struct GardeDuMurPremiumTests {
    @Test("Aucune origine ne peut ouvrir le mur sans geste de l utilisateur")
    func aucunSurgissementAutomatique() {
        for origine in OrigineDuMurPremium.allCases {
            for lecture in [true, false] {
                let decision = GardeDuMurPremium.decision(
                    origine: origine,
                    declencheur: .evenementDeLApplication,
                    lectureEnCours: lecture
                )

                #expect(decision == .refuser(.surgissementInterdit))
                #expect(decision.autorise == false)
            }
        }
    }

    @Test("Pendant la lecture, seules les commandes du lecteur ouvrent le mur")
    func pendantLaLectureSeulLeLecteurOuvre() {
        for origine in OrigineDuMurPremium.allCases {
            let decision = GardeDuMurPremium.decision(
                origine: origine,
                declencheur: .actionDeLUtilisateur,
                lectureEnCours: true
            )

            #expect(decision == (origine.appartientAuLecteur ? .ouvrir : .refuser(.lectureEnCours)))
        }
    }

    @Test("Hors lecture, un geste de l utilisateur ouvre le mur depuis n importe ou")
    func horsLectureToutesLesOriginesOuvrent() {
        for origine in OrigineDuMurPremium.allCases {
            let decision = GardeDuMurPremium.decision(
                origine: origine,
                declencheur: .actionDeLUtilisateur,
                lectureEnCours: false
            )

            #expect(decision == .ouvrir)
        }
    }

    @Test("La couronne du panneau de filtres est la seule origine du lecteur")
    func laSeuleOrigineDuLecteurEstLaCouronne() {
        let duLecteur = OrigineDuMurPremium.allCases.filter(\.appartientAuLecteur)

        #expect(duLecteur == [.panneauDeFiltresDuLecteur])
    }
}
