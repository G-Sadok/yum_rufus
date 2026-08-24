import Testing
@testable import Sources

/// Le numero de chapitre est deduit du nom de fichier, faute de convention.
/// Ces cas viennent de noms reellement rencontres dans des dossiers de manga.
struct NumeroDeChapitreTests {
    @Test(
        "Un marqueur de chapitre donne le numero",
        arguments: [
            ("Chapitre 12.cbz", 12.0),
            ("Chapter 12.cbz", 12.0),
            ("Ch.03.cbz", 3.0),
            ("ch 3.cbz", 3.0),
            ("c05.cbz", 5.0),
            ("Episode 7.cbz", 7.0),
            ("#42.cbz", 42.0),
            ("Chapitre 10.5.cbz", 10.5),
            ("Chapitre 10,5.cbz", 10.5),
        ]
    )
    func marqueurDeChapitre(nom: String, attendu: Double) {
        #expect(NumeroDeChapitre.extraire(de: nom) == attendu)
    }

    @Test("Le marqueur de chapitre l emporte sur le volume")
    func chapitreAvantVolume() {
        #expect(NumeroDeChapitre.extraire(de: "Serie - Vol.2 Ch.03 - titre.cbz") == 3)
    }

    @Test(
        "Sans marqueur, le dernier nombre du nom fait le numero",
        arguments: [
            ("012.cbz", 12.0),
            ("One Piece 1044.cbz", 1044.0),
            ("Serie 2020 - 15.cbz", 15.0),
        ]
    )
    func dernierNombre(nom: String, attendu: Double) {
        #expect(NumeroDeChapitre.extraire(de: nom) == attendu)
    }

    @Test("Un numero de volume seul ne devient jamais un numero de chapitre")
    func volumeSeulIgnore() {
        #expect(NumeroDeChapitre.extraire(de: "Vol.2.cbz") == nil)
        #expect(NumeroDeChapitre.extraire(de: "Tome 4.cbz") == nil)
    }

    @Test("L extension ne fournit jamais le numero")
    func extensionIgnoree() {
        #expect(NumeroDeChapitre.extraire(de: "serie.7z") == nil)
        #expect(NumeroDeChapitre.extraire(de: "serie.cb7") == nil)
    }

    @Test("Un nom sans nombre ne rend aucun numero")
    func aucunNombre() {
        #expect(NumeroDeChapitre.extraire(de: "Prologue.cbz") == nil)
        #expect(NumeroDeChapitre.extraire(de: "Tome unique.cbz") == nil)
    }

    @Test("Un mot commencant par ch ne se prend pas pour un marqueur")
    func motQuiCommenceParCh() {
        #expect(NumeroDeChapitre.extraire(de: "Chirurgien 12.cbz") == 12)
    }
}
