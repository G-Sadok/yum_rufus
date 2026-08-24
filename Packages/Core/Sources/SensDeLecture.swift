//
// SensDeLecture
//
// Propriete du modele, persistee, jamais deduite dans une vue.
//

/// Sens dans lequel les pages d une serie s enchainent.
///
/// C est une valeur du modele. Elle est reglable globalement et surchargeable
/// serie par serie via `Manga.sensLectureForce`. Elle gouverne l ordre des
/// pages, la composition des doubles pages, l ordre des moities apres division
/// d une image large, la direction du geste, le sens du curseur, la fleche
/// clavier et l orientation des zones de toucher.
///
/// Ne la confonds jamais avec la direction de l interface, qui suit la langue
/// du systeme. Les deux notions coincident en francais et divergent en arabe,
/// ou l interface passe de droite a gauche alors qu un manhwa se lit toujours
/// de gauche a droite.
public enum SensDeLecture: String, Sendable, Codable, CaseIterable, Hashable {
    /// Manga japonais. La premiere page d une double page est a droite.
    case droiteGauche

    /// Manhua, comics et la plupart des bandes dessinees occidentales.
    case gaucheDroite

    /// Webtoon, defilement vertical continu.
    case hautBas

    /// Sens applique quand ni la serie ni le reglage global ne tranchent.
    public static let parDefaut: SensDeLecture = .gaucheDroite

    /// Vrai quand la sequence se parcourt verticalement plutot qu en pages.
    public var estVertical: Bool {
        self == .hautBas
    }

    /// Vrai quand la moitie droite d une image large vient en premier apres
    /// division, et quand la premiere page d une paire se place a droite.
    public var commenceParLaDroite: Bool {
        self == .droiteGauche
    }
}
