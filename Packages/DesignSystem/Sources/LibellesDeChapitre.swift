import Core
import Foundation

//
// Composition du titre et de la sous ligne d un chapitre, tableau 4.5 de
// DESIGN-SPEC.md.
//
// Les mots viennent du catalogue de chaines de l application, sous forme de
// motifs. L assemblage vit ici, dans le paquet qui rend la ligne, parce qu il
// depend de l etat : un chapitre lu, un chapitre en cours et un chapitre non lu
// ne composent pas la meme sous ligne, et la regle de la section 9 veut qu une
// sous ligne ne soit jamais vide.
//
// Le separateur est une paire d espaces. Le document ecrit `12 aout 2026  24
// pages` et `Chapitre 43  Le titre du chapitre` : c est la seule forme de
// separation qu il emploie, la regle 0 lui interdisant le tiret cadratin.
//

/// Motifs de libelle d une ligne de chapitre, pris dans le catalogue de chaines.
public struct LibellesDeChapitre: Sendable, Equatable {
    /// Motif du titre, avec le numero en argument, `Chapitre %@`.
    public let chapitreNumerote: String

    /// Mot pose en tete de la sous ligne d un chapitre deja ouvert, `Lu`.
    public let lu: String

    /// Motif du nombre de pages, `%lld pages`.
    public let nombreDePages: String

    /// Motif de la progression, `page %1$lld sur %2$lld`.
    public let pageSurTotal: String

    /// Mot ajoute en fin de sous ligne pour un chapitre disponible hors ligne.
    public let telecharge: String

    /// Etiquette d accessibilite de l icone de telechargement.
    public let etiquetteDeTelechargement: String

    public init(
        chapitreNumerote: String,
        lu: String,
        nombreDePages: String,
        pageSurTotal: String,
        telecharge: String,
        etiquetteDeTelechargement: String
    ) {
        self.chapitreNumerote = chapitreNumerote
        self.lu = lu
        self.nombreDePages = nombreDePages
        self.pageSurTotal = pageSurTotal
        self.telecharge = telecharge
        self.etiquetteDeTelechargement = etiquetteDeTelechargement
    }
}

/// Assemblage des textes d une ligne de chapitre.
public enum TexteDeChapitre {
    /// Separateur employe par le document entre deux fragments d une meme ligne.
    public static let separateur = "  "

    /// Titre de la ligne, `Chapitre 43  Le titre du chapitre`.
    ///
    /// Le titre du chapitre est facultatif, beaucoup de sources n en donnent
    /// aucun. La ligne se reduit alors a `Chapitre 43`, jamais a un separateur
    /// suivi de rien.
    public static func titre(de chapitre: ChapitreDeFiche, libelles: LibellesDeChapitre) -> String {
        let numerote = String(
            format: libelles.chapitreNumerote,
            numero(chapitre.numero)
        )

        guard let titre = chapitre.titre, !titre.isEmpty else {
            return numerote
        }

        return joindre([numerote, titre])
    }

    /// Sous ligne de la ligne, jamais vide, tableau 4.5.
    ///
    /// - Non lu : `12 aout 2026  24 pages`, la date tombant quand la source ne
    ///   la donne pas.
    /// - Lu : `Lu`.
    /// - En cours : `Lu  page 14 sur 38`.
    /// - Telecharge : le suffixe `telecharge` s ajoute a la forme ci dessus.
    public static func sousLigne(
        de chapitre: ChapitreDeFiche,
        libelles: LibellesDeChapitre,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var fragments: [String] = []

        switch chapitre.lecture {
        case .nonLu:
            if let date = chapitre.datePublication {
                fragments.append(self.date(date, locale: locale))
            }

            fragments.append(
                String(format: libelles.nombreDePages, chapitre.nombrePages)
            )

        case .lu:
            fragments.append(libelles.lu)

        case .enCours:
            fragments.append(libelles.lu)
            fragments.append(
                String(
                    format: libelles.pageSurTotal,
                    chapitre.pageAtteinte + 1,
                    max(chapitre.nombrePages, chapitre.pageAtteinte + 1)
                )
            )
        }

        if chapitre.estTelecharge {
            fragments.append(libelles.telecharge)
        }

        return joindre(fragments)
    }

    /// Part de la progression d un chapitre en cours, de 0 a 1.
    ///
    /// Sert au filet de 3 pose sur le bord inferieur de la ligne. Un chapitre
    /// dont la source n annonce aucune page rend zero plutot qu une division
    /// par zero.
    public static func progression(de chapitre: ChapitreDeFiche) -> Double {
        guard chapitre.nombrePages > 0 else {
            return 0
        }

        let part = Double(chapitre.pageAtteinte + 1) / Double(chapitre.nombrePages)

        return min(max(part, 0), 1)
    }

    /// Numero de chapitre affiche, `42` ou `42,5` selon la langue.
    ///
    /// Les numeros entiers ne trainent pas de decimale, les chapitres bonus
    /// gardent la leur.
    public static func numero(_ valeur: Double) -> String {
        valeur.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Date de publication, `12 aout 2026`.
    public static func date(_ valeur: Date, locale: Locale = .autoupdatingCurrent) -> String {
        valeur.formatted(
            Date.FormatStyle(locale: locale)
                .day()
                .month(.wide)
                .year()
        )
    }

    /// Fragments assembles avec le separateur du document.
    ///
    /// Les fragments vides sont ecartes, pour qu aucune ligne ne se termine par
    /// un separateur orphelin.
    public static func joindre(_ fragments: [String]) -> String {
        fragments
            .filter { !$0.isEmpty }
            .joined(separator: separateur)
    }
}
