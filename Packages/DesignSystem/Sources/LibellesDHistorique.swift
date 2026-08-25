import Core
import Foundation

//
// Libelles de l ecran Historique, sections 5.2, 6.3, 6.4 et 6.5 de
// DESIGN-SPEC.md.
//
// Aucune chaine n est ecrite ici. Ce type transporte celles que l application a
// lues dans son catalogue, et sait laquelle correspond a quel etat.
//

/// Libelles de l historique et de sa modale de confirmation.
public struct LibellesDHistorique: Sendable, Equatable {
    /// Motif du chapitre affiche sous le titre de serie, `Chapitre %@`.
    public let chapitreNumerote: String

    /// En tete du jour courant.
    public let aujourdHui: String

    /// En tete de la veille.
    public let hier: String

    /// Etiquette d accessibilite du bouton de suppression d une entree.
    public let supprimerLEntree: String

    /// Commande d effacement global, tableau 6.5.
    public let effacerLHistorique: String

    /// Titre de la modale de confirmation, section 4.8.
    public let confirmationTitre: String

    /// Description de la modale de confirmation.
    public let confirmationDescription: String

    /// Bouton de gauche de la modale.
    public let confirmationAnnuler: String

    /// Bouton de droite de la modale, celui qui efface.
    public let confirmationEffacer: String

    public init(
        chapitreNumerote: String,
        aujourdHui: String,
        hier: String,
        supprimerLEntree: String,
        effacerLHistorique: String,
        confirmationTitre: String,
        confirmationDescription: String,
        confirmationAnnuler: String,
        confirmationEffacer: String
    ) {
        self.chapitreNumerote = chapitreNumerote
        self.aujourdHui = aujourdHui
        self.hier = hier
        self.supprimerLEntree = supprimerLEntree
        self.effacerLHistorique = effacerLHistorique
        self.confirmationTitre = confirmationTitre
        self.confirmationDescription = confirmationDescription
        self.confirmationAnnuler = confirmationAnnuler
        self.confirmationEffacer = confirmationEffacer
    }
}

/// Assemblage des textes de l ecran Historique.
public enum TexteDHistorique {
    /// Chapitre d une entree, `Chapitre 43  Le titre du chapitre`.
    ///
    /// Le titre du chapitre est facultatif. La ligne se reduit alors a
    /// `Chapitre 43`, jamais a un separateur suivi de rien.
    public static func chapitre(
        de entree: EntreeDHistorique,
        libelles: LibellesDHistorique
    ) -> String {
        let numerote = String(
            format: libelles.chapitreNumerote,
            TexteDeChapitre.numero(entree.numeroDeChapitre)
        )

        guard let titre = entree.titreDuChapitre, !titre.isEmpty else {
            return numerote
        }

        return TexteDeChapitre.joindre([numerote, titre])
    }

    /// Heure de la lecture, `21:04`, en chiffres tabulaires cote vue.
    public static func heure(
        de entree: EntreeDHistorique,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        entree.dateLecture.formatted(
            Date.FormatStyle(locale: locale)
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
        )
    }

    /// En tete d une journee, porte par l en tete collant.
    ///
    /// Les deux jours les plus recents se nomment, les autres portent leur
    /// date. La section 5.2 impose la date sans en fixer le format, et un
    /// en tete `Aujourd hui` se lit plus vite qu une date que l utilisateur
    /// doit comparer a la sienne.
    public static func enTete(
        de journee: JourneeDHistorique,
        libelles: LibellesDHistorique,
        calendrier: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        maintenant: Date = Date()
    ) -> String {
        let aujourdHui = calendrier.startOfDay(for: maintenant)

        if journee.debutDuJour == aujourdHui {
            return libelles.aujourdHui
        }

        let hier = calendrier.date(byAdding: .day, value: -1, to: aujourdHui)

        if journee.debutDuJour == hier {
            return libelles.hier
        }

        return journee.debutDuJour.formatted(
            Date.FormatStyle(locale: locale)
                .weekday(.wide)
                .day()
                .month(.wide)
                .year()
        )
    }
}
