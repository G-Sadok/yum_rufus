import Core
import Foundation
import GRDB

//
// MagasinDeProgression
//
// Seul point d ecriture de la position de lecture et du marquage automatique
// des chapitres lus, section 7.5 du cahier de developpement.
//
// Une position enregistree est une transaction validee. C est ce qui la fait
// survivre a une fermeture brutale : rien n attend la fermeture propre de
// l application pour partir sur le disque.
//
// Le compteur de chapitres non lus n est jamais touche ici. Les declencheurs de
// IndexEtDeclencheurs.swift le corrigent des que `estLu` change, y compris
// quand le changement vient du marquage automatique.
//
// La trace dans l historique part dans la meme transaction que la position.
// C est le seul chemin d ecriture de l historique : lire, c est laisser une
// trace, et une trace ecrite ailleurs finirait par diverger de la reprise.
//

/// Erreurs que la sauvegarde de position peut remonter.
public enum ErreurDeProgression: Error, Sendable, Equatable {
    /// Le chapitre vise n existe plus. La lecture porte sur un chapitre
    /// supprime ou sur une serie retiree pendant la session, il n y a plus rien
    /// a mettre a jour et l appelant referme le lecteur.
    case chapitreInconnu(identifiant: UUID)
}

/// Lit et ecrit la position de lecture d un chapitre.
public struct MagasinDeProgression: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Position ou reprendre ce chapitre.
    ///
    /// Un chapitre jamais ouvert rend une position en premiere page, et non
    /// nil : ouvrir un chapitre neuf et reprendre un chapitre entame sont la
    /// meme operation pour le lecteur.
    ///
    /// - Throws: `ErreurDeProgression.chapitreInconnu` si le chapitre n existe
    ///   pas.
    public func position(duChapitre identifiant: UUID) throws -> PositionDeLecture {
        try base.ecrivain.read { connexion in
            guard let chapitre = try Chapitre.fetchOne(connexion, key: identifiant) else {
                throw ErreurDeProgression.chapitreInconnu(identifiant: identifiant)
            }

            return PositionDeLecture(
                chapitreId: chapitre.id,
                pageIndex: chapitre.pageAtteinte,
                decalageDeDefilement: chapitre.decalageDeDefilement
            )
        }
    }

    // MARK: Ecriture

    /// Enregistre la position et marque le chapitre lu s il depasse le seuil.
    ///
    /// L ecriture est complete et atomique : page, decalage, date de lecture du
    /// chapitre et date de derniere lecture de la serie partent dans la meme
    /// transaction. Une fermeture brutale au milieu ne laisse donc pas une page
    /// enregistree sans son decalage.
    public func enregistrer(
        _ position: PositionDeLecture,
        le date: Date = Date(),
        calendrier: Calendar = .autoupdatingCurrent
    ) throws {
        try base.ecrivain.write { connexion in
            try Self.appliquer(position, le: date, calendrier: calendrier, dans: connexion)
        }
    }

    /// Ecrit la position sur le chapitre vise, dans la transaction ouverte.
    ///
    /// Le marquage automatique ne va que dans un sens. Un chapitre deja lu que
    /// l utilisateur rouvre a la premiere page reste lu : seul un demarquage
    /// explicite depuis la fiche de serie le fait revenir en arriere, et c est
    /// `MagasinDeFicheDeSerie` qui le porte.
    private static func appliquer(
        _ position: PositionDeLecture,
        le date: Date,
        calendrier: Calendar,
        dans connexion: Database
    ) throws {
        guard var chapitre = try Chapitre.fetchOne(connexion, key: position.chapitreId) else {
            throw ErreurDeProgression.chapitreInconnu(identifiant: position.chapitreId)
        }

        let bornee = position.normalisee(nombreDePages: chapitre.nombrePages)

        chapitre.pageAtteinte = bornee.pageIndex
        chapitre.decalageDeDefilement = bornee.decalageDeDefilement
        chapitre.dateLecture = date

        if ProgressionDeChapitre.depasseLeSeuil(
            pageAtteinte: bornee.pageIndex,
            nombreDePages: chapitre.nombrePages
        ) {
            chapitre.estLu = true
        }

        try chapitre.update(connexion)

        // La grille trie les series par derniere lecture, section 4.2 de
        // DESIGN-SPEC.md. Sans cette ligne, une serie lue pendant une heure
        // resterait au meme rang qu une serie jamais ouverte.
        try connexion.execute(
            sql: "UPDATE manga SET dateDerniereLecture = ? WHERE id = ?",
            arguments: [date, chapitre.mangaId]
        )

        try MagasinDHistorique.consigner(
            chapitre: bornee.chapitreId,
            pageAtteinte: bornee.pageIndex,
            le: date,
            calendrier: calendrier,
            dans: connexion
        )
    }
}

/// Le magasin est l enregistreur que le moteur de lecture pilote.
///
/// `ReaderEngine` ne connait que ce protocole, defini par Core. La cadence de
/// sauvegarde vit donc dans le moteur, et la base reste ici.
/// L ecriture ne se fait pas sur le fil appelant : la sauvegarde tourne toutes
/// les deux secondes pendant la lecture, et bloquer le fil a chaque echeance se
/// verrait sur la tourne de page.
extension MagasinDeProgression: EnregistreurDePosition {
    public func enregistrer(_ position: PositionDeLecture) async throws {
        let date = Date()
        let calendrier = Calendar.autoupdatingCurrent

        try await base.ecrivain.write { connexion in
            try Self.appliquer(position, le: date, calendrier: calendrier, dans: connexion)
        }
    }
}
