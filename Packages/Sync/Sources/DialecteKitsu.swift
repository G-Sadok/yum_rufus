import Core
import Foundation
import Sources

//
// DialecteKitsu
//
// Le service qui n ecrit pas sur la serie mais sur une entree de bibliotheque.
//
// C est la difference qui justifie l appel prealable du protocole. Chez les
// deux services precedents, publier une progression se dit en une phrase :
// pour cette serie, j en suis la. Ici, la progression appartient a une entree
// qui lie un compte et une serie, et cette entree existe deja ou pas. Publier
// sans la chercher creerait un doublon a chaque chapitre lu, et le service
// finirait par refuser.
//
// L echange se fait au format JSON:API, ou chaque objet porte son type et ou
// les liens vers d autres objets vivent dans une section a part. C est verbeux
// et parfaitement regulier.
//

/// Le service dont la progression vit dans une entree de bibliotheque.
public struct DialecteKitsu: DialecteDeSuivi {
    public let service = ServiceDeSuivi.kitsu

    public init() {}

    // MARK: Compte

    public func appelDuCompte() -> AppelDeSuivi {
        AppelDeSuivi(chemin: "users", parametres: [URLQueryItem(name: "filter[self]", value: "true")])
    }

    public func compte(depuis reponse: ReponseHttp) throws -> CompteDeSuivi {
        let recu = try lireOuLever(ReponseDesUtilisateurs.self, depuis: reponse)

        guard let utilisateur = recu.data.first else {
            throw ErreurDeSuivi.reponseIllisible(service: service)
        }

        return CompteDeSuivi(
            identifiant: utilisateur.id,
            pseudonyme: utilisateur.attributes.name ?? utilisateur.id
        )
    }

    // MARK: Recherche

    public func appelDeRecherche(titre: String) -> AppelDeSuivi {
        AppelDeSuivi(
            chemin: "manga",
            parametres: [
                URLQueryItem(name: "filter[text]", value: titre),
                URLQueryItem(name: "page[limit]", value: "10"),
            ]
        )
    }

    public func series(depuis reponse: ReponseHttp) throws -> [SerieDeSuivi] {
        let recu = try lireOuLever(ReponseDesSeries.self, depuis: reponse)

        return recu.data.map { entree in
            SerieDeSuivi(
                id: entree.id,
                titre: entree.attributes.canonicalTitle ?? "",
                titresAlternatifs: entree.attributes.autresTitres,
                annee: entree.attributes.annee,
                nombreDeChapitres: entree.attributes.chapterCount
            )
        }
    }

    // MARK: Publication

    public func appelDeLEntreeExistante(_ liaison: LiaisonSuivi, compte: CompteDeSuivi) -> AppelDeSuivi? {
        AppelDeSuivi(
            chemin: "library-entries",
            parametres: [
                URLQueryItem(name: "filter[user_id]", value: compte.identifiant),
                URLQueryItem(name: "filter[manga_id]", value: liaison.identifiantDistant),
                URLQueryItem(name: "page[limit]", value: "1"),
            ]
        )
    }

    public func entreeExistante(depuis reponse: ReponseHttp) throws -> String? {
        let recu = try lireOuLever(ReponseDesEntrees.self, depuis: reponse)

        return recu.data.first?.id
    }

    public func appelDePublication(
        _ liaison: LiaisonSuivi,
        compte: CompteDeSuivi,
        entreeExistante: String?
    ) throws -> AppelDeSuivi {
        guard liaison.identifiantDistant.isEmpty == false else {
            throw ErreurDeSuivi.liaisonAbsente(service: service)
        }

        let attributs = AttributsDEntree(
            progress: Int(liaison.chapitreVu.rounded(.down)),
            status: Self.statut(liaison.statut),
            ratingTwenty: liaison.note.map { Int($0.rounded()) }
        )

        // Une entree deja posee se modifie, une entree absente se cree. La
        // creation seule porte les liens vers le compte et la serie : une mise
        // a jour qui les reecrirait deplacerait l entree d un compte a l autre.
        guard let identifiantDEntree = entreeExistante else {
            let corps = try CorpsJson.encoder(
                EnveloppeDeCreation(
                    data: ObjetACreer(
                        type: Self.typeDEntree,
                        attributes: attributs,
                        relationships: LiensDEntree(
                            user: LienJsonApi(data: ReferenceJsonApi(type: "users", id: compte.identifiant)),
                            media: LienJsonApi(
                                data: ReferenceJsonApi(type: "manga", id: liaison.identifiantDistant)
                            )
                        )
                    )
                )
            )

            return AppelDeSuivi(chemin: "library-entries", methode: .post, corps: .json(corps))
        }

        let corps = try CorpsJson.encoder(
            EnveloppeDeModification(
                data: ObjetAModifier(
                    type: Self.typeDEntree,
                    id: identifiantDEntree,
                    attributes: attributs
                )
            )
        )

        return AppelDeSuivi(chemin: "library-entries/\(identifiantDEntree)", methode: .patch, corps: .json(corps))
    }

    /// Type JSON:API des entrees de bibliotheque.
    static let typeDEntree = "libraryEntries"

    /// Statut tel que le service le nomme.
    ///
    /// La relecture est ramenee a la lecture en cours, comme chez le service
    /// precedent et pour la meme raison.
    static func statut(_ statut: StatutDeSuivi) -> String {
        switch statut {
        case .enLecture, .relecture: "current"
        case .termine: "completed"
        case .enPause: "on_hold"
        case .abandonne: "dropped"
        case .prevu: "planned"
        }
    }
}

// MARK: Corps envoye

// La creation et la modification ont deux enveloppes distinctes plutot qu une
// enveloppe generique dont les liens seraient facultatifs. Un type generique
// dont le parametre n apparait que dans une valeur nulle ne s infere pas, et le
// specifier a la main a l appel dirait au lecteur qu il existe une forme sans
// liens sans lui dire laquelle. Deux types disent lequel des deux corps part,
// et la creation ne peut alors pas oublier ses liens.

private struct EnveloppeDeCreation: Encodable {
    let data: ObjetACreer
}

private struct ObjetACreer: Encodable {
    let type: String
    let attributes: AttributsDEntree
    let relationships: LiensDEntree
}

private struct EnveloppeDeModification: Encodable {
    let data: ObjetAModifier
}

private struct ObjetAModifier: Encodable {
    let type: String
    let id: String
    let attributes: AttributsDEntree
}

private struct AttributsDEntree: Encodable {
    let progress: Int
    let status: String
    let ratingTwenty: Int?
}

private struct LiensDEntree: Encodable {
    let user: LienJsonApi
    let media: LienJsonApi
}

private struct LienJsonApi: Encodable {
    let data: ReferenceJsonApi
}

private struct ReferenceJsonApi: Encodable {
    let type: String
    let id: String
}

// MARK: Corps recu

private struct ReponseDesUtilisateurs: Decodable {
    let data: [Utilisateur]

    struct Utilisateur: Decodable {
        let id: String
        let attributes: Attributs

        struct Attributs: Decodable {
            let name: String?
        }
    }
}

private struct ReponseDesSeries: Decodable {
    let data: [Serie]

    struct Serie: Decodable {
        let id: String
        let attributes: Attributs

        struct Attributs: Decodable {
            let canonicalTitle: String?
            let titles: [String: String]?
            let startDate: String?
            let chapterCount: Int?

            /// Titres publies autres que le titre canonique.
            var autresTitres: [String] {
                (titles ?? [:]).values
                    .filter { $0.isEmpty == false && $0 != canonicalTitle }
                    .sorted()
            }

            /// Annee lue au debut de la date de parution.
            var annee: Int? {
                startDate.flatMap { Int($0.prefix(4)) }
            }
        }
    }
}

private struct ReponseDesEntrees: Decodable {
    let data: [Entree]

    struct Entree: Decodable {
        let id: String
    }
}
