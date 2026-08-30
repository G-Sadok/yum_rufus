import Core
import SwiftUI

//
// Ecran Statistiques de lecture, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Gabarit colonne 580, quatre etats, quatre cartes : la journee en cours et son
// objectif, la serie de jours, les sept derniers jours, les totaux. Les lignes
// elles memes vivent dans LignesDeStatistiques.swift.
//
// Deux decisions de composition meritent d etre ecrites.
//
// La premiere est la place de l objectif quotidien. L inventaire de la section
// 9 du cahier de developpement le decrit comme un compteur de la section
// General, `Desactive` puis 1 a 20 chapitres. La section 5.5 de DESIGN-SPEC.md
// fixe le contenu de sa section General d apres le wireframe 05, qui en dessine
// quatre lignes et pas cinq. Ajouter la ligne la contredirait, la poser dans une
// autre des dix sept sections la mal nommerait. Le compteur vit donc sur l ecran
// qu il gouverne, avec la variante, les bornes et la valeur livree que le cahier
// impose. C est l arbitrage de la section 0.1 : la valeur chiffree du cahier
// fait foi, l organisation du document de design aussi.
//
// La seconde est l etat vide. La carte de l objectif reste montree meme quand
// rien n a encore ete compte : c est un reglage, et un ecran qui cacherait le
// reglage tant que la statistique est vide empecherait de fixer l objectif
// avant la premiere lecture, c est a dire au seul moment ou on veut le fixer.
// L etat vide prend la place des trois cartes de comptage, pas celle de la
// colonne entiere.
//

/// Etat de la zone de contenu de l ecran de statistiques.
public enum EtatDeStatistiques {
    /// Comptage en cours de lecture.
    case chargement

    /// Comptage pret. Un instantane sans journee donne l etat vide.
    case chargees(StatistiquesDeLecture, RappelDObjectif)

    /// Le comptage n a pas pu etre lu. L etat est compose par l appelant, qui
    /// seul connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les commandes de l ecran declenchent.
///
/// Aucune de ces fermetures n ecrit en base elle meme. Elles remontent a
/// l ecran, seul a connaitre le magasin.
public struct CommandesDeStatistiques {
    /// Remplace l objectif quotidien.
    public let definirLObjectif: @MainActor (ObjectifQuotidien) -> Void

    /// Arme ou desarme le rappel.
    public let basculerLeRappel: @MainActor (Bool) -> Void

    /// Ouvre la bibliotheque, action de l etat vide. Nulle quand l ecran ne peut
    /// mener nulle part, auquel cas l etat vide n affiche aucun bouton.
    public let ouvrirLaBibliotheque: (@MainActor () -> Void)?

    public init(
        definirLObjectif: @escaping @MainActor (ObjectifQuotidien) -> Void,
        basculerLeRappel: @escaping @MainActor (Bool) -> Void,
        ouvrirLaBibliotheque: (@MainActor () -> Void)?
    ) {
        self.definirLObjectif = definirLObjectif
        self.basculerLeRappel = basculerLeRappel
        self.ouvrirLaBibliotheque = ouvrirLaBibliotheque
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeStatistiques {
        CommandesDeStatistiques(
            definirLObjectif: { _ in },
            basculerLeRappel: { _ in },
            ouvrirLaBibliotheque: nil
        )
    }
}

/// Ecran de consultation des statistiques de lecture.
public struct VueDeStatistiques: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeStatistiques
    private let libelles: LibellesDeStatistiques
    private let commandes: CommandesDeStatistiques

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, comptage ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les controles declenchent.
    public init(
        etat: EtatDeStatistiques,
        libelles: LibellesDeStatistiques,
        commandes: CommandesDeStatistiques
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surfaces.canvas.couleur)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            colonne { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargees(statistiques, rappel):
            colonne {
                carteDeLaJournee(statistiques, rappel: rappel)

                if statistiques.estVide {
                    VueDEtatDeContenu(etatVide)
                } else {
                    carteDeLaSerie(statistiques)
                    carteDesDerniersJours(statistiques)
                    carteDesTotaux(statistiques)
                }
            }
        }
    }

    // MARK: Colonne

    /// Gabarit colonne 580, celui de l ecran Reglages dont ce sous ecran part.
    private func colonne(@ViewBuilder _ interieur: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Jetons.Statistiques.espaceEntreSections) {
                titre
                interieur()
            }
            .frame(maxWidth: Jetons.Statistiques.largeurDeColonne)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Jetons.Contenu.margeLaterale)
            .padding(.vertical, Jetons.Statistiques.margeVerticale)
        }
    }

    private var titre: some View {
        Text(libelles.titre)
            .style(Jetons.Statistiques.enTete)
            .foregroundStyle(palette.textes.primary.couleur)
            .accessibilityAddTraits(.isHeader)
    }

    /// Une carte de section : en tete, carte, description facultative.
    private func section(
        enTete: String,
        description: String? = nil,
        @ViewBuilder lignes: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(enTete)
                .style(Jetons.Statistiques.enTete)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.Statistiques.ecartApresLEnTete)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                lignes()
            }
            .background(palette.surfaces.card.couleur)
            .clipShape(
                RoundedRectangle(cornerRadius: Jetons.Statistiques.rayon, style: .continuous)
            )

            if let description {
                Text(description)
                    .style(Jetons.Statistiques.description)
                    .foregroundStyle(palette.textes.tertiary.couleur)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Jetons.Statistiques.ecartAvantLaDescription)
            }
        }
    }

    /// Filet encastre de 20 a gauche, affleurant a droite, section 4.2.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.Statistiques.epaisseurDuSeparateur)
            .padding(.leading, Jetons.Statistiques.encastrementDuSeparateur)
            .accessibilityHidden(true)
    }

    // MARK: La journee en cours

    private func carteDeLaJournee(
        _ statistiques: StatistiquesDeLecture,
        rappel: RappelDObjectif
    ) -> some View {
        section(
            enTete: libelles.sectionAujourdHui,
            description: String(
                format: libelles.descriptionDuRappel,
                TexteDeStatistiques.heureDuRappel(rappel)
            )
        ) {
            LigneDeProgressionDuJour(statistiques: statistiques, libelles: libelles)
            separateur
            LigneDObjectif(
                objectif: statistiques.objectif,
                libelles: libelles,
                changer: commandes.definirLObjectif
            )
            separateur
            LigneDeRappel(
                rappel: rappel,
                objectif: statistiques.objectif,
                libelles: libelles,
                basculer: commandes.basculerLeRappel
            )
        }
    }

    // MARK: La serie

    private func carteDeLaSerie(_ statistiques: StatistiquesDeLecture) -> some View {
        section(enTete: libelles.sectionSerie, description: libelles.descriptionDeLaSerie) {
            LigneChiffree(
                symbole: Jetons.Statistiques.symboleDeLaSerie,
                libelle: libelles.serie,
                valeur: TexteDeStatistiques.longueurDeLaSerie(
                    statistiques.serieDeJours,
                    libelles: libelles
                )
            )
            separateur
            LigneChiffree(
                symbole: Jetons.Statistiques.symboleDesJours,
                libelle: libelles.joursDeLecture,
                valeur: TexteDeStatistiques.compteDeJours(
                    statistiques.joursDeLecture,
                    libelles: libelles
                )
            )
        }
    }

    // MARK: Les sept derniers jours

    private func carteDesDerniersJours(_ statistiques: StatistiquesDeLecture) -> some View {
        let journees = statistiques.derniersJours
        let maximum = statistiques.maximumDesDerniersJours

        return section(enTete: libelles.sectionDerniersJours) {
            ForEach(Array(journees.enumerated()), id: \.element.id) { rang, journee in
                LigneDeJournee(
                    journee: journee,
                    part: Double(journee.chapitresLus) / Double(maximum),
                    libelles: libelles
                )

                if rang < journees.count - 1 {
                    separateur
                }
            }
        }
    }

    // MARK: Les totaux

    private func carteDesTotaux(_ statistiques: StatistiquesDeLecture) -> some View {
        section(enTete: libelles.sectionTotaux) {
            LigneChiffree(
                symbole: Jetons.Statistiques.symboleDesChapitres,
                libelle: libelles.chapitresLus,
                valeur: TexteDeStatistiques.compteDeChapitres(
                    statistiques.totalDeChapitres,
                    libelles: libelles
                )
            )
            separateur
            LigneChiffree(
                symbole: Jetons.Statistiques.symboleDesPages,
                libelle: libelles.pagesLues,
                valeur: TexteDeStatistiques.compteDePages(
                    statistiques.totalDePages,
                    libelles: libelles
                )
            )
        }
    }

    // MARK: Chargement et etat vide

    /// Squelettes aux dimensions exactes des cartes attendues, section 4.10.
    private var squelettes: some View {
        VStack(alignment: .leading, spacing: Jetons.Statistiques.espaceEntreSections) {
            ForEach(0..<Jetons.Statistiques.nombreDeSquelettes, id: \.self) { _ in
                VueDeSquelette()
                    .frame(height: Jetons.Statistiques.hauteurAvecBarre)
            }
        }
    }

    /// Etat vide de la section 4.10.
    ///
    /// Il porte l action seulement quand l appelant sait ou elle mene. Un bouton
    /// qui ne repond pas coute plus cher qu un etat vide sans bouton, et la
    /// section 4.10 rend l action facultative.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Statistiques.symbole,
            titre: libelles.videTitre,
            phrase: libelles.videPhrase,
            action: commandes.ouvrirLaBibliotheque.map { ouvrir in
                ActionDEtat(libelle: libelles.videAction) { ouvrir() }
            }
        )
    }
}
