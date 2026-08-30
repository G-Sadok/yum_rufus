import Core
import Foundation

//
// Textes de l ecran Statistiques de lecture, sous ecran de la section 5.5 de
// DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de
// l application.
//
// Le troisieme critere de F059 interdit toute formulation culpabilisante. Il
// est tenu au catalogue, et verifie par la suite de tests contre la liste de
// `FormulationBienveillante`. Ce fichier n a donc aucune regle de ton a porter,
// mais il a une regle de composition : rien ici ne qualifie une journee. Les
// fonctions rendent un compte, jamais un jugement sur ce compte.
//

/// Textes de l ecran de statistiques de lecture.
public struct LibellesDeStatistiques: Sendable, Equatable {
    /// Titre de l ecran, celui de la ligne de reglages qui mene ici.
    public let titre: String

    /// En tete de la carte de la journee en cours.
    public let sectionAujourdHui: String

    /// En tete de la carte de la serie de jours.
    public let sectionSerie: String

    /// En tete de la carte des derniers jours.
    public let sectionDerniersJours: String

    /// En tete de la carte des totaux.
    public let sectionTotaux: String

    /// Libelle de la ligne qui montre la journee en cours.
    public let lectureDuJour: String

    /// Libelle de la ligne d objectif.
    public let objectif: String

    /// Valeur du compteur quand aucun objectif n est fixe.
    public let objectifDesactive: String

    /// Valeur du compteur quand un objectif est fixe, `%lld chapitres`.
    public let objectifEnChapitres: String

    /// Etiquette du chevron qui augmente l objectif.
    public let augmenter: String

    /// Etiquette du chevron qui diminue l objectif.
    public let diminuer: String

    /// Libelle de la ligne de rappel.
    public let rappel: String

    /// Description posee sous la carte de la journee, `%@` est l heure.
    public let descriptionDuRappel: String

    /// Compte du jour avec objectif, `%1$lld sur %2$lld chapitres`.
    public let comptePartiel: String

    /// Compte du jour sans objectif, `%lld chapitres`.
    public let compteSimple: String

    /// Libelle de la ligne de serie.
    public let serie: String

    /// Longueur de la serie, `%lld jours`.
    public let serieEnJours: String

    /// Valeur de la serie quand elle vaut zero.
    public let serieVide: String

    /// Description posee sous la carte de la serie.
    public let descriptionDeLaSerie: String

    /// Libelle de la ligne des jours de lecture.
    public let joursDeLecture: String

    /// Nombre de jours, `%lld jours`.
    public let compteEnJours: String

    /// Libelle de la ligne des chapitres lus.
    public let chapitresLus: String

    /// Libelle de la ligne des pages lues.
    public let pagesLues: String

    /// Nombre de pages, `%lld pages`.
    public let compteEnPages: String

    /// Titre de l etat vide.
    public let videTitre: String

    /// Phrase de l etat vide, qui dit quoi faire.
    public let videPhrase: String

    /// Libelle de l action de l etat vide.
    public let videAction: String

    public init(
        titre: String,
        sectionAujourdHui: String,
        sectionSerie: String,
        sectionDerniersJours: String,
        sectionTotaux: String,
        lectureDuJour: String,
        objectif: String,
        objectifDesactive: String,
        objectifEnChapitres: String,
        augmenter: String,
        diminuer: String,
        rappel: String,
        descriptionDuRappel: String,
        comptePartiel: String,
        compteSimple: String,
        serie: String,
        serieEnJours: String,
        serieVide: String,
        descriptionDeLaSerie: String,
        joursDeLecture: String,
        compteEnJours: String,
        chapitresLus: String,
        pagesLues: String,
        compteEnPages: String,
        videTitre: String,
        videPhrase: String,
        videAction: String
    ) {
        self.titre = titre
        self.sectionAujourdHui = sectionAujourdHui
        self.sectionSerie = sectionSerie
        self.sectionDerniersJours = sectionDerniersJours
        self.sectionTotaux = sectionTotaux
        self.lectureDuJour = lectureDuJour
        self.objectif = objectif
        self.objectifDesactive = objectifDesactive
        self.objectifEnChapitres = objectifEnChapitres
        self.augmenter = augmenter
        self.diminuer = diminuer
        self.rappel = rappel
        self.descriptionDuRappel = descriptionDuRappel
        self.comptePartiel = comptePartiel
        self.compteSimple = compteSimple
        self.serie = serie
        self.serieEnJours = serieEnJours
        self.serieVide = serieVide
        self.descriptionDeLaSerie = descriptionDeLaSerie
        self.joursDeLecture = joursDeLecture
        self.compteEnJours = compteEnJours
        self.chapitresLus = chapitresLus
        self.pagesLues = pagesLues
        self.compteEnPages = compteEnPages
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.videAction = videAction
    }

    /// Tous les textes fixes de l ecran, motifs de composition compris.
    ///
    /// La suite de tests s en sert pour confronter l ecran entier a la liste de
    /// `FormulationBienveillante`, sans recopier la liste des champs. Un libelle
    /// ajoute a la structure et oublie ici ferait passer un texte non verifie,
    /// aussi la suite compare ce tableau au nombre de champs de la structure.
    public var tousLesTextes: [String] {
        [
            titre, sectionAujourdHui, sectionSerie, sectionDerniersJours, sectionTotaux,
            lectureDuJour, objectif, objectifDesactive, objectifEnChapitres, augmenter,
            diminuer, rappel, descriptionDuRappel, comptePartiel, compteSimple,
            serie, serieEnJours, serieVide, descriptionDeLaSerie, joursDeLecture,
            compteEnJours, chapitresLus, pagesLues, compteEnPages, videTitre,
            videPhrase, videAction,
        ]
    }
}

/// Assemblage des textes chiffres de l ecran de statistiques.
public enum TexteDeStatistiques {
    /// Compte de la journee en cours.
    ///
    /// Avec objectif, la ligne dit ou en est la journee par rapport a la cible.
    /// Sans objectif, elle dit seulement ce qui a ete lu : inventer une cible
    /// que personne n a fixee reviendrait a en faire un devoir.
    public static func compteDuJour(
        _ journee: JourneeDeLecture,
        objectif: ObjectifQuotidien,
        libelles: LibellesDeStatistiques
    ) -> String {
        guard let vise = objectif.chapitresParJour else {
            return String(format: libelles.compteSimple, journee.chapitresLus)
        }

        return String(format: libelles.comptePartiel, journee.chapitresLus, vise)
    }

    /// Valeur affichee par le compteur d objectif.
    public static func valeurDeLObjectif(
        _ objectif: ObjectifQuotidien,
        libelles: LibellesDeStatistiques
    ) -> String {
        guard let vise = objectif.chapitresParJour else {
            return libelles.objectifDesactive
        }

        return String(format: libelles.objectifEnChapitres, vise)
    }

    /// Longueur de la serie, ou son absence.
    ///
    /// Une serie a zero ne se dit pas avec un chiffre. `0 jours` se lit comme un
    /// score, et le critere d ecriture de F059 l ecarte.
    public static func longueurDeLaSerie(
        _ longueur: Int,
        libelles: LibellesDeStatistiques
    ) -> String {
        longueur > 0
            ? String(format: libelles.serieEnJours, longueur)
            : libelles.serieVide
    }

    /// Nombre de chapitres, `12 chapitres`.
    public static func compteDeChapitres(_ nombre: Int, libelles: LibellesDeStatistiques) -> String {
        String(format: libelles.compteSimple, nombre)
    }

    /// Nombre de pages, `340 pages`.
    public static func compteDePages(_ nombre: Int, libelles: LibellesDeStatistiques) -> String {
        String(format: libelles.compteEnPages, nombre)
    }

    /// Nombre de jours, `18 jours`.
    public static func compteDeJours(_ nombre: Int, libelles: LibellesDeStatistiques) -> String {
        String(format: libelles.compteEnJours, nombre)
    }

    /// Nom court d une journee de la carte des derniers jours, `lun.`.
    ///
    /// Le format vient du systeme, comme l en tete de journee de l historique.
    /// Aucun nom de jour n est ecrit dans le code ni dans le catalogue : ils
    /// changent avec la langue et avec le calendrier.
    public static func nomDeLaJournee(
        _ journee: JourneeDeLecture,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        journee.jour.formatted(Date.FormatStyle(locale: locale).weekday(.abbreviated))
    }

    /// Heure du rappel, `20:00`, telle que la description la cite.
    public static func heureDuRappel(
        _ rappel: RappelDObjectif,
        calendrier: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        reference: Date = Date()
    ) -> String {
        let echeance = calendrier.date(
            bySettingHour: rappel.heure,
            minute: rappel.minute,
            second: 0,
            of: reference,
            matchingPolicy: .nextTime
        ) ?? reference

        return echeance.formatted(
            Date.FormatStyle(locale: locale)
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
        )
    }

    /// Etiquette lue par VoiceOver sur une journee de la carte des derniers
    /// jours.
    ///
    /// La barre ne porte aucune information a elle seule, section 7 : le nom du
    /// jour et le compte sont dits dans la meme etiquette.
    public static func etiquetteDeLaJournee(
        _ journee: JourneeDeLecture,
        libelles: LibellesDeStatistiques,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        TexteDeChapitre.joindre([
            nomDeLaJournee(journee, locale: locale),
            compteDeChapitres(journee.chapitresLus, libelles: libelles),
        ])
    }
}
