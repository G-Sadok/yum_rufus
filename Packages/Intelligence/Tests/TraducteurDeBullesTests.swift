import Core
import Foundation
import ImagePipeline
import Testing
@testable import Intelligence

//
// Couvre les deuxieme et troisieme criteres de la fonctionnalite : le moteur sur
// l appareil fonctionne sans reseau, et le moteur dans le nuage est
// explicitement opt in.
//
// Les deux criteres sont des affirmations negatives, et une affirmation negative
// ne se verifie pas en regardant ce qui s affiche. Les tests portent donc sur ce
// que les moteurs recoivent : le moteur local doit avoir ete appele alors que le
// reseau est coupe, le moteur distant doit n avoir rien recu du tout tant que
// l accord manque. `MoteurCompteur` garde la liste exacte des textes qu il a vus,
// ce qui rend la seconde affirmation verifiable plutot que plausible.
//
// La suite est decoupee en cinq sujets plutot qu ecrite d un bloc. Les deux
// criteres, les echecs, le cache et le filtrage des lectures ne se relisent pas
// ensemble : le jour ou l un d eux change, on veut ouvrir sa seule section.
//

/// Materiel partage par les suites de la traduction.
enum MaterielDeTraduction {
    /// Planche decodee de reference.
    static func planche() throws -> ImageDePage {
        try #require(PagesDeTest.decodee(largeur: 240, hauteur: 360))
    }

    /// Cle de page de reference.
    static var cle: ClePage {
        ClePage(
            chapitre: UUID(uuidString: "00000000-0000-0000-0000-0000000000F5") ?? UUID(),
            index: 0
        )
    }

    /// Reglages qui demandent le moteur distant, avec ou sans accord.
    static func nuage(accepte: Bool) -> ReglagesDeTraduction {
        ReglagesDeTraduction(actif: true, moteur: .dansLeNuage, consentementAuNuage: accepte)
    }

    /// Traducteur monte autour des moteurs donnes.
    static func traducteur(
        detection: any DetecteurDeTexte,
        moteurs: [any MoteurDeTraductionDeTexte],
        reseau: DisponibiliteDuReseau
    ) -> TraducteurDeBulles {
        TraducteurDeBulles(
            detecteur: detection,
            moteurs: moteurs,
            reseau: reseau,
            seuilDeConfiance: 0.6
        )
    }
}

/// Deuxieme critere : le moteur sur l appareil fonctionne sans reseau.
struct MoteurSurLAppareilTests {
    @Test("Le moteur local traduit alors que le reseau est coupe")
    func leMoteurLocalTraduitHorsLigne() async throws {
        let local = MoteurCompteur.local()
        let detection = DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut)
        let acteur = MaterielDeTraduction.traducteur(
            detection: detection,
            moteurs: [local],
            reseau: ReseauSuppose.coupe
        )

        let bulles = try await acteur.bulles(
            de: MaterielDeTraduction.planche(),
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: .arme
        )

        #expect(bulles.count == 2)
        #expect(local.nombreDAppels == 1)
        #expect(bulles.allSatisfy { $0.moteur == .surLAppareil })
        #expect(bulles.allSatisfy { $0.texteTraduit.hasPrefix("local:") })
    }

    @Test("Le moteur distant refuse quand le reseau est coupe, avant de rien lire")
    func leMoteurDistantRefuseHorsLigne() async throws {
        let distant = MoteurCompteur.distant()
        let detection = DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut)
        let acteur = MaterielDeTraduction.traducteur(
            detection: detection,
            moteurs: [distant],
            reseau: ReseauSuppose.coupe
        )
        let page = try MaterielDeTraduction.planche()

        await #expect(throws: ErreurDeTraduction.reseauIndisponible) {
            try await acteur.bulles(
                de: page,
                pour: MaterielDeTraduction.cle,
                sens: .droiteGauche,
                reglages: MaterielDeTraduction.nuage(accepte: true)
            )
        }

        #expect(distant.recus.isEmpty)
        #expect(detection.nombreDAppels == 0)
    }
}

/// Troisieme critere : le moteur dans le nuage est explicitement opt in.
struct PorteDuNuageTests {
    @Test("Sans accord, rien ne part vers le moteur distant")
    func sansAccordRienNeSort() async throws {
        let local = MoteurCompteur.local()
        let distant = MoteurCompteur.distant()
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [local, distant],
            reseau: ReseauSuppose.joignable
        )

        let bulles = try await acteur.bulles(
            de: MaterielDeTraduction.planche(),
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: MaterielDeTraduction.nuage(accepte: false)
        )

        #expect(distant.nombreDAppels == 0)
        #expect(distant.recus.isEmpty)
        #expect(local.nombreDAppels == 1)
        #expect(bulles.allSatisfy { $0.moteur == .surLAppareil })
    }

    @Test("Une fois l accord donne, le moteur distant prend la main")
    func avecAccordLeMoteurDistantPrendLaMain() async throws {
        let local = MoteurCompteur.local()
        let distant = MoteurCompteur.distant()
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [local, distant],
            reseau: ReseauSuppose.joignable
        )

        let bulles = try await acteur.bulles(
            de: MaterielDeTraduction.planche(),
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: MaterielDeTraduction.nuage(accepte: true)
        )

        #expect(distant.nombreDAppels == 1)
        #expect(distant.recus.count == 2)
        #expect(local.nombreDAppels == 0)
        #expect(bulles.allSatisfy { $0.moteur == .dansLeNuage })
    }

    @Test("Retirer l accord ramene la traduction sur l appareil")
    func retirerLAccordRamenneSurLAppareil() async throws {
        let local = MoteurCompteur.local()
        let distant = MoteurCompteur.distant()
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [local, distant],
            reseau: ReseauSuppose.joignable
        )
        let page = try MaterielDeTraduction.planche()
        let avec = MaterielDeTraduction.nuage(accepte: true)

        _ = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: avec
        )

        let apres = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: avec.sansConsentement()
        )

        #expect(distant.nombreDAppels == 1)
        #expect(local.nombreDAppels == 1)
        #expect(apres.allSatisfy { $0.moteur == .surLAppareil })
    }
}

/// Ce que la traduction fait quand elle ne peut pas aboutir.
struct EchecsDeTraductionTests {
    @Test("L interrupteur inactif ne fait rien detecter ni rien traduire")
    func linterrupteurInactifNeFaitRien() async throws {
        let local = MoteurCompteur.local()
        let detection = DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut)
        let acteur = MaterielDeTraduction.traducteur(
            detection: detection,
            moteurs: [local],
            reseau: ReseauSuppose.joignable
        )

        let bulles = try await acteur.bulles(
            de: MaterielDeTraduction.planche(),
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: .parDefaut
        )

        #expect(bulles.isEmpty)
        #expect(detection.nombreDAppels == 0)
        #expect(local.nombreDAppels == 0)
    }

    @Test("Un moteur absent est nomme plutot que devine")
    func leMoteurAbsentEstNomme() async throws {
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [],
            reseau: ReseauSuppose.joignable
        )
        let page = try MaterielDeTraduction.planche()

        await #expect(throws: ErreurDeTraduction.moteurIndisponible(moteur: .surLAppareil)) {
            try await acteur.bulles(
                de: page,
                pour: MaterielDeTraduction.cle,
                sens: .droiteGauche,
                reglages: .arme
            )
        }
    }

    @Test("Une reponse tronquee est refusee plutot qu appariee de travers")
    func laReponseTronqueeEstRefusee() async throws {
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [MoteurBavard()],
            reseau: ReseauSuppose.joignable
        )
        let page = try MaterielDeTraduction.planche()

        await #expect(throws: ErreurDeTraduction.reponseIncoherente(attendus: 2, recus: 1)) {
            try await acteur.bulles(
                de: page,
                pour: MaterielDeTraduction.cle,
                sens: .droiteGauche,
                reglages: MaterielDeTraduction.nuage(accepte: true)
            )
        }
    }

    @Test("Une detection en echec laisse la page lisible telle quelle")
    func laDetectionEnEchecLaisseLaPageLisible() async throws {
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionEnEchec(),
            moteurs: [MoteurCompteur.local()],
            reseau: ReseauSuppose.coupe
        )
        let page = try MaterielDeTraduction.planche()

        let bulles = await acteur.bullesOuAucune(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: .arme
        )

        #expect(bulles.isEmpty)
    }
}

/// Le resultat n est jamais recalcule, et ne l est qu au bon moment.
struct CacheDeTraductionTests {
    @Test("Une planche deja traduite ne repasse ni par la detection ni par le moteur")
    func laPlancheDejaTraduiteNeRepassePas() async throws {
        let local = MoteurCompteur.local()
        let detection = DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut)
        let acteur = MaterielDeTraduction.traducteur(
            detection: detection,
            moteurs: [local],
            reseau: ReseauSuppose.coupe
        )
        let page = try MaterielDeTraduction.planche()

        for _ in 0..<4 {
            _ = try await acteur.bulles(
                de: page,
                pour: MaterielDeTraduction.cle,
                sens: .droiteGauche,
                reglages: .arme
            )
        }

        #expect(detection.nombreDAppels == 1)
        #expect(local.nombreDAppels == 1)
        #expect(await acteur.nombreDeTraductions == 1)
    }

    @Test("Changer de langue cible relance la traduction")
    func changerDeLangueRelanceLaTraduction() async throws {
        let local = MoteurCompteur.local()
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [local],
            reseau: ReseauSuppose.coupe
        )
        let page = try MaterielDeTraduction.planche()

        _ = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: ReglagesDeTraduction(actif: true, langueCible: .francais)
        )
        _ = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: ReglagesDeTraduction(actif: true, langueCible: .english)
        )

        #expect(local.nombreDAppels == 2)
    }

    @Test("Changer de sens de lecture ne relance rien, seul l ordre change")
    func changerDeSensNeRelanceRien() async throws {
        let local = MoteurCompteur.local()
        let acteur = MaterielDeTraduction.traducteur(
            detection: DetectionFigee(rendues: BullesDeTest.deuxBullesEnHaut),
            moteurs: [local],
            reseau: ReseauSuppose.coupe
        )
        let page = try MaterielDeTraduction.planche()

        let droiteGauche = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .droiteGauche,
            reglages: .arme
        )
        let gaucheDroite = try await acteur.bulles(
            de: page,
            pour: MaterielDeTraduction.cle,
            sens: .gaucheDroite,
            reglages: .arme
        )

        #expect(local.nombreDAppels == 1)
        #expect(droiteGauche.first?.texteDOrigine == "a droite")
        #expect(gaucheDroite.first?.texteDOrigine == "a gauche")
    }
}

/// Le filtrage des lectures douteuses, applique avant toute traduction.
struct FiltrageDesLecturesTests {
    @Test("Une lecture sous le seuil de confiance est ecartee")
    func laLectureDouteuseEstEcartee() throws {
        let sure = try #require(
            BullesDeTest.bulle(abscisse: 0.05, ordonnee: 0.05, texte: "sure", confiance: 0.9)
        )
        let douteuse = try #require(
            BullesDeTest.bulle(abscisse: 0.6, ordonnee: 0.6, texte: "douteuse", confiance: 0.2)
        )

        let retenues = TraducteurDeBulles.retenir(
            [sure, douteuse],
            seuil: 0.6,
            recouvrementMaximal: 0.5
        )

        #expect(retenues.map(\.texte) == ["sure"])
    }

    @Test("Deux lectures du meme cadre ne posent qu une surimpression")
    func lesLecturesQuiSeRecouvrentSontFondues() throws {
        let premiere = try #require(
            BullesDeTest.bulle(abscisse: 0.10, ordonnee: 0.10, texte: "sure", confiance: 0.95)
        )
        let seconde = try #require(
            BullesDeTest.bulle(abscisse: 0.11, ordonnee: 0.11, texte: "moins sure", confiance: 0.7)
        )

        let retenues = TraducteurDeBulles.retenir(
            [premiere, seconde],
            seuil: 0.6,
            recouvrementMaximal: 0.5
        )

        #expect(retenues.map(\.texte) == ["sure"])
    }
}
