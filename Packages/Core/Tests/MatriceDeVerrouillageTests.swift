import Foundation
import Testing
@testable import Core

//
// Matrice de verrouillage, section 10 du cahier de developpement.
//
// Les deux colonnes de la matrice ne sont pas recopiees ici. Elles sont lues
// dans le document, et confrontees a l enumeration du code. Une fonction
// deplacee d une colonne a l autre, ajoutee ou retiree, et la suite vire au
// rouge avant que l ecran ne mente sur ce que l abonnement ouvre.
//
// La suite couvre trois choses distinctes. Que le code connaisse exactement les
// fonctions du document. Que chaque fonction premium soit effectivement fermee
// sans abonnement, dans les cinq etats possibles. Et que rien de gratuit ne se
// ferme jamais, ce qui est la moitie la plus facile a casser par inadvertance.
//

/// Materiel partage par les suites de la matrice.
enum MaterielDeMatrice {
    /// Les cinq etats possibles de l abonnement, avec des dates fixes.
    static let tousLesEtats: [EtatDePremium] = [
        .gratuit,
        .essai(finLe: date(8, 3)),
        .abonne(genre: .mensuel, renouvelleLe: date(1, 4)),
        .definitif,
        .expire(le: date(1, 2)),
    ]

    /// Etats qui ouvrent les fonctions premium.
    static let etatsOuvrants: [EtatDePremium] = tousLesEtats
        .filter(\.donneAccesAuxFonctionsPremium)

    /// Etats qui les ferment.
    static let etatsFermants: [EtatDePremium] = tousLesEtats
        .filter { $0.donneAccesAuxFonctionsPremium == false }

    /// Date fixe, pour que rien ne depende de l heure de la machine.
    static func date(_ jour: Int, _ mois: Int) -> Date {
        var composantes = DateComponents()
        composantes.year = 2026
        composantes.month = mois
        composantes.day = jour
        composantes.timeZone = TimeZone(identifier: "UTC")

        return Calendar(identifier: .gregorian).date(from: composantes) ?? .distantPast
    }
}

/// Les fonctions connues du code sont exactement celles du document.
struct MatriceLueDansLeCahierTests {
    @Test("Le document liste bien deux colonnes non vides")
    func leDocumentPorteLaMatrice() throws {
        let matrice = try CahierDeDeveloppement.matricePremium()

        #expect(matrice.gratuites.isEmpty == false, "La section 10 doit lister les fonctions gratuites")
        #expect(matrice.premium.isEmpty == false, "La section 10 doit lister les fonctions premium")
    }

    @Test("Chaque fonction gratuite du document existe dans le code, du bon cote")
    func lesFonctionsGratuitesSontCouvertes() throws {
        let matrice = try CahierDeDeveloppement.matricePremium()

        for nom in matrice.gratuites {
            let fonction = FonctionDeLApplication.portant(leNomDuDocument: nom)

            #expect(fonction != nil, "La fonction gratuite \(nom) n a aucun cas dans le code")
            #expect(fonction?.estPremium == false, "\(nom) est gratuite au document et premium au code")
        }
    }

    @Test("Chaque fonction premium du document existe dans le code, du bon cote")
    func lesFonctionsPremiumSontCouvertes() throws {
        let matrice = try CahierDeDeveloppement.matricePremium()

        for nom in matrice.premium {
            let fonction = FonctionDeLApplication.portant(leNomDuDocument: nom)

            #expect(fonction != nil, "La fonction premium \(nom) n a aucun cas dans le code")
            #expect(fonction?.estPremium == true, "\(nom) est premium au document et gratuite au code")
        }
    }

    @Test("Le code n invente aucune fonction absente du document")
    func aucuneFonctionInventee() throws {
        let matrice = try CahierDeDeveloppement.matricePremium()
        let nomsDuDocument = Set(matrice.gratuites + matrice.premium)

        for fonction in FonctionDeLApplication.allCases {
            #expect(
                nomsDuDocument.contains(fonction.nomDuDocument),
                "\(fonction.nomDuDocument) ne figure dans aucune colonne de la section 10"
            )
        }
    }

    @Test("Les deux colonnes couvrent le meme nombre de cas que l enumeration")
    func aucunDoublonNiAucunTrou() throws {
        let matrice = try CahierDeDeveloppement.matricePremium()

        #expect(FonctionDeLApplication.allCases.count == matrice.gratuites.count + matrice.premium.count)
        #expect(FonctionDeLApplication.premium.count == matrice.premium.count)
        #expect(FonctionDeLApplication.gratuites.count == matrice.gratuites.count)
    }
}

/// L acces rendu par la matrice, etat par etat.
struct AccesRenduParLaMatriceTests {
    @Test("Sans abonnement, chaque fonction premium est verrouillee")
    func toutesLesFonctionsPremiumSontFermeesSansAbonnement() {
        for etat in MaterielDeMatrice.etatsFermants {
            for fonction in FonctionDeLApplication.premium {
                let acces = MatriceDeVerrouillage.acces(a: fonction, selon: etat)

                #expect(
                    acces == .verrouille,
                    "\(fonction.nomDuDocument) reste ouverte dans l etat \(etat)"
                )
            }
        }
    }

    @Test("Avec abonnement, essai ou achat definitif, chaque fonction premium est ouverte")
    func toutesLesFonctionsPremiumSontOuvertesAvecAbonnement() {
        for etat in MaterielDeMatrice.etatsOuvrants {
            for fonction in FonctionDeLApplication.premium {
                #expect(MatriceDeVerrouillage.acces(a: fonction, selon: etat) == .ouvert)
            }
        }
    }

    @Test("Une fonction gratuite n est jamais verrouillee, quel que soit l etat")
    func aucuneFonctionGratuiteNEstFermee() {
        for etat in MaterielDeMatrice.tousLesEtats {
            for fonction in FonctionDeLApplication.gratuites {
                #expect(
                    MatriceDeVerrouillage.acces(a: fonction, selon: etat) == .ouvert,
                    "\(fonction.nomDuDocument) se ferme dans l etat \(etat)"
                )
            }
        }
    }

    @Test("L expiration ferme exactement les memes fonctions que l absence d achat")
    func lExpirationSeComporteCommeLAbsenceDAchat() {
        let expire = EtatDePremium.expire(le: MaterielDeMatrice.date(1, 2))
        let apresExpiration = MatriceDeVerrouillage.fonctionsVerrouillees(selon: expire)
        let sansAchat = MatriceDeVerrouillage.fonctionsVerrouillees(selon: .gratuit)

        #expect(apresExpiration == sansAchat)
        #expect(apresExpiration == Set(FonctionDeLApplication.premium))
    }
}

/// Les fonctions atteintes par les lignes de reglages.
struct VerrouillageDesLignesDeReglagesTests {
    /// Les lignes que la section 10 place derriere l abonnement.
    ///
    /// La liste est celle des lignes qui arment une fonction premium, pas celle
    /// des sections. Une ligne qui n offre aucun controle, comme `Dernier
    /// envoi`, ne se verrouille pas : la couronne y remplacerait un controle
    /// qui n existe pas.
    static let lignesPremium: [IdentifiantDeReglage] = [
        .incognito,
        .traduireLesBulles,
        .moteurDeTraduction,
        .langueCible,
        .policeDeRemplacement,
        .servicesDeSuivi,
        .envoyerLaProgression,
        .confirmerAvantDEnvoyer,
        .qualiteDeTelechargement,
        .enWiFiSeulement,
        .chapitresALAvance,
        .emplacementDesTelechargements,
        .sauvegarderMaintenant,
        .sauvegardeAutomatique,
        .restaurerDepuisUnFichier,
        .synchroniserLaProgression,
        .synchroniserLaBibliotheque,
        .detailDuStockage,
    ]

    @Test("Chaque ligne du catalogue est classee, une seule fois")
    func toutesLesLignesSontClassees() {
        let classees = Set(MatriceDeVerrouillage.fonctionParLigne.keys)
        let sansFonction = MatriceDeVerrouillage.lignesSansFonction

        for identifiant in IdentifiantDeReglage.allCases {
            let dansLaTable = classees.contains(identifiant)
            let horsMatrice = sansFonction.contains(identifiant)

            #expect(
                dansLaTable != horsMatrice,
                "\(identifiant.rawValue) est classee deux fois ou pas du tout"
            )
        }

        #expect(classees.union(sansFonction).count == IdentifiantDeReglage.allCases.count)
    }

    @Test("Chaque ligne de la matrice est verrouillee sans abonnement")
    func lesLignesPremiumSontVerrouillees() {
        for identifiant in Self.lignesPremium {
            #expect(
                MatriceDeVerrouillage.estVerrouillee(identifiant, selon: .gratuit),
                "\(identifiant.rawValue) reste reglable sans abonnement"
            )
            #expect(
                MatriceDeVerrouillage.estVerrouillee(identifiant, selon: .expire(le: MaterielDeMatrice.date(1, 2))),
                "\(identifiant.rawValue) reste reglable apres expiration"
            )
        }
    }

    @Test("Aucune ligne premium ne reste verrouillee une fois l abonnement pris")
    func lesLignesPremiumSOuvrent() {
        for identifiant in Self.lignesPremium {
            for etat in MaterielDeMatrice.etatsOuvrants {
                #expect(MatriceDeVerrouillage.estVerrouillee(identifiant, selon: etat) == false)
            }
        }
    }

    @Test("Toute autre ligne du catalogue reste accessible sans abonnement")
    func lesLignesGratuitesRestentAccessibles() {
        let premium = Set(Self.lignesPremium)

        for ligne in CatalogueDeReglages.toutesLesLignes where premium.contains(ligne.id) == false {
            #expect(
                MatriceDeVerrouillage.estVerrouillee(ligne.id, selon: .gratuit) == false,
                "\(ligne.id.rawValue) se verrouille alors que la section 10 ne le demande pas"
            )
        }
    }

    @Test("Les deux commandes qui liberent de l espace restent accessibles sans abonnement")
    func lesPurgesDeStockageRestentAccessibles() {
        #expect(MatriceDeVerrouillage.estVerrouillee(.viderLeCacheDImages, selon: .gratuit) == false)
        #expect(
            MatriceDeVerrouillage.estVerrouillee(.supprimerTousLesTelechargements, selon: .gratuit) == false
        )
    }

    @Test("La ligne d appel a l abonnement n est jamais verrouillee par elle meme")
    func lAppelALAbonnementResteOuvert() {
        for etat in MaterielDeMatrice.tousLesEtats {
            #expect(MatriceDeVerrouillage.estVerrouillee(.passerAPremium, selon: etat) == false)
            #expect(MatriceDeVerrouillage.estVerrouillee(.restaurerLesAchats, selon: etat) == false)
        }
    }
}

/// Les fonctions atteintes par les sources et par les traitements d image.
struct VerrouillageDesSourcesTests {
    @Test("Les quatre serveurs de la matrice sont premium, les autres sources non")
    func lesServeursSontPremium() {
        let premium: Set<TypeDeSource> = [.komga, .kavita, .jellyfin, .opds]

        for type in TypeDeSource.allCases {
            let fonction = MatriceDeVerrouillage.fonction(de: type)

            #expect(
                fonction.estPremium == premium.contains(type),
                "\(type.rawValue) n est pas du bon cote de la matrice"
            )
        }
    }

    @Test("Une source premium est verrouillee sans abonnement et ouverte avec")
    func lAccesAUneSourceSuitLAbonnement() {
        for etat in MaterielDeMatrice.etatsFermants {
            #expect(MatriceDeVerrouillage.acces(aLaSourceDeType: .komga, selon: etat) == .verrouille)
        }

        for etat in MaterielDeMatrice.etatsOuvrants {
            #expect(MatriceDeVerrouillage.acces(aLaSourceDeType: .komga, selon: etat) == .ouvert)
        }
    }

    @Test("Une source gratuite reste ouverte dans les cinq etats")
    func lesSourcesGratuitesRestentOuvertes() {
        let gratuites: [TypeDeSource] = [
            .fichiersLocaux, .iCloudDrive, .smb, .nfs, .webdav,
            .extensionDeclarative, .depotExtensions, .transfertWiFi,
        ]

        for etat in MaterielDeMatrice.tousLesEtats {
            for type in gratuites {
                #expect(MatriceDeVerrouillage.acces(aLaSourceDeType: type, selon: etat) == .ouvert)
            }
        }
    }

    @Test("Les deux traitements par IA sont premium, la reduction de bruit non")
    func lesTraitementsIASontPremium() {
        for traitement in TraitementDImage.allCases {
            let fonction = MatriceDeVerrouillage.fonction(de: traitement)

            #expect(
                fonction.estPremium == traitement.estReserveAuPremium,
                "\(traitement.rawValue) n est pas du bon cote de la matrice"
            )
        }
    }
}
