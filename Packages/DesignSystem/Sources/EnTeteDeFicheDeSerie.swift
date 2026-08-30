import Core
import Foundation
import SwiftUI

//
// En tete de la fiche de serie, section 5.6 de DESIGN-SPEC.md.
//
// Banniere de 300 posee sous la barre de titre, couverture floutee a 40 px de
// rayon puis voile `#131315` a 55 pour cent. Couverture nette de 188 par 278 a
// 40 du bord gauche, metadonnees a 32 de la couverture, puis les actions.
//
// Les couleurs de cet en tete ne viennent pas de la palette. Le texte repose
// sur une image assombrie, pas sur une surface du systeme, et le document
// chiffre lui meme ses valeurs pour cette raison. Elles restent identiques en
// apparence claire, ou la banniere reste sombre.
//

/// Metadonnees affichees par l en tete, deja composees par l appelant.
///
/// Les auteurs et la ligne d etat arrivent sous forme de chaines completes,
/// comme le libelle d un onglet de categorie. Leur composition demande le
/// catalogue de chaines et la langue de l utilisateur, deux choses que le
/// paquet DesignSystem n a pas a connaitre.
public struct EnTeteDeSerie: Sendable, Equatable {
    /// Titre de la serie, en `display`.
    public let titre: String

    /// Auteurs au format `Nom  et  Nom`.
    public let auteurs: String

    /// Ligne d etat au format `En cours  Japonais  Nom de la source`.
    public let ligneDEtat: String

    /// Genres, en pastilles de 26.
    public let genres: [String]

    public init(titre: String, auteurs: String, ligneDEtat: String, genres: [String]) {
        self.titre = titre
        self.auteurs = auteurs
        self.ligneDEtat = ligneDEtat
        self.genres = genres
    }
}

/// Les quatre actions de l en tete, section 5.6.
///
/// Les fermetures sont isolees au fil principal. Une action d interface part
/// toujours d un geste rendu sur ce fil, et l etat qu elle touche y vit aussi.
public struct ActionsDeFicheDeSerie {
    /// Ouvre le chapitre propose par le bouton principal.
    public let principale: @MainActor () -> Void
    /// Ajoute ou retire la serie de la bibliotheque.
    public let dansMaListe: @MainActor () -> Void
    /// Suit la serie pour etre prevenu des nouveaux chapitres.
    public let suivre: @MainActor () -> Void
    /// Ouvre le menu d options de la serie.
    public let options: @MainActor () -> Void

    public init(
        principale: @escaping @MainActor () -> Void,
        dansMaListe: @escaping @MainActor () -> Void,
        suivre: @escaping @MainActor () -> Void,
        options: @escaping @MainActor () -> Void
    ) {
        self.principale = principale
        self.dansMaListe = dansMaListe
        self.suivre = suivre
        self.options = options
    }
}

/// Banniere et metadonnees de la fiche de serie.
public struct VueDEnTeteDeSerie<Couverture: View>: View {
    private let entete: EnTeteDeSerie
    private let action: ActionPrincipaleDeFiche
    private let libelles: LibellesDeFicheDeSerie
    private let actions: ActionsDeFicheDeSerie
    private let couverture: Couverture

    /// Construit l en tete.
    ///
    /// - Parameters:
    ///   - entete: metadonnees deja composees.
    ///   - action: cas du bouton principal, calcule par Core.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - actions: ce que declenchent les quatre boutons.
    ///   - couverture: vue de la couverture, posee nette au premier plan et
    ///     floutee en fond de banniere.
    public init(
        entete: EnTeteDeSerie,
        action: ActionPrincipaleDeFiche,
        libelles: LibellesDeFicheDeSerie,
        actions: ActionsDeFicheDeSerie,
        @ViewBuilder couverture: () -> Couverture
    ) {
        self.entete = entete
        self.action = action
        self.libelles = libelles
        self.actions = actions
        self.couverture = couverture()
    }

    public var body: some View {
        contenu
            .padding(.horizontal, Jetons.FicheDeSerie.margeDeCouverture)
            .frame(height: Jetons.FicheDeSerie.hauteurDeBanniere)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(banniere)
            .clipped()
    }

    private var contenu: some View {
        HStack(alignment: .center, spacing: Jetons.FicheDeSerie.ecartApresLaCouverture) {
            couvertureNette
            metadonnees
            Spacer(minLength: 0)
        }
    }

    private var couvertureNette: some View {
        couverture
            .frame(
                width: Jetons.FicheDeSerie.largeurDeCouverture,
                height: Jetons.FicheDeSerie.hauteurDeCouverture
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Jetons.FicheDeSerie.rayonDeCouverture,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var metadonnees: some View {
        VStack(alignment: .leading, spacing: Jetons.FicheDeSerie.ecartEntreMetadonnees) {
            Text(entete.titre)
                .style(Jetons.FicheDeSerie.titre)
                .foregroundStyle(Jetons.FicheDeSerie.couleurDuTitre.couleur)
                .lineLimit(2)

            Text(entete.auteurs)
                .style(Jetons.FicheDeSerie.auteurs)
                .foregroundStyle(Jetons.FicheDeSerie.couleurDesAuteurs.couleur)
                .lineLimit(1)

            Text(entete.ligneDEtat)
                .style(Jetons.FicheDeSerie.ligneDEtat)
                .foregroundStyle(Jetons.FicheDeSerie.couleurDeLaLigneDEtat.couleur)
                .lineLimit(1)

            genres
                .padding(.top, Jetons.FicheDeSerie.ecartEntreMetadonnees)

            boutons
                .padding(.top, Jetons.FicheDeSerie.ecartDansLeCorps)
        }
    }

    @ViewBuilder
    private var genres: some View {
        if !entete.genres.isEmpty {
            HStack(spacing: Jetons.FicheDeSerie.ecartEntreActions) {
                ForEach(entete.genres, id: \.self) { genre in
                    Text(genre)
                        .style(Jetons.FicheDeSerie.libelleDeGenre)
                        .foregroundStyle(Jetons.FicheDeSerie.couleurDesAuteurs.couleur)
                        .padding(.horizontal, Jetons.FicheDeSerie.remplissageDeGenre)
                        .frame(height: Jetons.FicheDeSerie.hauteurDeGenre)
                        .background(fondDeGenre)
                }
            }
        }
    }

    private var fondDeGenre: some View {
        RoundedRectangle(
            cornerRadius: Jetons.FicheDeSerie.rayonDeGenre,
            style: .continuous
        )
        .fill(Jetons.FicheDeSerie.fondDeGenre.couleur)
    }

    private var boutons: some View {
        HStack(spacing: Jetons.FicheDeSerie.ecartEntreActions) {
            Button(libelles.libelleDuBoutonPrincipal(action), action: actions.principale)
                .buttonStyle(
                    BoutonPrincipal(
                        hauteur: Jetons.FicheDeSerie.hauteurDAction,
                        rayon: Jetons.Bouton.rayonEnContenu
                    )
                )
                .disabled(!action.estActive)

            BoutonDeBanniere(libelle: libelles.dansMaListe, action: actions.dansMaListe)
            BoutonDeBanniere(libelle: libelles.suivre, action: actions.suivre)

            BoutonDeBanniere(
                libelle: libelles.options,
                largeur: Jetons.FicheDeSerie.largeurDuBoutonDOptions,
                symbole: Jetons.IconeDeFicheDeSerie.options,
                action: actions.options
            )
        }
    }

    /// Couverture floutee, voile, et rien d autre. Le flou ne porte aucune
    /// couleur.
    ///
    /// C est le seul flou des ecrans de navigation. Le lecteur en a un second,
    /// beaucoup plus petit, sous la surimpression de traduction de la section 8,
    /// qui reprend le meme principe, image floutee puis voile.
    private var banniere: some View {
        ZStack {
            couverture
                .scaledToFill()
                .blur(radius: Jetons.FicheDeSerie.rayonDeFlou)

            Jetons.FicheDeSerie.voile.couleur
        }
        .accessibilityHidden(true)
    }
}

/// Bouton secondaire pose sur la banniere.
///
/// Il n emploie pas `BoutonSecondaire` : la section 5.6 lui donne un fond
/// `rgba(255,255,255,0.16)` justement parce qu il ne repose pas sur une surface
/// du systeme mais sur une image assombrie.
private struct BoutonDeBanniere: View {
    let libelle: String
    var largeur: CGFloat?
    var symbole: String?
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            etiquette
                .padding(.horizontal, largeur == nil ? Jetons.Bouton.remplissageHorizontal : 0)
                .frame(width: largeur)
                .frame(height: Jetons.FicheDeSerie.hauteurDAction)
                .background(fond)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle)
    }

    @ViewBuilder
    private var etiquette: some View {
        if let symbole {
            Image(systemName: symbole)
                .foregroundStyle(Jetons.FicheDeSerie.couleurDuTitre.couleur)
        } else {
            Text(libelle)
                .style(Jetons.LigneDeChapitre.titre)
                .foregroundStyle(Jetons.FicheDeSerie.couleurDuTitre.couleur)
        }
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Bouton.rayonEnContenu, style: .continuous)
            .fill(Jetons.FicheDeSerie.fondDActionSecondaire.couleur)
    }
}
