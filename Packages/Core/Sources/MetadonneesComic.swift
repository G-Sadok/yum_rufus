import Foundation

//
// MetadonneesComic
//
// Metadonnees d un chapitre range dans un conteneur, section 5.1 et 5.3 du
// cahier de developpement.
//
// Un seul type porte les deux formats du domaine. `ComicInfo.xml` et
// `ComicBookInfo` nomment les memes notions avec des mots differents, et garder
// deux structures aurait force chaque appelant a connaitre les deux
// vocabulaires. La traduction se fait donc dans les analyseurs, une fois, et le
// reste du programme ne voit que ce type.
//
// Tous les champs sont optionnels, sans exception. Un fichier de metadonnees
// n est jamais garanti, jamais complet et jamais fiable : il vient d un outil
// de catalogage tiers, parfois d une saisie a la main. Un champ obligatoire
// ici obligerait l analyseur a inventer une valeur, et un titre invente est
// pire qu un titre absent.
//

/// Metadonnees lues dans un chapitre, quel que soit le format d origine.
public struct MetadonneesComic: Sendable, Hashable, Codable {
    /// Nom de la serie. `Series` en ComicInfo, `series` en ComicBookInfo.
    public var serie: String?

    /// Titre du chapitre ou du numero, distinct du nom de la serie.
    public var titre: String?

    /// Numero du chapitre, garde en texte.
    ///
    /// Le format ne promet pas un nombre : on rencontre `3.5`, `Annual`, `HS2`
    /// ou `1-2`. Le convertir a la lecture perdrait tout ce qui n est pas
    /// decimal. La conversion est offerte par `numeroDecimal`, qui rend nul
    /// quand elle n a pas de sens.
    public var numero: String?

    /// Numero de volume ou de tome.
    ///
    /// Attention a la lecture des comics occidentaux : beaucoup d outils y
    /// ecrivent l annee de lancement de la serie plutot qu un tome. La valeur
    /// est reprise telle quelle, c est la couche qui l affiche qui decide quoi
    /// en faire.
    public var volume: Int?

    /// Code de langue tel que le fichier l ecrit.
    ///
    /// `LanguageISO` porte un code ISO 639-1 en ComicInfo. `language` en
    /// ComicBookInfo devait porter le nom anglais de la langue, mais les outils
    /// courants y ecrivent aussi un code. La valeur n est donc ni normalisee ni
    /// validee ici.
    public var langue: String?

    /// Resume du chapitre. `Summary` en ComicInfo, `comments` en ComicBookInfo.
    public var resume: String?

    /// Scenaristes.
    public var auteurs: [String]

    /// Dessinateurs.
    public var dessinateurs: [String]

    /// Genres declares.
    public var genres: [String]

    /// Editeur.
    public var editeur: String?

    /// Sens de lecture deduit du champ `Manga` de ComicInfo, quand il tranche.
    ///
    /// C est le seul champ de metadonnees que ce projet traite comme une
    /// donnee du modele et non comme un simple affichage, parce que le sens de
    /// lecture gouverne la pagination, les gestes et la division des images.
    /// Le deduire plus tard dans une vue serait la sixieme erreur de la liste
    /// du CLAUDE.md.
    public var sensDeLecture: SensDeLecture?

    /// Nombre de pages annonce par le fichier de metadonnees.
    ///
    /// C est une annonce, pas une mesure. Le nombre de pages qui fait foi reste
    /// celui que le conteneur donne, parce qu un `PageCount` errone est
    /// frequent et qu il ferait sauter la derniere page du chapitre.
    public var nombrePagesAnnonce: Int?

    public init(
        serie: String? = nil,
        titre: String? = nil,
        numero: String? = nil,
        volume: Int? = nil,
        langue: String? = nil,
        resume: String? = nil,
        auteurs: [String] = [],
        dessinateurs: [String] = [],
        genres: [String] = [],
        editeur: String? = nil,
        sensDeLecture: SensDeLecture? = nil,
        nombrePagesAnnonce: Int? = nil
    ) {
        self.serie = serie
        self.titre = titre
        self.numero = numero
        self.volume = volume
        self.langue = langue
        self.resume = resume
        self.auteurs = auteurs
        self.dessinateurs = dessinateurs
        self.genres = genres
        self.editeur = editeur
        self.sensDeLecture = sensDeLecture
        self.nombrePagesAnnonce = nombrePagesAnnonce
    }

    /// Vrai quand aucun champ n a ete rempli.
    ///
    /// Sert aux analyseurs a distinguer un document lu sans rien y trouver
    /// d un document reellement decrit. Un ComicInfo vide ne doit pas masquer
    /// le ComicBookInfo de secours.
    public var estVide: Bool {
        serie == nil
            && titre == nil
            && numero == nil
            && volume == nil
            && langue == nil
            && resume == nil
            && editeur == nil
            && sensDeLecture == nil
            && nombrePagesAnnonce == nil
            && auteurs.isEmpty
            && dessinateurs.isEmpty
            && genres.isEmpty
    }

    /// Numero rendu en decimal, quand il en porte un.
    ///
    /// Rend nul pour un numero purement textuel comme `Annual`, plutot que zero
    /// qui viendrait se ranger avant le premier chapitre de la serie.
    public var numeroDecimal: Double? {
        guard let numero else { return nil }

        let nettoye = numero.trimmingCharacters(in: .whitespacesAndNewlines)
        if let valeur = Double(nettoye) {
            return valeur
        }

        // Les numeros composes comme `12 (of 24)` restent frequents. On garde
        // la tete numerique et on abandonne le reste.
        let tete = nettoye.prefix { $0.isNumber || $0 == "." || $0 == "," }

        return Double(tete.replacingOccurrences(of: ",", with: "."))
    }

    /// Complete les champs absents avec ceux d une source de secours.
    ///
    /// La section 5.3 fait de `ComicInfo.xml` la source prioritaire et du
    /// `ComicBookInfo` un secours. Secours ne veut pas dire ignore : quand le
    /// ComicInfo existe mais ne porte pas de resume, le prendre dans le
    /// commentaire de l archive vaut mieux que de le perdre. Aucun champ deja
    /// rempli n est ecrase.
    public func complete(par secours: MetadonneesComic) -> MetadonneesComic {
        var fusion = self

        fusion.serie = serie ?? secours.serie
        fusion.titre = titre ?? secours.titre
        fusion.numero = numero ?? secours.numero
        fusion.volume = volume ?? secours.volume
        fusion.langue = langue ?? secours.langue
        fusion.resume = resume ?? secours.resume
        fusion.editeur = editeur ?? secours.editeur
        fusion.sensDeLecture = sensDeLecture ?? secours.sensDeLecture
        fusion.nombrePagesAnnonce = nombrePagesAnnonce ?? secours.nombrePagesAnnonce
        fusion.auteurs = auteurs.isEmpty ? secours.auteurs : auteurs
        fusion.dessinateurs = dessinateurs.isEmpty ? secours.dessinateurs : dessinateurs
        fusion.genres = genres.isEmpty ? secours.genres : genres

        return fusion
    }
}

extension MetadonneesComic {
    /// Reporte les metadonnees sur une serie, sans jamais effacer l existant.
    ///
    /// Le sens de lecture n est ecrit que si la serie n en impose pas deja un :
    /// un choix fait par l utilisateur prime toujours sur ce qu annonce un
    /// fichier de catalogage.
    public func appliquer(a manga: Manga) -> Manga {
        var mis = manga

        if let serie, serie.isEmpty == false {
            mis.titre = serie
        }
        if let resume {
            mis.resume = resume
        }
        if let langue {
            mis.langue = langue
        }
        if auteurs.isEmpty == false {
            mis.auteurs = auteurs
        }
        if dessinateurs.isEmpty == false {
            mis.dessinateurs = dessinateurs
        }
        if genres.isEmpty == false {
            mis.genres = genres
        }
        if manga.sensLectureForce == nil {
            mis.sensLectureForce = sensDeLecture
        }

        return mis
    }

    /// Reporte les metadonnees sur un chapitre, sans jamais effacer l existant.
    ///
    /// `nombrePages` n est pas repris : le conteneur fait foi, voir
    /// `nombrePagesAnnonce`.
    public func appliquer(a chapitre: Chapitre) -> Chapitre {
        var mis = chapitre

        if let titre {
            mis.titre = titre
        }
        if let langue {
            mis.langue = langue
        }
        if let numeroDecimal {
            mis.numero = numeroDecimal
        }

        return mis
    }
}
