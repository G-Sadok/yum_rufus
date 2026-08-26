import Core
import Foundation

//
// Libelles de la feuille d installation d une extension et de l ecran de
// depot, sections 4.9 et 5.3 de DESIGN-SPEC.md.
//
// Aucune chaine n est ecrite ici. Ce type transporte celles que l application a
// lues dans son catalogue, et sait laquelle correspond a quel etat.
//

/// Libelles de la feuille d installation d une extension.
public struct LibellesDInstallationDExtension: Sendable, Equatable {
    /// Sous titre de la feuille, `Version %@, %@`, version puis langue.
    public let versionEtLangue: String

    /// Etiquette de la liste des domaines.
    public let etiquetteDesDomaines: String

    /// Phrase qui explique ce que la liste engage, au dessus de la liste.
    public let phraseDesDomaines: String

    /// Mention affichee quand un domaine couvre ses sous domaines.
    public let mentionDesSousDomaines: String

    /// Mention de responsabilite, section 4.3 du cahier de developpement.
    ///
    /// Elle n est affichee qu au premier ajout d un depot. Voir
    /// `AvertissementDeDepot.afficheLaResponsabilite`.
    public let mentionDeResponsabilite: String

    /// Case a cocher qui debloque l installation.
    public let confirmationDeLecture: String

    /// Etiquette d accessibilite d un domaine de la liste.
    public let etiquetteDUnDomaine: String

    /// Bouton de gauche, qui referme sans installer.
    public let annuler: String

    /// Bouton de droite, qui installe.
    public let installer: String

    public init(
        versionEtLangue: String,
        etiquetteDesDomaines: String,
        phraseDesDomaines: String,
        mentionDesSousDomaines: String,
        mentionDeResponsabilite: String,
        confirmationDeLecture: String,
        etiquetteDUnDomaine: String,
        annuler: String,
        installer: String
    ) {
        self.versionEtLangue = versionEtLangue
        self.etiquetteDesDomaines = etiquetteDesDomaines
        self.phraseDesDomaines = phraseDesDomaines
        self.mentionDesSousDomaines = mentionDesSousDomaines
        self.mentionDeResponsabilite = mentionDeResponsabilite
        self.confirmationDeLecture = confirmationDeLecture
        self.etiquetteDUnDomaine = etiquetteDUnDomaine
        self.annuler = annuler
        self.installer = installer
    }
}

/// Assemblage des textes de la feuille d installation.
public enum TexteDInstallationDExtension {
    /// Sous titre de la feuille, version puis langue.
    public static func versionEtLangue(
        de avertissement: AvertissementDInstallation,
        libelles: LibellesDInstallationDExtension
    ) -> String {
        String(format: libelles.versionEtLangue, "v" + avertissement.version.texte, avertissement.langue)
    }

    /// Etiquette d accessibilite d un domaine, qui nomme ce qu il couvre.
    ///
    /// Le domaine seul se lit mal a la synthese vocale : `*.exemple.net` s y
    /// prononce comme une suite de symboles. L etiquette dit la meme chose en
    /// mots.
    public static func etiquette(
        de domaine: DomaineAutorise,
        libelles: LibellesDInstallationDExtension
    ) -> String {
        String(format: libelles.etiquetteDUnDomaine, domaine.hote)
    }
}
