import Core
import DesignSystem
import Foundation

//
// Assemblage des libelles de la fiche de serie.
//
// C est le seul endroit de l application ou les cles du catalogue rejoignent le
// composant de la section 5.6. Le paquet DesignSystem choisit lequel afficher
// selon l etat, il n en ecrit aucun.
//

extension LibellesDeFicheDeSerie {
    /// Libelles de la fiche, pris dans le catalogue de chaines.
    static var duCatalogue: LibellesDeFicheDeSerie {
        LibellesDeFicheDeSerie(
            commencerLaLecture: Chaines.Fiche.commencerLaLecture,
            reprendreChapitre: Chaines.Fiche.reprendreChapitre,
            toutEstLu: Chaines.Fiche.toutEstLu,
            aucunChapitre: Chaines.Fiche.aucunChapitre,
            dansMaListe: Chaines.Fiche.dansMaListe,
            suivre: Chaines.Fiche.suivre,
            options: Chaines.Fiche.options,
            retour: Chaines.Fiche.retour,
            afficherPlus: Chaines.Fiche.afficherPlus,
            afficherMoins: Chaines.Fiche.afficherMoins,
            compteurDeChapitres: Chaines.Liste.compteurDeChapitres,
            filtrer: Chaines.Liste.filtrer,
            trier: Chaines.Liste.trier,
            toutMarquerLu: Chaines.Liste.toutMarquerLu,
            chapitres: .duCatalogue,
            selection: .duCatalogue
        )
    }
}

extension LibellesDeChapitre {
    /// Motifs d une ligne de chapitre, pris dans le catalogue de chaines.
    static var duCatalogue: LibellesDeChapitre {
        LibellesDeChapitre(
            chapitreNumerote: Chaines.Chapitre.numerote,
            lu: Chaines.Chapitre.lu,
            nombreDePages: Chaines.Chapitre.nombreDePages,
            pageSurTotal: Chaines.Chapitre.pageSurTotal,
            telecharge: Chaines.Chapitre.telecharge,
            etiquetteDeTelechargement: Chaines.Chapitre.etiquetteDeTelechargement
        )
    }
}

extension LibellesDeSelectionDeChapitres {
    /// Libelles de la barre de selection, pris dans le catalogue de chaines.
    static var duCatalogue: LibellesDeSelectionDeChapitres {
        LibellesDeSelectionDeChapitres(
            compteur: Chaines.Selection.compteur,
            marquerLu: Chaines.Selection.marquerLu,
            telecharger: Chaines.Selection.telecharger,
            supprimer: Chaines.Selection.supprimer,
            fermer: Chaines.Selection.fermer,
            selectionner: Chaines.Selection.selectionner,
            etendreLaSelection: Chaines.Selection.etendreLaSelection
        )
    }
}

/// Composition des metadonnees de l en tete, section 5.6.
///
/// Le titre, les auteurs et la ligne d etat sont assembles ici parce qu ils
/// demandent la langue de l utilisateur et le catalogue de chaines, deux choses
/// que le paquet DesignSystem ne connait pas.
enum MetadonneesDeSerie {
    /// En tete d une serie, source comprise.
    static func enTete(de serie: Manga, nomDeLaSource: String) -> EnTeteDeSerie {
        EnTeteDeSerie(
            titre: serie.titre,
            auteurs: auteurs(de: serie),
            ligneDEtat: ligneDEtat(de: serie, nomDeLaSource: nomDeLaSource),
            genres: serie.genres
        )
    }

    /// Auteurs et dessinateurs, au format `Nom  et  Nom` de la section 5.6.
    ///
    /// Un dessinateur deja cite comme auteur n apparait qu une fois : beaucoup
    /// de sources renseignent le meme nom dans les deux champs.
    static func auteurs(de serie: Manga) -> String {
        var noms: [String] = []

        for nom in serie.auteurs + serie.dessinateurs where !noms.contains(nom) {
            noms.append(nom)
        }

        return TexteDeChapitre.joindre(noms)
    }

    /// Ligne d etat au format `En cours  Japonais  Nom de la source`.
    ///
    /// Chaque fragment absent disparait sans laisser de separateur. Un statut
    /// inconnu n est pas affiche : le document veut une ligne qui informe, pas
    /// une ligne qui avoue son ignorance.
    static func ligneDEtat(de serie: Manga, nomDeLaSource: String) -> String {
        TexteDeChapitre.joindre([
            statut(de: serie) ?? "",
            langue(de: serie) ?? "",
            nomDeLaSource,
        ])
    }

    /// Statut editorial traduit, nul quand la source ne le connait pas.
    ///
    /// Le tableau 6.7 ne liste pas les statuts de serie, l ecran de reglages
    /// n en propose aucun. Ils passent donc par le catalogue de statuts du
    /// systeme, qui les traduit deja dans les six langues de la section 13.
    private static func statut(de serie: Manga) -> String? {
        switch serie.statut {
        case .inconnu: nil
        case .enCours: Chaines.Statut.enCours
        case .termine: Chaines.Statut.termine
        case .enPause: Chaines.Statut.enPause
        case .abandonne: Chaines.Statut.abandonne
        }
    }

    /// Langue de la serie, ecrite dans la langue de l utilisateur.
    private static func langue(de serie: Manga) -> String? {
        guard let code = serie.langue else {
            return nil
        }

        return Locale.autoupdatingCurrent.localizedString(forLanguageCode: code)
    }
}
