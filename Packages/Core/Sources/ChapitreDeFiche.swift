import Foundation

//
// ChapitreDeFiche
//
// Ligne de la liste des chapitres d une fiche de serie, section 4.5 de
// DESIGN-SPEC.md.
//
// Ce type existe pour la meme raison que MangaDeGrille du cote de Storage : la
// liste affiche quatre etats distincts et un ordre choisi par l utilisateur,
// elle n a besoin ni du groupe de traduction, ni de la langue, ni de
// l identifiant distant du chapitre. Ce qu elle a besoin de savoir, en
// revanche, c est si le chapitre est telecharge, information qui vit dans une
// autre table et qui ne se devine pas depuis `Chapitre`.
//
// L etat de telechargement est porte a cote de l etat de lecture et non
// dedans. Le tableau 4.5 le dit lui meme : la ligne Telecharge prend son fond
// et son titre "selon l etat de lecture". C est un supplement, pas un
// quatrieme cas exclusif.
//

/// Avancement de lecture d un chapitre, tableau 4.5.
public enum EtatDeLectureDeChapitre: String, Sendable, Codable, CaseIterable, Hashable {
    /// Jamais ouvert.
    case nonLu

    /// Ouvert, pas termine.
    case enCours

    /// Termine.
    case lu
}

/// Etat complet d une ligne de chapitre, tableau 4.5.
///
/// Les quatre lignes du tableau se lisent ici : `nonLu`, `lu`, `enCours`, et
/// n importe laquelle des trois avec `estTelecharge` a vrai.
public struct EtatDeLigneDeChapitre: Sendable, Codable, Hashable {
    /// Avancement de lecture.
    public let lecture: EtatDeLectureDeChapitre

    /// Vrai quand le chapitre est disponible hors ligne.
    public let estTelecharge: Bool

    public init(lecture: EtatDeLectureDeChapitre, estTelecharge: Bool = false) {
        self.lecture = lecture
        self.estTelecharge = estTelecharge
    }
}

/// Chapitre tel que la liste de la fiche de serie l affiche.
public struct ChapitreDeFiche: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID

    /// Numero du chapitre, decimal parce que les bonus portent des numeros
    /// comme 10.5.
    public var numero: Double

    /// Titre du chapitre, absent chez beaucoup de sources.
    public var titre: String?

    public var datePublication: Date?
    public var nombrePages: Int
    public var estLu: Bool

    /// Derniere page atteinte, indexee a partir de zero.
    public var pageAtteinte: Int

    public var dateLecture: Date?

    /// Rang du chapitre dans la serie, seul ordre fiable quand les numeros se
    /// repetent ou manquent.
    public var ordreDansSerie: Int

    /// Vrai quand le chapitre est disponible hors ligne.
    public var estTelecharge: Bool

    public init(
        id: UUID,
        numero: Double,
        titre: String? = nil,
        datePublication: Date? = nil,
        nombrePages: Int = 0,
        estLu: Bool = false,
        pageAtteinte: Int = 0,
        dateLecture: Date? = nil,
        ordreDansSerie: Int,
        estTelecharge: Bool = false
    ) {
        self.id = id
        self.numero = numero
        self.titre = titre
        self.datePublication = datePublication
        self.nombrePages = nombrePages
        self.estLu = estLu
        self.pageAtteinte = pageAtteinte
        self.dateLecture = dateLecture
        self.ordreDansSerie = ordreDansSerie
        self.estTelecharge = estTelecharge
    }

    /// Chapitre de la base, augmente de son etat de telechargement.
    public init(_ chapitre: Chapitre, estTelecharge: Bool = false) {
        self.init(
            id: chapitre.id,
            numero: chapitre.numero,
            titre: chapitre.titre,
            datePublication: chapitre.datePublication,
            nombrePages: chapitre.nombrePages,
            estLu: chapitre.estLu,
            pageAtteinte: chapitre.pageAtteinte,
            dateLecture: chapitre.dateLecture,
            ordreDansSerie: chapitre.ordreDansSerie,
            estTelecharge: estTelecharge
        )
    }

    /// Avancement de lecture, deduit de la seule base.
    ///
    /// Un chapitre marque lu est lu, quelle que soit la page atteinte. Sinon,
    /// une page atteinte non nulle veut dire qu il a ete ouvert.
    public var lecture: EtatDeLectureDeChapitre {
        if estLu {
            return .lu
        }

        return pageAtteinte > 0 ? .enCours : .nonLu
    }

    /// Etat de la ligne, tableau 4.5.
    public var etat: EtatDeLigneDeChapitre {
        EtatDeLigneDeChapitre(lecture: lecture, estTelecharge: estTelecharge)
    }
}
