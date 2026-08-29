import Foundation

//
// CorrespondanceDeSuivi
//
// Comment une serie de la bibliotheque trouve son entree chez un service de
// suivi, et comment l utilisateur corrige quand la machine se trompe.
//
// Le deuxieme critere de la fonctionnalite demande deux choses, et l ordre dans
// lequel elles sont ecrites compte : proposer d abord, corriger ensuite. Une
// liaison posee sans etre proposee obligerait a chercher a la main pour les
// cinq cents series d une bibliotheque. Une liaison proposee sans pouvoir etre
// corrigee serait pire : les titres de manga se ressemblent, les suites portent
// le nom de l original, et une progression envoyee sur la mauvaise entree
// remonte un chapitre lu sur une serie que l utilisateur n a jamais ouverte.
//
// La proposition ne decide donc jamais seule. Elle classe, elle dit a quel
// point elle est sure, et elle laisse la derniere main a l appelant. Le seul
// cas ou elle se suffit a elle meme est celui d un titre identique au caractere
// pres apres normalisation, sans second candidat proche.
//
// La comparaison porte sur des jetons et non sur la chaine entiere. Les
// services ecrivent le meme titre de trois facons, avec ou sans sous titre,
// avec ou sans ponctuation, en romanisation ou en anglais, et une distance
// d edition sur la chaine complete range alors une suite avant l original. Un
// recouvrement de mots resiste a ces trois ecarts.
//

/// Une entree de catalogue chez un service de suivi.
public struct SerieDeSuivi: Sendable, Hashable, Identifiable {
    /// Identifiant de la serie chez le service.
    public let id: String

    /// Titre principal tel que le service le publie.
    public let titre: String

    /// Autres titres publies par le service, romanisation et traductions.
    public let titresAlternatifs: [String]

    /// Annee de premiere publication, nulle quand le service ne la donne pas.
    public let annee: Int?

    /// Nombre de chapitres connus du service, nul quand la serie est en cours
    /// et que le service ne l annonce pas.
    public let nombreDeChapitres: Int?

    public init(
        id: String,
        titre: String,
        titresAlternatifs: [String] = [],
        annee: Int? = nil,
        nombreDeChapitres: Int? = nil
    ) {
        self.id = id
        self.titre = titre
        self.titresAlternatifs = titresAlternatifs
        self.annee = annee
        self.nombreDeChapitres = nombreDeChapitres
    }

    /// Tous les titres sous lesquels cette entree peut etre reconnue.
    public var titresConnus: [String] {
        [titre] + titresAlternatifs
    }
}

/// Une entree proposee pour une serie de la bibliotheque.
public struct CandidatDeLiaison: Sendable, Hashable, Identifiable {
    /// Entree proposee.
    public let serie: SerieDeSuivi

    /// Ressemblance avec le titre local, entre zero et un.
    public let score: Double

    public var id: String {
        serie.id
    }

    public init(serie: SerieDeSuivi, score: Double) {
        self.serie = serie
        self.score = score
    }
}

/// Ce que la recherche propose pour une serie, et ce qu elle laisse decider.
public struct PropositionDeLiaison: Sendable, Hashable {
    /// Candidats retenus, du plus ressemblant au moins ressemblant.
    public let candidats: [CandidatDeLiaison]

    public init(candidats: [CandidatDeLiaison]) {
        self.candidats = candidats
    }

    /// Aucune entree ne ressemble assez pour etre montree.
    public static let vide = PropositionDeLiaison(candidats: [])

    /// Candidat le mieux classe, nul quand rien n a ete retenu.
    public var meilleur: CandidatDeLiaison? {
        candidats.first
    }

    /// Vrai quand la proposition peut etre posee sans demander a l utilisateur.
    ///
    /// Deux conditions, et les deux comptent. Le meilleur candidat doit
    /// depasser le seuil de certitude, sans quoi une bibliotheque mal nommee se
    /// lierait a n importe quoi. Il doit aussi devancer nettement le suivant :
    /// une serie et sa suite obtiennent toutes deux un tres bon score, et celle
    /// qui gagne d un millieme le gagne par hasard.
    public var estCertaine: Bool {
        guard let meilleur, meilleur.score >= CorrespondanceDeSuivi.seuilDeCertitude else {
            return false
        }

        guard candidats.count > 1 else {
            return true
        }

        return meilleur.score - candidats[1].score >= CorrespondanceDeSuivi.ecartMinimal
    }

    /// Vrai quand l utilisateur doit choisir lui meme.
    ///
    /// C est l inverse exact de la certitude, nomme dans l autre sens parce que
    /// c est sous cette forme que l appelant pose la question.
    public var demandeUnChoix: Bool {
        estCertaine == false
    }
}

/// Rapprochement entre une serie locale et le catalogue d un service.
public enum CorrespondanceDeSuivi {
    /// Score au dela duquel une correspondance se pose sans confirmation.
    public static let seuilDeCertitude = 0.92

    /// Ecart minimal entre le premier et le deuxieme candidat pour trancher.
    public static let ecartMinimal = 0.1

    /// Score en dessous duquel un candidat n est meme pas montre.
    ///
    /// Une recherche de titre rend toujours quelque chose, y compris des
    /// series qui n ont qu un mot commun avec la demande. Les afficher
    /// noierait les deux entrees qui comptent au milieu de dix qui ne veulent
    /// rien dire.
    public static let seuilDeProposition = 0.34

    /// Classe les entrees d un service pour un titre local.
    ///
    /// - Parameters:
    ///   - titre: titre de la serie dans la bibliotheque.
    ///   - annee: annee de publication connue localement, quand elle l est.
    ///   - entrees: ce que la recherche du service a rendu.
    public static func proposer(
        pourTitre titre: String,
        annee: Int? = nil,
        parmi entrees: [SerieDeSuivi]
    ) -> PropositionDeLiaison {
        let notes = entrees.map { entree in
            CandidatDeLiaison(serie: entree, score: score(entre: titre, annee: annee, et: entree))
        }
        let retenus = notes.filter { $0.score >= seuilDeProposition }

        return PropositionDeLiaison(candidats: retenus.sorted(by: mieuxClasse))
    }

    /// Vrai quand le premier candidat passe devant le second.
    ///
    /// Le classement est total et ne depend pas de l ordre d arrivee. A score
    /// egal, l identifiant tranche : sans lui, deux executions sur le meme jeu
    /// de donnees pourraient rendre deux ordres, et le test qui verifie le
    /// premier candidat serait instable sans que personne ne comprenne
    /// pourquoi.
    private static func mieuxClasse(_ premier: CandidatDeLiaison, _ second: CandidatDeLiaison) -> Bool {
        guard premier.score == second.score else {
            return premier.score > second.score
        }

        return premier.serie.id < second.serie.id
    }

    /// Ressemblance entre un titre local et une entree, entre zero et un.
    ///
    /// Le meilleur des titres connus de l entree gagne : un service qui publie
    /// le titre original et sa romanisation doit repondre pareil que celui qui
    /// n en publie qu un.
    public static func score(entre titre: String, annee: Int? = nil, et entree: SerieDeSuivi) -> Double {
        let meilleur = entree.titresConnus
            .map { similitude(entre: titre, et: $0) }
            .max() ?? 0

        return borner(meilleur + correctionDAnnee(entre: annee, et: entree.annee))
    }

    /// Ressemblance entre deux titres, entre zero et un.
    ///
    /// Deux titres identiques une fois normalises rendent un, ce qui est le
    /// seul cas ou la certitude est possible. Sinon la mesure est le
    /// recouvrement de leurs mots : deux fois les mots communs, divise par le
    /// total des deux cotes. Un sous titre absent d un cote coute donc quelque
    /// chose sans tout emporter, alors qu un mot different en tete emporte
    /// beaucoup.
    public static func similitude(entre premier: String, et second: String) -> Double {
        let motsDuPremier = mots(de: premier)
        let motsDuSecond = mots(de: second)

        guard motsDuPremier.isEmpty == false, motsDuSecond.isEmpty == false else {
            return 0
        }

        if motsDuPremier == motsDuSecond {
            return 1
        }

        let communs = motsDuPremier.intersection(motsDuSecond).count

        return 2 * Double(communs) / Double(motsDuPremier.count + motsDuSecond.count)
    }

    /// Titre ramene a une forme comparable.
    ///
    /// Les accents tombent, la casse tombe, la ponctuation devient une
    /// separation, les espaces multiples se resorbent. Ce qui reste est ce que
    /// deux catalogues ecrivent pareil quand ils parlent de la meme serie.
    public static func normaliser(_ titre: String) -> String {
        let sansAccents = titre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let separe = sansAccents.map { caractere -> Character in
            caractere.isLetter || caractere.isNumber ? caractere : " "
        }

        return String(separe).split(separator: " ").joined(separator: " ")
    }

    /// Mots retenus d un titre, sans les mots vides.
    ///
    /// Les articles et les particules tombent, dans les trois langues qui
    /// remplissent les catalogues. Sans cela, `Le Voyage` et `Un Voyage`
    /// obtiendraient un demi point de ressemblance pour un mot qui ne dit rien,
    /// et deux series sans rapport se retrouveraient proposees.
    static func mots(de titre: String) -> Set<String> {
        let tous = normaliser(titre).split(separator: " ").map(String.init)
        let retenus = tous.filter { motsVides.contains($0) == false }

        // Un titre entierement fait de mots vides existe, `The End` par
        // exemple. Le vider completement le rendrait incomparable, on garde
        // alors ses mots tels quels.
        return Set(retenus.isEmpty ? tous : retenus)
    }

    /// Mots qui ne distinguent aucune serie d une autre.
    private static let motsVides: Set<String> = [
        "le", "la", "les", "un", "une", "des", "du", "de", "d", "l",
        "the", "a", "an", "of", "and",
        "no", "wa", "ga", "ni", "to", "wo",
    ]

    /// Ce que l accord ou le desaccord des annees ajoute au score.
    ///
    /// L annee ne fait jamais une correspondance a elle seule, elle departage.
    /// Une annee identique rapproche legerement, un ecart de plus d un an
    /// eloigne : c est le seul signal disponible pour distinguer une serie de
    /// son remake, qui portent souvent le meme titre au mot pres.
    private static func correctionDAnnee(entre locale: Int?, et distante: Int?) -> Double {
        guard let locale, let distante else {
            return 0
        }

        let ecart = abs(locale - distante)

        if ecart == 0 {
            return 0.05
        }

        return ecart > 1 ? -0.15 : 0
    }

    /// Ramene un score dans l intervalle de zero a un.
    private static func borner(_ valeur: Double) -> Double {
        min(1, max(0, valeur))
    }

    // MARK: Poser la liaison

    /// Liaison entre une serie locale et l entree choisie.
    ///
    /// C est le seul chemin par lequel une liaison se cree, que le choix vienne
    /// de la proposition ou de l utilisateur. L entree choisie n a pas a
    /// figurer dans les candidats : une correction manuelle part souvent d une
    /// recherche que la proposition n avait pas faite, avec le titre original
    /// plutot que le titre traduit.
    public static func liaison(
        pour mangaId: UUID,
        service: ServiceDeSuivi,
        vers entree: SerieDeSuivi,
        statut: StatutDeSuivi = .enLecture,
        chapitreVu: Double = 0
    ) -> LiaisonSuivi {
        LiaisonSuivi(
            mangaId: mangaId,
            service: service,
            identifiantDistant: entree.id,
            statut: statut,
            chapitreVu: chapitreVu
        )
    }
}
