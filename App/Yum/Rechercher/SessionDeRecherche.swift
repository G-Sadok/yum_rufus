import Core
import DesignSystem
import Foundation

//
// SessionDeRecherche
//
// Porte l ecran Rechercher : le terme saisi, et l etat d une rangee par source.
//
// La recherche part apres un temps de repos, pas a chaque frappe. Interroger
// huit serveurs a chaque caractere leur enverrait sept requetes inutiles par
// mot tape, et l affichage clignoterait a chaque reponse d une requete deja
// perimee.
//
// Chaque recherche annule la precedente. Une reponse arrivee en retard n est
// donc jamais rangee dans un ecran qui cherche autre chose : la tache est
// abandonnee, et le flux du registre annule les interrogations en cours.
//

@MainActor
@Observable
final class SessionDeRecherche {
    /// Terme saisi dans le champ de la barre d outils.
    var terme = "" {
        didSet {
            if terme != oldValue {
                programmer()
            }
        }
    }

    /// Etat des rangees, nul tant qu aucune recherche n a ete lancee.
    private(set) var resultats: ResultatsDeRecherche?

    /// Delai accorde a une source, ecrit dans sa ligne d erreur.
    var delaiEnSecondes: Int {
        Int(registre.registre.delaiMaximal.components.seconds)
    }

    /// Temps de repos avant qu une frappe declenche une recherche.
    ///
    /// Trois cents millisecondes : assez pour qu un mot tape normalement ne
    /// parte qu une fois, assez court pour que la reponse suive la saisie.
    private static let reposAvantRecherche: Duration = .milliseconds(300)

    private let registre: RegistreDesSourcesVivantes

    /// Recherche en cours, annulee des que le terme change.
    private var enCours: Task<Void, Never>?

    init(registre: RegistreDesSourcesVivantes) {
        self.registre = registre
    }

    /// Ouvre la fiche d une serie distante, nulle tant que rien ne la resout.
    var ouvrirLaSerie: (@MainActor (MangaDistant) -> Void)?

    var etat: EtatDeRecherche {
        guard let resultats else {
            return .invitation(
                .vide(
                    symbole: Jetons.Icone.rechercher,
                    titre: Chaines.EtatVide.rechercherTitre,
                    phrase: Chaines.EtatVide.rechercherPhrase,
                    action: nil
                )
            )
        }

        return .resultats(resultats)
    }

    var commandes: CommandesDeRecherche {
        CommandesDeRecherche(
            deplier: { [weak self] source in
                self?.resultats?.deplier(source)
            },
            replier: { [weak self] in
                self?.resultats?.replier()
            },
            reessayer: { [weak self] source in
                self?.relancer(source)
            },
            ouvrirLaSerie: ouvrirLaSerie
        )
    }

    // MARK: Lancement

    /// Programme la recherche du terme courant, apres son temps de repos.
    private func programmer() {
        enCours?.cancel()

        let cherche = terme.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cherche.isEmpty == false else {
            resultats = nil
            enCours = nil

            return
        }

        enCours = Task { [weak self] in
            try? await Task.sleep(for: Self.reposAvantRecherche)

            guard Task.isCancelled == false else { return }

            await self?.chercher(cherche)
        }
    }

    /// Interroge toutes les sources, et range chaque reponse a son arrivee.
    private func chercher(_ texte: String) async {
        let sources = await registre.registre.sourcesInterrogeesParUneRecherche()

        // Les rangees sont posees avant la premiere reponse, toutes en
        // chargement. Une rangee qui apparaitrait au moment de sa reponse
        // ferait sauter la mise en page a chaque source qui repond.
        resultats = ResultatsDeRecherche(terme: texte, sources: sources)

        guard sources.isEmpty == false else { return }

        let requete = RequeteRecherche(texte: texte)

        for await reponse in await registre.registre.rechercherAuFilDeLEau(requete) {
            guard Task.isCancelled == false else { return }

            // Une reponse qui ne correspond plus au terme affiche vient d une
            // recherche precedente. La ranger ferait apparaitre les resultats
            // d un mot que l utilisateur a fini d effacer.
            guard resultats?.terme == texte else { return }

            resultats?.appliquer(reponse)
        }
    }

    /// Relance la seule source dont la rangee a echoue.
    private func relancer(_ source: SourceID) {
        guard let texte = resultats?.terme else { return }

        resultats?.remettreEnChargement(source)

        Task { [weak self, registre] in
            let reponse = await registre.registre.rechercher(
                RequeteRecherche(texte: texte),
                dans: source
            )

            guard let reponse, let self, resultats?.terme == texte else { return }

            resultats?.appliquer(reponse)
        }
    }
}
