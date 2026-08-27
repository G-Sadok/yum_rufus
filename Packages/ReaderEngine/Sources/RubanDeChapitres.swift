import Core
import Foundation

//
// RubanDeChapitres
//
// Geometrie de plusieurs chapitres poses bout a bout dans le meme defilement,
// section 7.4 du cahier de developpement.
//
// Quatre choix structurent ce type.
//
// Le ruban se pose sur les piles existantes plutot que de les remplacer. Un
// segment porte la pile de pages de F040, et la pile de tuiles de F041 quand le
// chapitre est lu en webtoon. Les deux modes verticaux partagent donc la meme
// geometrie d enchainement, et les questions propres a chaque mode restent
// posees a la pile qui sait y repondre.
//
// Les debuts de segment sont cumules a chaque ajout, comme les debuts de page
// le sont a la construction d une pile. Trouver le chapitre a un decalage donne
// coute un logarithme, ce qui compte : la question est posee a chaque image du
// defilement, et un ruban de dix chapitres de deux cents pages porte deux mille
// pages.
//
// L intercalaire est une hauteur passee par la vue, jamais une valeur ecrite
// ici. Ses marges verticales sont un jeton d espacement de la section 5.8 de
// DESIGN-SPEC, et un paquet metier ne connait pas les jetons.
//
// Un decalage tombe dans l intercalaire appartient au chapitre qui vient de
// finir. C est la regle deja retenue pour l interstice entre deux pages, et la
// retenir ici garde une seule regle de frontiere dans tout le moteur : la
// transition appartient a ce que l utilisateur vient de terminer.
//

/// Un chapitre pose dans le ruban, avec la geometrie de son mode de lecture.
public struct SegmentDeChapitre: Sendable, Equatable {
    /// Chapitre, tel que le catalogue l identifie.
    public let chapitreId: UUID

    /// Numero du chapitre, porte par l intercalaire qui l annonce.
    public let numero: Double

    /// Pile des pages du chapitre.
    public let pile: DefilementContinu

    /// Pile des tuiles, presente quand le chapitre est lu en webtoon.
    ///
    /// Nulle en defilement continu : la vue y pose des pages entieres, et une
    /// pile de tuiles a une tuile par page ne ferait qu ajouter une indirection
    /// sans rien decrire de plus.
    public let tuiles: PileDeTuiles?

    /// Segment lu en defilement continu.
    public init(chapitreId: UUID, numero: Double, pile: DefilementContinu) {
        self.chapitreId = chapitreId
        self.numero = numero
        self.pile = pile
        tuiles = nil
    }

    /// Segment lu en webtoon, dont les pages longues sont tuilees.
    public init(chapitreId: UUID, numero: Double, tuiles: PileDeTuiles) {
        self.chapitreId = chapitreId
        self.numero = numero
        pile = tuiles.pile
        self.tuiles = tuiles
    }

    /// Hauteur du chapitre dans le ruban, interstices de pages compris.
    public var hauteur: Double {
        pile.hauteurTotale
    }

    /// Nombre de pages du chapitre.
    public var nombreDePages: Int {
        pile.nombreDePages
    }
}

/// Endroit du ruban atteint par le defilement.
public enum EmplacementDansLeRuban: Sendable, Equatable {
    /// Dans un chapitre, avec le decalage compte depuis le haut de ce chapitre.
    case chapitre(segment: Int, decalage: Double)

    /// Dans l intercalaire qui annonce le chapitre de ce rang.
    case intercalaire(avantLeSegment: Int)
}

/// Elements d un seul chapitre touches par la fenetre affichee.
public struct TrancheVisible: Sendable, Equatable {
    /// Rang du chapitre dans le ruban.
    public let segment: Int

    /// Pages ou tuiles touchees, selon la question posee.
    public let elements: Range<Int>

    public init(segment: Int, elements: Range<Int>) {
        self.segment = segment
        self.elements = elements
    }
}

/// Chapitres poses bout a bout dans un meme defilement vertical.
public struct RubanDeChapitres: Sendable, Equatable {
    /// Hauteur de l intercalaire pose entre deux chapitres.
    public let intercalaire: Double

    /// Chapitres du ruban, dans l ordre narratif.
    public private(set) var segments: [SegmentDeChapitre]

    /// Debut de chaque segment dans le ruban, cumule a chaque ajout.
    private var debuts: [Double]

    /// Hauteur du ruban entier, intercalaires compris.
    public private(set) var hauteurTotale: Double

    /// Recul applique au bord bas d une fenetre. Meme raison qu au bord bas
    /// d une pile de pages : une fenetre qui s arrete pile sur le debut d un
    /// chapitre ne montre pas ce chapitre.
    private static let bordExclusif: Double = 1e-6

    /// Ouvre un ruban.
    ///
    /// - Parameters:
    ///   - intercalaire: hauteur du separateur pose entre deux chapitres, en
    ///     points. La valeur vient de la couche vue, section 5.8 de DESIGN-SPEC.
    ///   - segments: chapitres deja charges, dans l ordre narratif.
    public init(intercalaire: Double = 0, segments: [SegmentDeChapitre] = []) {
        self.intercalaire = max(0, intercalaire)
        self.segments = []
        debuts = []
        hauteurTotale = 0

        for segment in segments {
            ajouter(segment)
        }
    }

    /// Pose un chapitre a la suite du ruban.
    ///
    /// Un chapitre deja present n est pas repose. L enchainement peut demander
    /// deux fois le meme chapitre quand un chargement lent croise un retour en
    /// arriere, et un ruban qui accepterait le doublon ferait lire deux fois le
    /// meme chapitre.
    public mutating func ajouter(_ segment: SegmentDeChapitre) {
        guard contient(segment.chapitreId) == false else {
            return
        }

        debuts.append(segments.isEmpty ? 0 : hauteurTotale + intercalaire)
        hauteurTotale = (debuts.last ?? 0) + segment.hauteur
        segments.append(segment)
    }

    /// Ruban augmente de ce chapitre.
    public func ajoutant(_ segment: SegmentDeChapitre) -> RubanDeChapitres {
        var copie = self
        copie.ajouter(segment)

        return copie
    }

    /// Nombre de chapitres poses.
    public var nombreDeChapitres: Int {
        segments.count
    }

    /// Vrai quand aucun chapitre n est pose.
    public var estVide: Bool {
        segments.isEmpty
    }

    /// Vrai quand ce chapitre est deja pose.
    public func contient(_ chapitreId: UUID) -> Bool {
        segments.contains { $0.chapitreId == chapitreId }
    }

    /// Rang d un chapitre dans le ruban, nul quand il n y est pas pose.
    public func rang(duChapitre chapitreId: UUID) -> Int? {
        segments.firstIndex { $0.chapitreId == chapitreId }
    }

    /// Debut d un chapitre dans le ruban, nul hors du ruban.
    public func debut(duSegment rang: Int) -> Double {
        guard debuts.indices.contains(rang) else { return 0 }

        return debuts[rang]
    }

    /// Fin d un chapitre dans le ruban, intercalaire exclu.
    public func fin(duSegment rang: Int) -> Double {
        guard segments.indices.contains(rang) else { return 0 }

        return debuts[rang] + segments[rang].hauteur
    }

    /// Endroit atteint pour ce decalage, nul quand le ruban est vide.
    public func emplacement(auDecalage decalage: Double) -> EmplacementDansLeRuban? {
        guard estVide == false else { return nil }

        let bornee = min(max(decalage, 0), hauteurTotale)
        let rang = segmentCommencantAvant(bornee)
        let interne = bornee - debuts[rang]

        guard interne > segments[rang].hauteur, rang + 1 < segments.count else {
            return .chapitre(segment: rang, decalage: min(interne, segments[rang].hauteur))
        }

        return .intercalaire(avantLeSegment: rang + 1)
    }

    /// Chapitre lu a ce decalage, nul quand le ruban est vide.
    ///
    /// Un decalage tombe dans un intercalaire rend le chapitre qui vient de
    /// finir, jamais celui qui arrive : c est ce qui evite de marquer lu un
    /// chapitre que le doigt effleure en remontant.
    public func segmentCourant(auDecalage decalage: Double) -> Int? {
        switch emplacement(auDecalage: decalage) {
        case let .chapitre(rang, _):
            rang
        case let .intercalaire(rangSuivant):
            rangSuivant - 1
        case nil:
            nil
        }
    }

    /// Position de reprise a enregistrer pour ce decalage.
    ///
    /// Elle nomme le chapitre reellement lu, ce qui est toute la difference avec
    /// la position rendue par une pile seule : sans le ruban, la position d un
    /// enchainement resterait ecrite sur le premier chapitre ouvert.
    public func positionDeLecture(auDecalage decalage: Double) -> PositionDeLecture? {
        guard let emplacement = emplacement(auDecalage: decalage) else { return nil }

        switch emplacement {
        case let .chapitre(rang, interne):
            let segment = segments[rang]

            return segment.pile.positionDeLecture(
                chapitreId: segment.chapitreId,
                auDecalage: interne
            )

        case let .intercalaire(rangSuivant):
            let segment = segments[rangSuivant - 1]

            return segment.pile.positionDeLecture(
                chapitreId: segment.chapitreId,
                auDecalage: segment.hauteur
            )
        }
    }

    /// Decalage a restituer pour reprendre cette position dans le ruban.
    ///
    /// Nul quand le chapitre vise n est pas pose : un ruban n a pas a deviner ou
    /// commencerait un chapitre qu il n a pas charge.
    public func decalage(pourReprise position: PositionDeLecture) -> Double? {
        guard let rang = rang(duChapitre: position.chapitreId) else { return nil }

        return debuts[rang] + segments[rang].pile.decalage(pourReprise: position)
    }

    /// Pages touchees par la fenetre, chapitre par chapitre.
    ///
    /// La fenetre traverse l intercalaire sans se couper en deux : c est ce qui
    /// fait qu un chapitre entre par le bas de l ecran pendant que le precedent
    /// en sort par le haut, au lieu d apparaitre d un coup.
    public func pagesVisibles(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> [TrancheVisible] {
        tranches(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre) { segment, haut, hauteur in
            segment.pile.pagesVisibles(auDecalage: haut, hauteurDeLaFenetre: hauteur)
        }
    }

    /// Tuiles touchees par la fenetre, chapitre par chapitre.
    ///
    /// Un chapitre pose sans pile de tuiles ne rend aucune tranche : il est lu
    /// en defilement continu, ou la question ne se pose pas.
    public func tuilesVisibles(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> [TrancheVisible] {
        tranches(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre) { segment, haut, hauteur in
            guard let tuiles = segment.tuiles else { return 0..<0 }

            return tuiles.tuilesVisibles(auDecalage: haut, hauteurDeLaFenetre: hauteur)
        }
    }

    /// Chapitres touches par la fenetre, du premier au dernier.
    public func segmentsVisibles(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> Range<Int> {
        guard estVide == false else { return 0..<0 }

        let haut = min(max(decalage, 0), hauteurTotale)
        let bas = max(haut, haut + max(0, hauteurDeLaFenetre) - Self.bordExclusif)

        let premier = segmentCommencantAvant(haut)
        let dernier = max(premier, segmentCommencantAvant(min(bas, hauteurTotale)))

        return premier..<(dernier + 1)
    }

    /// Distance qui separe ce decalage du bas du ruban.
    ///
    /// C est elle qui declenche le chargement du chapitre suivant, et l ecran de
    /// fin de serie quand il n y a plus rien a charger.
    public func resteAParcourir(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> Double {
        let bas = min(max(decalage, 0), hauteurTotale) + max(0, hauteurDeLaFenetre)

        return max(0, hauteurTotale - bas)
    }

    /// Tranches d elements touchees par la fenetre, chapitre par chapitre.
    private func tranches(
        auDecalage decalage: Double,
        hauteurDeLaFenetre: Double,
        elements: (SegmentDeChapitre, Double, Double) -> Range<Int>
    ) -> [TrancheVisible] {
        guard estVide == false else { return [] }

        let haut = min(max(decalage, 0), hauteurTotale)
        let bas = haut + max(0, hauteurDeLaFenetre)

        return segmentsVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)
            .compactMap { rang in
                let segment = segments[rang]
                let hautLocal = max(0, haut - debuts[rang])
                let basLocal = min(bas - debuts[rang], segment.hauteur)

                guard basLocal > hautLocal else { return nil }

                let touches = elements(segment, hautLocal, basLocal - hautLocal)

                guard touches.isEmpty == false else { return nil }

                return TrancheVisible(segment: rang, elements: touches)
            }
    }

    /// Dernier chapitre dont le debut precede ce decalage, par dichotomie.
    private func segmentCommencantAvant(_ decalage: Double) -> Int {
        var bas = 0
        var haut = segments.count - 1

        while bas < haut {
            let milieu = (bas + haut + 1) / 2

            if debuts[milieu] <= decalage {
                bas = milieu
            } else {
                haut = milieu - 1
            }
        }

        return bas
    }
}
