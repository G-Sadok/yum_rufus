import Core
import SwiftUI

//
// Feuille d installation d une extension, entree 12 du menu de la section 5.3
// de DESIGN-SPEC.md, aux dimensions de la feuille de configuration 4.9.
//
// C est la moitie visible du troisieme critere de la section 4.3 du cahier de
// developpement : l utilisateur voit la liste des domaines avant d installer et
// doit confirmer.
//
// Deux choix de forme tiennent ce critere, et aucun des deux n est cosmetique.
//
// La liste des domaines n est jamais tronquee ni repliee. Une liste derriere un
// bouton Voir plus serait une liste que l utilisateur peut ne pas avoir lue, et
// la confirmation ne vaudrait plus rien.
//
// Le bouton Installer reste desactive tant que la case de lecture n est pas
// cochee. C est la meme regle que celle de la section 4.9, ou Enregistrer reste
// desactive tant que le test de connexion n a pas reussi : la feuille refuse
// l action tant que sa condition n est pas remplie, au lieu de la proposer puis
// de la refuser.
//
// La vue ne connait ni le manifeste ni l installateur. Elle recoit
// l avertissement, qui ne porte que ce qui s affiche, et rend la confirmation a
// l appelant. Elle ne peut donc pas installer par ses propres moyens ce qu elle
// est en train de presenter.
//

/// Ce que la feuille d installation presente et ce qu elle declenche.
public struct ContenuDInstallationDExtension {
    /// Ce que l utilisateur doit lire, construit depuis le manifeste verifie.
    public let avertissement: AvertissementDInstallation

    /// Vrai quand la mention de responsabilite doit etre affichee.
    ///
    /// Voir `AvertissementDeDepot.afficheLaResponsabilite`. Elle n est montree
    /// qu au premier depot ajoute.
    public let afficheLaResponsabilite: Bool

    public let libelles: LibellesDInstallationDExtension

    /// Action de gauche, qui referme sans installer.
    public let annuler: ActionDEtat

    /// Action de droite, qui installe.
    public let installer: ActionDEtat

    public init(
        avertissement: AvertissementDInstallation,
        afficheLaResponsabilite: Bool,
        libelles: LibellesDInstallationDExtension,
        annuler: ActionDEtat,
        installer: ActionDEtat
    ) {
        self.avertissement = avertissement
        self.afficheLaResponsabilite = afficheLaResponsabilite
        self.libelles = libelles
        self.annuler = annuler
        self.installer = installer
    }
}

/// Feuille d installation d une extension, sections 4.9 et 5.3.
public struct VueDInstallationDExtension: View {
    @Environment(\.palette) private var palette

    /// Vrai quand l utilisateur declare avoir lu la liste des domaines.
    ///
    /// L etat vit dans la vue et non chez l appelant : il ne survit pas a la
    /// fermeture de la feuille, et c est voulu. Rouvrir la feuille redemande la
    /// lecture, parce que la liste a pu changer entre temps.
    @State private var listeLue = false

    private let contenu: ContenuDInstallationDExtension

    public init(_ contenu: ContenuDInstallationDExtension) {
        self.contenu = contenu
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Jetons.InstallationDExtension.ecartEntreBlocs) {
            enTete
            domaines
            responsabilite
            caseDeLecture
            boutons
        }
        .padding(.horizontal, Jetons.Feuille.margeHaute)
        .padding(.top, Jetons.Feuille.margeHaute)
        .padding(.bottom, Jetons.Feuille.margeBasse)
        .frame(width: Jetons.Feuille.largeur, alignment: .leading)
        .frame(minHeight: Jetons.Feuille.hauteurDeReference, alignment: .top)
        .background(fond)
        .elevation(Jetons.Feuille.elevation, rayon: Jetons.Feuille.rayon, palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Blocs

    private var enTete: some View {
        VStack(alignment: .leading, spacing: Jetons.Feuille.ecartApresLEtiquette) {
            Text(contenu.avertissement.nomDeLExtension)
                .style(Jetons.Feuille.titre)
                .foregroundStyle(palette.textes.primary.couleur)

            Text(TexteDInstallationDExtension.versionEtLangue(
                de: contenu.avertissement,
                libelles: contenu.libelles
            ))
            .style(Jetons.Feuille.explication)
            .foregroundStyle(palette.textes.tertiary.couleur)
        }
    }

    private var domaines: some View {
        VStack(alignment: .leading, spacing: Jetons.Feuille.ecartApresLEtiquette) {
            Text(contenu.libelles.etiquetteDesDomaines)
                .style(Jetons.Feuille.etiquette)
                .foregroundStyle(palette.textes.secondary.couleur)

            Text(contenu.libelles.phraseDesDomaines)
                .style(Jetons.Feuille.explication)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)

            liste
            mentionDesSousDomaines
        }
    }

    /// La liste complete, jamais tronquee.
    private var liste: some View {
        VStack(alignment: .leading, spacing: Jetons.InstallationDExtension.ecartEntreDomaines) {
            ForEach(contenu.avertissement.domaines, id: \.texte) { domaine in
                ligne(de: domaine)
            }
        }
    }

    private func ligne(de domaine: DomaineAutorise) -> some View {
        HStack(spacing: Jetons.InstallationDExtension.ecartApresLeGlyphe) {
            Image(systemName: Jetons.IconeDExtension.domaine)
                .font(.system(size: Jetons.InstallationDExtension.tailleDuGlyphe))
                .foregroundStyle(palette.textes.tertiary.couleur)

            Text(domaine.texte)
                .style(Jetons.InstallationDExtension.domaine)
                .foregroundStyle(palette.textes.primary.couleur)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TexteDInstallationDExtension.etiquette(
            de: domaine,
            libelles: contenu.libelles
        ))
    }

    @ViewBuilder
    private var mentionDesSousDomaines: some View {
        if contenu.avertissement.couvreDesSousDomaines {
            mention(contenu.libelles.mentionDesSousDomaines, couleur: palette.semantiques.warning.couleur)
        }
    }

    @ViewBuilder
    private var responsabilite: some View {
        if contenu.afficheLaResponsabilite {
            mention(contenu.libelles.mentionDeResponsabilite, couleur: palette.textes.tertiary.couleur)
        }
    }

    private func mention(_ texte: String, couleur: Color) -> some View {
        HStack(alignment: .top, spacing: Jetons.InstallationDExtension.ecartApresLeGlyphe) {
            // Le glyphe redit ce que la mention ecrit. Masque a VoiceOver.
            Image(systemName: Jetons.IconeDExtension.avertissement)
                .font(.system(size: Jetons.InstallationDExtension.tailleDuGlyphe))
                .foregroundStyle(couleur)
                .accessibilityHidden(true)

            Text(texte)
                .style(Jetons.InstallationDExtension.avertissement)
                .foregroundStyle(couleur)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caseDeLecture: some View {
        Button {
            listeLue.toggle()
        } label: {
            HStack(spacing: Jetons.InstallationDExtension.ecartApresLeGlyphe) {
                // La coche porte l etat de la case. Elle est masquee a
                // VoiceOver, qui recoit le meme etat par le trait `isSelected`
                // pose sur le bouton, plus lisible qu un nom de symbole.
                Image(systemName: listeLue
                    ? Jetons.IconeDExtension.listeLue
                    : Jetons.IconeDExtension.listeNonLue)
                    .font(.system(size: Jetons.InstallationDExtension.tailleDuGlyphe))
                    .accessibilityHidden(true)

                Text(contenu.libelles.confirmationDeLecture)
                    .style(Jetons.InstallationDExtension.domaine)
            }
        }
        .buttonStyle(BoutonDiscret())
        .accessibilityAddTraits(listeLue ? [.isSelected] : [])
    }

    private var boutons: some View {
        HStack(spacing: Jetons.Feuille.gouttiereEntreBoutons) {
            Spacer(minLength: 0)

            Button(contenu.annuler.libelle, action: contenu.annuler.action)
                .buttonStyle(
                    BoutonSecondaire(
                        hauteur: Jetons.Feuille.hauteurDeBouton,
                        rayon: Jetons.Feuille.rayonDeBouton
                    )
                )
                .frame(width: Jetons.Feuille.largeurDeBouton)
                .keyboardShortcut(.cancelAction)

            Button(contenu.installer.libelle, action: contenu.installer.action)
                .buttonStyle(
                    BoutonPrincipal(
                        hauteur: Jetons.Feuille.hauteurDeBouton,
                        rayon: Jetons.Feuille.rayonDeBouton
                    )
                )
                .frame(width: Jetons.Feuille.largeurDeBouton)
                .keyboardShortcut(.defaultAction)
                .disabled(listeLue == false)
        }
        .frame(maxWidth: .infinity)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Feuille.rayon, style: .continuous)
            .fill(palette.surfaces.sheet.couleur)
            .overlay {
                RoundedRectangle(cornerRadius: Jetons.Feuille.rayon, style: .continuous)
                    .strokeBorder(
                        palette.semantiques.border.couleur,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }
}
