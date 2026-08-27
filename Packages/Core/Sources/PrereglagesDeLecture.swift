import Foundation

//
// PrereglagesDeLecture
//
// Contenu d un prereglage de lecture, section 7 du tableau de la section 5.5 de
// DESIGN-SPEC.md et section 9 du cahier de developpement.
//
// L entite `PrereglageLecture` de la section 3.1 ne porte qu un nom et un bloc
// JSON que la base ne relit jamais. Ce fichier dit ce que ce bloc contient, et
// lui seul. C est cette separation qui permet d ajouter un reglage au
// prereglage sans toucher au schema.
//
// Ce qui est capture est nomme par la description de la section 9 : `le sens,
// les filtres, la teinte et les traitements IA`. Le sens vient du menu Sens de
// lecture, la teinte du menu Fond du lecteur, les filtres et les traitements du
// panneau de la section 5.7. La mise en page les accompagne parce qu elle
// impose le sens vertical : capturer un sens sans sa mise en page rendrait le
// prereglage contradictoire des sa relecture.
//

/// Ce qu un prereglage de lecture capture, et reapplique en une seule action.
public struct ContenuDePrereglage: Sendable, Codable, Equatable, Hashable {
    /// Version du format ecrit dans `PrereglageLecture.donneesReglages`.
    ///
    /// Elle est relue avant tout usage : un prereglage produit par une version
    /// que celle ci ne sait pas lire se refuse en le disant, il ne se lit
    /// jamais de travers.
    public static let versionCourante = 1

    public let version: Int

    /// Sens de lecture choisi au menu de la section 6, hors sens vertical.
    public let sens: SensDeLecture

    /// Mise en page choisie au menu de la section 6.
    public let miseEnPage: MiseEnPage

    /// Fond du lecteur, la teinte de la description de la section 9.
    public let fond: ChoixDeFondDuLecteur

    /// Etat de la ligne Rogner les bords de la section 6.
    public let rognerLesBords: Bool

    /// Les cinq curseurs et les trois traitements du panneau de la section 5.7.
    public let filtres: ReglagesDeFiltres

    public init(
        version: Int = ContenuDePrereglage.versionCourante,
        sens: SensDeLecture = .parDefaut,
        miseEnPage: MiseEnPage = .parDefaut,
        fond: ChoixDeFondDuLecteur = .parDefaut,
        rognerLesBords: Bool = false,
        filtres: ReglagesDeFiltres = .parDefaut
    ) {
        self.version = version
        self.sens = sens
        self.miseEnPage = miseEnPage
        self.fond = fond
        self.rognerLesBords = rognerLesBords
        self.filtres = filtres
    }

    /// Contenu d une installation neuve, ou rien n a jamais ete change.
    public static let parDefaut = ContenuDePrereglage()

    // MARK: Capture

    /// Capture l etat de lecture courant.
    ///
    /// - Parameters:
    ///   - reglages: valeurs de l ecran Reglages, defauts du catalogue compris.
    ///   - filtres: etat du panneau de filtres du lecteur. Il ne vit pas dans la
    ///     table des reglages, il est donc passe a part.
    public static func capture(
        reglages: ReglagesDeLApplication,
        filtres: ReglagesDeFiltres
    ) -> ContenuDePrereglage {
        ContenuDePrereglage(
            sens: sensChoisi(dans: reglages),
            miseEnPage: reglages.choix(.miseEnPage, comme: MiseEnPage.self),
            fond: reglages.choix(.fondDuLecteur, comme: ChoixDeFondDuLecteur.self),
            rognerLesBords: reglages.booleen(.rognerLesBords),
            filtres: filtres
        )
    }

    // MARK: Application

    /// Sens reellement applique, mise en page comprise.
    ///
    /// Le menu de la section 6 ne propose que les deux sens horizontaux, le
    /// sens vertical vient de la mise en page `continuVertical`. La regle est
    /// celle de `MiseEnPage.sensImpose`, elle n est pas reinventee ici.
    public var sensApplique: SensDeLecture {
        miseEnPage.sensImpose ?? sens
    }

    /// Reglages obtenus en posant ce prereglage sur ceux qui sont en place.
    ///
    /// Seules les lignes que le prereglage capture sont remplacees. Le theme,
    /// la langue ou la qualite de telechargement ne bougent pas : un prereglage
    /// de lecture ne regle que la lecture.
    ///
    /// La luminosite est ecrite depuis le curseur du panneau, parce que la
    /// ligne `Luminosite du lecteur` et le curseur `Luminosite` sont deux
    /// surfaces pour la meme grandeur, comme `ReglagesDeFiltres.depuis` le pose
    /// deja dans l autre sens. Les laisser diverger donnerait deux luminosites
    /// contradictoires selon l ecran ouvert.
    public func appliquer(a reglages: ReglagesDeLApplication) -> ReglagesDeLApplication {
        var appliques = reglages

        for (identifiant, valeur) in valeursAEcrire {
            appliques.definir(valeur, pour: identifiant)
        }

        return appliques
    }

    /// Lignes de reglage que l application de ce prereglage reecrit.
    ///
    /// Le magasin les pose toutes dans une seule transaction. Une application
    /// ligne par ligne laisserait le lecteur voir un etat intermediaire, moitie
    /// ancien moitie nouveau.
    public var valeursAEcrire: [IdentifiantDeReglage: ValeurDeReglage] {
        [
            .sensDeLecture: .choix(sens.rawValue),
            .miseEnPage: .choix(miseEnPage.rawValue),
            .fondDuLecteur: .choix(fond.rawValue),
            .rognerLesBords: .booleen(rognerLesBords),
            .luminositeDuLecteur: .curseur(filtres.valeur(.luminosite)),
        ]
    }

    // MARK: Forme persistee

    /// Encode le contenu tel qu il est range dans la colonne JSON.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(self)
    }

    /// Relit un contenu deja encode.
    ///
    /// - Throws: `ErreurDePrereglage.contenuIllisible` quand les octets ne
    ///   decrivent pas un contenu, `.formatInconnu` quand ils viennent d une
    ///   version que celle ci ne sait pas lire.
    public init(donnees: Data) throws {
        guard let relu = try? JSONDecoder().decode(ContenuDePrereglage.self, from: donnees) else {
            throw ErreurDePrereglage.contenuIllisible
        }

        guard relu.version == Self.versionCourante else {
            throw ErreurDePrereglage.formatInconnu(version: relu.version)
        }

        self = relu
    }

    /// Sens ecrit dans la ligne de reglage, defaut du modele a defaut.
    ///
    /// La ligne n est pas declaree par un `ChoixDeReglage` : le menu ne propose
    /// que deux des trois sens, et l enumeration du modele en compte trois. La
    /// valeur brute est donc relue ici, avec le meme repli que partout ailleurs.
    private static func sensChoisi(dans reglages: ReglagesDeLApplication) -> SensDeLecture {
        guard case let .choix(brut) = reglages[.sensDeLecture],
              let sens = SensDeLecture(rawValue: brut)
        else {
            return .parDefaut
        }

        return sens
    }
}

// MARK: Entite

extension PrereglageLecture {
    /// Enregistre un contenu sous un nom.
    ///
    /// - Throws: ce que l encodage du contenu remonte.
    public init(id: UUID = UUID(), nom: String, contenu: ContenuDePrereglage) throws {
        try self.init(id: id, nom: nom, donneesReglages: contenu.donnees())
    }

    /// Contenu range dans la colonne JSON.
    ///
    /// - Throws: `ErreurDePrereglage.contenuIllisible` ou `.formatInconnu`.
    public func contenu() throws -> ContenuDePrereglage {
        try ContenuDePrereglage(donnees: donneesReglages)
    }
}

// MARK: Erreurs

/// Erreurs que la gestion des prereglages peut remonter jusqu a l interface.
///
/// Chaque cas nomme la cause. La traduction en message utilisateur se fait dans
/// la couche vue, avec le catalogue de chaines.
public enum ErreurDePrereglage: Error, Sendable, Equatable {
    /// Le nom demande est vide, ou ne contient que des espaces.
    case nomVide

    /// Un autre prereglage porte deja ce nom, aux accents et a la casse pres.
    case nomDejaPris(nom: String)

    /// Le prereglage vise n existe pas ou plus.
    case prereglageInconnu(identifiant: UUID)

    /// La colonne JSON ne decrit pas un contenu de prereglage.
    case contenuIllisible

    /// Le contenu vient d une version que celle ci ne sait pas lire.
    case formatInconnu(version: Int)
}

// MARK: Ordre et nommage

/// Ordre de la liste des prereglages, et regles de nommage.
///
/// La table ne porte aucun rang, section 3.1 : `id`, `nom`, `donneesReglages`.
/// L ordre de la liste est donc entierement derive du nom, et il est total pour
/// que deux lectures de la meme base rendent toujours la meme liste.
public enum OrdreDesPrereglages {
    /// Prereglages dans l ordre de la liste.
    ///
    /// Le tri est naturel et non lexicographique, comme celui des pages :
    /// `Webtoon 10` se range apres `Webtoon 2`, pas avant. L identifiant
    /// departage deux noms qui se comparent egaux, ce qui rend l ordre total.
    public static func trier(_ prereglages: [PrereglageLecture]) -> [PrereglageLecture] {
        prereglages.sorted { premier, second in
            switch TriNaturel.comparer(premier.nom, second.nom) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: premier.id.uuidString < second.id.uuidString
            }
        }
    }

    /// Nom debarrasse de ses espaces de bordure.
    ///
    /// - Throws: `ErreurDePrereglage.nomVide` quand il ne reste rien.
    public static func nomNettoye(_ nom: String) throws -> String {
        let nettoye = nom.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !nettoye.isEmpty else {
            throw ErreurDePrereglage.nomVide
        }

        return nettoye
    }

    /// Verifie qu aucun autre prereglage ne porte deja ce nom.
    ///
    /// La comparaison ignore la casse et les diacritiques, comme celle des
    /// categories : deux prereglages nommes `Webtoon` et `webtoon` seraient
    /// indiscernables dans la liste.
    ///
    /// - Parameter sauf: prereglage exclu de la comparaison, celui que l on
    ///   renomme.
    public static func verifierLaDisponibilite(
        de nom: String,
        parmi prereglages: [PrereglageLecture],
        sauf identifiant: UUID? = nil
    ) throws {
        let recherche = RechercheLocale.normaliser(nom)

        let collision = prereglages.contains { prereglage in
            prereglage.id != identifiant && RechercheLocale.normaliser(prereglage.nom) == recherche
        }

        if collision {
            throw ErreurDePrereglage.nomDejaPris(nom: nom)
        }
    }
}
