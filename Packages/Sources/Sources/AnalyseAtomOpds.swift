import Foundation

//
// AnalyseAtomOpds
//
// La lecture d un flux OPDS 1.2, qui est un document Atom.
//
// L analyse passe par `XMLParser` et non par un balayage de texte, pour les
// memes trois raisons que `ComicInfo.xml` de la section 5.3 : l encodage, que
// seul libxml2 sait deduire de la declaration du document, les entites et les
// sections litterales, qu un resume porte systematiquement, et la tolerance a
// la troncature, qui laisse valable tout ce qui precede la cassure.
//
// Une difference avec `ComicInfo.xml` merite d etre dite. La, un document casse
// ne doit jamais empecher l ouverture d un chapitre, et l analyse rend donc nul
// sans jamais lever. Ici un flux illisible veut dire que la source ne repond
// pas ce qu elle annonce, et l utilisateur doit le savoir : l analyse rend nul,
// et c est l appelant qui en fait `ErreurReseau.reponseIllisible`.
//
// Les noms d elements arrivent avec leur prefixe de nom d espace, `dc:language`
// et `pse:count` par exemple, parce que le traitement des noms d espaces reste
// desactive. Ce n est pas un oubli. L activer obligerait a connaitre l URI
// exacte de chaque espace, et les serveurs reels en declarent des variantes.
// Comparer sur le nom local est plus tolerant, et aucun flux OPDS ne porte deux
// elements de meme nom local dans deux espaces differents.
//

/// Lecture d un flux OPDS 1.2 au format Atom.
enum AnalyseAtomOpds {
    /// Analyse les octets d un flux Atom.
    ///
    /// - Returns: le flux lu, ou nul quand le document ne porte ni entree ni
    ///   lien, ce qui veut dire qu il n etait pas un flux OPDS.
    static func analyser(_ donnees: Data) -> FluxOpds? {
        guard donnees.isEmpty == false else {
            return nil
        }

        let collecteur = CollecteurAtom()
        let analyseur = XMLParser(data: donnees)
        analyseur.delegate = collecteur

        // Le verdict est ignore volontairement. Un document tronque rend faux
        // alors que les entrees deja fermees sont exploitables, et une page de
        // catalogue amputee de sa fin vaut mieux qu une source muette.
        _ = analyseur.parse()

        let flux = collecteur.flux()

        return flux.entrees.isEmpty && flux.liens.isEmpty ? nil : flux
    }
}

///
/// Le collecteur est une classe parce que `XMLParserDelegate` l exige. Il ne
/// sort jamais de `analyser(_:)`, n est jamais partage entre taches, et n a donc
/// pas a etre `Sendable`.
///
private final class CollecteurAtom: NSObject, XMLParserDelegate {
    /// Les champs scalaires que l analyse retient, par nom local.
    ///
    /// La liste est fermee pour que les elements imbriques d un resume en HTML
    /// ne viennent pas interrompre la lecture du resume qui les contient.
    private static let champsRetenus: Set<String> = [
        "id",
        "title",
        "updated",
        "published",
        "issued",
        "summary",
        "content",
        "language",
        "name",
    ]

    private var titreDuFlux: String?
    private var liensDuFlux: [LienOpds] = []
    private var entrees: [EntreeOpds] = []

    private var dansUneEntree = false
    private var dansUnAuteur = false
    private var profondeurDeLEntree = 0
    private var profondeur = 0

    private var champs: [String: String] = [:]
    private var auteurs: [String] = []
    private var categories: [String] = []
    private var liensDeLEntree: [LienOpds] = []

    private var elementCourant: String?
    private var texteCourant = ""

    /// Le flux assemble a partir de ce qui a ete lu.
    func flux() -> FluxOpds {
        FluxOpds(titre: titreDuFlux, liens: liensDuFlux, entrees: entrees)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        profondeur += 1

        switch Self.nomLocal(elementName) {
        case "entry":
            commencerUneEntree()
        case "link":
            ajouterUnLien(attributeDict)
        case "author":
            dansUnAuteur = true
        case "category":
            ajouterUneCategorie(attributeDict)
        case let nom where Self.champsRetenus.contains(nom):
            elementCourant = nom
            texteCourant = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard elementCourant != nil else {
            return
        }

        texteCourant += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard elementCourant != nil, let texte = String(data: CDATABlock, encoding: .utf8) else {
            return
        }

        texteCourant += texte
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let nom = Self.nomLocal(elementName)

        if nom == "entry", dansUneEntree, profondeur == profondeurDeLEntree {
            terminerLEntree()
        } else if nom == "author" {
            dansUnAuteur = false
        } else if elementCourant == nom {
            rangerLeTexte(de: nom)
        }

        profondeur -= 1
    }

    // MARK: Assemblage

    private func commencerUneEntree() {
        dansUneEntree = true
        profondeurDeLEntree = profondeur
        champs = [:]
        auteurs = []
        categories = []
        liensDeLEntree = []
    }

    private func terminerLEntree() {
        dansUneEntree = false

        guard let titre = champs["title"]?.sansBlancs else {
            // Une entree sans titre n a rien a montrer a l ecran. La compter
            // quand meme ferait une ligne vide dans le catalogue, que rien ne
            // permettrait d ouvrir ni de comprendre.
            return
        }

        entrees.append(
            EntreeOpds(
                identifiant: champs["id"]?.sansBlancs,
                titre: titre,
                auteurs: auteurs.sansDoublons(),
                resume: champs["summary"]?.sansBlancs ?? champs["content"]?.sansBlancs,
                categories: categories.sansDoublons(),
                langue: champs["language"]?.sansBlancs,
                miseAJour: LecteurDeDateDeServeur.lire(
                    champs["issued"] ?? champs["published"] ?? champs["updated"]
                ),
                liens: liensDeLEntree
            )
        )
    }

    private func ajouterUnLien(_ attributs: [String: String]) {
        guard let adresse = Self.attribut(attributs, "href")?.sansBlancs else {
            return
        }

        let lien = LienOpds(
            relation: Self.attribut(attributs, "rel") ?? "",
            type: Self.attribut(attributs, "type"),
            adresse: adresse,
            titre: Self.attribut(attributs, "title"),
            nombreDePages: Self.attribut(attributs, "count").flatMap(Int.init)
        )

        if dansUneEntree {
            liensDeLEntree.append(lien)
        } else {
            liensDuFlux.append(lien)
        }
    }

    private func ajouterUneCategorie(_ attributs: [String: String]) {
        guard dansUneEntree else {
            return
        }
        guard let nom = (Self.attribut(attributs, "label") ?? Self.attribut(attributs, "term"))?.sansBlancs else {
            return
        }

        categories.append(nom)
    }

    /// Range le texte accumule dans le champ qui vient de se fermer.
    private func rangerLeTexte(de nom: String) {
        defer {
            elementCourant = nil
            texteCourant = ""
        }

        guard let valeur = texteCourant.sansBlancs else {
            return
        }

        if nom == "name", dansUnAuteur, dansUneEntree {
            auteurs.append(valeur)
        } else if dansUneEntree {
            // Le premier gagne. Un flux qui repete un champ a l interieur d une
            // entree le fait dans un element imbriquee, et la valeur de tete est
            // celle qui decrit l entree elle meme.
            champs[nom] = champs[nom] ?? valeur
        } else if nom == "title", profondeur == Self.profondeurDuTitreDuFlux {
            titreDuFlux = titreDuFlux ?? valeur
        }
    }

    /// Profondeur du titre du flux, la racine valant un.
    private static let profondeurDuTitreDuFlux = 2

    // MARK: Lecture des noms

    /// Le nom sans son prefixe de nom d espace, en minuscules.
    private static func nomLocal(_ nom: String) -> String {
        guard let separateur = nom.lastIndex(of: ":") else {
            return nom.lowercased()
        }

        return String(nom[nom.index(after: separateur)...]).lowercased()
    }

    /// La valeur de l attribut portant ce nom local, quel que soit son prefixe.
    private static func attribut(_ attributs: [String: String], _ nom: String) -> String? {
        if let direct = attributs[nom] {
            return direct
        }

        return attributs.first { nomLocal($0.key) == nom }?.value
    }
}
