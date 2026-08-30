import Core
import SwiftUI

//
// Les lignes de l ecran Statistiques de lecture, section 4.1 de DESIGN-SPEC.md.
//
// Elles vivent a cote de l ecran et non dedans, pour que le fichier de l ecran
// reste lisible d un seul tenant : il decrit alors la colonne et ses quatre
// cartes, sans le detail de chaque ligne.
//
// Aucune de ces lignes n invente de geometrie. Elles reprennent la ligne de
// reglage de la section 4.1, sa marge de 20, son icone de 22 en accent, sa
// gouttiere de 16, sa hauteur de 52, et 76 quand une barre se pose sous le
// libelle.
//

/// Ligne qui montre ce que la journee en cours a compte, et sa barre.
///
/// La barre est un complement du chiffre, jamais son remplacant : la section 7
/// interdit qu une information ne soit portee que par une forme ou une couleur.
struct LigneDeProgressionDuJour: View {
    @Environment(\.palette) private var palette

    let statistiques: StatistiquesDeLecture
    let libelles: LibellesDeStatistiques

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Statistiques.ecartAvantLaBarre) {
            HStack(spacing: Jetons.Statistiques.gouttiereApresLIcone) {
                IconeDeLigneDeStatistiques(symbole: Jetons.Statistiques.symboleDesChapitres)

                Text(libelles.lectureDuJour)
                    .style(Jetons.Statistiques.libelle)
                    .foregroundStyle(palette.textes.primary.couleur)

                Spacer(minLength: Jetons.Statistiques.ecartAvantLaValeur)

                Text(compte)
                    .style(Jetons.Statistiques.valeur, chiffresTabulaires: true)
                    .foregroundStyle(palette.textes.secondary.couleur)
            }

            BarreDeProgressionDeLecture(part: part)
                .padding(.leading, Jetons.Statistiques.decalageDeLaBarre)
        }
        .padding(.horizontal, Jetons.Statistiques.margeLaterale)
        .frame(minHeight: Jetons.Statistiques.hauteurAvecBarre)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(libelles.lectureDuJour)
        .accessibilityValue(compte)
    }

    private var compte: String {
        TexteDeStatistiques.compteDuJour(
            statistiques.journeeDuJour,
            objectif: statistiques.objectif,
            libelles: libelles
        )
    }

    private var part: Double {
        statistiques.objectif.part(chapitresLus: statistiques.journeeDuJour.chapitresLus)
    }
}

/// Ligne du compteur d objectif, variante 5 de la section 4.1.
struct LigneDObjectif: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let objectif: ObjectifQuotidien
    let libelles: LibellesDeStatistiques
    let changer: @MainActor (ObjectifQuotidien) -> Void

    var body: some View {
        HStack(spacing: Jetons.Statistiques.gouttiereApresLIcone) {
            IconeDeLigneDeStatistiques(symbole: Jetons.Statistiques.symboleDeLObjectif)

            Text(libelles.objectif)
                .style(Jetons.Statistiques.libelle)
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer(minLength: Jetons.Statistiques.ecartAvantLaValeur)

            CompteurDeReglage(
                valeur: objectif.compteur,
                texte: TexteDeStatistiques.valeurDeLObjectif(objectif, libelles: libelles),
                bornes: ObjectifQuotidien.bornesDuCompteur,
                etiquetteDAugmentation: libelles.augmenter,
                etiquetteDeDiminution: libelles.diminuer,
                changer: { cran in changer(ObjectifQuotidien(compteur: cran)) }
            )
            .focused($focalisee)
            .accessibilityLabel(libelles.objectif)
        }
        .padding(.horizontal, Jetons.Statistiques.margeLaterale)
        .frame(minHeight: Jetons.Statistiques.hauteurDeLigne)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(ContourDeFocusDeStatistiques(visible: focalisee))
    }
}

/// Ligne du rappel, variante 1 de la section 4.1.
///
/// L interrupteur est inactif tant qu aucun objectif n est fixe : un rappel sans
/// objectif n aurait rien a rappeler. Il n est pas masque pour autant, sans quoi
/// la carte changerait de hauteur au premier cran du compteur.
struct LigneDeRappel: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let rappel: RappelDObjectif
    let objectif: ObjectifQuotidien
    let libelles: LibellesDeStatistiques
    let basculer: @MainActor (Bool) -> Void

    var body: some View {
        HStack(spacing: Jetons.Statistiques.gouttiereApresLIcone) {
            IconeDeLigneDeStatistiques(symbole: Jetons.Statistiques.symboleDuRappel)

            Text(libelles.rappel)
                .style(Jetons.Statistiques.libelle)
                .foregroundStyle(couleurDuLibelle)

            Spacer(minLength: Jetons.Statistiques.ecartAvantLaValeur)

            Toggle(
                libelles.rappel,
                isOn: Binding(get: { rappel.actif }, set: { basculer($0) })
            )
            .labelsHidden()
            .toggleStyle(StyleDInterrupteur())
            .focused($focalisee)
        }
        .padding(.horizontal, Jetons.Statistiques.margeLaterale)
        .frame(minHeight: Jetons.Statistiques.hauteurDeLigne)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(ContourDeFocusDeStatistiques(visible: focalisee))
        .disabled(objectif.estActif == false)
    }

    private var couleurDuLibelle: Color {
        objectif.estActif ? palette.textes.primary.couleur : palette.textes.disabled.couleur
    }
}

/// Ligne qui montre un libelle et un nombre.
struct LigneChiffree: View {
    @Environment(\.palette) private var palette

    let symbole: String
    let libelle: String
    let valeur: String

    var body: some View {
        HStack(spacing: Jetons.Statistiques.gouttiereApresLIcone) {
            IconeDeLigneDeStatistiques(symbole: symbole)

            Text(libelle)
                .style(Jetons.Statistiques.libelle)
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer(minLength: Jetons.Statistiques.ecartAvantLaValeur)

            Text(valeur)
                .style(Jetons.Statistiques.valeur, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.secondary.couleur)
        }
        .padding(.horizontal, Jetons.Statistiques.margeLaterale)
        .frame(minHeight: Jetons.Statistiques.hauteurDeLigne)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Une journee de la carte des sept derniers jours.
struct LigneDeJournee: View {
    @Environment(\.palette) private var palette

    let journee: JourneeDeLecture
    let part: Double
    let libelles: LibellesDeStatistiques

    var body: some View {
        HStack(spacing: Jetons.Statistiques.ecartDansUneJournee) {
            Text(TexteDeStatistiques.nomDeLaJournee(journee))
                .style(Jetons.Statistiques.libelleDeJournee)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .lineLimit(1)
                .frame(
                    width: Jetons.Statistiques.largeurDuLibelleDeJournee,
                    alignment: .leading
                )

            BarreDeProgressionDeLecture(part: part)

            Text(String(journee.chapitresLus))
                .style(Jetons.Statistiques.valeurSecondaire, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.secondary.couleur)
                .frame(
                    width: Jetons.Statistiques.largeurDuCompteDeJournee,
                    alignment: .trailing
                )
        }
        .padding(.horizontal, Jetons.Statistiques.margeLaterale)
        .frame(minHeight: Jetons.Statistiques.hauteurDeJournee)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TexteDeStatistiques.etiquetteDeLaJournee(journee, libelles: libelles))
    }
}

/// Barre de progression, geometrie du filet de la section 3.
struct BarreDeProgressionDeLecture: View {
    @Environment(\.palette) private var palette

    let part: Double

    var body: some View {
        GeometryReader { cadre in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.surfaces.selected.couleur)

                Capsule()
                    .fill(palette.semantiques.accent.couleur)
                    .frame(width: cadre.size.width * min(max(part, 0), 1))
            }
        }
        .frame(height: Jetons.Statistiques.hauteurDeLaBarre)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// Icone de gauche d une ligne, section 4.1.
struct IconeDeLigneDeStatistiques: View {
    @Environment(\.palette) private var palette

    let symbole: String

    var body: some View {
        Image(systemName: symbole)
            .font(.system(size: Jetons.Statistiques.tailleDIcone))
            .foregroundStyle(palette.semantiques.accent.couleur)
            .frame(width: Jetons.Statistiques.tailleDIcone)
            .accessibilityHidden(true)
    }
}

/// Contour de focus clavier, section 7. Jamais supprime.
struct ContourDeFocusDeStatistiques: View {
    @Environment(\.palette) private var palette

    let visible: Bool

    var body: some View {
        if visible {
            RoundedRectangle(cornerRadius: Jetons.Focus.decalage, style: .continuous)
                .strokeBorder(
                    palette.semantiques.focusRing.couleur,
                    lineWidth: Jetons.Focus.epaisseur
                )
                .padding(-Jetons.Focus.decalage)
        }
    }
}
