import Foundation
import Testing
@testable import ImagePipeline

/// Couvre le quatrieme point de la section 6.1 : cache disque separe, plafond
/// configurable, purge par date d acces.
struct CacheDisqueDePagesTests {
    private let chapitre = UUID()

    /// Cent mille octets par page, deux cent cinquante mille de plafond. Deux
    /// pages tiennent, la troisieme fait purger.
    private let poidsDUnePage = 100_000
    private let plafond = PlafondDeCacheDisque(octets: 250_000)

    // MARK: Plafond

    @Test("Le plafond configure tient depot apres depot")
    func plafondJamaisDepasse() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let temps = HorlogeReglable()
        let cache = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: plafond,
            horloge: temps.horloge
        )

        for index in 0..<12 {
            try await cache.deposer(page(), pour: cle(index))
            temps.avancer()

            #expect(await cache.octetsUtilises <= plafond.octets)

            // Le compte du cache pourrait mentir. La mesure sur le systeme de
            // fichiers, elle, ne ment pas.
            #expect(DossierDeTest.octetsSurLeDisque(dossier) <= plafond.octets)
        }

        #expect(await cache.nombreDEntrees == 2)
    }

    @Test("Un plafond reduit entre deux sessions est applique a l ouverture")
    func plafondReduitApresRedemarrage() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let temps = HorlogeReglable()
        let large = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: PlafondDeCacheDisque(octets: 1_000_000),
            horloge: temps.horloge
        )

        for index in 0..<8 {
            try await large.deposer(page(), pour: cle(index))
            temps.avancer()
        }

        #expect(await large.nombreDEntrees == 8)

        let etroit = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: plafond,
            horloge: temps.horloge
        )

        #expect(await etroit.octetsUtilises <= plafond.octets)
        #expect(DossierDeTest.octetsSurLeDisque(dossier) <= plafond.octets)

        // Les deux dernieres lues sont les deux dernieres deposees.
        #expect(await etroit.contient(cle(7)))
        #expect(await etroit.contient(cle(6)))
        #expect(await etroit.contient(cle(0)) == false)
    }

    @Test("Une page plus lourde que le plafond est refusee")
    func pageTropLourdeRefusee() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        let enorme = Data(repeating: 0x41, count: plafond.octets + 1)

        #expect(try await cache.deposer(enorme, pour: cle(0)) == false)
        #expect(await cache.nombreDEntrees == 0)
        #expect(DossierDeTest.octetsSurLeDisque(dossier) == 0)
    }

    // MARK: Purge par date d acces

    @Test("La purge supprime la moins recemment lue, pas la moins recemment ecrite")
    func purgeParDateDAcces() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let temps = HorlogeReglable()
        let cache = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: plafond,
            horloge: temps.horloge
        )

        try await cache.deposer(page(), pour: cle(0))
        temps.avancer()
        try await cache.deposer(page(), pour: cle(1))
        temps.avancer()

        // La page zero est relue, elle cesse d etre la plus ancienne bien
        // qu elle reste la plus anciennement ecrite.
        #expect(await cache.donnees(pour: cle(0)) != nil)
        temps.avancer()

        try await cache.deposer(page(), pour: cle(2))

        #expect(await cache.contient(cle(0)))
        #expect(await cache.contient(cle(1)) == false)
        #expect(await cache.contient(cle(2)))
    }

    @Test("La lecture met la date d acces a jour")
    func lectureDateLAcces() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let temps = HorlogeReglable()
        let cache = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: plafond,
            horloge: temps.horloge
        )

        try await cache.deposer(page(), pour: cle(0))
        let depot = try #require(await cache.dateDAcces(de: cle(0)))

        temps.avancer(de: 60)
        #expect(await cache.donnees(pour: cle(0)) != nil)

        let lecture = try #require(await cache.dateDAcces(de: cle(0)))
        #expect(lecture > depot)
    }

    @Test("La date d acces survit a un redemarrage")
    func dateDAccesPersistee() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let temps = HorlogeReglable()
        let premiere = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: PlafondDeCacheDisque(octets: 1_000_000),
            horloge: temps.horloge
        )

        try await premiere.deposer(page(), pour: cle(0))
        temps.avancer()
        try await premiere.deposer(page(), pour: cle(1))
        temps.avancer(de: 60)

        // Relue apres coup, la page zero doit survivre a la purge que la
        // seconde session declenche.
        #expect(await premiere.donnees(pour: cle(0)) != nil)

        let seconde = try await CacheDisqueDePages(
            dossier: dossier,
            plafond: PlafondDeCacheDisque(octets: 150_000),
            horloge: temps.horloge
        )

        #expect(await seconde.contient(cle(0)))
        #expect(await seconde.contient(cle(1)) == false)
    }

    // MARK: Contenu

    @Test("Ce qui est depose est rendu octet pour octet")
    func depotEtRelecture() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        let contenu = page()

        try await cache.deposer(contenu, pour: cle(0))

        #expect(await cache.donnees(pour: cle(0)) == contenu)
        #expect(await cache.donnees(pour: cle(5)) == nil)
    }

    @Test("Deux variantes de la meme page sont deux entrees distinctes")
    func variantesDistinctes() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        let brute = ClePage(chapitre: chapitre, index: 0)
        let rognee = ClePage(chapitre: chapitre, index: 0, variante: "rognage-4")

        try await cache.deposer(Data(repeating: 0x01, count: 32), pour: brute)
        try await cache.deposer(Data(repeating: 0x02, count: 32), pour: rognee)

        let contenuBrut = await cache.donnees(pour: brute)
        let contenuRogne = await cache.donnees(pour: rognee)

        #expect(await cache.nombreDEntrees == 2)
        #expect(contenuBrut != contenuRogne)
        #expect(contenuBrut != nil)
    }

    @Test("Vider le cache supprime les fichiers, pas seulement le compte")
    func viderSupprimeLesFichiers() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        try await cache.deposer(page(), pour: cle(0))
        await cache.vider()

        #expect(await cache.nombreDEntrees == 0)
        #expect(await cache.octetsUtilises == 0)
        #expect(DossierDeTest.octetsSurLeDisque(dossier) == 0)
    }

    @Test("Une entree dont le fichier a disparu est oubliee plutot que rendue")
    func fichierDisparuOublie() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        try await cache.deposer(page(), pour: cle(0))

        let fichier = dossier.appendingPathComponent(cle(0).empreinte, isDirectory: false)
        try FileManager.default.removeItem(at: fichier)

        #expect(await cache.donnees(pour: cle(0)) == nil)
        #expect(await cache.nombreDEntrees == 0)
        #expect(await cache.octetsUtilises == 0)
    }

    @Test("Un fichier laisse par une ecriture interrompue est compte et purge")
    func fichierOrphelinAdopte() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let orphelin = dossier.appendingPathComponent(cle(99).empreinte, isDirectory: false)
        try Data(repeating: 0x7F, count: 400_000).write(to: orphelin)

        let cache = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)

        // Ni ignore, ni conserve en silence : compte, puis purge parce qu il
        // depasse a lui seul le plafond.
        #expect(await cache.octetsUtilises == 0)
        #expect(DossierDeTest.octetsSurLeDisque(dossier) == 0)
    }

    @Test("Le cache disque ne connait pas le cache memoire")
    func cachesSepares() async throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let disque = try await CacheDisqueDePages(dossier: dossier, plafond: plafond)
        let memoire = CacheMemoireDePages()
        let image = try #require(ImageDeTest.page())

        try await disque.deposer(page(), pour: cle(0))
        await memoire.deposer(image, pour: cle(0))
        await memoire.reagirAUneAlerteMemoire()

        // L alerte memoire a vide la memoire. Le disque, lui, n a pas bouge.
        #expect(await memoire.nombreDePages == 0)
        #expect(await disque.contient(cle(0)))
    }

    private func page() -> Data {
        Data(repeating: 0x2A, count: poidsDUnePage)
    }

    private func cle(_ index: Int) -> ClePage {
        ClePage(chapitre: chapitre, index: index)
    }
}
