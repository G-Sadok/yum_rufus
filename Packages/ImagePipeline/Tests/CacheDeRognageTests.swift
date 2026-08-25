import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Compte les analyses reellement lancees.
///
/// Le marqueur non verifie est sur : le compteur ne detient qu un entier,
/// protege par un verrou pris a chaque acces, et n expose aucune reference.
private final class CompteurDAnalyses: @unchecked Sendable {
    private let verrou = NSLock()
    private var compte = 0

    var total: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return compte
    }

    func incrementer() {
        verrou.lock()
        compte += 1
        verrou.unlock()
    }
}

/// Couvre la mise en cache du rognage : une zone n est mesuree qu une fois par
/// page et par jeu de parametres, et un changement de parametre ne peut jamais
/// faire ressortir une zone mesuree selon les anciens.
struct CacheDeRognageTests {
    private let chapitre = UUID()

    private func page(_ index: Int, variante: String = "") -> ClePage {
        ClePage(chapitre: chapitre, index: index, variante: variante)
    }

    private var zoneDeTest: ZoneUtile {
        ZoneUtile(origineX: 26, origineY: 46, taille: TailleEnPixels(largeur: 148, hauteur: 208))
    }

    // MARK: La cle integre les parametres

    @Test("Deux jeux de seuils differents donnent deux cles differentes")
    func lesSeuilsEntrentDansLaCle() {
        let stricte = ReglagesDeRognage(actif: true, seuilDeVariance: 0.0016)
        let large = ReglagesDeRognage(actif: true, seuilDeVariance: 0.02)

        #expect(
            CacheDeRognage.cle(pour: page(0), reglages: stricte)
                != CacheDeRognage.cle(pour: page(0), reglages: large)
        )
    }

    @Test("Chaque parametre pese dans la cle")
    func chaqueParametrePeseDansLaCle() {
        let reference = ReglagesDeRognage(actif: true)
        let variantes = [
            ReglagesDeRognage(actif: true, seuilDeVariance: 0.02),
            ReglagesDeRognage(actif: true, toleranceDeBlanc: 0.2),
            ReglagesDeRognage(actif: true, toleranceDeNoir: 0.2),
            ReglagesDeRognage(actif: true, margeDeSecurite: 12),
            ReglagesDeRognage(actif: true, partMinimaleConservee: 0.5),
            ReglagesDeRognage(actif: false),
        ]

        for variante in variantes {
            #expect(reference.empreinte != variante.empreinte)
        }
    }

    @Test("Deux reglages identiques donnent la meme cle")
    func reglagesIdentiquesMemeCle() {
        let premier = ReglagesDeRognage(actif: true, margeDeSecurite: 6)
        let second = ReglagesDeRognage(actif: true, margeDeSecurite: 6)

        #expect(
            CacheDeRognage.cle(pour: page(3), reglages: premier)
                == CacheDeRognage.cle(pour: page(3), reglages: second)
        )
    }

    @Test("La cle du rognage prolonge la variante deja portee par la page")
    func laVarianteDOrigineEstConservee() {
        let cle = CacheDeRognage.cle(pour: page(2, variante: "z=1600x2400"), reglages: .recommande)

        #expect(cle.variante.contains("z=1600x2400"))
        #expect(cle.variante.contains(ReglagesDeRognage.recommande.empreinte))
        #expect(cle.chapitre == chapitre)
        #expect(cle.index == 2)
    }

    @Test("Deux pages differentes ne partagent pas leur entree")
    func deuxPagesDeuxCles() {
        #expect(
            CacheDeRognage.cle(pour: page(0), reglages: .recommande)
                != CacheDeRognage.cle(pour: page(1), reglages: .recommande)
        )
    }

    @Test("L empreinte des reglages tient dans un nom de fichier de cache")
    func empreinteUtilisableSurDisque() {
        let empreinte = CacheDeRognage.cle(pour: page(0), reglages: .recommande).empreinte

        #expect(empreinte.count == 64)
        #expect(empreinte != CacheDeRognage.cle(pour: page(0), reglages: .parDefaut).empreinte)
    }

    // MARK: Le resultat est bien retenu

    @Test("Une zone deja mesuree n est pas remesuree")
    func mesureUneSeuleFois() async {
        let cache = CacheDeRognage()
        let compteur = CompteurDAnalyses()
        let zone = zoneDeTest

        for _ in 0..<3 {
            let rendue = await cache.zoneUtile(pour: page(0), reglages: .recommande) {
                compteur.incrementer()

                return zone
            }

            #expect(rendue == zone)
        }

        #expect(compteur.total == 1)
        await #expect(cache.nombreDEntrees == 1)
    }

    @Test("Un changement de parametre force une nouvelle mesure")
    func changementDeParametreForceLaMesure() async {
        let cache = CacheDeRognage()
        let compteur = CompteurDAnalyses()
        let zone = zoneDeTest
        let large = ReglagesDeRognage(actif: true, margeDeSecurite: 12)

        for reglages in [ReglagesDeRognage.recommande, large, .recommande, large] {
            _ = await cache.zoneUtile(pour: page(0), reglages: reglages) {
                compteur.incrementer()

                return zone
            }
        }

        #expect(compteur.total == 2)
        await #expect(cache.nombreDEntrees == 2)
    }

    @Test("Le rognage inactif ne partage pas l entree du rognage actif")
    func actifEtInactifSeparees() async {
        let cache = CacheDeRognage()
        let zone = zoneDeTest

        await cache.deposer(zone, pour: page(0), reglages: .recommande)

        await #expect(cache.zoneConnue(pour: page(0), reglages: .parDefaut) == nil)
        await #expect(cache.zoneConnue(pour: page(0), reglages: .recommande) == zone)
    }

    @Test("Une zone deposee se relit telle quelle")
    func depotPuisRelecture() async {
        let cache = CacheDeRognage()
        let zone = zoneDeTest

        await cache.deposer(zone, pour: page(7), reglages: .recommande)

        await #expect(cache.zoneConnue(pour: page(7), reglages: .recommande) == zone)
    }

    @Test("Vider le cache fait remesurer")
    func viderForceLaMesure() async {
        let cache = CacheDeRognage()
        let compteur = CompteurDAnalyses()
        let zone = zoneDeTest

        _ = await cache.zoneUtile(pour: page(0), reglages: .recommande) {
            compteur.incrementer()

            return zone
        }
        await cache.vider()
        _ = await cache.zoneUtile(pour: page(0), reglages: .recommande) {
            compteur.incrementer()

            return zone
        }

        #expect(compteur.total == 2)
    }

    @Test("Retirer une page n emporte pas les autres")
    func retraitCible() async {
        let cache = CacheDeRognage()
        let zone = zoneDeTest

        await cache.deposer(zone, pour: page(0), reglages: .recommande)
        await cache.deposer(zone, pour: page(1), reglages: .recommande)
        await cache.retirer(page(0), reglages: .recommande)

        await #expect(cache.zoneConnue(pour: page(0), reglages: .recommande) == nil)
        await #expect(cache.zoneConnue(pour: page(1), reglages: .recommande) == zone)
    }

    // MARK: Capacite

    @Test("Le cache ne depasse pas sa capacite et sacrifie la plus ancienne")
    func capaciteTenue() async {
        let cache = CacheDeRognage(capacite: 2)
        let zone = zoneDeTest

        for index in 0..<3 {
            await cache.deposer(zone, pour: page(index), reglages: .recommande)
        }

        await #expect(cache.nombreDEntrees == 2)
        await #expect(cache.zoneConnue(pour: page(0), reglages: .recommande) == nil)
        await #expect(cache.zoneConnue(pour: page(2), reglages: .recommande) == zone)
    }

    @Test("Une lecture rajeunit l entree et la met a l abri de l eviction")
    func lectureRajeunit() async {
        let cache = CacheDeRognage(capacite: 2)
        let zone = zoneDeTest

        await cache.deposer(zone, pour: page(0), reglages: .recommande)
        await cache.deposer(zone, pour: page(1), reglages: .recommande)
        _ = await cache.zoneConnue(pour: page(0), reglages: .recommande)
        await cache.deposer(zone, pour: page(2), reglages: .recommande)

        await #expect(cache.zoneConnue(pour: page(0), reglages: .recommande) == zone)
        await #expect(cache.zoneConnue(pour: page(1), reglages: .recommande) == nil)
    }

    // MARK: Bout en bout

    @Test("La zone rendue par le cache est celle que l analyse aurait mesuree")
    func memeZoneQueLAnalyse() async throws {
        let matrice = try #require(PageAMarges.avecContenu(
            taille: TailleEnPixels(largeur: 200, hauteur: 300),
            fond: 255,
            bloc: PageAMarges.Bloc(origineX: 30, origineY: 50, largeur: 140, hauteur: 200),
            contenu: PageAMarges.Contenu(clair: 200, sombre: 40)
        ))
        let page = try #require(PageAMarges.page(de: matrice))
        let rognage = RognageAutomatique(reglages: .recommande)
        let cache = CacheDeRognage()
        let cle = self.page(0, variante: "z=200x300")

        let mesuree = await cache.zoneUtile(pour: cle, reglages: rognage.reglages) {
            rognage.zoneUtile(de: page)
        }
        let relue = await cache.zoneConnue(pour: cle, reglages: rognage.reglages)

        #expect(mesuree == rognage.zoneUtile(de: matrice))
        #expect(relue == mesuree)
    }
}
