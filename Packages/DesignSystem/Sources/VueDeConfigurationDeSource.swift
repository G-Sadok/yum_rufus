import Core
import SwiftUI

//
// VueDeConfigurationDeSource
//
// La feuille qu ouvre chaque entree du menu d ajout, section 5.3.
//
// Une seule feuille sert les huit sources a serveur. Elles demandent toutes la
// meme chose, une adresse et de quoi s authentifier, et une feuille par source
// n aurait multiplie que le nombre d endroits ou corriger la meme faute.
//
// Le bouton Enregistrer reste inerte tant que le test de connexion n a pas
// reussi. C est le critere de F027, et il protege d une source enregistree qui
// ne repondra jamais : l utilisateur la verrait dans sa liste, vide, sans
// savoir si le tort vient de l adresse, du mot de passe ou du serveur.
//

/// Ou en est la feuille.
public enum EtatDeConfiguration: Sendable, Equatable {
    /// Rien n a encore ete teste.
    case saisie

    /// Le test de connexion court.
    case test

    /// Le serveur a repondu, la source peut etre enregistree.
    case reussi

    /// Le serveur n a pas repondu, avec la raison.
    case echec(String)

    /// Vrai quand la source peut etre enregistree.
    public var permetDEnregistrer: Bool {
        self == .reussi
    }
}

/// Textes de la feuille.
public struct LibellesDeConfiguration: Sendable, Equatable {
    public let titre: String
    public let adresse: String
    public let compte: String
    public let motDePasse: String
    public let tester: String
    public let enregistrer: String
    public let annuler: String
    public let reussite: String

    public init(
        titre: String,
        adresse: String,
        compte: String,
        motDePasse: String,
        tester: String,
        enregistrer: String,
        annuler: String,
        reussite: String
    ) {
        self.titre = titre
        self.adresse = adresse
        self.compte = compte
        self.motDePasse = motDePasse
        self.tester = tester
        self.enregistrer = enregistrer
        self.annuler = annuler
        self.reussite = reussite
    }
}

/// Feuille de configuration d une source a serveur, section 5.3.
public struct VueDeConfigurationDeSource: View {
    @Environment(\.palette) private var palette

    @State private var adresse = ""
    @State private var compte = ""
    @State private var motDePasse = ""

    private let etat: EtatDeConfiguration
    private let libelles: LibellesDeConfiguration
    private let tester: (String, String, String) -> Void
    private let enregistrer: (String, String, String) -> Void
    private let annuler: () -> Void

    public init(
        etat: EtatDeConfiguration,
        libelles: LibellesDeConfiguration,
        tester: @escaping (String, String, String) -> Void,
        enregistrer: @escaping (String, String, String) -> Void,
        annuler: @escaping () -> Void
    ) {
        self.etat = etat
        self.libelles = libelles
        self.tester = tester
        self.enregistrer = enregistrer
        self.annuler = annuler
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.x4) {
            Text(libelles.titre)
                .style(Jetons.Configuration.titre)
                .foregroundStyle(palette.textes.primary.couleur)

            champ(libelles.adresse, texte: $adresse)
            champ(libelles.compte, texte: $compte)
            champSecret(libelles.motDePasse, texte: $motDePasse)

            message

            Spacer(minLength: 0)

            boutons
        }
        .padding(Jetons.Configuration.marge)
        .frame(width: Jetons.Configuration.largeur)
        .background(palette.surfaces.window.couleur)
    }

    private func champ(_ libelle: String, texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.x1) {
            Text(libelle)
                .style(Jetons.Configuration.etiquette)
                .foregroundStyle(palette.textes.tertiary.couleur)

            TextField("", text: texte)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private func champSecret(_ libelle: String, texte: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.x1) {
            Text(libelle)
                .style(Jetons.Configuration.etiquette)
                .foregroundStyle(palette.textes.tertiary.couleur)

            SecureField("", text: texte)
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Le resultat du test, quand il y en a un.
    @ViewBuilder
    private var message: some View {
        switch etat {
        case .saisie:
            EmptyView()

        case .test:
            ProgressView()
                .controlSize(.small)

        case .reussi:
            Text(libelles.reussite)
                .style(Jetons.Configuration.message)
                .foregroundStyle(palette.semantiques.accentText.couleur)

        case let .echec(raison):
            Text(raison)
                .style(Jetons.Configuration.message)
                .foregroundStyle(palette.semantiques.danger.couleur)
        }
    }

    private var boutons: some View {
        HStack(spacing: Jetons.Espace.x3) {
            Button(libelles.annuler, action: annuler)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button(libelles.tester) {
                tester(adresse, compte, motDePasse)
            }
            .disabled(adresse.isEmpty || etat == .test)

            Button(libelles.enregistrer) {
                enregistrer(adresse, compte, motDePasse)
            }
            .keyboardShortcut(.defaultAction)
            // Le critere de F027 : rien ne s enregistre avant que le serveur
            // ait repondu.
            .disabled(etat.permetDEnregistrer == false)
        }
    }
}
