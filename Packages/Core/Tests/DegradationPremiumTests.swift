import Foundation
import Testing
@testable import Core

//
// Degradation a l expiration, regle de la section 10 du cahier de
// developpement.
//
// La phrase du document tient en une ligne : si l abonnement expire, aucune
// donnee n est supprimee, les sources premium passent en lecture seule et
// affichent une banniere expliquant comment les reactiver.
//
// Trois choses se testent ici, et la premiere est la plus importante. Une
// transition d abonnement ne rend que des effets d acces, et le type des effets
// ne porte aucun cas destructeur : il n existe donc aucun chemin par lequel
// l expiration efface quoi que ce soit. Le reste verifie que la source premium
// garde ses lectures et perd ses ecritures, et que la banniere ne parait que la
// ou elle a un sens.
//

/// Materiel partage par les suites de la degradation.
enum MaterielDeDegradation {
    /// Inventaire d une bibliotheque bien remplie, avant expiration.
    static let inventaire = InventaireDesDonnees(
        sourcesConfigurees: [.fichiersLocaux, .komga, .opds, .webdav],
        seriesEnBibliotheque: 5000,
        chapitresTelecharges: 200_000,
        entreesDHistorique: 4200,
        signets: 318,
        prereglagesDeLecture: 6,
        sauvegardes: 3,
        identifiantsDansLeTrousseau: 4
    )

    /// Etat abonne de reference.
    static let abonne = EtatDePremium.abonne(
        genre: .mensuel,
        renouvelleLe: MaterielDeMatrice.date(1, 4)
    )

    /// Etat expire de reference.
    static let expire = EtatDePremium.expire(le: MaterielDeMatrice.date(1, 2))
}

/// Ce que l expiration fait aux donnees, c est a dire rien.
struct ExpirationSansPerteTests {
    @Test("Aucune transition d abonnement ne touche a l inventaire")
    func aucuneTransitionNeSupprimeRien() {
        for avant in MaterielDeMatrice.tousLesEtats {
            for apres in MaterielDeMatrice.tousLesEtats {
                let transition = TransitionDePremium(avant: avant, apres: apres)
                let apresDegradation = transition.appliquer(a: MaterielDeDegradation.inventaire)

                #expect(
                    apresDegradation == MaterielDeDegradation.inventaire,
                    "La transition de \(avant) vers \(apres) modifie l inventaire"
                )
            }
        }
    }

    @Test("Aucun effet de degradation ne touche aux donnees")
    func aucunEffetNeToucheAuxDonnees() {
        for avant in MaterielDeMatrice.tousLesEtats {
            for apres in MaterielDeMatrice.tousLesEtats {
                let transition = TransitionDePremium(avant: avant, apres: apres)

                for effet in transition.effets(pour: MaterielDeDegradation.inventaire.sourcesConfigurees) {
                    #expect(
                        effet.toucheAuxDonnees == false,
                        "L effet \(effet) touche aux donnees"
                    )
                }
            }
        }
    }

    @Test("L expiration verrouille toutes les fonctions premium, et rien d autre")
    func lExpirationVerrouilleLesFonctionsPremium() {
        let transition = TransitionDePremium(
            avant: MaterielDeDegradation.abonne,
            apres: MaterielDeDegradation.expire
        )

        let verrouillees = transition
            .effets(pour: MaterielDeDegradation.inventaire.sourcesConfigurees)
            .compactMap(\.fonctionVerrouillee)

        #expect(Set(verrouillees) == Set(FonctionDeLApplication.premium))
    }

    @Test("Reprendre un abonnement rouvre les fonctions sans rien recreer")
    func laReactivationRouvreLesFonctions() {
        let transition = TransitionDePremium(
            avant: MaterielDeDegradation.expire,
            apres: MaterielDeDegradation.abonne
        )

        let effets = transition.effets(pour: MaterielDeDegradation.inventaire.sourcesConfigurees)
        let deverrouillees = effets.compactMap(\.fonctionDeverrouillee)

        #expect(Set(deverrouillees) == Set(FonctionDeLApplication.premium))
        #expect(effets.contains(.retirerLaBanniereDeReactivation))
        #expect(transition.appliquer(a: MaterielDeDegradation.inventaire) == MaterielDeDegradation.inventaire)
    }

    @Test("Un etat inchange ne produit aucun effet")
    func unEtatInchangeNeProduitRien() {
        for etat in MaterielDeMatrice.tousLesEtats {
            let transition = TransitionDePremium(avant: etat, apres: etat)

            #expect(transition.effets(pour: MaterielDeDegradation.inventaire.sourcesConfigurees).isEmpty)
        }
    }

    @Test("Les identifiants du trousseau survivent a l expiration")
    func lesIdentifiantsSurvivent() {
        let transition = TransitionDePremium(
            avant: MaterielDeDegradation.abonne,
            apres: MaterielDeDegradation.expire
        )

        let apres = transition.appliquer(a: MaterielDeDegradation.inventaire)

        #expect(apres.identifiantsDansLeTrousseau == MaterielDeDegradation.inventaire.identifiantsDansLeTrousseau)
        #expect(apres.sourcesConfigurees == MaterielDeDegradation.inventaire.sourcesConfigurees)
        #expect(apres.chapitresTelecharges == MaterielDeDegradation.inventaire.chapitresTelecharges)
    }
}

/// Ce qu une source premium laisse faire une fois l abonnement fini.
struct SourcePremiumEnLectureSeuleTests {
    @Test("Une source premium passe en lecture seule apres expiration")
    func laSourcePremiumPasseEnLectureSeule() {
        for etat in MaterielDeMatrice.etatsFermants {
            let acces = AccesAUneSource(type: .komga, selon: etat)

            #expect(acces.estEnLectureSeule, "Komga reste modifiable dans l etat \(etat)")
        }
    }

    @Test("Une source premium redevient complete une fois l abonnement repris")
    func laSourcePremiumRedevientComplete() {
        for etat in MaterielDeMatrice.etatsOuvrants {
            #expect(AccesAUneSource(type: .komga, selon: etat).estEnLectureSeule == false)
        }
    }

    @Test("Une source gratuite n est jamais en lecture seule")
    func laSourceGratuiteResteComplete() {
        for etat in MaterielDeMatrice.tousLesEtats {
            #expect(AccesAUneSource(type: .webdav, selon: etat).estEnLectureSeule == false)
            #expect(AccesAUneSource(type: .fichiersLocaux, selon: etat).estEnLectureSeule == false)
        }
    }

    @Test("En lecture seule, tout ce qui lit reste offert")
    func laLectureResteOfferte() {
        let acces = AccesAUneSource(type: .komga, selon: MaterielDeDegradation.expire)

        for action in ActionDeSource.allCases where action.estUneEcriture == false {
            #expect(acces.autorise(action), "\(action.rawValue) est refusee alors qu elle ne fait que lire")
        }
    }

    @Test("En lecture seule, tout ce qui ecrit est refuse")
    func lEcritureEstRefusee() {
        let acces = AccesAUneSource(type: .komga, selon: MaterielDeDegradation.expire)

        for action in ActionDeSource.allCases where action.estUneEcriture {
            #expect(acces.autorise(action) == false, "\(action.rawValue) reste offerte en lecture seule")
        }

        #expect(acces.autoriseLaModificationDeLaConfiguration == false)
    }

    @Test("La suppression d une source reste possible en lecture seule")
    func laSuppressionResteOfferte() {
        let acces = AccesAUneSource(type: .komga, selon: MaterielDeDegradation.expire)

        #expect(acces.autoriseLaSuppression)
    }

    @Test("Une source complete autorise tout ce que ses capacites permettent")
    func laSourceCompleteAutoriseTout() {
        let acces = AccesAUneSource(type: .komga, selon: MaterielDeDegradation.abonne)

        for action in ActionDeSource.allCases {
            #expect(acces.autorise(action))
        }

        #expect(acces.autoriseLaModificationDeLaConfiguration)
        #expect(acces.autoriseLaSuppression)
    }
}

/// Quand la banniere de reactivation parait, et quand elle se tait.
struct BanniereDeReactivationTests {
    @Test("Une source premium en lecture seule porte la banniere")
    func laBanniereParaitSurLaSourcePremium() {
        #expect(AccesAUneSource(type: .komga, selon: MaterielDeDegradation.expire).porteLaBanniere)
        #expect(AccesAUneSource(type: .opds, selon: .gratuit).porteLaBanniere)
    }

    @Test("Une source gratuite ne porte jamais de banniere")
    func laBanniereNeParaitPasSurUneSourceGratuite() {
        for etat in MaterielDeMatrice.tousLesEtats {
            #expect(AccesAUneSource(type: .smb, selon: etat).porteLaBanniere == false)
        }
    }

    @Test("Aucune banniere quand l abonnement est actif")
    func laBanniereSeTaitAvecUnAbonnement() {
        for etat in MaterielDeMatrice.etatsOuvrants {
            #expect(AccesAUneSource(type: .komga, selon: etat).porteLaBanniere == false)
        }
    }

    @Test("La banniere ne parait qu une fois par ecran, meme avec plusieurs sources premium")
    func laBanniereEstUniqueParEcran() {
        let effets = TransitionDePremium(
            avant: MaterielDeDegradation.abonne,
            apres: MaterielDeDegradation.expire
        )
        .effets(pour: [.komga, .opds, .kavita, .fichiersLocaux])

        let bannieres = effets.filter { $0 == .afficherLaBanniereDeReactivation }

        #expect(bannieres.count == 1)
    }

    @Test("La banniere d une expiration porte la date de fin, celle d une installation neuve non")
    func leMotifDistingueLesDeuxCas() {
        let apresExpiration = AccesAUneSource(type: .komga, selon: MaterielDeDegradation.expire)
        let sansAchat = AccesAUneSource(type: .komga, selon: .gratuit)

        #expect(apresExpiration.motifDeLaBanniere == .abonnementExpire(le: MaterielDeMatrice.date(1, 2)))
        #expect(sansAchat.motifDeLaBanniere == .aucunAbonnement)
        #expect(AccesAUneSource(type: .komga, selon: MaterielDeDegradation.abonne).motifDeLaBanniere == nil)
    }

    @Test("Aucune banniere quand aucune source premium n est configuree")
    func laBanniereSeTaitSansSourcePremium() {
        let effets = TransitionDePremium(
            avant: MaterielDeDegradation.abonne,
            apres: MaterielDeDegradation.expire
        )
        .effets(pour: [.fichiersLocaux, .smb])

        #expect(effets.contains(.afficherLaBanniereDeReactivation) == false)
    }
}
