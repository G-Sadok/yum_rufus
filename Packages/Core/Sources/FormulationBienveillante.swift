import Foundation

//
// FormulationBienveillante
//
// Le troisieme critere de F059 dit : aucune formulation culpabilisante dans les
// textes. Un critere ecrit comme celui la ne se verifie pas a la relecture, il
// se verifie contre une liste.
//
// La liste ci dessous est donc la definition operatoire du critere. Elle
// enumere les tournures qui reprochent quelque chose au lecteur : celles qui
// jugent un resultat, celles qui prescrivent un comportement, et celles qui
// dramatisent une serie interrompue. Un libelle qui en porte une echoue au
// test, et le critere devient une chose que le code peut prouver plutot qu une
// intention que le verdict affirme.
//
// La comparaison ignore la casse et les signes diacritiques. Le catalogue du
// projet est ecrit sans accent, mais une traduction n a pas cette contrainte et
// le controle doit tenir dans les cinq langues du tableau 6.7.
//
// Elle se fait mot a mot et non caractere a caractere. Une recherche de sous
// chaine signalerait `rate` dans `separateur`, et le controle passerait son
// temps a accuser des textes irreprochables.
//
// Deux regles d ecriture de la section 6 de DESIGN-SPEC.md sont verifiees au
// meme endroit, parce qu elles vont dans le meme sens : aucun point
// d exclamation, aucun tiret cadratin.
//

/// Controle du ton des textes, troisieme critere de F059.
public enum FormulationBienveillante {
    /// Tournures qui reprochent un resultat au lecteur.
    ///
    /// Un objectif non atteint est une information, pas une faute. Rien dans
    /// l ecran ne qualifie la journee.
    public static let jugementsProscrits = [
        "echec",
        "echoue",
        "rate",
        "manque",
        "insuffisant",
        "pas assez",
        "trop peu",
        "decevant",
        "deception",
        "dommage",
        "helas",
        "malheureusement",
        "honte",
        "paresse",
        "en retard",
        "mauvaise journee",
    ]

    /// Tournures qui prescrivent un comportement au lecteur.
    ///
    /// L ecran montre ce qui a ete lu. Il ne demande rien, ne conseille rien et
    /// ne fixe aucun devoir : l objectif est celui que l utilisateur a pose.
    public static let injonctionsProscrites = [
        "vous devez",
        "vous devriez",
        "vous auriez",
        "il faut",
        "il faudrait",
        "ne laissez pas",
        "n oubliez pas",
        "depechez",
        "plus qu un effort",
    ]

    /// Tournures qui dramatisent une serie interrompue.
    ///
    /// Une serie qui s arrete redemarre a la lecture suivante. Le vocabulaire
    /// de la perte et de la sanction est proscrit.
    public static let dramatisationsProscrites = [
        "perdu",
        "perdue",
        "brisee",
        "rompue",
        "cassee",
        "penalite",
        "sanction",
        "vous avez tout",
    ]

    /// Toutes les tournures proscrites.
    public static let tournuresProscrites =
        jugementsProscrits + injonctionsProscrites + dramatisationsProscrites

    /// Tournures proscrites presentes dans ce texte.
    public static func tournuresTrouvees(dans texte: String) -> [String] {
        let normalise = " \(motsDe(texte).joined(separator: " ")) "

        return tournuresProscrites.filter { tournure in
            normalise.contains(" \(motsDe(tournure).joined(separator: " ")) ")
        }
    }

    /// Vrai quand le texte ne porte aucune tournure proscrite, aucun point
    /// d exclamation et aucun tiret cadratin.
    public static func estBienveillante(_ texte: String) -> Bool {
        tournuresTrouvees(dans: texte).isEmpty
            && texte.contains("!") == false
            && texte.contains(tiretCadratin) == false
    }

    /// Tiret cadratin, construit par son code plutot qu ecrit en clair.
    ///
    /// Ecrit en clair, il ferait echouer le controle 4 sur ce fichier meme.
    private static let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

    /// Mots du texte, en minuscules et sans signe diacritique.
    ///
    /// Tout ce qui n est pas une lettre ou un chiffre separe deux mots, y
    /// compris l apostrophe. Le catalogue ecrit `n oubliez pas` en trois mots,
    /// une traduction pourra ecrire `n'oubliez pas` : les deux formes doivent
    /// donner la meme suite de mots.
    private static func motsDe(_ texte: String) -> [String] {
        texte
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
            .split(whereSeparator: { caractere in
                caractere.isLetter == false && caractere.isNumber == false
            })
            .map(String.init)
    }
}
