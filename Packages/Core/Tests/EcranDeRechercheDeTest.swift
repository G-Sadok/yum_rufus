import Core
import Foundation

//
// Montage commun aux suites de l ecran Rechercher.
//
// Les deux suites partent du meme etat : un registre, des sources de test, et
// l ecran prepare avec une rangee en chargement par source. Le montage vit ici
// pour que chaque suite ne porte que ce qu elle verifie.
//

/// Montage d une recherche multi sources, pour les tests.
enum EcranDeRechercheDeTest {
    /// Delai court, pour qu une source muette coute des millisecondes.
    static let delaiCourt: Duration = .milliseconds(80)

    /// Attente d une source lente, largement au dessus du temps que met une
    /// source immediate a repondre.
    static let attenteDeLaSourceLente: Duration = .milliseconds(400)

    static func requete(_ texte: String = "Serie") -> RequeteRecherche {
        RequeteRecherche(texte: texte)
    }

    /// Etat de depart de l ecran, une rangee en chargement par source.
    static func etatInitial(
        _ registre: RegistreDeSources,
        terme: String = "Serie"
    ) async -> ResultatsDeRecherche {
        await ResultatsDeRecherche(
            terme: terme,
            sources: registre.sourcesInterrogeesParUneRecherche()
        )
    }

    /// Lance la recherche et applique chaque reponse des qu elle arrive.
    static func rechercher(
        _ registre: RegistreDeSources,
        terme: String = "Serie"
    ) async -> ResultatsDeRecherche {
        var etat = await etatInitial(registre, terme: terme)

        for await resultat in await registre.rechercherAuFilDeLEau(requete(terme)) {
            etat.appliquer(resultat)
        }

        return etat
    }
}
