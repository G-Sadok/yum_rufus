import Foundation

//
// AnalyseurDeComicInfo
//
// Lecture de `ComicInfo.xml`, source prioritaire de metadonnees selon la
// section 5.3 du cahier de developpement.
//
// L analyse passe par `XMLParser` plutot que par un balayage de texte ecrit
// ici. Trois raisons, dans l ordre ou elles auraient fait mal.
//
// 1. L encodage. Un `ComicInfo.xml` n est pas toujours en UTF-8. Les outils de
//    catalogage en produisent en ISO-8859-1 et en UTF-16, avec ou sans marque
//    d ordre. Decoder les octets nous memes supposerait de lire la declaration
//    XML avant de savoir la lire, ce qui est circulaire. `XMLParser` s appuie
//    sur libxml2, qui sait le faire.
// 2. Les entites et les sections litterales. Un resume porte `&amp;`, `&#233;`
//    ou un bloc CDATA. Un balayage naif rendrait le texte brut a l utilisateur.
// 3. La tolerance. Un fichier tronque arrete l analyse a l endroit exact de la
//    cassure, et tout ce qui precede reste valable.
//
// Aucune fonction de ce fichier ne leve. Un fichier de metadonnees casse ne
// doit jamais empecher l ouverture d un chapitre : la seule sanction possible
// est de rendre nul.
//

/// Lecture du document `ComicInfo.xml`.
public enum AnalyseurDeComicInfo {
    /// Analyse les octets d un `ComicInfo.xml`.
    ///
    /// - Returns: les metadonnees trouvees, ou nul si le document est vide,
    ///   illisible, ou ne porte aucun champ connu. Un document tronque rend ce
    ///   qui precede la cassure.
    public static func analyser(_ donnees: Data) -> MetadonneesComic? {
        guard donnees.isEmpty == false else { return nil }

        let collecteur = CollecteurDeComicInfo()
        let analyseur = XMLParser(data: donnees)
        analyseur.delegate = collecteur

        // Le verdict est volontairement ignore. Un document tronque rend faux
        // alors que les champs deja fermes sont parfaitement exploitables, et
        // c est exactement le cas que la section 5.3 demande de ne pas laisser
        // interrompre l ouverture du chapitre.
        _ = analyseur.parse()

        let metadonnees = collecteur.metadonnees()

        return metadonnees.estVide ? nil : metadonnees
    }
}

///
/// Le collecteur est une classe parce que `XMLParserDelegate` l exige. Il ne
/// sort jamais de `analyser(_:)`, n est jamais partage entre taches, et n a donc
/// pas a etre `Sendable`.
///
private final class CollecteurDeComicInfo: NSObject, XMLParserDelegate {
    /// Valeur de chaque element fils de la racine, indexee par nom minuscule.
    private var champs: [String: String] = [:]

    /// Nom de l element en cours de lecture, quand il est fils de la racine.
    private var elementEnCours: String?

    private var texteEnCours = ""

    /// Profondeur atteinte dans le document, la racine valant un.
    private var profondeur = 0

    /// Profondeur des elements qui portent les champs de `ComicInfo`.
    private static let profondeurDesChamps = 1

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        // Seuls les fils directs de la racine sont des champs. Sans ce test,
        // les elements `Page` du bloc `Pages` viendraient ecraser les champs du
        // meme nom, et un `ComicInfo` imbrique dans un autre document serait lu
        // comme s il etait a la racine.
        if profondeur == Self.profondeurDesChamps {
            elementEnCours = elementName.lowercased()
            texteEnCours = ""
        }

        profondeur += 1
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard elementEnCours != nil else { return }

        texteEnCours += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard elementEnCours != nil else { return }
        guard let texte = String(data: CDATABlock, encoding: .utf8) else { return }

        texteEnCours += texte
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        profondeur -= 1

        guard profondeur == Self.profondeurDesChamps,
              elementEnCours == elementName.lowercased()
        else {
            return
        }

        let valeur = texteEnCours.trimmingCharacters(in: .whitespacesAndNewlines)
        if valeur.isEmpty == false {
            champs[elementName.lowercased()] = valeur
        }

        elementEnCours = nil
        texteEnCours = ""
    }

    /// Traduit les champs collectes dans le vocabulaire du projet.
    func metadonnees() -> MetadonneesComic {
        MetadonneesComic(
            serie: champs["series"],
            titre: champs["title"],
            numero: champs["number"],
            volume: champs["volume"].flatMap(Int.init),
            langue: champs["languageiso"],
            resume: champs["summary"],
            auteurs: liste("writer"),
            dessinateurs: liste("penciller"),
            genres: liste("genre"),
            editeur: champs["publisher"],
            sensDeLecture: sensDeLecture(),
            nombrePagesAnnonce: champs["pagecount"].flatMap(Int.init)
        )
    }

    /// Decoupe un champ multivalue.
    ///
    /// Le format range plusieurs auteurs dans un seul element, separes par des
    /// virgules. C est la seule convention que les outils respectent.
    private func liste(_ nom: String) -> [String] {
        guard let brut = champs[nom] else { return [] }

        return brut
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    /// Traduit le champ `Manga` en sens de lecture.
    ///
    /// Le format admet quatre valeurs : `Unknown`, `No`, `Yes` et
    /// `YesAndRightToLeft`. Seules deux tranchent. `Yes` dit que le titre est un
    /// manga sans dire dans quel sens il se lit, et beaucoup de manhwa sont
    /// etiquetes ainsi alors qu ils se lisent de gauche a droite : en tirer un
    /// sens droite a gauche retournerait la lecture d une partie du catalogue.
    /// Un champ qui ne tranche pas laisse donc le reglage global decider.
    private func sensDeLecture() -> SensDeLecture? {
        switch champs["manga"]?.lowercased() {
        case "yesandrighttoleft": .droiteGauche
        case "no": .gaucheDroite
        default: nil
        }
    }
}
