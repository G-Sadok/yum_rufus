import Foundation

//
// Libelles de la confidentialite, section 11 du cahier de developpement.
//
// Meme decoupage que pour l abonnement : ce qui parle du mode incognito et du
// verrouillage vit ici, et se relit ensemble le jour ou la section 11 change.
//
// Deux libelles sont empruntes plutot que reecrits. Le titre de la banniere est
// celui de la ligne de reglages qui allume le mode, `Incognito`, et le titre de
// l ecran de verrouillage est celui de la ligne qui arme le verrou,
// `Verrouillage de l app`. Le meme mot pour la meme chose d un bout a l autre du
// parcours, regle d ecriture de la section 6.
//

extension Chaines {
    /// Banniere du mode incognito, section 11.
    ///
    /// La phrase ne vient pas de la section 6, qui ne dessine pas la banniere.
    /// Elle reprend les mots de la description de la carte Confidentialite du
    /// tableau 6.8, `l activite de lecture n est pas enregistree`, pour que la
    /// banniere et le reglage disent la meme chose.
    enum Incognito {
        static let titre = String(localized: "reglages.ligne.confidentialite.incognito")
        static let phrase = String(localized: "incognito.banniere.phrase")
        static let etiquette = String(localized: "incognito.banniere.etiquette")
    }

    /// Ecran de verrouillage, section 11.
    ///
    /// Aucun de ces textes n est dessine par le document. Ils suivent les regles
    /// d ecriture de la section 6 et du tableau 6.4 : voix active, le bouton dit
    /// ce qui se passe, et l erreur nomme sa cause avant d indiquer la sortie.
    enum Verrouillage {
        static let titre = String(localized: "reglages.ligne.confidentialite.verrouillageDeLApp")
        static let phrase = String(localized: "verrouillage.phrase")
        static let deverrouiller = String(localized: "verrouillage.deverrouiller")
        static let echecTitre = String(localized: "verrouillage.echec.titre")
        static let echecPhrase = String(localized: "verrouillage.echec.phrase")
        static let aucunMoyenPhrase = String(localized: "verrouillage.aucunMoyen.phrase")
        static let raison = String(localized: "verrouillage.raison")
    }
}
