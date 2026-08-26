import Core
import Foundation
import Testing

/// Couvre le langage declaratif lui meme : chemins JSON, selecteurs et
/// gabarits.
///
/// Chaque test qui refuse une forme sert le premier critere. Ce qui n est pas
/// analysable ne s execute pas, et surtout ne se transforme pas en calcul :
/// c est pour cela que les filtres de JSONPath et les pseudo classes
/// fonctionnelles de CSS sont refuses ici plutot qu ignores.
struct CheminJsonTests {
    private static let document = ValeurJson.objet([
        "results": .liste([
            .objet(["id": .nombre(12), "title": .texte("Premiere")]),
            .objet(["id": .texte("b7"), "title": .texte("Seconde")]),
        ]),
        "total": .nombre(2),
        "next": .nul,
    ])

    @Test("Un chemin se relit sous sa forme canonique")
    func formeCanonique() throws {
        #expect(try CheminJson("$.results[*].id").texte == "$.results[*].id")
        #expect(try CheminJson("results[0].title").texte == "$.results[0].title")
        #expect(try CheminJson("$").estRacine)
        #expect(try CheminJson("").texte == "$")
    }

    @Test("Une etoile rend tous les elements")
    func toutesLesValeurs() throws {
        let chemin = try CheminJson("$.results[*].id")
        let valeurs = chemin.valeurs(dans: Self.document)

        #expect(valeurs.compactMap(\.texteLisible) == ["12", "b7"])
    }

    @Test("Un rang rend un seul element")
    func unSeulElement() throws {
        let chemin = try CheminJson("$.results[1].title")

        #expect(chemin.valeur(dans: Self.document)?.texteLisible == "Seconde")
    }

    @Test("Un chemin qui ne designe rien rend une liste vide")
    func cheminSansResultat() throws {
        #expect(try CheminJson("$.absent.encore").valeurs(dans: Self.document).isEmpty)
        #expect(try CheminJson("$.results[7]").valeurs(dans: Self.document).isEmpty)
        #expect(try CheminJson("$.total[*]").valeurs(dans: Self.document).isEmpty)
    }

    @Test("Un chemin racine rend la valeur elle meme")
    func cheminRacine() throws {
        #expect(try CheminJson("$").valeur(dans: .texte("brut"))?.texteLisible == "brut")
    }

    @Test("Un filtre de JSONPath est refuse")
    func filtreRefuse() {
        for texte in ["$.results[?(@.id > 2)]", "$.results[(@.length-1)]", "$..id", "$.results[*] + 1"] {
            #expect(throws: ErreurDExtension.self, "\(texte) devrait etre refuse") {
                try CheminJson(texte)
            }
        }
    }

    @Test("Un nombre entier rendu en texte ne gagne pas de decimale")
    func nombreEnTexte() {
        #expect(ValeurJson.nombre(12).texteLisible == "12")
        #expect(ValeurJson.nombre(10.5).texteLisible == "10.5")
        #expect(ValeurJson.texte("18").nombreLisible == 18)
        #expect(ValeurJson.nul.texteLisible == nil)
    }

    @Test("Un document JSON quelconque se lit sans schema")
    func lectureSansSchema() throws {
        let lu = try ValeurJson(donnees: Data("""
        { "a": [1, "deux", true, null], "b": { "c": 3.5 } }
        """.utf8))

        #expect(lu.entrees?["a"]?.elements.count == 4)
        #expect(lu.clesPresentes == ["a", "b", "c"])
        #expect(lu.entrees?["b"]?.entrees?["c"]?.nombreLisible == 3.5)
    }
}

/// Couvre le sous ensemble de CSS que l interprete applique.
struct SelecteurHtmlTests {
    @Test("Un selecteur se relit sous sa forme canonique")
    func formeCanonique() throws {
        #expect(try SelecteurHtml("div.serie a.titre").texte == "div.serie a.titre")
        #expect(try SelecteurHtml("ul#chapitres>li").texte == "ul#chapitres > li")
        #expect(try SelecteurHtml("IMG[SRC]").texte == "img[src]")
    }

    @Test("Les quatre comparaisons d attribut se lisent")
    func comparaisonsDAttribut() throws {
        #expect(try SelecteurHtml("a[href=/serie]").etapes.first?.attributs.first?.comparaison == .egale)
        #expect(try SelecteurHtml("a[href*=serie]").etapes.first?.attributs.first?.comparaison == .contient)
        #expect(try SelecteurHtml("a[href^=/serie]").etapes.first?.attributs.first?.comparaison == .commencePar)
        #expect(try SelecteurHtml("img[src$=.jpg]").etapes.first?.attributs.first?.comparaison == .finitPar)
        #expect(try SelecteurHtml("img[src]").etapes.first?.attributs.first?.comparaison == .presence)
    }

    @Test("Une valeur d attribut entre guillemets perd ses guillemets")
    func valeurEntreGuillemets() throws {
        let condition = try SelecteurHtml("a[rel=\"suivant\"]").etapes.first?.attributs.first

        #expect(condition?.valeur == "suivant")
        #expect(condition?.estSatisfaite(par: "suivant") == true)
        #expect(condition?.estSatisfaite(par: "precedent") == false)
        #expect(condition?.estSatisfaite(par: nil) == false)
    }

    @Test("Une pseudo classe fonctionnelle est refusee")
    func pseudoClasseRefusee() {
        for texte in ["li:nth-child(2n+1)", "div:has(> a)", "a:not(.externe)", "", "  ", ">"] {
            #expect(throws: ErreurDExtension.self, "\(texte) devrait etre refuse") {
                try SelecteurHtml(texte)
            }
        }
    }

    @Test("Une etape sans contrainte est refusee")
    func etapeSansContrainte() {
        #expect(throws: ErreurDExtension.self) {
            try SelecteurHtml("div .")
        }
        #expect(throws: ErreurDExtension.self) {
            try SelecteurHtml("div #")
        }
    }

    @Test("L etoile vaut n importe quelle balise")
    func etoile() throws {
        let selecteur = try SelecteurHtml("*[data-id]")

        #expect(selecteur.etapes.first?.balise == nil)
        #expect(selecteur.etapes.first?.attributs.first?.nom == "data-id")
    }
}

/// Couvre les gabarits d adresse, seul endroit ou une extension compose une
/// chaine, et donc seul endroit ou elle pourrait citer autre chose que ce que
/// nous lui donnons.
struct GabaritDeTexteTests {
    private static let contexte = ContexteDeGabarit(
        texteRecherche: "berserk",
        page: 3,
        langue: "fr",
        identifiantSerie: "s-12",
        identifiantChapitre: "c-7"
    )

    @Test("Un gabarit remplit les variables du contexte")
    func remplissage() throws {
        let gabarit = try GabaritDeTexte("/series/{identifiantSerie}/chapitres/{identifiantChapitre}")

        #expect(gabarit.remplir(Self.contexte) == "/series/s-12/chapitres/c-7")
    }

    @Test("Un gabarit sans variable rend son texte")
    func sansVariable() throws {
        #expect(try GabaritDeTexte("/recentes").remplir(Self.contexte) == "/recentes")
        #expect(try GabaritDeTexte("").remplir(Self.contexte).isEmpty)
    }

    @Test("Un gabarit annonce les variables qu il cite")
    func variablesCitees() throws {
        let gabarit = try GabaritDeTexte("{texteRecherche}-{page}")

        #expect(gabarit.variablesCitees == [.texteRecherche, .page])
        #expect(gabarit.remplir(Self.contexte) == "berserk-3")
        #expect(gabarit.texte == "{texteRecherche}-{page}")
    }

    @Test("Une variable inconnue est refusee")
    func variableInconnue() {
        #expect(throws: ErreurDExtension.variableInconnue(nom: "cleDApi")) {
            try GabaritDeTexte("/api?cle={cleDApi}")
        }
        #expect(throws: ErreurDExtension.variableInconnue(nom: "chemin/../etc")) {
            try GabaritDeTexte("{chemin/../etc}")
        }
    }

    @Test("Une accolade non fermee est refusee")
    func accoladeNonFermee() {
        #expect(throws: ErreurDExtension.self) {
            try GabaritDeTexte("/api?q={texteRecherche")
        }
    }
}
