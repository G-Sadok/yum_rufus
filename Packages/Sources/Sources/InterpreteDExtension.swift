import Core
import Foundation

//
// InterpreteDExtension
//
// L executeur de la section 4.3 : un interprete que nous ecrivons, qui applique
// les regles declaratives, et qui n execute aucun code fourni par l extension.
//
// Tout ce fichier ne fait que trois choses. Assembler une adresse a partir d un
// gabarit et d un contexte que nous fournissons. Lire des valeurs a un chemin
// ou a un selecteur. Ranger ces valeurs dans les entites du protocole. Il n y a
// nulle part de branche dont la condition viendrait du manifeste, ni de nom
// tire du manifeste qui deciderait quelle fonction appeler.
//
// Une valeur absente n interrompt jamais la lecture d une liste. Un element
// sans identifiant est ecarte, les autres sont rendus. C est la meme regle que
// pour les metadonnees d archive : un element casse ne fait pas tomber le
// chapitre. La liste entierement vide, elle, leve, parce qu une source qui rend
// toujours zero resultat sans rien dire est indiscernable d une source vide.
//

/// L application des regles d une extension a ce qu un serveur a repondu.
public struct InterpreteDExtension: Sendable {
    private let regles: ReglesDExtension
    private let lecteurDeDate: LecteurDeDateDExtension

    public init(regles: ReglesDExtension) {
        self.regles = regles
        lecteurDeDate = LecteurDeDateDExtension(format: regles.formatDeDate)
    }

    // MARK: Adresses

    /// Assemble l adresse que cette regle demande.
    ///
    /// Le numero de page est decale par `pageDeDepart` ici, une fois, parce que
    /// c est la seule arithmetique du systeme et qu elle n a rien a faire dans
    /// un gabarit.
    ///
    /// - Throws: `ErreurReseau.serveurIntrouvable` quand l adresse ne
    ///   s assemble pas.
    public func adresse(pour requete: RegleDeRequete, contexte: ContexteDeGabarit) throws -> URL {
        var decale = contexte
        decale.page = contexte.page + regles.pageDeDepart

        let parametres = requete.parametres.map {
            URLQueryItem(name: $0.nom, value: $0.valeur.remplir(decale))
        }

        return try ClientHttp.adresse(
            base: regles.adresseDeBase,
            chemin: requete.chemin.remplir(decale),
            parametres: parametres
        )
    }

    // MARK: Series

    /// Lit une page de series.
    ///
    /// - Throws: `ErreurDExtension.extractionSansResultat` quand le document
    ///   contient des elements mais qu aucun ne porte les champs obligatoires.
    public func series(
        depuis donnees: Data,
        regle: RegleDeSeries,
        page: Int
    ) throws -> PageResultats<MangaDistant> {
        let document = try DocumentInterprete.lire(donnees, format: regle.requete.format)
        let elements = document.elements(regle.elements)
        let series = elements.compactMap { serie(de: $0, champs: regle.champs) }

        try verifier(series.count, parmi: elements.count, champ: "identifiant")

        return PageResultats(
            elements: series,
            page: page,
            ilResteDesPages: ilResteDesPages(
                regle.pagination,
                dans: document,
                recus: elements.count,
                page: page
            )
        )
    }

    /// Lit le detail d une serie.
    ///
    /// - Throws: `ErreurDeSource.mangaIntrouvable` quand le document ne porte
    ///   pas les champs obligatoires.
    public func detail(depuis donnees: Data, regle: RegleDeDetail, identifiant: String) throws -> MangaDistant {
        let document = try DocumentInterprete.lire(donnees, format: regle.requete.format)
        let racine = regle.element.flatMap { document.elements($0).first } ?? document.racine

        guard let serie = serie(de: racine, champs: regle.champs) else {
            throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        }

        return serie
    }

    /// Assemble une serie depuis un element, ou rend nul quand il lui manque
    /// l essentiel.
    private func serie(de element: ElementInterprete, champs: CorrespondanceDeSerie) -> MangaDistant? {
        guard
            let identifiant = element.texte(champs.identifiant),
            let titre = element.texte(champs.titre)
        else {
            return nil
        }

        return MangaDistant(
            identifiant: identifiant,
            titre: titre,
            auteurs: element.textes(champs.auteurs),
            resume: element.texte(champs.resume),
            genres: element.textes(champs.genres),
            statut: StatutSerie.depuisUneExtension(element.texte(champs.statut)),
            langue: element.texte(champs.langue),
            urlCouverture: adresseAbsolue(element.texte(champs.couverture)),
            nombreChapitres: element.nombre(champs.nombreChapitres).map { Int($0) }
        )
    }

    // MARK: Chapitres

    /// Lit les chapitres d une serie, dans l ordre de lecture.
    ///
    /// L ordre du protocole est celui de la lecture, du premier chapitre au
    /// dernier. Une source qui publie du plus recent au plus ancien est
    /// retournee ici, une fois, et le rang est attribue apres le retournement.
    public func chapitres(
        depuis donnees: Data,
        regle: RegleDeChapitres,
        identifiantManga: String
    ) throws -> [ChapitreDistant] {
        let document = try DocumentInterprete.lire(donnees, format: regle.requete.format)
        let elements = document.elements(regle.elements)
        let lisibles = regle.ordreInverse ? Array(elements.reversed()) : elements
        let identifiants = lisibles.compactMap { $0.texte(regle.champs.identifiant) }

        try verifier(identifiants.count, parmi: elements.count, champ: "identifiant")

        return lisibles.enumerated().compactMap { rang, element in
            chapitre(
                de: element,
                champs: regle.champs,
                identifiantManga: identifiantManga,
                rang: rang
            )
        }
    }

    /// Assemble un chapitre depuis un element.
    private func chapitre(
        de element: ElementInterprete,
        champs: CorrespondanceDeChapitre,
        identifiantManga: String,
        rang: Int
    ) -> ChapitreDistant? {
        guard let identifiant = element.texte(champs.identifiant) else {
            return nil
        }

        return ChapitreDistant(
            identifiant: identifiant,
            identifiantManga: identifiantManga,
            // Le rang tient lieu de numero quand la source n en publie pas.
            // Un numero absent ramene a zero ferait tous les chapitres egaux.
            numero: element.nombre(champs.numero) ?? Double(rang + 1),
            titre: element.texte(champs.titre),
            langue: element.texte(champs.langue),
            datePublication: lecteurDeDate.lire(element.texte(champs.datePublication)),
            nombrePages: element.nombre(champs.nombrePages).map { Int($0) },
            ordre: rang
        )
    }

    // MARK: Pages

    /// Lit les pages d un chapitre, dans l ordre de lecture.
    public func pages(
        depuis donnees: Data,
        regle: RegleDePages,
        identifiantChapitre: String
    ) throws -> [PageDistante] {
        let document = try DocumentInterprete.lire(donnees, format: regle.requete.format)
        let elements = document.elements(regle.elements)
        let adresses = elements.compactMap { element in
            element.texte(regle.champs.emplacement).flatMap(adresseAbsolueComplete)
        }

        try verifier(adresses.count, parmi: elements.count, champ: "emplacement")

        return adresses.enumerated().map { index, adresse in
            PageDistante(identifiantChapitre: identifiantChapitre, index: index, emplacement: adresse)
        }
    }

    // MARK: Pagination

    /// Vrai quand la regle de pagination annonce une page suivante.
    private func ilResteDesPages(
        _ regle: ReglePagination?,
        dans document: DocumentInterprete,
        recus: Int,
        page: Int
    ) -> Bool {
        switch regle {
        case nil:
            return false
        case let .listePleine(taille):
            return taille > 0 && recus >= taille
        case let .lienSuivant(extraction):
            return document.racine.texte(extraction) != nil
        case let .totalAnnonce(extraction, taille):
            guard let total = document.racine.nombre(extraction), taille > 0 else {
                return false
            }

            return Double((page + 1) * taille) < total
        }
    }

    // MARK: Outils

    /// Leve quand le document portait des elements mais aucun exploitable.
    private func verifier(_ retenus: Int, parmi observes: Int, champ: String) throws {
        guard retenus == 0, observes > 0 else {
            return
        }

        throw ErreurDExtension.extractionSansResultat(champ: champ)
    }

    /// Ramene une adresse relative a l adresse de base de l extension.
    ///
    /// Un catalogue HTML publie ses couvertures en chemin relatif la moitie du
    /// temps. Les resoudre ici evite que chaque couche qui recoit une
    /// `MangaDistant` ait a savoir d ou elle vient.
    private func adresseAbsolue(_ texte: String?) -> String? {
        adresseAbsolueComplete(texte)?.absoluteString
    }

    /// La meme resolution, sous forme d URL.
    private func adresseAbsolueComplete(_ texte: String?) -> URL? {
        guard let texte, texte.isEmpty == false else {
            return nil
        }

        return URL(string: texte, relativeTo: regles.adresseDeBase)?.absoluteURL
    }
}
