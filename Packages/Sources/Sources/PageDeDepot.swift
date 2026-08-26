import Core
import Foundation

//
// PageDeDepot
//
// Les deux pages servies par la reception Wi-Fi : celle qui demande le code, et
// celle qui recoit les fichiers.
//
// Ce sont des pages web, pas des vues de l application. Elles ne passent donc
// ni par le systeme de design ni par le catalogue de chaines, qui n existent
// pas dans un navigateur, et leurs libelles arrivent par `LibellesDeLaPageDeDepot`
// pour que la couche interface puisse les traduire le jour ou elle le voudra,
// sans que ce paquet connaisse la localisation.
//
// Aucune couleur n est ecrite ici, et c est volontaire deux fois. D abord la
// regle du projet : aucune valeur visuelle hors de DesignSystem. Ensuite le bon
// sens : la page s affiche dans le navigateur d une autre machine, dont le
// theme clair ou sombre n a aucune raison de suivre celui de l application. La
// page declare donc `color-scheme: light dark` et n emploie que les couleurs
// systeme du navigateur, qui sont deja les bonnes des deux cotes.
//
// Le formulaire de code et le formulaire de fichiers ne sont jamais servis dans
// la meme page. C est ce qui rend le code obligatoire visible dans le document
// lui meme : tant qu aucun code juste n a ete presente, le champ de fichiers
// n existe nulle part dans ce que le navigateur recoit.
//

/// Libelles de la page servie par la reception Wi-Fi.
public struct LibellesDeLaPageDeDepot: Sendable, Equatable {
    public var titre: String
    public var demandeDeCode: String
    public var champDeCode: String
    public var validerLeCode: String
    public var invitationADeposer: String
    public var champDeFichiers: String
    public var deposer: String
    public var fichiersRecus: String
    public var refus: String

    public init(
        titre: String = "Transfert Wi-Fi",
        demandeDeCode: String = "Saisis le code a six chiffres affiche sur l appareil.",
        champDeCode: String = "Code a six chiffres",
        validerLeCode: String = "Continuer",
        invitationADeposer: String = "Choisis les fichiers a envoyer vers la bibliotheque.",
        champDeFichiers: String = "Fichiers",
        deposer: String = "Envoyer",
        fichiersRecus: String = "Fichiers recus",
        refus: String = "Fichiers refuses"
    ) {
        self.titre = titre
        self.demandeDeCode = demandeDeCode
        self.champDeCode = champDeCode
        self.validerLeCode = validerLeCode
        self.invitationADeposer = invitationADeposer
        self.champDeFichiers = champDeFichiers
        self.deposer = deposer
        self.fichiersRecus = fichiersRecus
        self.refus = refus
    }
}

/// Ecriture des pages servies par la reception Wi-Fi.
enum PageDeDepot {
    /// Nom du champ du formulaire de code.
    static let champDuCode = "code"

    /// Nom du champ du formulaire de fichiers.
    static let champDesFichiers = "fichiers"

    /// La page qui demande le code, avec un refus eventuel a expliquer.
    static func demandeDeCode(_ libelles: LibellesDeLaPageDeDepot, refus: ErreurDeTransfert? = nil) -> String {
        var corps = "<p>\(echapper(libelles.demandeDeCode))</p>\n"

        corps += message(refus)
        corps += """
        <form method="post" action="\(CheminsDeLaReception.session)">
        <label for="code">\(echapper(libelles.champDeCode))</label>
        <input id="code" name="\(champDuCode)" type="text" inputmode="numeric" autocomplete="off"\
         pattern="[0-9]{\(CodeDeTransfert.nombreDeChiffres)}" maxlength="\(CodeDeTransfert.nombreDeChiffres)"\
         required autofocus>
        <button type="submit">\(echapper(libelles.validerLeCode))</button>
        </form>

        """

        return document(libelles, corps: corps)
    }

    /// La page qui recoit les fichiers, avec le resultat du dernier depot.
    static func depot(
        _ libelles: LibellesDeLaPageDeDepot,
        recus: [String] = [],
        refuses: [(nom: String, cause: ErreurDeTransfert)] = []
    ) -> String {
        var corps = "<p>\(echapper(libelles.invitationADeposer))</p>\n"

        corps += """
        <form method="post" action="\(CheminsDeLaReception.depot)" enctype="multipart/form-data">
        <label for="fichiers">\(echapper(libelles.champDeFichiers))</label>
        <input id="fichiers" name="\(champDesFichiers)" type="file" multiple required>
        <button type="submit">\(echapper(libelles.deposer))</button>
        </form>

        """

        if recus.isEmpty == false {
            corps += liste(libelles.fichiersRecus, elements: recus.map(echapper))
        }
        if refuses.isEmpty == false {
            corps += liste(
                libelles.refus,
                elements: refuses.map { echapper($0.nom) + " : " + echapper($0.cause.messageUtilisateur) }
            )
        }

        return document(libelles, corps: corps)
    }

    /// La page servie quand la requete n aboutit a rien de nommable.
    static func refus(_ libelles: LibellesDeLaPageDeDepot, cause: ErreurDeTransfert) -> String {
        document(libelles, corps: message(cause))
    }

    // MARK: Ecriture

    private static func document(_ libelles: LibellesDeLaPageDeDepot, corps: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(echapper(libelles.titre))</title>
        <style>
        :root { color-scheme: light dark; }
        body { font-family: system-ui, sans-serif; margin: 0 auto; max-width: 36rem; padding: 2rem 1rem; }
        form { display: grid; gap: 0.75rem; margin: 1.5rem 0; }
        input, button { font: inherit; padding: 0.6rem; }
        ul { padding-left: 1.2rem; }
        </style>
        </head>
        <body>
        <h1>\(echapper(libelles.titre))</h1>
        \(corps)</body>
        </html>

        """
    }

    private static func liste(_ titre: String, elements: [String]) -> String {
        var bloc = "<h2>\(echapper(titre))</h2>\n<ul>\n"

        for element in elements {
            bloc += "<li>\(element)</li>\n"
        }

        return bloc + "</ul>\n"
    }

    private static func message(_ cause: ErreurDeTransfert?) -> String {
        guard let cause else {
            return ""
        }

        return "<p role=\"alert\">\(echapper(cause.messageUtilisateur))</p>\n"
    }

    /// Echappe ce qui vient de l exterieur avant de l ecrire dans la page.
    ///
    /// Le nom d un fichier depose est reaffiche, et il vient d une autre
    /// machine. Sans cet echappement, un fichier nomme avec une balise de script
    /// ferait executer ce script dans le navigateur du deposant, sur une page
    /// servie par l appareil de l utilisateur.
    static func echapper(_ texte: String) -> String {
        texte
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

/// Les chemins servis par la reception Wi-Fi.
enum CheminsDeLaReception {
    /// La page, quel que soit l etat de la session.
    static let racine = "/"

    /// Le depot du code.
    static let session = "/session"

    /// Le depot des fichiers.
    static let depot = "/depot"
}
