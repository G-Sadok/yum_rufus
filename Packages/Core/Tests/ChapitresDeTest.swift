import Core
import Foundation

/// Fabrique de chapitres pour les tests de la fiche de serie.
///
/// Les identifiants sont tires au hasard, seuls comptent le rang, l etat de
/// lecture et le telechargement.
enum ChapitresDeTest {
    /// Chapitre au rang demande, non lu par defaut.
    static func chapitre(
        rang: Int,
        numero: Double? = nil,
        titre: String? = nil,
        datePublication: Date? = nil,
        nombrePages: Int = 24,
        estLu: Bool = false,
        pageAtteinte: Int = 0,
        dateLecture: Date? = nil,
        estTelecharge: Bool = false
    ) -> ChapitreDeFiche {
        ChapitreDeFiche(
            id: UUID(),
            numero: numero ?? Double(rang + 1),
            titre: titre,
            datePublication: datePublication,
            nombrePages: nombrePages,
            estLu: estLu,
            pageAtteinte: pageAtteinte,
            dateLecture: dateLecture,
            ordreDansSerie: rang,
            estTelecharge: estTelecharge
        )
    }

    /// Serie de chapitres non lus, du rang zero au rang demande moins un.
    static func serie(de nombre: Int) -> [ChapitreDeFiche] {
        (0..<nombre).map { rang in chapitre(rang: rang) }
    }

    /// Les quatre etats du tableau 4.5, dans l ordre du document.
    static func lesQuatreEtats() -> [ChapitreDeFiche] {
        [
            chapitre(rang: 0),
            chapitre(rang: 1, estLu: true, dateLecture: Date()),
            chapitre(rang: 2, nombrePages: 38, pageAtteinte: 13),
            chapitre(rang: 3, estTelecharge: true),
        ]
    }
}
