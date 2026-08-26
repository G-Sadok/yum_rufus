import Foundation

//
// ModeleOpds
//
// La forme neutre d un flux OPDS, celle que la source manipule, quelle que soit
// la version du protocole qui l a produite.
//
// C est la piece qui rend le tableau 4.2 tenable. OPDS existe en deux versions
// qui ne partagent pas un octet de syntaxe : la 1.2 est un document Atom, la
// 2.0 est un document JSON. Elles decrivent pourtant la meme chose, un flux qui
// porte des liens et des entrees, et chaque entree qui porte a son tour des
// liens. Poser cette forme commune ici veut dire que la pagination, la
// traduction en entites du domaine et la lecture sont ecrites une seule fois.
// Deux jeux de code paralleles auraient diverge au premier defaut de serveur.
//
// Le vocabulaire d OPDS tient dans les relations de liens, et rien d autre. Une
// entree n annonce pas qu elle est une serie ou un chapitre : elle porte un
// lien de navigation, et c est une serie, ou un lien d acquisition, et c est un
// chapitre. Les relations sont donc des constantes nommees et non des chaines
// recopiees a chaque comparaison.
//

/// Les relations de lien qu OPDS definit et que cette source emploie.
enum RelationOpds {
    /// Le flux suivant d une liste paginee. C est le seul chemin vers la page
    /// deux : OPDS ne numerote pas ses pages, il les enchaine.
    static let suivante = "next"

    /// Un sous catalogue, donc une serie dans le vocabulaire de ce projet.
    static let sousSection = "subsection"

    /// Prefixe des relations d acquisition, qui designent un fichier a lire.
    ///
    /// C est un prefixe et non une valeur : la norme decline la relation en
    /// `open-access`, `borrow`, `buy` et `sample`, et toutes designent le meme
    /// fichier au meme endroit.
    static let prefixeDAcquisition = "http://opds-spec.org/acquisition"

    /// La couverture de l entree.
    static let image = "http://opds-spec.org/image"

    /// La vignette de couverture, servie quand la couverture manque.
    static let vignette = "http://opds-spec.org/image/thumbnail"

    /// La section des nouveautes du catalogue.
    static let nouveautes = "http://opds-spec.org/sort/new"

    /// La section des series les plus consultees du catalogue.
    static let populaires = "http://opds-spec.org/sort/popular"

    /// Le flux de pages de l extension de diffusion page par page.
    ///
    /// L extension n est pas dans la norme OPDS, elle est publiee a part, et
    /// c est pourtant elle qui rend un catalogue lisible sans rapatrier chaque
    /// conteneur en entier. Komga et Kavita la servent tous les deux.
    static let diffusionDePages = "http://vaemendis.net/opds-pse/stream"
}

/// Les types de documents qu un flux OPDS annonce dans ses liens.
enum TypeOpds {
    /// Le profil de catalogue, present dans le type MIME des flux Atom.
    static let profilDeCatalogue = "profile=opds-catalog"

    /// Le type des flux OPDS 2.0.
    static let fluxJson = "application/opds+json"

    /// Le type des flux OPDS 1.2.
    static let fluxAtom = "application/atom+xml"

    /// Le marqueur des documents d entree, qui ne sont pas des sous catalogues.
    ///
    /// Un flux Atom declare `type=entry` dans le type MIME d un lien qui mene a
    /// la fiche d une seule entree. Le prendre pour un sous catalogue ferait
    /// apparaitre chaque chapitre comme une serie.
    static let documentDEntree = "type=entry"
}

/// Un lien porte par un flux ou par une entree.
struct LienOpds: Sendable, Hashable {
    /// Relation, ramenee en minuscules parce que les serveurs varient.
    let relation: String

    /// Type MIME annonce, quand le serveur en annonce un.
    let type: String?

    /// Adresse telle que le serveur l ecrit, absolue ou relative.
    let adresse: String

    let titre: String?

    /// Nombre de pages annonce par l extension de diffusion page par page.
    let nombreDePages: Int?

    /// Vrai quand l adresse est un gabarit a completer, ce que la 2.0 declare.
    let gabarit: Bool

    init(
        relation: String,
        type: String? = nil,
        adresse: String,
        titre: String? = nil,
        nombreDePages: Int? = nil,
        gabarit: Bool = false
    ) {
        self.relation = relation.lowercased()
        self.type = type
        self.adresse = adresse
        self.titre = titre
        self.nombreDePages = nombreDePages
        self.gabarit = gabarit
    }

    /// Vrai quand ce lien designe un fichier a lire.
    var estUneAcquisition: Bool {
        relation.hasPrefix(RelationOpds.prefixeDAcquisition)
    }

    /// Vrai quand ce lien mene a un autre flux du catalogue.
    ///
    /// La relation seule ne suffit pas : un serveur annonce ses sous catalogues
    /// par `subsection`, un autre par une relation vide et un type MIME qui
    /// porte le profil. Le document d une seule entree est exclu des deux
    /// cotes, sans quoi chaque chapitre deviendrait une serie.
    var estUneNavigation: Bool {
        guard estUneAcquisition == false else {
            return false
        }
        guard let type else {
            return relation == RelationOpds.sousSection
        }
        guard type.contains(TypeOpds.documentDEntree) == false else {
            return false
        }

        return relation == RelationOpds.sousSection
            || type.contains(TypeOpds.profilDeCatalogue)
            || type.contains(TypeOpds.fluxJson)
    }

    /// Vrai quand ce lien porte une couverture.
    var estUneImage: Bool {
        relation == RelationOpds.image || relation == RelationOpds.vignette
    }
}

/// Une entree de flux, serie ou chapitre selon les liens qu elle porte.
struct EntreeOpds: Sendable, Hashable {
    /// Identifiant annonce par le serveur, qui n est pas une adresse.
    ///
    /// Il n est pas retenu comme identifiant de serie ni de chapitre : OPDS
    /// n offre aucun moyen de retrouver une entree par cet identifiant la. Ce
    /// sont les adresses des liens qui servent d identifiants, parce qu elles
    /// sont les seules a etre interrogeables.
    let identifiant: String?

    let titre: String
    let auteurs: [String]
    let resume: String?
    let categories: [String]
    let langue: String?
    let miseAJour: Date?

    /// Nombre de pages, quand la 2.0 le declare dans ses metadonnees.
    let nombreDePages: Int?

    let liens: [LienOpds]

    init(
        identifiant: String? = nil,
        titre: String,
        auteurs: [String] = [],
        resume: String? = nil,
        categories: [String] = [],
        langue: String? = nil,
        miseAJour: Date? = nil,
        nombreDePages: Int? = nil,
        liens: [LienOpds] = []
    ) {
        self.identifiant = identifiant
        self.titre = titre
        self.auteurs = auteurs
        self.resume = resume
        self.categories = categories
        self.langue = langue
        self.miseAJour = miseAJour
        self.nombreDePages = nombreDePages
        self.liens = liens
    }

    /// Le lien qui rapporte le fichier du chapitre, quand il y en a un.
    var acquisition: LienOpds? {
        liens.first { $0.estUneAcquisition }
    }

    /// Le lien qui mene au flux de la serie, quand il y en a un.
    var navigation: LienOpds? {
        liens.first { $0.estUneNavigation }
    }

    /// Le lien de diffusion page par page, quand le serveur sert l extension.
    var diffusionDePages: LienOpds? {
        liens.first { $0.relation == RelationOpds.diffusionDePages }
    }

    /// La couverture, la vraie de preference, la vignette a defaut.
    var couverture: LienOpds? {
        liens.first { $0.relation == RelationOpds.image }
            ?? liens.first { $0.relation == RelationOpds.vignette }
    }

    /// Vrai quand cette entree designe un chapitre a lire.
    ///
    /// L acquisition est testee avant la navigation, et l ordre est le sujet :
    /// une entree de livre porte aussi un lien vers sa propre fiche, et tester
    /// la navigation d abord ferait de chaque chapitre une serie vide.
    var estUnChapitre: Bool {
        acquisition != nil
    }

    /// Vrai quand cette entree designe une serie, donc un sous catalogue.
    var estUneSerie: Bool {
        estUnChapitre == false && navigation != nil
    }
}

/// Un flux OPDS, dans la forme commune aux deux versions du protocole.
struct FluxOpds: Sendable, Hashable {
    /// Titre du flux, qui nomme la serie quand le flux est celui d une serie.
    let titre: String?

    let liens: [LienOpds]
    let entrees: [EntreeOpds]

    init(titre: String? = nil, liens: [LienOpds] = [], entrees: [EntreeOpds] = []) {
        self.titre = titre
        self.liens = liens
        self.entrees = entrees
    }

    /// Le lien vers le flux suivant, quand la liste continue.
    var suivante: LienOpds? {
        liens.first { $0.relation == RelationOpds.suivante }
    }

    /// Le lien d une section du catalogue, quand le flux racine la publie.
    func section(_ relation: String) -> LienOpds? {
        liens.first { $0.relation == relation }
    }

    /// Les entrees qui designent des series.
    var series: [EntreeOpds] {
        entrees.filter(\.estUneSerie)
    }

    /// Les entrees qui designent des chapitres.
    var chapitres: [EntreeOpds] {
        entrees.filter(\.estUnChapitre)
    }
}
