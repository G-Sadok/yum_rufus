import Core
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

//
// Contenu affiche pour chaque destination.
//
// Les ecrans eux memes arrivent avec leurs fonctionnalites. Ce que la coquille
// montre aujourd hui n est pas un bouchon : c est l etat reel de chaque ecran
// sur une installation neuve, avec les libelles exacts du tableau 6.3.
//
// Reglages fait exception. La section 5.5 dit que sa colonne est toujours
// complete, meme sur une installation neuve, ou seules les valeurs disent
// l absence. Cet ecran n a donc pas d etat vide : il montre ses lignes, et des
// squelettes tant que la base n a rien rendu.
//

/// Zone de contenu d une destination.
struct VueDeDestination: View {
    /// Destination affichee.
    let destination: DestinationPrincipale

    /// Etat de l ecran Historique, partage avec la barre d outils qui porte sa
    /// commande d effacement.
    let historique: EtatDHistorique

    /// Ecran Parcourir, section 5.3.
    @Bindable var parcourir: SessionDeParcourir

    /// Ecran Bibliotheque, section 5.1.
    let bibliotheque: SessionDeBibliotheque

    /// Fiche de serie ouverte, section 5.6.
    let serie: SessionDeNavigationDeSerie

    /// Colonne de reglages, section 5.5.
    ///
    /// Liee et non simplement passee : la feuille posee par dessus la colonne
    /// se referme en ecrivant dans la session, et une valeur non liee ne
    /// laisserait aucun moyen de la refermer.
    @Bindable var reglages: SessionDeReglages

    /// Ecrans ouverts depuis les lignes de navigation des reglages.
    let statistiques: SessionDeStatistiques
    let stockage: SessionDeStockage
    let prereglages: SessionDePrereglages

    /// Ouvre une autre destination, pour les actions des etats vides.
    let ouvrir: (DestinationPrincipale) -> Void

    var body: some View {
        switch destination {
        case .bibliotheque:
            VueDeBibliotheque(
                etat: bibliotheque.etat,
                libelles: .duCatalogue,
                commandes: bibliotheque.commandes(
                    ouvrirLaSerie: { serie.ouvrir($0) },
                    ajouterUneSource: { ouvrir(.parcourir) }
                )
            )
            .task { bibliotheque.recharger() }

        case .historique:
            // La navigation vers le lecteur n existe pas encore dans la
            // coquille. Plutot qu une ligne qui ne repond pas au clic, les
            // entrees restent inertes tant que rien ne peut les ouvrir : un
            // bouton qui ment coute plus cher qu un bouton absent.
            EcranDHistorique(
                etat: historique,
                ouvrirLeChapitre: nil,
                ouvrirLaBibliotheque: { ouvrir(.bibliotheque) }
            )

        case .parcourir:
            VueDeParcourir(
                etat: parcourir.etat,
                libelles: .duCatalogue,
                commandes: parcourir.commandes
            )
            .task { parcourir.recharger() }
            .fileImporter(
                isPresented: $parcourir.choisitUnDossier,
                allowedContentTypes: [.folder]
            ) { resultat in
                if case let .success(url) = resultat {
                    parcourir.ajouterLeDossier(url)
                }
            }
            .sheet(item: $parcourir.typeEnConfiguration) { type in
                VueDeConfigurationDeSource(
                    etat: parcourir.etatDeConfiguration,
                    libelles: .duCatalogue(pour: type),
                    tester: { adresse, compte, motDePasse in
                        parcourir.tester(
                            adresse: adresse,
                            compte: compte,
                            motDePasse: motDePasse
                        )
                    },
                    enregistrer: { adresse, compte, motDePasse in
                        parcourir.enregistrerLaSource(
                            adresse: adresse,
                            compte: compte,
                            motDePasse: motDePasse
                        )
                    },
                    annuler: { parcourir.fermerLaConfiguration() }
                )
            }

        case .rechercher:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.icone(de: destination),
                    titre: Chaines.EtatVide.rechercherTitre,
                    phrase: Chaines.EtatVide.rechercherPhrase,
                    action: nil
                )
            )

        case .reglages:
            VueDeReglages(
                etat: reglages.etat,
                banniere: reglages.banniere,
                libelles: .duCatalogue,
                commandes: reglages.commandes
            )
            .sheet(item: $reglages.ecranOuvert) { ecran in
                ecranDeReglages(ecran)
            }
        }
    }

    /// Ecran pose par dessus la colonne de reglages.
    @ViewBuilder
    private func ecranDeReglages(_ ecran: EcranDeReglages) -> some View {
        switch ecran {
        case .statistiques:
            VueDeStatistiques(
                etat: statistiques.etat,
                libelles: .duCatalogue,
                commandes: statistiques.commandes { ouvrir(.bibliotheque) }
            )
            .task { statistiques.recharger() }

        case .stockage:
            VueDeGestionDuStockage(
                etat: stockage.etat,
                libelles: .duCatalogue,
                commandes: stockage.commandes { _ in }
            )
            .task { await stockage.recharger() }

        case .prereglages:
            VueDeGestionDesPrereglages(
                etat: prereglages.etat,
                libelles: .duCatalogue,
                commandes: prereglages.commandes
            )
            .task { prereglages.recharger() }
        }
    }
}
